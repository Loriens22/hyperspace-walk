## Lesson E: tangent space and Levi-Civita parallel transport on a sphere (holonomy = curvature x area,
## Gauss 1827), then Kaluza-Klein compactification shown explicitly as THEORY.
extends Station

const SR := 1.25
var sphere_node: Node3D
var arrow: Node3D
var ghost: Node3D
var tangent_plane: MeshInstance3D
var hose: Node3D
var ant: MeshInstance3D
var _t := 0.0
var _anim := false
var info: Label3D

func _ready() -> void:
	lesson_id = "E"; requires = "D"
	build_terminal("V · Curved space & extra dimensions", "V · Изкривено пространство и измерения")
	focus_offset = Vector3(0, 2.6, 1.2)
	sphere_node = Node3D.new(); sphere_node.position = Vector3(-2.9, 2.3, 0.2); add_child(sphere_node)
	var sm := SphereMesh.new(); sm.radius = SR; sm.height = SR * 2
	var smi := MeshInstance3D.new(); smi.mesh = sm
	var hm := ShaderMaterial.new(); hm.shader = preload("res://shaders/holo.gdshader")
	hm.set_shader_parameter("color", Color(0.3, 0.7, 1.0)); hm.set_shader_parameter("energy", 0.8)
	smi.material_override = hm; sphere_node.add_child(smi)
	# geodesic triangle N -> (1,0,0) -> (0,0,-1) -> N
	var A := []; var B := []
	var path := func(f: Callable):
		for i in 24:
			var a: Vector3 = f.call(i / 24.0) * SR * 1.01; var b: Vector3 = f.call((i + 1) / 24.0) * SR * 1.01
			A.append(Vector4(a.x, a.y, a.z, 0)); B.append(Vector4(b.x, b.y, b.z, 0))
	path.call(func(s): return _leg_p(0, s))
	path.call(func(s): return _leg_p(1, s))
	path.call(func(s): return _leg_p(2, s))
	var tri := MeshInstance3D.new(); tri.mesh = PolyView.ribbon_mesh(A, B, 1)
	var tm := ShaderMaterial.new(); tm.shader = preload("res://shaders/edge4d.gdshader")
	tm.set_shader_parameter("mode", 3); tm.set_shader_parameter("width", 0.03)
	tm.set_shader_parameter("col_near", Color(1, 0.85, 0.3)); tm.set_shader_parameter("col_far", Color(1, 0.85, 0.3)); tm.set_shader_parameter("energy", 1.6)
	tri.material_override = tm; tri.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	sphere_node.add_child(tri)
	arrow = _make_arrow(Color(0.4, 1.0, 0.5), 1.0); sphere_node.add_child(arrow)
	ghost = _make_arrow(Color(1.0, 0.4, 0.8), 0.6); sphere_node.add_child(ghost)
	ghost.transform = _arrow_xf(Vector3(0, 1, 0), Vector3(1, 0, 0))
	tangent_plane = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(1.0, 1.0); tangent_plane.mesh = pm
	var pmat := ShaderMaterial.new(); pmat.shader = preload("res://shaders/holo.gdshader")
	pmat.set_shader_parameter("color", Color(0.5, 1.0, 0.7)); pmat.set_shader_parameter("energy", 0.5); pmat.set_shader_parameter("base", 0.4)
	tangent_plane.material_override = pmat; tangent_plane.visible = false
	sphere_node.add_child(tangent_plane)
	info = Label3D.new(); info.font_size = 46; info.pixel_size = 0.005; info.outline_size = 10
	info.billboard = BaseMaterial3D.BILLBOARD_ENABLED; info.position = Vector3(0, SR + 0.6, 0)
	sphere_node.add_child(info)
	# Kaluza-Klein "garden hose"
	hose = Node3D.new(); hose.position = Vector3(3.0, 1.5, 0.0); add_child(hose)
	var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.07; cm.height = 5.0
	var hmi := MeshInstance3D.new(); hmi.mesh = cm; hmi.rotation.x = PI / 2
	var hmat := ShaderMaterial.new(); hmat.shader = preload("res://shaders/holo.gdshader")
	hmat.set_shader_parameter("color", Color(1.0, 0.6, 0.3)); hmat.set_shader_parameter("energy", 1.2)
	hmi.material_override = hmat; hose.add_child(hmi)
	var zoom := MeshInstance3D.new(); var ztm := TorusMesh.new(); ztm.inner_radius = 0.56; ztm.outer_radius = 0.62
	zoom.mesh = ztm; zoom.rotation.x = PI / 2; zoom.position = Vector3(0, 1.3, 0)
	zoom.material_override = hmat; hose.add_child(zoom)
	ant = MeshInstance3D.new(); var am := SphereMesh.new(); am.radius = 0.06; am.height = 0.12; ant.mesh = am
	var amat := ShaderMaterial.new(); amat.shader = preload("res://shaders/emit.gdshader"); amat.set_shader_parameter("color", Color(0.4, 1, 0.6))
	ant.material_override = amat; hose.add_child(ant)
	var kl := Label3D.new(); kl.font_size = 46; kl.pixel_size = 0.005; kl.outline_size = 10; kl.modulate = Color(1, 0.75, 0.4)
	kl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; kl.position = Vector3(0, 2.35, 0)
	kl.name = "KL"; hose.add_child(kl)
	G.lang_changed.connect(_relabel_e); _relabel_e()

func _relabel_e() -> void:
	(hose.get_node("KL") as Label3D).text = G.T("THEORY, not established fact\nKaluza 1921 · Klein 1926 · strings 1985\nextra dimension curled into a tiny circle", "ТЕОРИЯ, не установен факт\nКалуца 1921 · Клайн 1926 · струни 1985\nдопълнително измерение, навито в малка окръжност")

func _make_arrow(col: Color, en: float) -> Node3D:
	var n := Node3D.new()
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/emit.gdshader")
	m.set_shader_parameter("color", col); m.set_shader_parameter("energy", 2.2 * en)
	var shaft := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.025; cm.bottom_radius = 0.025; cm.height = 0.45
	shaft.mesh = cm; shaft.position.y = 0.225; shaft.material_override = m; n.add_child(shaft)
	var head := MeshInstance3D.new(); var hm := CylinderMesh.new(); hm.top_radius = 0.0; hm.bottom_radius = 0.07; hm.height = 0.16
	head.mesh = hm; head.position.y = 0.52; head.material_override = m; n.add_child(head)
	return n

func _leg_p(leg: int, s: float) -> Vector3:
	var a := s * PI / 2
	match leg:
		0: return Vector3(sin(a), cos(a), 0)
		1: return Vector3(cos(a), 0, -sin(a))
		_: return Vector3(0, sin(a), -cos(a))

## parallel-transported vector along each geodesic leg (constant angle with the leg's tangent)
func _leg_v(leg: int, s: float) -> Vector3:
	var a := s * PI / 2
	match leg:
		0: return Vector3(cos(a), -sin(a), 0)
		1: return Vector3(0, -1, 0)
		_: return -Vector3(0, cos(a), sin(a))

func _arrow_xf(n: Vector3, v: Vector3) -> Transform3D:
	var x := v.cross(n).normalized()
	return Transform3D(Basis(x, v.normalized(), n.normalized()), n * SR * 1.02)

func handle_cue(lesson: String, c: String) -> void:
	if lesson != "E": return
	match c:
		"tangent": tangent_plane.visible = true
		"transport", "transport_anim": _anim = true; tangent_plane.visible = true

func _process(delta: float) -> void:
	super._process(delta)
	if _anim or G.lessons_done.has("E"):
		_t += delta * 0.33 * G.rot_speed_scale()
	var cyc := fmod(_t, 4.0)
	var n := Vector3(0, 1, 0); var v := Vector3(1, 0, 0)
	if cyc < 3.0:
		var leg := int(cyc); var s := cyc - leg
		n = _leg_p(leg, s); v = _leg_v(leg, s)
		info.text = G.T("parallel transport · leg %d/3", "паралелно пренасяне · отсечка %d/3") % (leg + 1)
	else:
		n = Vector3(0, 1, 0); v = Vector3(0, 0, -1)
		info.text = G.T("back at the pole: turned 90° = (1/8 · 4πR²)/R²", "обратно на полюса: завъртяна на 90° = (1/8 · 4πR²)/R²")
	arrow.transform = _arrow_xf(n, v)
	ghost.visible = cyc >= 3.0
	tangent_plane.transform = Transform3D(Basis(v.cross(n).normalized(), n, v.cross(n).cross(n).normalized() * -1.0), n * SR * 1.005)
	var a := Time.get_ticks_msec() / 1000.0 * 1.2
	ant.position = Vector3(cos(a) * 0.59, 1.3 + sin(a) * 0.59, 0)
