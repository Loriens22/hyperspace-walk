// 4D realm, additive glowing parts.
// kind 0: edges in the 4D Eye (CUSTOM0/1 = 4D endpoints, UV = (endpoint, side)).
// kind 1: translucent 2-faces in the 4D Eye (CUSTOM0..2 = 4D triangle, UV.x = which corner).
// kind 2: slice of 2-faces (CUSTOM0..2 = 4D triangle, UV = (endpoint 0/1, side)):
//         a triangle meets the hyperplane a = 0 in a segment, drawn as a ribbon.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;
#include "res://shaders/realm4d.gdshaderinc"
uniform int kind = 0;
varying vec3 vret;
varying vec3 vcol;
varying float vside;
varying float vkeep;

vec3 ribbon(vec3 va, vec3 vo, float side, float w) {
	vec3 dir = normalize(vo - va + vec3(1e-6, 0.0, 0.0));
	vec3 s = normalize(cross(dir, normalize(-va)) + vec3(0.0, 1e-6, 0.0));
	return va + s * side * w * max(-va.z, 0.05);
}

void vertex() {
	vkeep = 1.0; vside = UV.y; vret = vec3(0.0);
	vec3 col = COLOR.rgb;
	if (kind == 0) {
		vec4 ca = to_cam(CUSTOM0); vec4 cb = to_cam(CUSTOM1);
		if (ca.z < near_f && cb.z < near_f) { vkeep = 0.0; }
		if (ca.z < near_f) ca = mix(ca, cb, (near_f - ca.z) / (cb.z - ca.z + 1e-6));
		if (cb.z < near_f) cb = mix(cb, ca, (near_f - cb.z) / (ca.z - cb.z + 1e-6));
		vec4 cs = UV.x < 0.5 ? ca : cb; vec4 co = UV.x < 0.5 ? cb : ca;
		vec3 p = retina(cs); vec3 o = retina(co);
		vret = p;
		vec3 va = (MODELVIEW_MATRIX * vec4(p, 1.0)).xyz;
		vec3 vo = (MODELVIEW_MATRIX * vec4(o, 1.0)).xyz;
		float wpx = width * length(MODELVIEW_MATRIX[0].xyz);
		VERTEX = ribbon(va, vo, UV.y, wpx);
		float d = length(cs);
		vcol = depth_tint(col, d) * depth_bright(d) * energy * COLOR.a * vkeep;
	} else if (kind == 1) {
		vec4 c0 = to_cam(CUSTOM0); vec4 c1 = to_cam(CUSTOM1); vec4 c2 = to_cam(CUSTOM2);
		if (min(c0.z, min(c1.z, c2.z)) < near_f) vkeep = 0.0;
		vec4 cs = UV.x < 0.5 ? c0 : (UV.x < 1.5 ? c1 : c2);
		vec3 p = retina(cs) * vkeep;
		vret = p;
		VERTEX = (MODELVIEW_MATRIX * vec4(p, 1.0)).xyz;
		float d = length(cs);
		vcol = depth_tint(col, d) * depth_bright(d) * energy * COLOR.a * vkeep;
		vside = 0.0;
	} else {
		vec4 c[3] = vec4[](to_cam(CUSTOM0), to_cam(CUSTOM1), to_cam(CUSTOM2));
		vec4 P[2] = vec4[](vec4(0.0), vec4(0.0));
		int n = 0;
		for (int i = 0; i < 3; i++) {
			vec4 p0 = c[i]; vec4 p1 = c[(i + 1) % 3];
			if ((p0.w > 0.0) != (p1.w > 0.0) && n < 2) {
				P[n] = mix(p0, p1, p0.w / (p0.w - p1.w));
				n++;
			}
		}
		if (n < 2) vkeep = 0.0;
		vec4 cs = UV.x < 0.5 ? P[0] : P[1]; vec4 co = UV.x < 0.5 ? P[1] : P[0];
		vec3 va = vec3(cs.x, cs.y, -cs.z) * vkeep;
		vec3 vo = vec3(co.x, co.y, -co.z) * vkeep;
		float wpx = width * length(MODELVIEW_MATRIX[0].xyz);
		VERTEX = ribbon(va, vo, UV.y, wpx) * vkeep;
		float d = length(cs.xyz);
		vcol = col * depth_bright(d) * energy * COLOR.a * vkeep;
		vret = vec3(0.0);
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	if (vkeep < 0.5) discard;
	if (kind < 2 && any(greaterThan(abs(vret), vec3(retina_half * 1.002)))) discard;
	float soft = kind == 1 ? 1.0 : (1.0 - smoothstep(0.35, 1.0, abs(vside)));
	ALBEDO = vcol * soft * alpha_mul;
}
