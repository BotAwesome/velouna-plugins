// Ink marbling, one simulation step: the exact inverse mapping of all
// operations of this step, then Catmull-Rom sampling of the previous state.
// Channels: weights of colours a, b, c and the accent.
uniform sampler2D u_prev;

vec4 ink_vec(float i) {
    if (i < -0.5) return vec4(0.0);
    if (i < 0.5) return vec4(1.0, 0.0, 0.0, 0.0);
    if (i < 1.5) return vec4(0.0, 1.0, 0.0, 0.0);
    if (i < 2.5) return vec4(0.0, 0.0, 1.0, 0.0);
    return vec4(0.0, 0.0, 0.0, 1.0);
}

vec4 crw(float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    return vec4(-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0, -1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2);
}

vec4 sample_cr(vec2 q) {
    vec2 p = q - 0.5;
    vec2 fl = floor(p);
    ivec2 ip = ivec2(fl);
    vec2 f = p - fl;
    vec4 wx = crw(f.x);
    vec4 wy = crw(f.y);
    vec4 acc = vec4(0.0);
    vec4 mn = vec4(1e9);
    vec4 mx = vec4(-1e9);
    for (int j = 0; j < 4; j++) {
        vec4 row = vec4(0.0);
        for (int i = 0; i < 4; i++) {
            vec4 v = fetch_tl(u_prev, ip + ivec2(i - 1, j - 1));
            row += v * wx[i];
            if ((i == 1 || i == 2) && (j == 1 || j == 2)) {
                mn = min(mn, v);
                mx = max(mx, v);
            }
        }
        acc += row * wy[j];
    }
    return clamp(acc, mn, mx);
}

vec4 finw(vec4 w0) {
    vec4 w = clamp(w0, vec4(0.0), vec4(1.0));
    float tot = w.r + w.g + w.b + w.a;
    if (tot > 1.0) w = w / tot;
    return w;
}

void main() {
    float m = min(u_size.x, u_size.y);
    vec2 p = px() / m;
    int n = int(u_step.x);
    for (int i = n - 1; i >= 0; i--) {
        vec4 head = op_tex(i, 0);
        vec4 a = op_tex(i, 1);
        vec4 b = op_tex(i, 2);
        float kind = head.x;
        if (kind < 0.5) {
            // drop
            vec2 v = p - a.xy;
            float d2 = dot(v, v);
            float dr2 = a.z;
            if (d2 < dr2) {
                o_color = finw(ink_vec(head.y));
                return;
            }
            p = a.xy + v * sqrt(max(1.0 - dr2 / max(d2, 1e-12), 0.0));
        } else if (kind < 1.5) {
            // tine (one stroke)
            vec2 M = a.zw;
            vec2 N = vec2(-M.y, M.x);
            float d = abs(dot(p - a.xy, N));
            p -= M * b.x * b.y / (d + b.y);
        } else if (kind < 2.5) {
            // comb
            vec2 M = a.zw;
            vec2 N = vec2(-M.y, M.x);
            float sp = b.z;
            float q = dot(p - a.xy, N);
            float qm = q - sp * floor(q / sp);
            float d = min(qm, sp - qm);
            p -= M * b.x * b.y / (d + b.y);
        } else if (kind < 3.5) {
            // wave
            vec2 D = a.xy;
            vec2 P = vec2(-D.y, D.x);
            p -= D * a.z * sin(dot(p, P) * a.w + b.x);
        } else {
            // vortex
            vec2 v = p - a.xy;
            float d = length(v);
            float ang = -a.z * exp(-d / a.w);
            p = a.xy + rot(ang) * v;
        }
    }
    vec4 src = sample_cr(p * m);
    float d = u_step.y;
    o_color = finw(src * vec4(d, d, d, d * d * d));
}
