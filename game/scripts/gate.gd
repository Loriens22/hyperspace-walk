## Puzzle: the slice lock. A tesseract is sliced by the fixed hyperplane w = 0 (in its own frame).
## The gate opens when the slice is a 1 x sqrt(2) x 1 box (tall). Solution: 45° in the yw plane (3 x 15°).
## Rotations in planes without w (xy, xz, yz) only spin the cube; xw or zw stretch the wrong axis.
extends Node3D

var lock: PolyView
var outline: MeshInstance3D
var barrier: StaticBody3D
var barrier_mat: ShaderMaterial
var lbl: Label3D
var solved := false
var hint1 := false
var hint2 := false
var intro_said := false
const LOCK_POS := Vector3(3.0, 0, 5.2)
const SZ := 1.2

func _ready() -> void:
	var arch: Node3D = (load("res://assets/arch.glb") as PackedScene).instantiate()
	add_child(arch)
	for x in [-2.3, 2.3]:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
		bs.size = Vector3(0.6, 4.6, 0.8); cs.shape = bs; sb.position = Vector3(x, 2.3, 0); sb.add_child(cs); add_child(sb)
	barrier = StaticBody3D.new()
	var cs2 := CollisionShape3D.new(); var b2 := BoxShape3D.new(); b2.size = Vector3(16, 6, 0.3); cs2.shape = b2
	barrier.add_child(cs2); barrier.position = Vector3(0, 2.5, 0)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(4.0, 4.4, 0.08); mi.mesh = bm
	mi.position = Vector3(0, -0.3, 0)
	barrier_mat = ShaderMaterial.new(); barrier_mat.shader = preload("res://shaders/wslab.gdshader")
	barrier_mat.set_shader_parameter("color", Color(1.0, 0.3, 0.6))
	mi.material_override = barrier_mat
	barrier.add_child(mi)
	add_child(barrier)
	# pedestal + lock tesseract
	var ped: Node3D = (load("res://assets/terminal.glb") as PackedScene).instantiate()
	ped.position = LOCK_POS; add_child(ped)
	lock = PolyView.new().setup("tesseract", SZ)
	lock.position = LOCK_POS + Vector3(0, 2.6, 0)
	lock.slice_mode = true; lock.slice_follow_player = false; lock.slice_h = 0.0
	lock.show_proj_when_slicing = 0.1; lock.width = 0.03
	lock.add_to_group("rotatable"); lock.set_meta("display", G.T("slice lock tesseract", "тесеракт-ключалка"))
	lock.set_meta("lock", true)
	add_child(lock)
	# target outline: 1 x sqrt2 x 1 box
	var hx := 0.5; var hy := sqrt(2.0) * 0.5; var hz := 0.5
	var c := []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				c.append(Vector4(sx * hx, sy * hy, sz * hz, 0))
	var A := []; var B := []
	for i in 8:
		for j in range(i + 1, 8):
			var d: Vector4 = c[i] - c[j]
			var nz := 0
			for k in 3:
				if absf(d[k]) > 0.001: nz += 1
			if nz == 1: A.append(c[i]); B.append(c[j])
	outline = MeshInstance3D.new(); outline.mesh = PolyView.ribbon_mesh(A, B, 1)
	var om := ShaderMaterial.new(); om.shader = preload("res://shaders/edge4d.gdshader")
	om.set_shader_parameter("mode", 3); om.set_shader_parameter("size", SZ); om.set_shader_parameter("width", 0.02)
	om.set_shader_parameter("col_near", Color(0.3, 1.0, 0.45)); om.set_shader_parameter("col_far", Color(0.3, 1.0, 0.45))
	om.set_shader_parameter("energy", 1.2)
	outline.material_override = om; outline.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	outline.position = lock.position
	add_child(outline)
	lbl = Label3D.new(); lbl.font_size = 48; lbl.pixel_size = 0.005; lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.position = LOCK_POS + Vector3(0, 4.2, 0)
	add_child(lbl)
	if G.gate_open:
		_open(true)

## Skip: set the lock to the real solution (45° in yw) and open the gate.
func solve() -> void:
	if solved: return
	lock._pend.clear(); lock.spin = []
	lock.rot = P4.rot_plane_idx(4, PI / 4.0) * lock.base_rot
	lock.turns = [0, 0, 0, 0, 3, 0]
	lock.slice_mode = true
	G.gate_open = true
	_open(false)
	G.play_sfx("door", -4.0)
	get_tree().call_group("director", "play", "lock_ok")
	G.toast.emit(G.T("GATE UNLOCKED", "ПОРТАТА Е ОТКЛЮЧЕНА"))

func _open(instant: bool) -> void:
	solved = true
	barrier.collision_layer = 0
	if instant:
		barrier.visible = false
	else:
		var tw := create_tween()
		tw.tween_method(func(v): barrier_mat.set_shader_parameter("presence", v), 1.0, 0.0, 1.5)
		tw.tween_callback(func(): barrier.visible = false)

func _process(_d: float) -> void:
	var s: Dictionary = lock.last_slice
	var bb := AABB()
	var n := 0
	if s.has("points"):
		n = s["points"].size()
		bb = P4.bbox(s["points"])
	var turns := 0
	for t in lock.turns: turns += absi(int(t))
	if solved:
		lbl.text = G.T("UNLOCKED · slice = 1 × √2 × 1", "ОТКЛЮЧЕНО · сечение = 1 × √2 × 1")
		lbl.modulate = Color(0.4, 1, 0.5)
		return
	lbl.text = G.T("SLICE LOCK  target 1.00 × 1.41 × 1.00\nnow  %.2f × %.2f × %.2f", "КЛЮЧАЛКА  цел 1.00 × 1.41 × 1.00\nсега  %.2f × %.2f × %.2f") % [bb.size.x, bb.size.y, bb.size.z]
	var ok := n == 8 and absf(bb.size.x - 1.0) < 0.03 and absf(bb.size.y - sqrt(2.0)) < 0.03 and absf(bb.size.z - 1.0) < 0.03
	if ok and lock.pending_steps() == 0:
		G.gate_open = true
		_open(false)
		G.play_sfx("success"); G.play_sfx("door", -4.0)
		get_tree().call_group("director", "play", "lock_ok")
		G.toast.emit(G.T("GATE UNLOCKED", "ПОРТАТА Е ОТКЛЮЧЕНА"))
		return
	if not G.rot_unlocked: return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and p.global_position.distance_to(global_position + LOCK_POS) < 6.5:
		if not intro_said:
			intro_said = true
			get_tree().call_group("director", "play", "lock")
		elif turns >= 3 and not hint1 and lock.pending_steps() == 0:
			hint1 = true; get_tree().call_group("director", "play", "lock_hint")
		elif turns >= 8 and not hint2 and lock.pending_steps() == 0:
			hint2 = true; get_tree().call_group("director", "play", "lock_hint2")
