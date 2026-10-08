## A 3-sphere of radius R centred at w = w0. Its slice by the hyperplane w = player_w is a 2-sphere of
## radius r = sqrt(R^2 - (w - w0)^2) (empty when |w - w0| > R).
class_name HyperSphere
extends Node3D

var R := 1.4
var w0 := 0.0
var color := Color(0.3, 0.9, 1.0)
var show_label := true
var label: Label3D
var _mi: MeshInstance3D
var _wire: MeshInstance3D
var _mat: ShaderMaterial
var r_now := 0.0

func _ready() -> void:
	_mi = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 48; sm.rings = 24
	_mi.mesh = sm
	_mat = ShaderMaterial.new(); _mat.shader = preload("res://shaders/holo.gdshader")
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("energy", 1.4)
	_mi.material_override = _mat
	add_child(_mi)
	# latitude / longitude rings for shape reading
	var A := []; var B := []
	for k in 7:
		var lat := -PI / 2 + PI * (k + 1) / 8.0
		for s in 32:
			var a0 := TAU * s / 32.0; var a1 := TAU * (s + 1) / 32.0
			A.append(Vector4(cos(lat) * cos(a0), sin(lat), cos(lat) * sin(a0), 0)); B.append(Vector4(cos(lat) * cos(a1), sin(lat), cos(lat) * sin(a1), 0))
	for m in 8:
		var lon := TAU * m / 8.0
		for s in 32:
			var t0 := -PI / 2 + PI * s / 32.0; var t1 := -PI / 2 + PI * (s + 1) / 32.0
			A.append(Vector4(cos(t0) * cos(lon), sin(t0), cos(t0) * sin(lon), 0)); B.append(Vector4(cos(t1) * cos(lon), sin(t1), cos(t1) * sin(lon), 0))
	_wire = MeshInstance3D.new()
	_wire.mesh = PolyView.ribbon_mesh(A, B, 1)
	var wm := ShaderMaterial.new(); wm.shader = preload("res://shaders/edge4d.gdshader")
	wm.set_shader_parameter("mode", 3); wm.set_shader_parameter("width", 0.012)
	wm.set_shader_parameter("col_near", color); wm.set_shader_parameter("col_far", color); wm.set_shader_parameter("energy", 0.9)
	_wire.material_override = wm
	_wire.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	add_child(_wire)
	if show_label:
		label = Label3D.new()
		label.font_size = 56; label.pixel_size = 0.005; label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, R + 0.55, 0)
		add_child(label)

func _process(_d: float) -> void:
	var dw: float = G.player_w - w0
	var inside := absf(dw) < R
	r_now = sqrt(max(R * R - dw * dw, 0.0))
	var s: float = max(r_now, 0.001)
	_mi.scale = Vector3.ONE * s
	_wire.scale = Vector3.ONE * s
	_mi.visible = inside
	_wire.visible = inside
	if label:
		if inside:
			label.text = "r(w) = √(R² − w²) = √(%.2f − %.2f) = %.2f" % [R * R, dw * dw, r_now]
		else:
			label.text = G.T("|w| > R : the hypersphere is not in this slice", "|w| > R : хиперсферата не е в това сечение")
