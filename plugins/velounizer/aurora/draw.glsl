// Aurora: veils of light over a starry sky.

float stars(vec2 q, float scale, uint s, float density) {
    vec2 sp = q / F_time.w * scale;
    ivec2 cell = ivec2(floor(sp));
    vec2 h = hash22(cell, s);
    if (h.x > density) return 0.0;
    vec2 pos = hash22(cell, s + 91u) * 0.7 + 0.15;
    float d = length(fract(sp) - pos) * (F_time.w / scale);
    float b = h.y;
    float tw = 0.65 + 0.35 * sin(F_time.x * (1.0 + 4.0 * b) + b * 40.0);
    return smoothstep(1.6, 0.0, d) * (0.35 + 0.65 * b) * tw;
}

void main() {
    vec2 pix = px();
    float m = F_time.w;
    vec2 res = F_res.xy;
    vec2 p = (pix - res * 0.5) / m;
    p.y = -p.y;
    vec2 so = seed_off();
    float size = F_shape0.x;
    float warpP = F_shape0.y;
    float speed = F_shape0.z;
    float starP = F_shape0.w;
    float raysP = F_shape1.x;
    float glow = F_shape1.y;
    float horizon = F_shape1.z;
    float ripP = F_shape1.w;
    float sub = F_au0.x;
    float bass = F_au0.y;
    float inten = F_au2.x;
    float sg = F_au2.y;
    float kick = F_pulse.x * F_react0.x;
    float snare = F_pulse.y * F_react0.y;
    float hat = F_pulse.z * F_react0.z;
    float ft = F_phase.z * speed;

    // ripples bend the light
    vec2 disp = vec2(0.0);
    int nr = int(F_cam.w);
    for (int i = 0; i < nr; i++) {
        vec4 r = F_rip(i);
        vec2 c = rip_center(i);
        c.y = -c.y;
        vec2 d = p - c;
        float dist = length(d) + 1e-5;
        bool isK = r.w > 0.0;
        float front = r.z * (isK ? 0.6 : 0.9);
        float wdt = (isK ? 0.07 : 0.035) + r.z * 0.04;
        float env = exp(-r.z * 1.7) * exp(-pow((dist - front) / wdt, 2.0));
        disp += (d / dist) * env * abs(r.w) * (isK ? 0.035 : 0.012) * ripP;
    }
    float ang = (fract(F_time.z * 0.0137) - 0.5) * 0.6;
    vec2 q = rot(ang) * (p + disp);
    float sc = 1.0 / size;

    // warp
    vec2 w1 = vec2(fbm(q * 1.1 * sc + so + vec2(0.0, ft * 0.05), 4), fbm(q * 1.1 * sc + so.yx + vec2(ft * 0.04, 3.1), 4));
    float wamp = warpP * (0.25 + 0.75 * (0.6 * bass + 0.4 * sub) * F_react0.w + 0.2 * inten);
    vec2 r = q + w1 * wamp * 0.55;

    // sky
    vec3 col = mix(C(1), C(0), smoothstep(-0.7, 0.5, p.y));
    float neb = fbm(q * 0.9 * sc + so * 1.7 + vec2(ft * 0.01, 0.0), 5) * 0.5 + 0.5;
    col += C(4) * pow(neb, 3.0) * 0.22 * glow;
    float starsV = (stars(pix, 70.0, 11u, 0.22) + 0.6 * stars(pix, 140.0, 37u, 0.12)) * starP;

    vec3 light = vec3(0.0);
    float lum = 0.0;
    // two layers of veils
    for (int layer = 0; layer < 2; layer++) {
        float lf = float(layer);
        vec2 lo = so + vec2(lf * 13.7, lf * 7.1);
        vec2 lr = rot((fract(F_time.z * 0.31 + lf * 0.37) - 0.5) * 0.35 * lf) * r;
        float base = (horizon - 0.5) * 1.1 + lf * 0.24 + 0.34 * fbm(vec2(lr.x * 0.75 * sc, ft * 0.04 + lf * 3.0) + lo, 3) + 0.06 * gnoise(vec2(lr.x * 3.0 * sc, ft * 0.1) + lo.yx);
        float above = lr.y - base;
        // gaps in the band
        float gap = clamp(smoothstep(-0.3, 0.25, gnoise(vec2(lr.x * 0.9 * sc + lo.y, ft * 0.03 + lf * 5.0))) + 0.12, 0.0, 1.0);
        float body;
        if (above > 0.0) {
            body = exp(-above * (2.6 - 0.9 * inten + lf * 1.5));
        } else {
            body = exp(-pow(above / 0.035, 2.0));
        }
        float fx = lr.x * sc * 2.3 + 1.7 * fbm(vec2(lr.x * 0.8 * sc, lr.y * 0.4 * sc) + lo * 1.3 + vec2(ft * 0.07, 0.0), 4);
        float n1 = gnoise(vec2(fx, ft * 0.12 + lf * 3.0) + lo);
        float ridge = pow(clamp(1.0 - abs(n1) * 1.7, 0.0, 1.0), 2.5);
        float rn = gnoise(vec2(lr.x * sc * 34.0 + lo.x, ft * 0.35 + lf * 9.0)) * 0.5 + 0.5;
        float streak = mix(1.0, 0.35 + 1.1 * rn * rn, raysP);
        float I = body * (0.25 + 0.75 * ridge) * streak * (1.0 - 0.45 * lf) * gap;
        float h01 = clamp(above / 0.55, 0.0, 1.0);
        vec3 lc = mix(C(2), C(3), smoothstep(0.0, 0.55, h01));
        lc = mix(lc, C(4), smoothstep(0.45, 1.0, h01));
        if (layer == 1) lc = mix(lc, C(4), 0.5);
        light += lc * I;
        lum += I;
    }
    float bright = glow * (0.45 + 0.55 * sg * (0.4 + 0.6 * inten) + 0.55 * kick + 0.3 * bass * F_react0.w + 0.25 * F_au2.w);
    col += starsV * vec3(0.9, 0.93, 1.0) * (1.0 + 1.6 * hat) * clamp(1.0 - lum * 1.4, 0.0, 1.0);
    col += light * bright;
    // hot core in the accent colour
    col += C(5) * pow(clamp(lum, 0.0, 1.5), 3.0) * (0.15 + 0.6 * kick + 0.3 * snare) * glow;
    // shimmer at the horizon
    col += C(2) * exp(-pow((p.y - (horizon - 0.5) * 1.1 + 0.05) / 0.25, 2.0)) * 0.05 * (1.0 + kick);
    o_color = vec4(col, 1.0);
}
