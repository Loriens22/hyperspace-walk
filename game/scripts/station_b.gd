## Lesson B: slicing. Flatland analogy (sphere through a plane -> circle of radius sqrt(R^2-h^2)),
## the 3-sphere sliced at the player's w, and a tilted tesseract whose slice changes with w.
extends Station

var plane: MeshInstance3D
var ball: MeshInstance3D
var ring: MeshInstance3D
var flat_label: Label3D
var flat_node: Node3D
var hs: HyperSphere
var tslice: PolyView
var _flat_t := 0.0
var _flat_anim := false
const FR := 0.7

func _ready() -> void:
	lesson_id = "B"; requires = "A"
	build_terminal("II · Slicing", "II · Сечения")
	focus_offset = Vector3(0, 2.4, 1.0)
	flat_node = Node3D.new(); flat_node.position = Vector3(-3.4, 1.7, 0.4); add_child(flat_node)
	plane = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(2.6, 2.6); plane.mesh = pm
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/holo.gdshader")
	m.set_shader_parameter("color", Color(0.3, 1.0, 0.6)); m.set_shader_parameter("energy", 0.45); m.set_shader_parameter("base", 0.35)
	plane.material_override = m
	flat_node.add_child(plane)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = FR; sm.height = FR * 2; ball.mesh = sm
	var bm := ShaderMaterial.new(); bm.shader = preload("res://shaders/holo.gdshader")
	bm.set_shader_parameter("color", Color(1.0, 0.75, 0.3)); bm.set_shader_parameter("energy", 0.9)
	ball.material_override = bm
	flat_node.add_child(ball)
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.97; tm.outer_radius = 1.03; tm.rings = 48; tm.ring_segments = 6
	ring.mesh = tm
	var rm := ShaderMaterial.new(); rm.shader = preload("res://shaders/emit.gdshader")
	rm.set_shader_parameter("color", Color(1.0, 0.95, 0.5)); rm.set_shader_parameter("energy", 3.0)
	ring.material_override = rm
	flat_node.add_child(ring)
	flat_label = Label3D.new(); flat_label.font_size = 48; flat_label.pixel_size = 0.005; flat_label.outline_size = 10
	flat_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; flat_label.position = Vector3(0, 1.6, 0)
	flat_node.add_child(flat_label)
	var fl2 := Label3D.new(); fl2.font_size = 44; fl2.pixel_size = 0.005; fl2.outline_size = 10; fl2.modulate = Color(0.6, 1, 0.75)
	fl2.billboard = BaseMaterial3D.BILLBOARD_ENABLED; fl2.position = Vector3(0, -0.35, 1.45)
	fl2.text = "FLATLAND (Abbott 1884)"
	flat_node.add_child(fl2)
	hs = HyperSphere.new(); hs.R = 1.4; hs.position = Vector3(3.4, 2.1, 0.4)
	add_child(hs)
	var hl := Label3D.new(); hl.font_size = 44; hl.pixel_size = 0.005; hl.outline_size = 10; hl.modulate = Color(0.6, 0.9, 1)
	hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; hl.position = Vector3(3.4, 0.35, 0.4)
	hl.text = "3-SPHERE  x²+y²+z²+w² = R²,  R = 1.4"
	add_child(hl)
	tslice = PolyView.new().setup("tesseract", 1.35)
	tslice.position = Vector3(0, 2.7, -3.0)
	tslice.rot = P4.rot_plane_idx(2, 0.62) * P4.rot_plane_idx(4, 0.55) * P4.rot_plane_idx(5, 0.48) * P4.rot_plane_idx(0, 0.3)
	tslice.slice_mode = true
	tslice.show_proj_when_slicing = 0.18
	tslice.add_to_group("rotatable"); tslice.set_meta("display", G.T("tilted tesseract (slice)", "наклонен тесеракт (сечение)"))
	add_child(tslice)
	var tl := Label3D.new(); tl.font_size = 44; tl.pixel_size = 0.005; tl.outline_size = 10; tl.modulate = Color(1, 0.95, 0.6)
	tl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; tl.position = Vector3(0, 1.0, -3.0)
	tl.name = "TLabel"
	add_child(tl)
	G.lang_changed.connect(_relabel_b)

func _relabel_b() -> void:
	pass

func handle_cue(lesson: String, c: String) -> void:
	if lesson != "B": return
	if c == "flat_anim" or c == "flat_on": _flat_anim = true

func _process(delta: float) -> void:
	super._process(delta)
	_flat_t += delta * 0.45 * G.rot_speed_scale()
	var h: float = sin(_flat_t) * (FR + 0.25)
	ball.position.y = h
	var r: float = sqrt(max(FR * FR - h * h, 0.0))
	ring.visible = absf(h) < FR
	ring.scale = Vector3(max(r, 0.001), 1.0, max(r, 0.001))
	if absf(h) < FR:
		flat_label.text = "h = %+.2f   r = √(R² − h²) = %.2f" % [h, r]
	else:
		flat_label.text = "h = %+.2f   " % h + G.T("(no circle: |h| > R)", "(няма кръг: |h| > R)")
	var s: Dictionary = tslice.last_slice
	var lbl := get_node("TLabel") as Label3D
	if s.has("points"):
		var nv: int = s["points"].size()
		var nf: int = s["faces"]
		var ne: int = s["segs"].size() / 2
		if nv == 0:
			lbl.text = "w = %+.2f : " % G.player_w + G.T("empty slice", "празно сечение")
		else:
			lbl.text = "w = %+.2f :  %d " % [G.player_w, nv] + G.T("vertices", "върха") + " · %d " % ne + G.T("edges", "ръба") + " · %d " % nf + G.T("faces", "стени") + "   (V − E + F = %d)" % (nv - ne + nf)
