## Base class for a lesson station: a terminal on a platform that starts its lesson when the player
## comes close (if the prerequisite lesson is done) and reacts to the director's cues.
class_name Station
extends Node3D

var lesson_id := ""
var requires := ""
var radius := 4.5
var focus_offset := Vector3(0, 2.2, 0)
var title_label: Label3D
var _beacon: MeshInstance3D

func build_terminal(title_en: String, title_bg: String) -> void:
	var term: Node3D = (load("res://assets/terminal.glb") as PackedScene).instantiate()
	add_child(term)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.55; cy.height = 1.2
	cs.shape = cy; cs.position.y = 0.6; col.add_child(cs); add_child(col)
	title_label = Label3D.new()
	title_label.font_size = 72; title_label.pixel_size = 0.006; title_label.outline_size = 14
	title_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	title_label.position = Vector3(0, 4.2, 0)
	title_label.modulate = Color(0.7, 0.95, 1.0)
	add_child(title_label)
	set_meta("title_en", title_en); set_meta("title_bg", title_bg)
	_beacon = MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.3; cm.height = 2.6
	_beacon.mesh = cm; _beacon.position.y = 2.4
	var bm := ShaderMaterial.new(); bm.shader = preload("res://shaders/holo.gdshader")
	bm.set_shader_parameter("color", Color(0.3, 0.9, 1.0)); bm.set_shader_parameter("energy", 0.5)
	_beacon.material_override = bm
	add_child(_beacon)
	G.lang_changed.connect(_relabel)
	_relabel()

func _relabel() -> void:
	if title_label:
		title_label.text = G.T(get_meta("title_en"), get_meta("title_bg"))

func available() -> bool:
	return lesson_id != "" and not G.lessons_done.has(lesson_id) and (requires == "" or G.lessons_done.has(requires))

func focus_point() -> Vector3:
	return global_position + focus_offset

func _process(_d: float) -> void:
	if _beacon:
		_beacon.visible = available()

func handle_cue(_lesson: String, _cue: String) -> void:
	pass

func on_lesson_finished(_lesson: String) -> void:
	pass
