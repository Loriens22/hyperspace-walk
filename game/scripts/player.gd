## The explorer: walks in the current 3D slice (x,y,z) and translates along w (Q/E) once unlocked.
## First-person / over-the-shoulder camera toggle (V). Procedural walk cycle on the Blender model's limbs.
class_name Player
extends CharacterBody3D

const WALK := 4.2
const RUN := 7.5
const CROUCH := 2.0
const JUMP := 5.2
const GRAV := 13.0
const W_SPEED := 1.1

var yaw := 0.0
var pitch := -0.08
var third_person := true
var cam_dist := 0.0
var cam: Camera3D
var yaw_node: Node3D
var pitch_node: Node3D
var model: Node3D
var limbs := {}
var head: Node3D
var phase := 0.0
var crouching := false
var input_enabled := true
var respawn_point := Vector3(0, 0.5, 4)
var respawn_yaw := 0.0
var respawn_w := 0.0
var _step_t := 0.0
var _w_blocked_t := 0.0
var _wlocked_said := false
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var w_vel := 0.0

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new(); _capsule.radius = 0.35; _capsule.height = 1.75
	_shape.shape = _capsule; _shape.position.y = 0.875
	add_child(_shape)
	model = (load("res://assets/explorer.glb") as PackedScene).instantiate()
	model.rotation.y = PI
	add_child(model)
	for n in ["ArmL", "ArmR", "LegL", "LegR"]:
		limbs[n] = model.find_child(n, true, false)
	head = model.find_child("Head", true, false)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	yaw_node = Node3D.new(); yaw_node.position.y = 1.55; add_child(yaw_node)
	pitch_node = Node3D.new(); yaw_node.add_child(pitch_node)
	cam = Camera3D.new(); cam.fov = 72; cam.near = 0.05; cam.far = 900
	pitch_node.add_child(cam)
	cam.current = true
	_apply_cam(true)

func set_view(tp: bool) -> void:
	third_person = tp
	_apply_cam(true)

func _apply_cam(_instant: bool) -> void:
	model.visible = third_person

func _unhandled_input(e: InputEvent) -> void:
	if not G.playing or G.paused or not input_enabled: return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = float(G.settings["sens"]) * 0.01
		yaw -= e.relative.x * s
		pitch = clamp(pitch - e.relative.y * s, -1.35, 1.25)
	elif e.is_action_pressed("cam"):
		set_view(not third_person)

func _physics_process(delta: float) -> void:
	if not G.playing: return
	var active: bool = input_enabled and not G.paused
	# keyboard look fallback (arrow keys)
	if active:
		yaw -= Input.get_axis("look_left", "look_right") * delta * 2.2
	yaw_node.rotation.y = yaw
	pitch_node.rotation.x = pitch
	# camera boom (third person over-the-shoulder)
	var target_d := 3.1 if third_person else 0.0
	cam_dist = lerp(cam_dist, target_d, min(1.0, delta * 8.0))
	var boom := Vector3(0.55 * (cam_dist / 3.1), 0.25 * (cam_dist / 3.1), cam_dist)
	# keep camera from going through floors/walls
	if cam_dist > 0.1:
		var space := get_world_3d().direct_space_state
		var from := yaw_node.global_position
		var to := pitch_node.global_transform * boom
		var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit:
			boom *= max(0.15, (from.distance_to(hit.position) - 0.2) / max(from.distance_to(to), 0.01))
	cam.position = boom
	yaw_node.position.y = lerp(yaw_node.position.y, 1.0 if crouching else 1.55, min(1.0, delta * 10.0))

	var dir := Vector3.ZERO
	if active:
		var iv := Input.get_vector("left", "right", "fwd", "back")
		dir = (Basis(Vector3.UP, yaw) * Vector3(iv.x, 0, iv.y))
		if dir.length() > 1.0: dir = dir.normalized()
		crouching = Input.is_action_pressed("crouch")
	var spd := WALK
	if crouching: spd = CROUCH
	elif active and Input.is_action_pressed("run"): spd = RUN
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := 12.0 if is_on_floor() else 3.0
	hv = hv.lerp(dir * spd, min(1.0, accel * delta))
	velocity.x = hv.x; velocity.z = hv.z
	if is_on_floor():
		if active and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAV * delta
	move_and_slide()
	_shape.scale.y = 1.0
	# ---- w translation (4th dimension)
	if active:
		var wi := Input.get_axis("kata", "ana")
		if wi != 0.0 and not G.w_unlocked:
			if not _wlocked_said:
				_wlocked_said = true
				get_tree().call_group("director", "bark", "wlocked")
		elif G.w_unlocked:
			w_vel = lerp(w_vel, wi * W_SPEED * (1.6 if Input.is_action_pressed("run") else 1.0), min(1.0, delta * 8.0))
			if absf(w_vel) > 0.001:
				var nw: float = clamp(G.player_w + w_vel * delta, G.W_MIN, G.W_MAX)
				if _w_move_ok(nw):
					if absf(G.player_w - nw) > 0.0001:
						G.player_w = nw
				else:
					w_vel = 0.0
					if _w_blocked_t <= 0.0:
						_w_blocked_t = 2.0
						G.toast.emit(G.T("Blocked: something occupies that w-slice here.", "Блокирано: нещо заема това w-сечение тук."))
	_w_blocked_t -= delta
	# ---- model facing + walk cycle
	if hv.length() > 0.3:
		var face := atan2(-hv.x, -hv.z)
		model.rotation.y = lerp_angle(model.rotation.y, face + PI, min(1.0, delta * 10.0))
		phase += delta * hv.length() * 2.1
		_step_t -= delta * hv.length()
		if _step_t <= 0.0 and is_on_floor():
			_step_t = 1.6
			G.play_sfx("step", -14.0, randf_range(0.9, 1.1))
	else:
		phase = lerp(phase, round(phase / PI) * PI, min(1.0, delta * 6.0))
	var amp: float = clamp(hv.length() / RUN, 0.0, 1.0) * 0.9
	var sw := sin(phase)
	if limbs["ArmL"]: limbs["ArmL"].rotation.x = sw * amp
	if limbs["ArmR"]: limbs["ArmR"].rotation.x = -sw * amp
	if limbs["LegL"]: limbs["LegL"].rotation.x = -sw * amp
	if limbs["LegR"]: limbs["LegR"].rotation.x = sw * amp
	model.position.y = absf(cos(phase)) * 0.04 * amp - (0.35 if crouching else 0.0)
	if not is_on_floor():
		for n in ["ArmL", "ArmR"]:
			if limbs[n]: limbs[n].rotation.z = lerp(limbs[n].rotation.z, (0.6 if n == "ArmL" else -0.6), min(1.0, delta * 6.0))
	else:
		for n in ["ArmL", "ArmR"]:
			if limbs[n]: limbs[n].rotation.z = lerp(limbs[n].rotation.z, 0.0, min(1.0, delta * 6.0))
	# ---- fell into the void
	if global_position.y < -14.0:
		G.play_sfx("fall")
		respawn()
		get_tree().call_group("director", "bark", "respawn")

func _w_move_ok(nw: float) -> bool:
	var box := AABB(global_position + Vector3(-0.35, 0.05, -0.35), Vector3(0.7, 1.7, 0.7))
	for o in get_tree().get_nodes_in_group("wobjects"):
		var wo := o as WObject
		if wo.contains_w(nw) and not wo.contains_w(G.player_w) and wo.overlaps(box):
			return false
	return true

func respawn() -> void:
	global_position = respawn_point
	velocity = Vector3.ZERO
	yaw = respawn_yaw
	G.player_w = respawn_w

func forward() -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
