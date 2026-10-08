## Lesson D: the six convex regular 4-polytopes (Schläfli 1852), each on a pedestal in a ring,
## projected live (double rotation). Labels: name, Schläfli symbol, vertex/edge/face/cell counts.
extends Station

const IDS := ["5cell", "tesseract", "16cell", "24cell", "600cell", "120cell"]
const NAMES_BG := {"5cell": "5-клетъчник", "tesseract": "тесеракт (8-клетъчник)", "16cell": "16-клетъчник", "24cell": "24-клетъчник", "600cell": "600-клетъчник", "120cell": "120-клетъчник"}
const NAMES_EN := {"5cell": "5-cell", "tesseract": "tesseract (8-cell)", "16cell": "16-cell", "24cell": "24-cell", "600cell": "600-cell", "120cell": "120-cell"}
var views := {}
var labels := {}
var peds := {}
var hl_ring: MeshInstance3D
var hl_id := ""

func _ready() -> void:
	lesson_id = "D"; requires = "C"; radius = 5.0
	focus_offset = Vector3(0, 2.8, 0)
	var center_lbl := Label3D.new(); center_lbl.font_size = 80; center_lbl.pixel_size = 0.006; center_lbl.outline_size = 14
	center_lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; center_lbl.position = Vector3(0, 5.2, 0); center_lbl.modulate = Color(0.7, 0.95, 1)
	center_lbl.name = "Title"; add_child(center_lbl)
	set_meta("title_en", "IV · The six regular polytopes"); set_meta("title_bg", "IV · Шестте правилни политопа")
	title_label = center_lbl
	for i in IDS.size():
		var id: String = IDS[i]
		var a := deg_to_rad(60.0 * i)
		var pos := Vector3(cos(a) * 5.6, 0, sin(a) * 5.6)
		var ped: Node3D = (load("res://assets/terminal.glb") as PackedScene).instantiate()
		ped.position = pos; ped.rotation.y = -a - PI / 2; add_child(ped)
		peds[id] = pos
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.55; cy.height = 1.2
		cs.shape = cy; sb.position = pos + Vector3(0, 0.6, 0); sb.add_child(cs); add_child(sb)
		var v := PolyView.new().setup(id, 1.05)
		v.position = pos + Vector3(0, 2.45, 0)
		v.spin = [[0, 0.22], [5, 0.22 * (0.6 + 0.15 * i)]]
		if id == "5cell": v.size = 1.1
		v.add_to_group("rotatable")
		var p: Dictionary = P4.poly(id)
		v.set_meta("display", "%s %s" % [NAMES_EN[id], p["schlafli"]])
		add_child(v)
		views[id] = v
		var l := Label3D.new(); l.font_size = 46; l.pixel_size = 0.005; l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.position = pos + Vector3(0, 4.05, 0)
		add_child(l); labels[id] = l
	hl_ring = MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 1.15; tm.outer_radius = 1.25; hl_ring.mesh = tm
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/emit.gdshader")
	m.set_shader_parameter("color", Color(1.0, 0.85, 0.3)); m.set_shader_parameter("energy", 2.5); m.set_shader_parameter("pulse", 0.25)
	hl_ring.material_override = m; hl_ring.visible = false
	add_child(hl_ring)
	G.lang_changed.connect(_relabel_all)
	_relabel_all()

func _relabel_all() -> void:
	_relabel()
	for id in IDS:
		var p: Dictionary = P4.poly(id)
		var nm: String = NAMES_BG[id] if G.lang == "bg" else NAMES_EN[id]
		var cnt := G.T("V %d · E %d · F %d · C %d", "В %d · Р %d · С %d · К %d") % [p["verts"].size(), p["edges"].size(), p["faces"].size(), p["cells"].size()]
		labels[id].text = "%s  %s\n%s" % [nm, p["schlafli"], cnt]

func handle_cue(lesson: String, c: String) -> void:
	if lesson != "D": return
	hl_id = ""
	match c:
		"hl_5cell": hl_id = "5cell"
		"hl_tess16": hl_id = "tesseract"
		"hl_24cell": hl_id = "24cell"
		"hl_600cell": hl_id = "600cell"
		"hl_120cell": hl_id = "120cell"
	hl_ring.visible = hl_id != ""
	if hl_id != "":
		hl_ring.position = peds[hl_id] + Vector3(0, 1.2, 0)

func focus_point() -> Vector3:
	if hl_id != "":
		var p: Vector3 = peds[hl_id]
		return global_position + p * 0.72 + Vector3(0, 3.0, 0)
	return global_position + focus_offset

func _process(delta: float) -> void:
	super._process(delta)
	if hl_id == "tesseract" and fmod(Time.get_ticks_msec() / 1000.0, 6.0) > 3.0:
		hl_ring.position = peds["16cell"] + Vector3(0, 1.2, 0)
	elif hl_id != "":
		hl_ring.position = peds[hl_id] + Vector3(0, 1.2, 0)
