## Builds the level: floating hex platforms (Blender kit) joined by walkways, the Flatland door and w-bridge
## (objects that exist only in a w-interval), 4D "bubbles" (small 3-spheres at various w), giant background
## polytopes, sky, fog and lights. Ordinary architecture is extruded over all w (a prism in R^4).
class_name World
extends Node3D

const Z_HUB := 0.0
const Z_A := -18.0
const Z_B := -44.54
const Z_C := -62.54
const Z_GAL := -84.31
const Z_E := -104.54
const APO := 3.4641          # hex apothem for radius 4

var env: Environment
var sky_mat: ShaderMaterial
var stations := {}
var gate: Node3D
var door: WObject
var bridge: WObject
var bubbles: Array[HyperSphere] = []
var giants: Array[PolyView] = []
var walk_mat: StandardMaterial3D
var strip_mat: StandardMaterial3D

func _ready() -> void:
	_environment()
	walk_mat = StandardMaterial3D.new(); walk_mat.albedo_color = Color(0.07, 0.08, 0.1); walk_mat.metallic = 0.8; walk_mat.roughness = 0.35
	strip_mat = StandardMaterial3D.new(); strip_mat.albedo_color = Color(0.1, 0.8, 1.0); strip_mat.emission_enabled = true
	strip_mat.emission = Color(0.1, 0.8, 1.0); strip_mat.emission_energy_multiplier = 3.0
	_platform(Vector3(0, 0, Z_HUB), 1.6)
	_platform(Vector3(0, 0, Z_A), 1.6)
	_platform(Vector3(0, 0, Z_B), 1.6)
	_platform(Vector3(0, 0, Z_C), 1.6)
	_platform(Vector3(0, 0, Z_GAL), 2.4)
	_platform(Vector3(0, 0, Z_E), 1.6)
	_walk(Z_HUB - APO * 1.6, Z_A + APO * 1.6)
	_walk(Z_A - APO * 1.6, -31.0)
	_walk(Z_B - APO * 1.6, Z_C + APO * 1.6)
	_walk(Z_C - APO * 1.6, Z_GAL + APO * 2.4)
	_walk(Z_GAL - APO * 2.4, Z_E + APO * 1.6)
	# Flatland door: a wall that exists only for -0.6 <= w <= 0.6
	door = WObject.new().setup(Vector3(16, 5, 0.5), -0.6, 0.6, Color(1.0, 0.35, 0.8), "w ∈ [−0.6, +0.6]")
	door.position = Vector3(0, 2.5, -27.0)
	add_child(door)
	# w-bridge over the gap: exists only for 1.4 <= w <= 2.6
	bridge = WObject.new().setup(Vector3(3.0, 0.4, 8.05), 1.4, 2.6, Color(0.3, 1.0, 0.6), "")
	bridge.position = Vector3(0, -0.2, -35.0)
	add_child(bridge)
	var sign_l := Label3D.new(); sign_l.text = "BRIDGE  w ∈ [1.4, 2.6]"; sign_l.font_size = 72; sign_l.pixel_size = 0.006
	sign_l.outline_size = 14; sign_l.modulate = Color(0.5, 1, 0.7); sign_l.position = Vector3(0, 2.3, -30.6)
	sign_l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; add_child(sign_l)
	for x in [-1.7, 1.7]:
		_post(Vector3(x, 0, -30.8), Color(0.3, 1.0, 0.6))
		_post(Vector3(x, 0, -39.2), Color(0.3, 1.0, 0.6))
	# pillars & decor
	for z in [Z_HUB, Z_A, Z_B, Z_C, Z_E]:
		for sx in [-1, 1]:
			var p: Node3D = (load("res://assets/pillar.glb") as PackedScene).instantiate()
			p.position = Vector3(sx * 4.6, 0, z + 2.2); p.scale = Vector3.ONE * 0.8
			add_child(p)
			var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.45; cy.height = 5.0
			cs.shape = cy; sb.position = p.position + Vector3(0, 2.5, 0); sb.add_child(cs); add_child(sb)
	_hub_sign()
	_bubbles()
	_giants()
	_lights()

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new(); sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.32, 0.5)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.08, 0.16)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)

func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(0.75, 0.82, 1.0); sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -150, 0)
	fill.light_color = Color(0.8, 0.35, 1.0); fill.light_energy = 0.35
	add_child(fill)

func _platform(pos: Vector3, sc: float) -> void:
	var p: Node3D = (load("res://assets/platform.glb") as PackedScene).instantiate()
	p.position = pos; p.scale = Vector3.ONE * sc
	add_child(p)
	var sb := StaticBody3D.new(); sb.position = pos
	var cs := CollisionShape3D.new(); var cv := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for k in 6:
		# Blender X -> Godot X, Blender Y -> Godot -Z (hex vertex at +X)
		var a := deg_to_rad(60.0 * k)
		pts.append(Vector3(cos(a) * 4.0 * sc, 0, -sin(a) * 4.0 * sc))
		pts.append(Vector3(cos(a) * 4.0 * sc, -0.6, -sin(a) * 4.0 * sc))
	cv.points = pts; cs.shape = cv; sb.add_child(cs); add_child(sb)

func _walk(z0: float, z1: float) -> void:
	var len := absf(z0 - z1) + 0.6
	var zc := (z0 + z1) * 0.5
	var sb := StaticBody3D.new(); sb.position = Vector3(0, -0.2, zc)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(3.0, 0.4, len); cs.shape = bs
	sb.add_child(cs); add_child(sb)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(3.0, 0.4, len); mi.mesh = bm
	mi.material_override = walk_mat; sb.add_child(mi)
	for x in [-1.42, 1.42]:
		var s := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(0.08, 0.03, len)
		s.mesh = sm; s.material_override = strip_mat; s.position = Vector3(x, 0.215, 0); sb.add_child(s)
	var under := MeshInstance3D.new(); var um := BoxMesh.new(); um.size = Vector3(1.0, 0.2, len)
	under.mesh = um; under.material_override = walk_mat; under.position = Vector3(0, -0.3, 0); sb.add_child(under)

func _post(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.1; cm.height = 1.4
	mi.mesh = cm; mi.position = pos + Vector3(0, 0.7, 0)
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 2.5
	mi.material_override = m; add_child(mi)

func _hub_sign() -> void:
	var l := Label3D.new()
	l.text = "HYPERSPACE WALK"; l.font_size = 160; l.pixel_size = 0.008; l.outline_size = 24
	l.modulate = Color(0.6, 0.95, 1.0); l.position = Vector3(0, 6.2, -5.0)
	add_child(l)
	var l2 := Label3D.new()
	l2.text = "ℝ⁴ = {(x, y, z, w)}"; l2.font_size = 96; l2.pixel_size = 0.006; l2.outline_size = 16
	l2.modulate = Color(1.0, 0.55, 0.9); l2.position = Vector3(0, 5.0, -5.0)
	add_child(l2)

func _bubbles() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var cols := [Color(0.3, 0.9, 1.0), Color(1.0, 0.35, 0.85), Color(0.5, 1.0, 0.6), Color(1.0, 0.8, 0.3), Color(0.6, 0.5, 1.0)]
	for i in 34:
		var h := HyperSphere.new()
		h.show_label = false
		h.R = rng.randf_range(0.7, 2.2)
		h.w0 = rng.randf_range(-3.0, 3.0)
		h.color = cols[i % cols.size()]
		var side := -1.0 if i % 2 == 0 else 1.0
		h.position = Vector3(side * rng.randf_range(9.0, 26.0), rng.randf_range(-5.0, 12.0), rng.randf_range(12.0, -125.0))
		add_child(h)
		bubbles.append(h)

func _giants() -> void:
	var g := PolyView.new().setup("120cell", 38.0)
	g.position = Vector3(0, 46, -70); g.width = 0.22; g.spin = [[0, 0.03], [5, 0.03]]
	g.keep_colors = true; g.col_near = Color(0.3, 0.6, 1.0); g.col_far = Color(0.7, 0.25, 1.0)
	add_child(g); giants.append(g); g.energy = 0.28
	var g2 := PolyView.new().setup("24cell", 16.0)
	g2.position = Vector3(-55, 14, -35); g2.width = 0.12; g2.spin = [[1, 0.05], [4, 0.07]]
	add_child(g2); giants.append(g2)
	var g3 := PolyView.new().setup("600cell", 22.0)
	g3.position = Vector3(62, 10, -95); g3.width = 0.14; g3.mode = 2; g3.spin = [[2, 0.04], [3, 0.04]]
	add_child(g3); giants.append(g3)

func _process(_d: float) -> void:
	sky_mat.set_shader_parameter("wshift", G.player_w / 3.0)
	var k: float = G.player_w / 3.0
	env.fog_light_color = Color(0.05, 0.08, 0.16).lerp(Color(0.14, 0.05, 0.18) if k > 0 else Color(0.03, 0.13, 0.14), absf(k))
