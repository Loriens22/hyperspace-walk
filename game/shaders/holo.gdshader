// Translucent holographic surface (fresnel rim + scanlines), used for slices, spheres and panels.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float energy = 1.0;
uniform float rim = 2.5;
uniform float base = 0.12;
uniform float scan = 0.25;
uniform float alpha = 1.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fr = pow(f, rim);
	float s = 0.5 + 0.5 * sin(wpos.y * 60.0 - TIME * 3.0);
	ALBEDO = color.rgb * energy * alpha * (base + fr * 0.9 + scan * s * 0.15);
}
