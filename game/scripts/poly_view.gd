## A 4D object (regular 4-polytope) living at a position in R^4 (node position = x,y,z; `w0` = its w).
## Draws either its 4D->3D projection (GPU, edge4d/vert4d shaders) or its exact 3D slice at the
## player's current w (CPU, P4.slice) as glowing edges + translucent faces.
class_name PolyView
extends Node3D

const EDGE_SH := preload("res://shaders/edge4d.gdshader")
const VERT_SH := preload("res://shaders/vert4d.gdshader")
const HOLO_SH := preload("res://shaders/holo.gdshader")

var poly_id := "tesseract"
var size := 1.0
var w0 := 0.0
var mode := 0              # 0 persp, 1 ortho, 2 stereo
var eye := 3.0
var morph := 0.0
var extent := Vector4.ONE
var rot := Projection.IDENTITY
var spin := []             # [[plane_idx, rad_per_sec], ...]
var spin_scale := 1.0
var slice_mode := false
var slice_follow_player := true
var slice_h := 0.0
var width := 0.025
var dot_size := 0.05
var col_near := Color(0.25, 0.95, 1.0)
var col_far := Color(1.0, 0.3, 0.85)
var energy := 1.6
var alpha := 1.0
var show_verts := true
var segs_per_edge := 6
var show_proj_when_slicing := 0.12   # faint projection ghost while slicing
var base_rot := Projection.IDENTITY
var keep_colors := false
var base_spin := []
var base_slice := false
var turns := [0, 0, 0, 0, 0, 0]       # user rotation steps per plane (15° each)

var _p: Dictionary
var _edge_mi: MeshInstance3D
var _vert_mi: MeshInstance3D
var _slice_edges_mi: MeshInstance3D
var _slice_faces_mi: MeshInstance3D
var _edge_mat: ShaderMaterial
var _vert_mat: ShaderMaterial
var _sl_edge_mat: ShaderMaterial
var _sl_face_mat: ShaderMaterial
var _last_key := ""
var last_slice := {}

func setup(id: String, sz: float = 1.0) -> PolyView:
	poly_id = id
	size = sz
	return self

func _ready() -> void:
	_p = P4.poly(poly_id)
	base_rot = rot
	base_spin = spin.duplicate()
	base_slice = slice_mode
	if not keep_colors:
		var pal: Array = G.palette()
		col_near = pal[0]; col_far = pal[1]
	G.settings_changed.connect(_on_settings)
	var small := size < 4.0
	if _p["v4"].size() > 200:
		segs_per_edge = 3; energy = 0.32; dot_size = 0.0; show_verts = false
		if small: width = min(width, 0.014)
	elif _p["v4"].size() > 50:
		segs_per_edge = 5; energy = 0.5
		if small: width = min(width, 0.016); dot_size = min(dot_size, 0.025)
		else: show_verts = false
	elif _p["v4"].size() > 20:
		energy = 1.1
	_edge_mat = ShaderMaterial.new(); _edge_mat.shader = EDGE_SH
	_vert_mat = ShaderMaterial.new(); _vert_mat.shader = VERT_SH
	_edge_mi = _mk_mi(_build_edge_mesh(), _edge_mat)
	_vert_mi = _mk_mi(_build_vert_mesh(), _vert_mat)
	_sl_edge_mat = ShaderMaterial.new(); _sl_edge_mat.shader = EDGE_SH
	_sl_face_mat = ShaderMaterial.new(); _sl_face_mat.shader = HOLO_SH
	_slice_edges_mi = _mk_mi(null, _sl_edge_mat)
	_slice_faces_mi = _mk_mi(null, _sl_face_mat)
	_push()

func _on_settings() -> void:
	if keep_colors: return
	var p2: Array = G.palette()
	col_near = p2[0]; col_far = p2[1]; _last_key = ""

func _mk_mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-6, -6, -6) * max(size, 1.0), Vector3(12, 12, 12) * max(size, 1.0))
	add_child(mi)
	return mi

static func ribbon_mesh(pairs_a: Array, pairs_b: Array, segs: int) -> ArrayMesh:
	var n := pairs_a.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var idx := PackedInt32Array()
	var nv := n * segs * 4
	verts.resize(nv); uvs.resize(nv); c0.resize(nv * 4); c1.resize(nv * 4); idx.resize(n * segs * 6)
	var vi := 0
	var ii := 0
	for e in n:
		var a: Vector4 = pairs_a[e]
		var b: Vector4 = pairs_b[e]
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var corners := [Vector2(t0, -1), Vector2(t0, 1), Vector2(t1, -1), Vector2(t1, 1)]
			for k in 4:
				verts[vi + k] = Vector3(a.x, a.y, a.z)
				uvs[vi + k] = corners[k]
				var o := (vi + k) * 4
				c0[o] = a.x; c0[o + 1] = a.y; c0[o + 2] = a.z; c0[o + 3] = a.w
				c1[o] = b.x; c1[o + 1] = b.y; c1[o + 2] = b.z; c1[o + 3] = b.w
			idx[ii] = vi; idx[ii + 1] = vi + 1; idx[ii + 2] = vi + 2
			idx[ii + 3] = vi + 2; idx[ii + 4] = vi + 1; idx[ii + 5] = vi + 3
			vi += 4; ii += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	arr[Mesh.ARRAY_INDEX] = idx
	var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var m := ArrayMesh.new()
	if n > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
	return m

static func dots_mesh(points: Array) -> ArrayMesh:
	var n := points.size()
	var verts := PackedVector3Array(); verts.resize(n * 4)
	var uvs := PackedVector2Array(); uvs.resize(n * 4)
	var c0 := PackedFloat32Array(); c0.resize(n * 16)
	var idx := PackedInt32Array(); idx.resize(n * 6)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for i in n:
		var p: Vector4 = points[i]
		for k in 4:
			var vi := i * 4 + k
			verts[vi] = Vector3(p.x, p.y, p.z)
			uvs[vi] = corners[k]
			c0[vi * 4] = p.x; c0[vi * 4 + 1] = p.y; c0[vi * 4 + 2] = p.z; c0[vi * 4 + 3] = p.w
		var b := i * 4
		idx[i * 6] = b; idx[i * 6 + 1] = b + 1; idx[i * 6 + 2] = b + 2
		idx[i * 6 + 3] = b + 2; idx[i * 6 + 4] = b + 1; idx[i * 6 + 5] = b + 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if n > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return m

func _build_edge_mesh() -> ArrayMesh:
	var v4: Array[Vector4] = _p["v4"]
	var e2: PackedInt32Array = _p["e2"]
	var A := []
	var B := []
	for k in e2.size() / 2:
		A.append(v4[e2[2 * k]]); B.append(v4[e2[2 * k + 1]])
	return ribbon_mesh(A, B, segs_per_edge)

func _build_vert_mesh() -> ArrayMesh:
	var pts := []
	for v in _p["v4"]: pts.append(v)
	return dots_mesh(pts)

var _pend := []

## Queue a user rotation of +-15 degrees in coordinate plane k (animated). Stops any auto-spin.
func queue_turn(k: int, sgn: int) -> void:
	_pend.append([k, sgn * deg_to_rad(15.0)])
	turns[k] += sgn
	spin = []

func pending_steps() -> int:
	return _pend.size()

func reset_user() -> void:
	_pend.clear()
	rot = base_rot
	spin = base_spin.duplicate()
	turns = [0, 0, 0, 0, 0, 0]
	slice_mode = base_slice
	_last_key = ""

func player_w() -> float:
	var g = get_node_or_null("/root/G")
	return g.player_w if g else 0.0

func current_h() -> float:
	return (player_w() - w0) / size if slice_follow_player else slice_h

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _pend.is_empty():
		var pe: Array = _pend[0]
		var rem: float = pe[1]
		var stp: float = signf(rem) * minf(absf(rem), delta * 2.4 * G.rot_speed_scale())
		rot = P4.rot_plane_idx(int(pe[0]), stp) * rot
		pe[1] = rem - stp
		if absf(pe[1]) < 1e-7:
			_pend.pop_front()
	if not spin.is_empty():
		var rs = get_node_or_null("/root/G")
		var k: float = spin_scale * (rs.rot_speed_scale() if rs else 1.0)
		for s in spin:
			rot = P4.rot_plane_idx(int(s[0]), float(s[1]) * delta * k) * rot
		rot = P4.orthonormalize(rot)
	_push()
	if slice_mode:
		var h := current_h()
		var key := "%s|%.4f|%s" % [str(rot), h, str(extent)]
		if key != _last_key:
			_last_key = key
			_rebuild_slice(h)

func _push() -> void:
	var proj_alpha := alpha * (show_proj_when_slicing if slice_mode else 1.0)
	for m in [_edge_mat, _vert_mat]:
		m.set_shader_parameter("rot4", rot)
		m.set_shader_parameter("extent", extent)
		m.set_shader_parameter("eye", eye)
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("morph", morph)
		m.set_shader_parameter("size", size)
		m.set_shader_parameter("col_near", col_near)
		m.set_shader_parameter("col_far", col_far)
		m.set_shader_parameter("energy", energy)
		m.set_shader_parameter("alpha", proj_alpha)
	_edge_mat.set_shader_parameter("width", width)
	_vert_mat.set_shader_parameter("dot_size", dot_size)
	_vert_mi.visible = show_verts and proj_alpha > 0.01
	_edge_mi.visible = proj_alpha > 0.01
	_slice_edges_mi.visible = slice_mode
	_slice_faces_mi.visible = slice_mode

func _rebuild_slice(h: float) -> void:
	var s := P4.slice(_p, rot, h + 0.00001, extent)
	last_slice = s
	var segs: PackedVector3Array = s["segs"]
	var A := []
	var B := []
	for i in range(0, segs.size(), 2):
		A.append(Vector4(segs[i].x, segs[i].y, segs[i].z, 0)); B.append(Vector4(segs[i + 1].x, segs[i + 1].y, segs[i + 1].z, 0))
	_slice_edges_mi.mesh = ribbon_mesh(A, B, 1)
	_sl_edge_mat.set_shader_parameter("mode", 3)
	_sl_edge_mat.set_shader_parameter("size", size)
	_sl_edge_mat.set_shader_parameter("width", width * 1.6)
	_sl_edge_mat.set_shader_parameter("col_near", Color(1.0, 0.95, 0.6))
	_sl_edge_mat.set_shader_parameter("col_far", Color(1.0, 0.95, 0.6))
	_sl_edge_mat.set_shader_parameter("energy", energy * 1.3 * alpha)
	var tris: PackedVector3Array = s["tris"]
	if tris.is_empty():
		_slice_faces_mi.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, tris.size(), 3):
		var a := tris[i] * size
		var b := tris[i + 1] * size
		var c := tris[i + 2] * size
		var nrm := (b - a).cross(c - a).normalized()
		if nrm.dot(a) < 0: nrm = -nrm
		st.set_normal(nrm); st.add_vertex(a)
		st.set_normal(nrm); st.add_vertex(b)
		st.set_normal(nrm); st.add_vertex(c)
	_slice_faces_mi.mesh = st.commit()
	_sl_face_mat.set_shader_parameter("color", col_near)
	_sl_face_mat.set_shader_parameter("energy", 0.9 * alpha)
