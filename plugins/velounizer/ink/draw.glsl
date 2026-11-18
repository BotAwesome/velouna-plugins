// Ink on water: water gradient, pigments, pigment edges, relief.
uniform sampler2D u_sim;

float total(vec4 w) { return min(w.r + w.g + w.b + w.a, 1.0); }

void main() {
    vec2 q = px();
    vec2 uv = q / u_size;
    vec2 tp = 1.0 / vec2(textureSize(u_sim, 0));
    vec4 w = tex_tl(u_sim, uv);
    vec4 wl = tex_tl(u_sim, uv - vec2(tp.x, 0.0));
    vec4 wr = tex_tl(u_sim, uv + vec2(tp.x, 0.0));
    vec4 wu = tex_tl(u_sim, uv - vec2(0.0, tp.y));
    vec4 wd = tex_tl(u_sim, uv + vec2(0.0, tp.y));
    float th = total(w);
    float gx = total(wr) - total(wl);
    float gy = total(wd) - total(wu);

    float m = F_time.w;
    vec2 p = q / m;
    float kick = F_pulse.x * F_react0.x;
    // water: gradient and a slow shimmer
    vec3 water = mix(C(1), C(0), smoothstep(0.0, 1.0, uv.y * 0.9 + 0.05));
    float sh = fbm(p * 1.6 + seed_off() + vec2(F_phase.z * 0.04, -F_phase.z * 0.03), 4);
    water += (C(1) - C(0) + vec3(0.02)) * sh * 0.5;
    water *= 1.0 + 0.12 * kick * F_au2.y;

    vec3 inkc = (w.r * C(2) + w.g * C(3) + w.b * C(4) + w.a * C(5)) / max(th, 1e-4);
    vec3 col = mix(water, inkc, th * 0.95);

    // pigment edges
    float edge = clamp(length(vec2(gx, gy)) * 1.4, 0.0, 1.0);
    col = mix(col, col * 0.55 + water * 0.12, edge * F_shape1.w * 0.75);

    // relief and gloss
    vec3 n = normalize(vec3(-gx * 3.0, -gy * 3.0, 1.0));
    vec3 L = normalize(vec3(-0.45, -0.7, 0.55));
    float diff = dot(n, L) - L.z;
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
    float spec = pow(max(dot(n, H), 0.0), 60.0) - pow(H.z, 60.0);
    col += (diff * 0.45 + max(spec, 0.0) * 0.8) * F_shape1.z * th * (0.8 + 0.4 * kick);

    // the accent glows a little
    col += C(5) * w.a * 0.12 * (1.0 + kick);
    // drop flash
    col += C(2) * F_au2.w * 0.06;
    o_color = vec4(col, 1.0);
}
