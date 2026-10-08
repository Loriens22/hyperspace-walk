// Surface of an object that exists only for a range of w (a "4D slab").
// presence = 1 when the player's w is inside [wmin, wmax]; ghosted grid when outside.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float presence = 1.0;
uniform float energy = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 g = abs(fract(lp * 2.0) - 0.5);
	float grid = smoothstep(0.47, 0.5, max(max(g.x, g.y), g.z));
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float scan = 0.5 + 0.5 * sin(lp.y * 18.0 - TIME * 2.5);
	float solid = 0.18 + 0.5 * grid + 0.6 * pow(f, 2.0) + 0.06 * scan;
	float ghost = (0.25 * grid * step(0.5, fract((lp.x + lp.y + lp.z) * 3.0 + TIME))) + 0.02;
	ALBEDO = color.rgb * energy * mix(ghost, solid, presence);
}
