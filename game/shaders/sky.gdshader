// Deep-space sky: gradient, nebula and stars. `wshift` (player w / 3) tints the sky so each w-slice feels different.
shader_type sky;
uniform float wshift = 0.0;
float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float n3(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 4; i++) { s += a * n3(p); p *= 2.03; a *= 0.5; } return s; }
void sky() {
	vec3 d = EYEDIR;
	float up = d.y * 0.5 + 0.5;
	vec3 base = mix(vec3(0.004, 0.006, 0.016), vec3(0.01, 0.018, 0.045), up);
	vec3 tintA = mix(vec3(0.10, 0.25, 0.55), vec3(0.35, 0.10, 0.50), clamp(wshift * 0.5 + 0.5, 0.0, 1.0));
	vec3 tintB = mix(vec3(0.05, 0.40, 0.45), vec3(0.55, 0.15, 0.35), clamp(-wshift * 0.5 + 0.5, 0.0, 1.0));
	float neb = fbm(d * 2.2 + vec3(0.0, wshift * 0.6, 0.0));
	float neb2 = fbm(d * 4.5 - vec3(wshift * 0.4, 0.0, 1.7));
	vec3 col = base + tintA * pow(neb, 3.0) * 0.55 + tintB * pow(neb2, 4.0) * 0.4;
	vec3 sp = d * 220.0;
	float st = h3(floor(sp));
	vec3 fp = fract(sp) - 0.5;
	float star = step(0.985, st) * smoothstep(0.32, 0.0, length(fp)) * (0.5 + 0.5 * h3(floor(sp) + 3.1));
	col += vec3(0.8, 0.9, 1.0) * star * 1.4;
	// faint 4D lattice band near the horizon
	col += vec3(0.05, 0.25, 0.4) * smoothstep(0.08, 0.0, abs(d.y + 0.05)) * 0.15;
	COLOR = col;
}
