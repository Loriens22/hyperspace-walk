// Vertices of a 4-polytope: billboarded glowing dots. CUSTOM0 = 4D position, UV = quad corner.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;
uniform mat4 rot4;
uniform vec4 extent = vec4(1.0);
uniform float eye = 3.0;
uniform int mode = 0;
uniform float morph = 0.0;
uniform float size = 1.0;
uniform float dot_size = 0.06;
uniform vec4 col_near : source_color = vec4(0.25, 0.95, 1.0, 1.0);
uniform vec4 col_far : source_color = vec4(1.0, 0.25, 0.85, 1.0);
uniform float energy = 1.6;
uniform float alpha = 1.0;
varying vec3 vcol;
varying vec2 vuv;

vec3 proj(vec4 q, out float f) {
	if (mode == 3) { f = 1.0; return q.xyz; }
	if (mode == 2) {
		float r = length(q);
		vec4 s = r > 1e-5 ? q / r : vec4(0.0, 0.0, 0.0, -1.0);
		float d = max(1.0 - s.w, 0.04);
		f = 1.0 / d;
		return s.xyz / d * 0.5;
	}
	float d = max(eye - q.w, 0.15);
	f = mix(eye / d, 1.0, morph);
	if (mode == 1) f = 1.0;
	return q.xyz * f;
}

void vertex() {
	vec4 q = (mode == 3) ? CUSTOM0 : rot4 * (CUSTOM0 * extent);
	float f;
	vec3 p = proj(q, f) * size;
	vec3 v = (MODELVIEW_MATRIX * vec4(p, 1.0)).xyz;
	float s = dot_size * clamp(sqrt(f), 0.45, 2.0);
	VERTEX = v + vec3(UV * s, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	float k = (mode == 3) ? 0.5 : smoothstep(-1.0, 1.0, q.w);
	vcol = mix(col_far.rgb, col_near.rgb, k);
	vuv = UV;
}

void fragment() {
	float r2 = dot(vuv, vuv);
	if (r2 > 1.0) discard;
	float g = (1.0 - r2);
	ALBEDO = vcol * energy * (g * g * 1.6 + 0.15) * alpha;
}
