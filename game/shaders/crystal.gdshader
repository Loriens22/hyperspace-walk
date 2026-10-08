// Aether's semi-translucent crystalline body: fresnel rim, faceted sparkle, internal circuit glow.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.12, 0.45, 1.0, 0.55);
uniform float glow = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	vec3 q = lp * 40.0;
	float circ = step(0.92, fract(q.y + floor(q.x) * 0.37)) * step(0.5, fract(q.x * 0.5 + floor(q.z) * 0.5));
	float pulse = 0.6 + 0.4 * sin(TIME * 2.0 + lp.y * 30.0);
	ALBEDO = tint.rgb * 0.4;
	ROUGHNESS = 0.05;
	METALLIC = 0.2;
	SPECULAR = 0.9;
	EMISSION = tint.rgb * (0.25 + f * 1.6) * glow + vec3(0.35, 0.85, 1.0) * circ * pulse * 0.9 * glow;
	ALPHA = clamp(tint.a + f * 0.4, 0.0, 1.0);
}
