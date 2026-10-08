// OPAQUE variant. 4D realm, solid slice of 3-cells. Each tetrahedron of a cell decomposition (CUSTOM0..3, 4D)
// meets the hyperplane a = 0 in a triangle or a quadrilateral (marching tetrahedra);
// UV.x selects the polygon corner (0..3; triangle case repeats the last corner).
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;
#include "res://shaders/realm4d.gdshaderinc"
varying vec3 vcol;
varying float valpha;
varying float vkeep;

void vertex() {
	vec4 c[4] = vec4[](to_cam(CUSTOM0), to_cam(CUSTOM1), to_cam(CUSTOM2), to_cam(CUSTOM3));
	int npos = 0;
	for (int i = 0; i < 4; i++) { if (c[i].w > 0.0) npos++; }
	vec4 P[4] = vec4[](vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0));
	vkeep = 1.0;
	if (npos == 1 || npos == 3) {
		bool lone_pos = npos == 1;
		int lone = 0;
		for (int i = 0; i < 4; i++) { if ((c[i].w > 0.0) == lone_pos) lone = i; }
		int k = 0;
		for (int j = 0; j < 4; j++) {
			if (j == lone) continue;
			vec4 a = c[lone]; vec4 b = c[j];
			P[k] = mix(a, b, a.w / (a.w - b.w));
			k++;
		}
		P[3] = P[2];
	} else if (npos == 2) {
		int ip[2] = int[](0, 0); int in_[2] = int[](0, 0); int np = 0; int nn = 0;
		for (int i = 0; i < 4; i++) {
			if (c[i].w > 0.0) { ip[np] = i; np++; } else { in_[nn] = i; nn++; }
		}
		vec4 a; vec4 b;
		a = c[ip[0]]; b = c[in_[0]]; P[0] = mix(a, b, a.w / (a.w - b.w));
		a = c[ip[0]]; b = c[in_[1]]; P[1] = mix(a, b, a.w / (a.w - b.w));
		a = c[ip[1]]; b = c[in_[1]]; P[2] = mix(a, b, a.w / (a.w - b.w));
		a = c[ip[1]]; b = c[in_[0]]; P[3] = mix(a, b, a.w / (a.w - b.w));
	} else {
		vkeep = 0.0;
	}
	int sel = int(UV.x + 0.5);
	vec4 cs = P[sel];
	vec3 v = vec3(cs.x, cs.y, -cs.z) * vkeep;
	vec3 p0 = vec3(P[0].x, P[0].y, -P[0].z); vec3 p1 = vec3(P[1].x, P[1].y, -P[1].z); vec3 p2 = vec3(P[2].x, P[2].y, -P[2].z);
	vec3 nrm = cross(p1 - p0, p2 - p0);
	float shade = length(nrm) > 1e-9 ? 0.45 + 0.55 * abs(dot(normalize(nrm), normalize(-v + vec3(0.0, 0.0, 1e-5)))) : 0.7;
	VERTEX = v;
	NORMAL = vec3(0.0, 0.0, 1.0);
	float d = length(cs.xyz);
	vcol = COLOR.rgb * shade * depth_bright(d) * energy;
	valpha = COLOR.a * alpha_mul;
}

void fragment() {
	if (vkeep < 0.5) discard;
	ALBEDO = vcol;
}
