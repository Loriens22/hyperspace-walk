## Aether, the floating crystalline companion. Follows the player at shoulder height with a weightless
## spring motion, faces the player (or a point of interest), leaves a particle trail, pulses while speaking.
class_name Aether
extends Node3D

var player: Player
var focus_point = null          # Vector3 or null: hover near this point (lesson holograms)
var speaking := false
var vel := Vector3.ZERO
var _t := 0.0
var _model: Node3D
var _rings: Array[Node3D] = []
var _fins: Node3D
var _core_mat: ShaderMaterial
var _eye_mat: ShaderMaterial
var _body_mat: ShaderMaterial
var _light: OmniLight3D
var _trail: CPUParticles3D

func _ready() -> void:
	_model = (load("res://assets/aether.glb") as PackedScene).instantiate()
	_model.scale = Vector3.ONE * 1.25
	add_child(_model)
	_body_mat = ShaderMaterial.new(); _body_mat.shader = preload("res://shaders/crystal.gdshader")
	_core_mat = ShaderMaterial.new(); _core_mat.shader = preload("res://shaders/emit.gdshader")
	_core_mat.set_shader_parameter("color", Color(0.45, 0.9, 1.0)); _core_mat.set_shader_parameter("energy", 3.0)
	_eye_mat = ShaderMaterial.new(); _eye_mat.shader = preload("res://shaders/emit.gdshader")
	_eye_mat.set_shader_parameter("color", Color(0.75, 1.0, 1.0)); _eye_mat.set_shader_parameter("energy", 2.5)
	var ring_mat := ShaderMaterial.new(); ring_mat.shader = preload("res://shaders/emit.gdshader")
	ring_mat.set_shader_parameter("color", Color(0.2, 0.55, 1.0)); ring_mat.set_shader_parameter("energy", 1.8)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var n := String(m.name)
		var par := String(m.get_parent().name)
		var key := n + "|" + par
		if key.contains("Body"): m.material_override = _body_mat
		elif key.contains("Core") or key.contains("Thruster"): m.material_override = _core_mat
		elif key.contains("Eye"): m.material_override = _eye_mat
		elif key.contains("Ring"): m.material_override = ring_mat
	for n in ["Ring1", "Ring2"]:
		var r := _model.find_child(n, true, false)
		if r: _rings.append(r)
	_fins = _model.find_child("Fins", true, false)
	_light = OmniLight3D.new(); _light.light_color = Color(0.35, 0.7, 1.0); _light.light_energy = 1.2
	_light.omni_range = 3.5; _light.shadow_enabled = false
	add_child(_light)
	_trail = CPUParticles3D.new()
	_trail.amount = 48; _trail.lifetime = 1.4; _trail.local_coords = false
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _trail.emission_sphere_radius = 0.06
	_trail.gravity = Vector3(0, 0.15, 0); _trail.initial_velocity_min = 0.02; _trail.initial_velocity_max = 0.12
	_trail.direction = Vector3(0, -1, 0); _trail.spread = 60
	_trail.scale_amount_min = 0.6; _trail.scale_amount_max = 1.2
	var curve := Curve.new(); curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(1, 0))
	_trail.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.9, 1.0, 1.0)); grad.set_color(1, Color(0.2, 0.3, 1.0, 0.0))
	_trail.color_ramp = grad
	var qm := QuadMesh.new(); qm.size = Vector2(0.05, 0.05)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	pm.albedo_texture = _dot_tex()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = pm
	_trail.mesh = qm
	_trail.position = Vector3(0, -0.15, 0)
	add_child(_trail)

func _dot_tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func teleport_to_player() -> void:
	if player: global_position = _home()

func _home() -> Vector3:
	var right := player.forward().cross(Vector3.UP).normalized()
	return player.global_position + Vector3.UP * 1.75 + right * 0.85 - player.forward() * 0.2

func _process(delta: float) -> void:
	if not player: return
	_t += delta
	var target: Vector3 = _home() if focus_point == null else focus_point
	target.y += sin(_t * 1.6) * 0.07
	# critically-damped spring: weightless but smooth
	var k := 5.0
	var acc := (target - global_position) * k * k - vel * 2.0 * k
	vel += acc * delta
	global_position += vel * delta
	if global_position.distance_to(target) > 25.0:
		global_position = target; vel = Vector3.ZERO
	# face the camera / player
	var look_at_p := player.cam.global_position
	var to := look_at_p - global_position
	to.y *= 0.4
	if to.length() > 0.1:
		var want := atan2(to.x, to.z)
		rotation.y = lerp_angle(rotation.y, want, min(1.0, delta * 4.0))
	rotation.z = lerp(rotation.z, clamp(-vel.x * 0.08, -0.35, 0.35), min(1.0, delta * 3.0))
	rotation.x = lerp(rotation.x, clamp(vel.z * 0.05, -0.3, 0.3), min(1.0, delta * 3.0))
	var spin_k: float = G.rot_speed_scale()
	if _rings.size() > 0: _rings[0].rotate_object_local(Vector3.UP, delta * 1.3 * spin_k)
	if _rings.size() > 1: _rings[1].rotate_object_local(Vector3.UP, -delta * 0.9 * spin_k)
	if _fins: _fins.rotation.y += delta * 0.4 * spin_k
	var talk: float = (0.5 + 0.5 * sin(_t * 18.0) * sin(_t * 7.3)) if speaking else 0.0
	_core_mat.set_shader_parameter("energy", 2.6 + talk * 3.0)
	_eye_mat.set_shader_parameter("energy", 2.2 + talk * 2.0)
	_light.light_energy = 1.0 + talk * 1.2
	_body_mat.set_shader_parameter("glow", 1.0 + talk * 0.6)
