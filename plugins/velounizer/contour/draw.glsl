// Contour: topographic lines with ripples.

void main() {
    vec2 pix = px();
    float m = F_time.w;
    vec2 res = F_res.xy;
    vec2 p = (pix - res * 0.5) / m;
    vec2 so = seed_off();
    float lines = F_shape0.x;
    float width = F_shape0.y;
    float relief = F_shape0.z;
    float scale = F_shape0.w;
    float drift = F_shape1.x;
    float fillP = F_shape1.y;
    float ripP = F_shape1.z;
    float bass = F_au0.y;
    float inten = F_au2.x;
    float sg = F_au2.y;
    float kick = F_pulse.x * F_react0.x;
    float hat = F_pulse.z * F_react0.z;
    float ft = F_phase.z * drift;

    float ang = fract(F_time.z * 0.0731) * 6.2831853;
    vec2 q = rot(ang) * p * (1.5 / scale) + so;
    q += vec2(ft * 0.035, ft * 0.022);
    q += 0.3 * vec2(fbm(q * 0.55 + vec2(0.0, ft * 0.02), 3), fbm(q * 0.55 + vec2(5.2, -ft * 0.02), 3));
    float h = fbm(q, 5) * (1.0 + 0.35 * bass * F_react0.w) + 0.5;

    float hot = 0.0;
    int nr = int(F_cam.w);
    for (int i = 0; i < nr; i++) {
        vec4 r = F_rip(i);
        vec2 c = rip_center(i);
        float d = length(p - c);
        bool isK = r.w > 0.0;
        float front = r.z * (isK ? 0.5 : 0.75);
        float wdt = (isK ? 0.05 : 0.03) + r.z * 0.035;
        float env = exp(-r.z * 1.3) * exp(-pow((d - front) / wdt, 2.0));
        h += env * abs(r.w) * ripP * (isK ? 0.085 : 0.035) * cos((d - front) * 34.0);
        hot += env * abs(r.w) * ripP;
    }

    float v = h * lines;
    float fw = max(fwidth(v), 1e-4);
    float dl = abs(fract(v + 0.5) - 0.5);
    float idx = floor(v + 0.5);
    bool major = abs(idx - 5.0 * floor(idx / 5.0 + 0.5)) < 0.5;
    float pxs = m / 1080.0;
    float wpx = width * 1.3 * pxs * (major ? 2.0 : 1.0);
    float lineA = 1.0 - smoothstep(wpx * 0.5 - 0.5, wpx * 0.5 + 0.8, dl / fw);
    // screen y grows downwards here, GL's dFdy upwards
    vec2 gh = vec2(dFdx(h), -dFdy(h)) * m;

    // terrain
    vec2 uv = pix / u_size;
    vec3 col = mix(C(1), C(0), smoothstep(0.0, 1.0, uv.y));
    float band = clamp(idx / lines, 0.0, 1.0);
    vec3 fillc = mix(C(0), C(2), smoothstep(0.15, 1.0, band));
    col = mix(col, fillc, fillP * 0.85);
    vec3 n = normalize(vec3(-gh * 0.06, 1.0));
    vec3 L = normalize(vec3(-0.5, -0.6, 0.65));
    float shade = clamp(dot(n, L) / L.z, 0.3, 1.6);
    col *= mix(1.0, shade, relief * 0.6);

    vec3 lc = mix(C(3), C(4), major ? 1.0 : 0.0);
    lc *= 0.55 + 0.35 * sg + 0.25 * inten + 0.45 * kick;
    lc = mix(lc, C(5), clamp(hot * 1.4, 0.0, 1.0));
    float la = lineA * (0.55 + 0.45 * (major ? 1.0 : 0.0));
    col = mix(col, lc, clamp(la, 0.0, 1.0));

    // hats: sparks on the lines
    float sp = hash21(ivec2(floor(pix / (3.0 * pxs))), uint(F_phase.w));
    col += C(4) * lineA * step(0.975, sp) * hat * 1.5;
    col += C(3) * F_au2.w * 0.08;
    o_color = vec4(col, 1.0);
}
