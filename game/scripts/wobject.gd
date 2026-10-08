## An object of the 4D world that only exists for w in [wmin, wmax] (a box extruded over a w-interval).
## Collision is enabled only while the player's w is inside that interval (Flatland-style walls/bridges).
class_name WObject
extends StaticBody3D

var wmin := -0.6
var wmax := 0.6
var size := Vector3(4, 4, 0.4)
var color := Color(1.0, 0.35, 0.85)
var label_text := ""
var _mat: ShaderMaterial
var _shape: CollisionShape3D
var presence := 1.0

func setup(sz: Vector3, w0: float, w1: float, col: Color, lbl: String = "") -> WObject:
	size = sz; wmin = w0; wmax = w1; color = col; label_text = lbl
	return self

func _ready() -> void:
	add_to_group("wobjects")
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	_shape.shape = bs
	add_child(_shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	_mat = ShaderMaterial.new(); _mat.shader = preload("res://shaders/wslab.gdshader")
	_mat.set_shader_parameter("color", color)
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if label_text != "":
		for side in [-1, 1]:
			var l := Label3D.new()
			l.text = label_text
			l.font_size = 64; l.pixel_size = 0.006
			l.modulate = Color(1, 1, 1, 0.95); l.outline_size = 12
			l.position = Vector3(0, size.y * 0.5 + 0.45, side * (size.z * 0.5 + 0.02))
			if side < 0: l.rotation.y = PI
			l.no_depth_test = false
			l.double_sided = false
			add_child(l)

func contains_w(w: float) -> bool:
	return w >= wmin and w <= wmax

## Would a body with this world AABB overlap the slab?
func overlaps(aabb: AABB) -> bool:
	var mine := AABB(global_position - size * 0.5, size)
	return mine.intersects(aabb)

func _process(delta: float) -> void:
	var w: float = G.player_w
	var d: float = max(wmin - w, w - wmax)   # <0 inside
	var target: float = 1.0 if d <= 0.0 else clamp(1.0 - d / 0.35, 0.0, 1.0) * 0.35
	presence = lerp(presence, target, min(1.0, delta * 10.0))
	_mat.set_shader_parameter("presence", presence)
	var solid := contains_w(w)
	collision_layer = 1 if solid else 0
