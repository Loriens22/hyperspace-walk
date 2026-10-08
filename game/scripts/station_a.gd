## Lesson A: point -> segment -> square -> cube -> tesseract by extrusion along x, y, z, w;
## perspective vs orthographic projection; Schlegel diagram.
extends Station

var tess: PolyView
var axes: Node3D
var _goal_extent := Vector4.ONE
var _goal_eye := 3.0
var _goal_morph := 0.0
var _tilt_goal := 0.0
var _tilt := 0.0
var info: Label3D

func _ready() -> void:
	lesson_id = "A"; requires = "intro"
	build_terminal("I · From a point to a tesseract", "I · От точка до тесеракт")
	tess = PolyView.new().setup("tesseract", 1.25)
	tess.position = Vector3(0, 2.75, 0)
	tess.width = 0.032; tess.dot_size = 0.07
	tess.spin = [[0, 0.25], [5, 0.18]]
	tess.add_to_group("rotatable"); tess.set_meta("display", "tesseract {4,3,3}")
	add_child(tess)
	axes = _make_axes()
	axes.position = Vector3(-2.6, 1.4, 0.6)
	axes.visible = false
	add_child(axes)
	info = Label3D.new(); info.font_size = 52; info.pixel_size = 0.005; info.outline_size = 10
	info.billboard = BaseMaterial3D.BILLBOARD_ENABLED; info.position = Vector3(0, 1.45, 0)
	add_child(info)

func _make_axes() -> Node3D:
	var n := Node3D.new()
	var dirs := [[Vector3(1, 0, 0), Color(1, 0.35, 0.3), "x"], [Vector3(0, 1, 0), Color(0.4, 1, 0.4), "y"],
		[Vector3(0, 0, 1), Color(0.4, 0.6, 1), "z"], [Vector3(-0.7, -0.45, -0.55).normalized(), Color(1, 0.3, 0.9), "w ⟂ x,y,z"]]
	for d in dirs:
		var A := [Vector4(0, 0, 0, 0)]; var B := [Vector4(d[0].x, d[0].y, d[0].z, 0) * 1.2]
		var mi := MeshInstance3D.new(); mi.mesh = PolyView.ribbon_mesh(A, B, 1)
		var m := ShaderMaterial.new(); m.shader = preload("res://shaders/edge4d.gdshader")
		m.set_shader_parameter("mode", 3); m.set_shader_parameter("width", 0.035)
		m.set_shader_parameter("col_near", d[1]); m.set_shader_parameter("col_far", d[1]); m.set_shader_parameter("energy", 2.0)
		mi.material_override = m; mi.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		n.add_child(mi)
		var l := Label3D.new(); l.text = d[2]; l.font_size = 64; l.pixel_size = 0.006; l.modulate = d[1]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.position = d[0] * 1.42; l.outline_size = 10
		n.add_child(l)
	return n

func handle_cue(lesson: String, c: String) -> void:
	if lesson != "A": return
	match c:
		"axes":
			axes.visible = true; tess.spin = []; tess.rot = P4.rot_plane_idx(1, 0.5) * P4.rot_plane_idx(3, 0.35)
			tess.base_rot = tess.rot
			_goal_extent = Vector4.ZERO; tess.extent = Vector4.ZERO
		"extrude0": _goal_extent = Vector4.ZERO; _set_info("0D: 1 vertex", "0D: 1 връх")
		"extrude1": _goal_extent = Vector4(1, 0, 0, 0); _set_info("1D: 2 vertices · 1 edge", "1D: 2 върха · 1 ръб")
		"extrude2": _goal_extent = Vector4(1, 1, 0, 0); _set_info("2D: 4 vertices · 4 edges", "2D: 4 върха · 4 ръба")
		"extrude3": _goal_extent = Vector4(1, 1, 1, 0); _set_info("3D: 8 v · 12 e · 6 faces", "3D: 8 в · 12 р · 6 стени")
		"extrude4":
			_goal_extent = Vector4.ONE; axes.visible = true
			_set_info("4D: 16 v · 32 e · 24 squares · 8 cubes", "4D: 16 в · 32 р · 24 квадрата · 8 куба")
		"persp":
			axes.visible = false; tess.mode = 0; _goal_morph = 0.0; _goal_eye = 3.0
			tess.rot = P4.rot_plane_idx(1, 0.5) * P4.rot_plane_idx(3, 0.35); _tilt = 0.0; _tilt_goal = 0.0
			_set_info("perspective: x' = x·d/(d − w)", "перспектива: x' = x·d/(d − w)")
		"ortho":
			_goal_morph = 1.0; _set_info("orthographic: (x,y,z,w) ↦ (x,y,z)", "ортогонална: (x,y,z,w) ↦ (x,y,z)")
		"ortho_tilt":
			_tilt_goal = 0.45; _set_info("orthographic, tilted 26° in xw", "ортогонална, наклон 26° в xw")
		"schlegel":
			_goal_morph = 0.0; _goal_eye = 1.35; _tilt_goal = 0.0
			_set_info("Schlegel diagram (4D eye close to a cell)", "Диаграма на Шлегел (4D окото близо до клетка)")
		"slice_hint", "unlock_w":
			_goal_eye = 3.0; tess.spin = [[0, 0.25], [5, 0.18]]; _set_info("", "")
			if c == "unlock_w":
				G.w_unlocked = true
				G.play_sfx("unlock")
				G.toast.emit(G.T("W-MOVEMENT UNLOCKED  ·  E = ana (+w)   Q = kata (−w)", "ДВИЖЕНИЕ ПО W ОТКЛЮЧЕНО  ·  E = ана (+w)   Q = ката (−w)"))
				G.changed.emit()

func _set_info(en: String, bg: String) -> void:
	info.text = G.T(en, bg)

func _process(delta: float) -> void:
	super._process(delta)
	var k: float = min(1.0, delta * 1.6)
	tess.extent = tess.extent.lerp(_goal_extent, k)
	tess.eye = lerp(tess.eye, _goal_eye, k)
	tess.morph = lerp(tess.morph, _goal_morph, k)
	var nt: float = lerp(_tilt, _tilt_goal, k)
	if absf(nt - _tilt) > 0.00001:
		tess.rot = P4.rot_plane_idx(2, nt - _tilt) * tess.rot
		_tilt = nt

func on_lesson_finished(lesson: String) -> void:
	if lesson == "A":
		_goal_extent = Vector4.ONE; _goal_morph = 0.0; _goal_eye = 3.0; axes.visible = false
