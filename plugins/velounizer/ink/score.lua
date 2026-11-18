-- Tinte / Ink: the marbling score (port of SunoViz's InkScore).
-- Kicks set rings in a well that moves per bar, snares splash, hats dot,
-- note onsets set pale rings, sections bring strokes, combs and vortices,
-- the bass drives a slow current.

local A, B, C, ACC, CLEAR = 0, 1, 2, 3, -1
local DROP, TINE, COMB, WAVE, VORTEX = 0, 1, 2, 3, 4

local song, seed, P, R, aw, ah
local acts, starts, max_dur, flow_dirs = {}, {}, 0, {}
local energy = { calm = 0.25, groove = 0.6, build = 0.75, drop = 1.0 }

local function kind_at(t)
  local k = song:section(t)
  return k or "groove"
end

local function section_energy(t)
  local e = function(x)
    local k = song:section(x)
    return k and energy[k] or 0.6
  end
  return (e(t - 0.6) + 2 * e(t) + e(t + 0.6)) * 0.25
end

local function gain(t)
  local d = R.dynamics
  return 1 - d + d * section_energy(t)
end

local function well_center(t)
  local bar = song:bar_index(t)
  local r = velouna.rng(velouna.hash2(seed ~ 0xA11CE, bar))
  return r:range(0.14 * aw, 0.86 * aw), r:range(0.16 * ah, 0.84 * ah)
end

local function ease(e, u)
  if u < 0 then u = 0 elseif u > 1 then u = 1 end
  if e == "out" then return 1 - (1 - u) ^ 3
  elseif e == "inout" then return u * u * (3 - 2 * u)
  elseif e == "in" then return u * u * u end
  return u
end

local n_push = 0
local function push(t, dur, e, op)
  n_push = n_push + 1
  op.t, op.dur, op.e, op.n = t, dur, e, n_push
  acts[#acts + 1] = op
end
local function drop(x, y, r2, ink) return { DROP, ink, x, y, r2 } end
local function tine(x, y, mx, my, z, lam) return { TINE, x, y, mx, my, z, lam } end
local function comb(x, y, mx, my, z, lam, sp) return { COMB, x, y, mx, my, z, lam, sp } end
local function wave(dx, dy, amp, freq, phase) return { WAVE, dx, dy, amp, freq, phase } end
local function vortex(x, y, theta, lam) return { VORTEX, x, y, theta, lam } end

-- 12 numbers per operation: head (kind, ink, 0, 0), a, b
local function encode(out, op, k)
  local n = #out
  local kind = op[1]
  local v
  if kind == DROP then v = { 0, op[2], 0, 0, op[3], op[4], op[5] * k, 0, 0, 0, 0, 0 }
  elseif kind == TINE then v = { 1, 0, 0, 0, op[2], op[3], op[4], op[5], op[6] * k, op[7], 0, 0 }
  elseif kind == COMB then v = { 2, 0, 0, 0, op[2], op[3], op[4], op[5], op[6] * k, op[7], op[8], 0 }
  elseif kind == WAVE then v = { 3, 0, 0, 0, op[2], op[3], op[4] * k, op[5], op[6], 0, 0, 0 }
  else v = { 4, 0, 0, 0, op[2], op[3], op[4] * k, op[5], 0, 0, 0, 0 } end
  for i = 1, 12 do out[n + i] = v[i] end
end

function build(s, ctx)
  song, seed, P, R, aw, ah = s, ctx.seed, ctx.params, ctx.react, ctx.aw, ctx.ah
  local size, combs, vort, start = P.size, P.combs, P.vortex, P.start
  local r = velouna.rng(seed)
  local rx = function(rr, m) return rr:range(m * aw, (1 - m) * aw) end
  local ry = function(rr, m) return rr:range(m * ah, (1 - m) * ah) end

  -- start pattern from the seed (the "background")
  local n0 = math.floor(7 * start + 0.5)
  local style = r:below(3)
  for i = 0, n0 - 1 do
    local x, y = rx(r, 0.05), ry(r, 0.05)
    local rings = 2 + r:below(4)
    local rad = r:range(0.05, 0.13) * math.sqrt(size)
    for k = 0, rings - 1 do
      local ink = (k % 2 == 1) and CLEAR or ({ A, B, C })[(i + k // 2) % 3 + 1]
      push(0, 0, "lin", drop(x, y, rad * rad, ink))
      rad = rad * r:range(0.55, 0.8)
    end
  end
  if n0 > 0 then
    for _ = 1, 1 + style do
      local ang = r:range(0, 2 * math.pi)
      local mx, my = math.cos(ang), math.sin(ang)
      local which = r:below(3)
      if which == 0 then
        local x, y = rx(r, 0.2), ry(r, 0.2)
        local z = r:range(0.04, 0.09)
        push(0, 0, "lin", comb(x, y, mx, my, z, 0.012, r:range(0.06, 0.12)))
      elseif which == 1 then
        local x, y = rx(r, 0.2), ry(r, 0.2)
        push(0, 0, "lin", tine(x, y, mx, my, r:range(0.1, 0.25), 0.04))
      else
        local x, y = rx(r, 0.25), ry(r, 0.25)
        local th = r:range(-2.5, 2.5)
        push(0, 0, "lin", vortex(x, y, th, r:range(0.12, 0.3)))
      end
    end
    if style == 2 then
      local amp = r:range(0.02, 0.05)
      local fq = r:range(6, 14)
      push(0, 0, "lin", wave(1, 0, amp, fq, r:range(0, 6.28)))
    end
  end

  -- kicks: rings in the bar's well
  local ring = { A, CLEAR, B, CLEAR, C, CLEAR, A, CLEAR, B, ACC, CLEAR }
  local ri, last_bar = 0, -1
  local kicks = song:hits("kick")
  for k, h in ipairs(kicks) do
    local g = gain(h.t) * R.kick
    if h.s * g >= 0.14 then
      local bar = song:bar_index(h.t)
      if bar ~= last_bar then
        ri = (velouna.hash2(seed, bar) % 3) * 2
        last_bar = bar
      end
      local x, y = well_center(h.t)
      local rr = velouna.rng(velouna.hash2(seed, k - 1))
      local rad = (0.035 + 0.06 * h.s) * size * (0.6 + 0.4 * math.min(g, 1.4))
      local ink = ring[ri % #ring + 1]
      if ink == ACC and kind_at(h.t) ~= "drop" then ink = CLEAR end
      ri = ri + 1
      local nx = kicks[k + 1]
      local next = nx and (nx.t - h.t - 0.02) or 1.0
      local dx, dy = rr:range(-0.012, 0.012), rr:range(-0.012, 0.012)
      push(h.t, math.min(math.max(next, 0.04), 0.22), "out", drop(x + dx, y + dy, rad * rad, ink))
    end
  end

  -- snares: splashes
  for k, h in ipairs(song:hits("snare")) do
    local g = gain(h.t) * R.snare
    local s2 = h.s * g
    if s2 >= 0.2 then
      local rr = velouna.rng(velouna.hash2(seed ~ 0x5A5E, k - 1))
      local cx, cy = rx(rr, 0.1), ry(rr, 0.12)
      local n = 3 + math.floor(s2 * 3)
      local drop_sec = kind_at(h.t) == "drop"
      for _ = 1, n do
        local rad = rr:range(0.007, 0.02) * size * (0.7 + 0.5 * s2)
        local ang = rr:range(0, 6.283)
        local d = rr:range(0, 0.07) * (0.6 + 0.6 * s2)
        local ink
        if drop_sec and rr:chance(0.07) then ink = ACC else ink = ({ A, B, C })[rr:below(3) + 1] end
        local dt = rr:range(0, 0.03)
        push(h.t + dt, 0.12, "out", drop(cx + math.cos(ang) * d, cy + math.sin(ang) * d, rad * rad, ink))
      end
    end
  end

  -- hats: fine dots, only in lively parts
  if R.hats > 0.01 then
    for k, h in ipairs(song:hits("hat")) do
      if kind_at(h.t) ~= "calm" and h.s * R.hats * gain(h.t) >= 0.35 then
        local rr = velouna.rng(velouna.hash2(seed ~ 0x4A7, k - 1))
        local rad = rr:range(0.003, 0.006) * math.sqrt(size)
        local x, y = rx(rr, 0.05), ry(rr, 0.05)
        push(h.t, 0.05, "out", drop(x, y, rad * rad, rr:chance(0.5) and A or B))
      end
    end
  end

  -- note onsets: pale rings of four drops
  if R.keys > 0.01 then
    local last = -10
    for k, h in ipairs(song:hits("tonal")) do
      if h.t - last >= 0.7 and h.s * R.keys >= 0.4 then
        last = h.t
        local rr = velouna.rng(velouna.hash2(seed ~ 0x6E75, k - 1))
        local cx, cy = rx(rr, 0.12), ry(rr, 0.12)
        local rr0 = rr:range(0.03, 0.06)
        local a0 = rr:range(0, 6.28)
        for q = 0, 3 do
          local ang = a0 + q * math.pi / 2
          local rad = 0.011 * size * (0.7 + 0.6 * h.s)
          push(h.t + q * 0.03, 0.3, "out", drop(cx + math.cos(ang) * rr0, cy + math.sin(ang) * rr0, rad * rad, A))
        end
      end
    end
  end

  -- bar gestures per section
  local bl = song.beat_period * 4
  for bi0, bt in ipairs(song:downbeats()) do
    local bi = bi0 - 1
    local kind = kind_at(bt + 0.05)
    local rr = velouna.rng(velouna.hash2(seed ~ 0xBA5, bi))
    local g = gain(bt)
    if kind == "drop" and combs > 0 then
      if bi % 2 == 0 then
        local horiz = (bi // 2) % 2 == 0
        local mx, my
        if horiz then mx, my = (rr:chance(0.5) and 1 or -1), 0 else mx, my = 0, (rr:chance(0.5) and 1 or -1) end
        local x, y = rx(rr, 0.2), ry(rr, 0.2)
        push(bt, bl * 0.9, "inout", tine(x, y, mx, my, 0.13 * combs * g, 0.03))
      end
      if bi % 4 == 3 then
        local ang = rr:range(0, 6.28)
        local x, y = rx(rr, 0.3), ry(rr, 0.3)
        push(bt, bl * 0.5, "inout", comb(x, y, math.cos(ang), math.sin(ang), 0.035 * combs, 0.009, 0.07))
      end
      if bi % 2 == 1 then
        local fq = rr:range(5, 9)
        push(bt, bl, "inout", wave(0, 1, 0.025 * combs * g, fq, rr:range(0, 6.28)))
      end
    elseif kind == "groove" and combs > 0 and bi % 4 == 0 then
      local ang = rr:range(0, 6.28)
      local x, y = rx(rr, 0.2), ry(rr, 0.2)
      push(bt, bl * 1.5, "inout", tine(x, y, math.cos(ang), math.sin(ang), 0.08 * combs, 0.035))
    elseif kind == "calm" and vort > 0 and bi % 8 == 0 then
      local x, y = rx(rr, 0.3), ry(rr, 0.3)
      push(bt, bl * 8, "inout", vortex(x, y, rr:range(-1, 1) * vort, 0.3))
    end
  end

  -- build-up: one vortex over its length; drop start: a big clear drop
  local sections = song:sections()
  for si0, s2 in ipairs(sections) do
    local si = si0 - 1
    local rr = velouna.rng(velouna.hash2(seed ~ 0xB11D, si))
    if s2.kind == "build" and vort > 0 then
      local dir = rr:chance(0.5) and 1 or -1
      local x = aw * 0.5 + rr:range(-0.2, 0.2)
      local y = ah * 0.5 + rr:range(-0.15, 0.15)
      push(s2.start, s2.stop - s2.start, "in", vortex(x, y, dir * 3.8 * vort, 0.32))
    end
    local prev_drop = si > 0 and sections[si0 - 1].kind == "drop"
    if s2.kind == "drop" and not prev_drop and si > 0 then
      local x = aw * 0.5 + rr:range(-0.1, 0.1)
      local y = ah * 0.5 + rr:range(-0.08, 0.08)
      local r1 = 0.26 * math.sqrt(size)
      push(s2.start, 0.34, "out", drop(x, y, r1 * r1, CLEAR))
      local r2 = 0.085 * math.sqrt(size)
      push(s2.start + 0.36, 0.28, "out", drop(x, y, r2 * r2, ACC))
      local r3 = 0.07 * math.sqrt(size)
      push(s2.start + 0.66, 0.22, "out", drop(x, y, r3 * r3, CLEAR))
    end
  end

  -- every section change (except into a drop) brings a seed pattern back
  for si0, s2 in ipairs(sections) do
    local si = si0 - 1
    if si > 0 and s2.kind ~= "drop" and start > 0 then
      local rr = velouna.rng(velouna.hash2(seed ~ 0x5EC7, si))
      local n = math.floor(3 * start + 0.5)
      for i = 0, n - 1 do
        local x, y = rr:range(0.1 * aw, 0.9 * aw), rr:range(0.12 * ah, 0.88 * ah)
        local rings = 2 + rr:below(3)
        local rad = rr:range(0.05, 0.1) * math.sqrt(size)
        local t0 = s2.start + i * 0.6
        for k = 0, rings - 1 do
          local ink = (k % 2 == 1) and CLEAR or ({ A, B, C })[(i + k // 2 + si) % 3 + 1]
          push(t0 + k * 0.14, 0.12, "out", drop(x, y, rad * rad, ink))
          rad = rad * rr:range(0.55, 0.8)
        end
      end
      local ang = rr:range(0, 6.283)
      local z = rr:range(0.03, 0.06)
      push(s2.start + 0.6, 2.5, "inout", comb(aw * 0.5, ah * 0.5, math.cos(ang), math.sin(ang), z, 0.012, rr:range(0.08, 0.13)))
    end
  end

  table.sort(acts, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.n < b.n
  end)
  for _, a in ipairs(acts) do
    if a.dur > max_dur then max_dur = a.dur end
    starts[#starts + 1] = a.t
  end
  local fr = velouna.rng(seed ~ 0xF10)
  local a1 = fr:range(0, 6.28)
  local a2 = a1 + math.pi / 2 + fr:range(-0.4, 0.4)
  local f1, p1 = fr:range(5, 8), fr:range(0, 6.28)
  local f2, p2 = fr:range(3, 6), fr:range(0, 6.28)
  flow_dirs = { { math.cos(a1), math.sin(a1), f1, p1 }, { math.cos(a2), math.sin(a2), f2, p2 } }
end

-- first index with start time >= t
local function lower_bound(t)
  local lo, hi = 1, #starts + 1
  while lo < hi do
    local mid = (lo + hi) // 2
    if starts[mid] < t then lo = mid + 1 else hi = mid end
  end
  return lo
end

local CAP = (64 - 2) * 12

function step(t0, dt, first)
  local t1 = t0 + dt
  local out = {}
  if first and t0 > 0 then
    -- restarted inside the song: lay down the start pattern again
    for i = 1, #acts do
      local a = acts[i]
      if a.t > 0 or #out >= CAP then break end
      if a.dur <= 0 then encode(out, a, 1) end
    end
  end
  for i = lower_bound(t0 - max_dur - dt), #acts do
    local a = acts[i]
    if a.t >= t1 or #out >= CAP then break end
    local k
    if a.dur <= 0 then
      k = ((a.t >= t0 and a.t < t1) or (t0 <= 0 and a.t <= 0)) and 1 or 0
    else
      k = ease(a.e, (t1 - a.t) / a.dur) - ease(a.e, (t0 - a.t) / a.dur)
    end
    if k > 1e-6 then encode(out, a, k) end
  end
  -- current: two slow waves, strength from sub and bass
  local sub, bass = song:env("sub", t0), song:env("bass", t0)
  local strength = P.flow * (0.006 + 0.05 * (0.6 * sub + 0.4 * bass) * R.bass * gain(t0)) * dt
  for i, f in ipairs(flow_dirs) do
    local drift = t0 * (0.05 + 0.03 * (i - 1)) + (seed % 7)
    encode(out, wave(f[1], f[2], strength * (1 - 0.35 * (i - 1)), f[3], f[4] + drift), 1)
  end
  -- decay per step: how long ink lives, by section; everything sinks at the end
  local mult = ({ calm = 1.25, build = 0.9, drop = 0.75 })[kind_at(t0)] or 1.0
  local life = P.life * mult
  local sink = (t0 > song.dur - 4) and 4 or 1
  return out, math.exp(-dt * sink / math.max(life, 0.5))
end
