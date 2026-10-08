// Shared code for the 4D realm (see docs/MATH.md, "The 4D realm").
// A 4D observer has position cam_pos and an orthonormal basis (columns of cam_basis):
//   R = right, U = up, F = forward (view direction), A = ana (the observer's own 4th axis).
// Camera coordinates of a world point p:  c = E^T (p - cam_pos) = (r, u, f, a).
// 4D Eye: perspective projection onto a 3D retina,  retina = (r, u, a) * focal / f   (f > near).
// Slice: the observer's 3D hyperplane a = 0; points there are shown at (r, u, -f) in view space.
uniform mat4 cam_basis = mat4(1.0);
uniform vec4 cam_pos = vec4(0.0);
uniform mat4 obj_rot = mat4(1.0);
uniform vec4 obj_pos = vec4(0.0);
uniform float obj_scale = 1.0;
uniform float focal = 1.1;
uniform float retina_half = 1.0;
uniform float near_f = 0.12;
uniform float fog_dist = 16.0;
uniform float fog_on = 1.0;
uniform float width = 0.0035;
uniform float energy = 1.0;
uniform float alpha_mul = 1.0;

vec4 to_cam(vec4 p) {
	vec4 wp = obj_rot * (p * obj_scale) + obj_pos;
	return (wp - cam_pos) * cam_basis;   // row-vector * matrix = E^T (wp - cam_pos)
}

vec3 retina(vec4 c) {
	return vec3(c.x, c.y, c.w) * (focal * retina_half / max(c.z, near_f));
}

float depth_bright(float d) {
	return mix(1.0, clamp(1.35 * exp(-d / fog_dist), 0.04, 1.35), fog_on);
}

// colour by 4D depth: near = object colour (whitened), far = deep violet-blue
vec3 depth_tint(vec3 col, float d) {
	float k = clamp(d / (fog_dist * 2.5), 0.0, 1.0);
	vec3 nearc = mix(col, vec3(1.0), 0.08);
	vec3 farc = mix(col * 0.6, vec3(0.3, 0.25, 0.95) * length(col) * 0.6, 0.6);
	return mix(nearc, farc, k * fog_on);
}
