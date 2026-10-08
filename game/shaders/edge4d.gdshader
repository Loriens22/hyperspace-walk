// Edges of a 4-polytope drawn as camera-facing glowing ribbons.
// Each ribbon vertex stores both 4D endpoints (CUSTOM0, CUSTOM1), the parameter t along the edge (UV.x)
// and the ribbon side (UV.y). The 4D rotation and the 4D->3D projection run here on the GPU.
// Projection models (see docs/MATH.md): perspective x' = x*d/(d-w), orthographic x' = x,
// stereographic (edge points pushed onto the unit 3-sphere, then projected from the pole w=1).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;

uniform mat4 rot4;                 // 4x4 rotation in R^4 (columns)
uniform vec4 extent = vec4(1.0);   // per-axis scale before rotation (extrusion animation)
uniform float eye = 3.0;           // 4D eye distance on the w axis (perspective)
uniform int mode = 0;              // 0 perspective, 1 orthographic, 2 stereographic, 3 raw 3D (slice)
uniform float morph = 0.0;         // blend between perspective (0) and orthographic (1)
uniform float size = 1.0;          // world size of radius 1
uniform float width = 0.025;
uniform vec4 col_near : source_color = vec4(0.25, 0.95, 1.0, 1.0);
uniform vec4 col_far : source_color = vec4(1.0, 0.25, 0.85, 1.0);
uniform float energy = 1.6;
uniform float alpha = 1.0;
varying vec3 vcol;
varying float vside;
varying float vfade;

vec4 rotp(vec4 p) { return rot4 * (p * extent); }

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
	float fp = eye / d;
	f = mix(fp, 1.0, morph);
	if (mode == 1) f = 1.0;
	return q.xyz * f;
}

void vertex() {
	vec4 a = CUSTOM0;
	vec4 b = CUSTOM1;
	float t = UV.x;
	float dt = t < 0.98 ? 0.02 : -0.02;
	vec4 qa = (mode == 3) ? mix(a, b, t) : rotp(mix(a, b, t));
	vec4 qb = (mode == 3) ? mix(a, b, t + dt) : rotp(mix(a, b, t + dt));
	float fa; float fb;
	vec3 pa = proj(qa, fa) * size;
	vec3 pb = proj(qb, fb) * size;
	vec3 va = (MODELVIEW_MATRIX * vec4(pa, 1.0)).xyz;
	vec3 vb = (MODELVIEW_MATRIX * vec4(pb, 1.0)).xyz;
	vec3 dir = normalize((vb - va) * sign(dt) + vec3(1e-6, 0.0, 0.0));
	vec3 side = normalize(cross(dir, normalize(-va)) + vec3(0.0, 1e-6, 0.0));
	float w = width * clamp(sqrt(fa), 0.45, 2.2);
	VERTEX = va + side * UV.y * w;
	NORMAL = vec3(0.0, 0.0, 1.0);
	float k = (mode == 3) ? 0.5 : smoothstep(-1.0, 1.0, qa.w);
	vcol = mix(col_far.rgb, col_near.rgb, k);
	vside = UV.y;
	vfade = (mode == 2) ? clamp(1.6 / (0.6 + dot(pa, pa) / (size * size)), 0.0, 1.0) : 1.0;
}

void fragment() {
	float core = 1.0 - vside * vside;
	float glow = core * core;
	ALBEDO = vcol * energy * (0.35 + 0.9 * glow) * alpha * vfade;
}
