-- Ripples for Aurora and Contour (port of SunoViz's `ripples`): kicks send
-- rings from a well that moves every bar, snares from scattered points.
-- frame(t) returns up to 16 rings { x, y, age, strength } in min-side
-- units, origin top left; snare rings have a negative strength.

local song, seed, R, aw, ah
local kicks, snares = {}, {}
local energy = { calm = 0.25, groove = 0.6, build = 0.75, drop = 1.0 }

local function gain(t)
  local e = function(x)
    local k = song:section(x)
    return k and energy[k] or 0.6
  end
  local d = R.dynamics
  return 1 - d + d * (e(t - 0.6) + 2 * e(t) + e(t + 0.6)) * 0.25
end

local function well_center(t)
  local r = velouna.rng(velouna.hash2(seed ~ 0xA11CE, song:bar_index(t)))
  return r:range(0.14 * aw, 0.86 * aw), r:range(0.16 * ah, 0.84 * ah)
end

function build(s, ctx)
  song, seed, R, aw, ah = s, ctx.seed, ctx.react, ctx.aw, ctx.ah
  -- Everything that does not depend on the frame time, once per song.
  for k, h in ipairs(song:hits("kick")) do
    local x, y = well_center(h.t)
    local r = velouna.rng(velouna.hash2(seed, k - 1))
    local dx = r:range(-0.05, 0.05)
    local dy = r:range(-0.05, 0.05)
    kicks[k] = { t = h.t, s = h.s * R.kick * gain(h.t), x = x + dx, y = y + dy }
  end
  for k, h in ipairs(song:hits("snare")) do
    local r = velouna.rng(velouna.hash2(seed ~ 0x5A5E, k - 1))
    local x = r:range(0.1 * aw, 0.9 * aw)
    local y = r:range(0.12 * ah, 0.88 * ah)
    snares[k] = { t = h.t, s = h.s * R.snare * gain(h.t), x = x, y = y }
  end
end

-- number of hits at or before t
local function upto(list, t)
  local lo, hi = 1, #list + 1
  while lo < hi do
    local mid = (lo + hi) // 2
    if list[mid].t <= t then lo = mid + 1 else hi = mid end
  end
  return lo - 1
end

function frame(t)
  local out = {}
  for k = upto(kicks, t), 1, -1 do
    local h = kicks[k]
    local age = t - h.t
    if age > 3.2 or #out >= 10 then break end
    if h.s >= 0.12 then out[#out + 1] = { h.x, h.y, age, h.s } end
  end
  local ns = 0
  for k = upto(snares, t), 1, -1 do
    local h = snares[k]
    local age = t - h.t
    if age > 1.6 or ns >= 6 or #out >= 16 then break end
    if h.s >= 0.15 then
      out[#out + 1] = { h.x, h.y, age, -h.s }
      ns = ns + 1
    end
  end
  return { rip = out }
end
