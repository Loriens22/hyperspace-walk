## Lets the player rotate the nearest 4D object (after lesson C): 1-6 choose the rotation plane
## (xy, xz, xw, yz, yw, zw), R/F turn +-15°, 0 reset, X slice/projection, C cycle projection model.
class_name Manipulator
extends Node

var player: Player
var focused: PolyView = null
var plane := 2
const MODES_EN := ["perspective", "orthographic", "stereographic"]
const MODES_BG := ["перспективна", "ортогонална", "стереографска"]

func _process(_d: float) -> void:
	if not player or not G.playing or G.paused: return
	var best: PolyView = null
	var bd := 7.5
	for n in get_tree().get_nodes_in_group("rotatable"):
		var v := n as PolyView
		if not v.is_visible_in_tree(): continue
		var d := v.global_position.distance_to(player.global_position + Vector3(0, 1.5, 0))
		if d < bd:
			bd = d; best = v
	focused = best
	if not G.rot_unlocked or focused == null:
		if Input.is_action_just_pressed("rot_plus") or Input.is_action_just_pressed("rot_minus"):
			if not G.rot_unlocked:
				G.toast.emit(G.T("4D rotation is not unlocked yet (Station III).", "4D въртенето още не е отключено (Станция III)."))
		return
	for i in 6:
		if Input.is_action_just_pressed("plane%d" % (i + 1)):
			plane = i; G.play_sfx("ui", -10.0)
	if Input.is_action_just_pressed("rot_plus"):
		focused.queue_turn(plane, 1); G.play_sfx("wstep", -12.0, 1.4)
	elif Input.is_action_just_pressed("rot_minus"):
		focused.queue_turn(plane, -1); G.play_sfx("wstep", -12.0, 1.2)
	elif Input.is_action_just_pressed("rot_reset"):
		focused.reset_user(); G.play_sfx("ui", -8.0)
	elif Input.is_action_just_pressed("slice") and not focused.has_meta("lock"):
		focused.slice_mode = not focused.slice_mode; G.play_sfx("ui", -8.0)
	elif Input.is_action_just_pressed("proj") and not focused.slice_mode:
		focused.mode = (focused.mode + 1) % 3; G.play_sfx("ui", -8.0)

func focus_text() -> String:
	if focused == null: return ""
	var nm: String = focused.get_meta("display", focused.poly_id)
	var view: String
	if focused.slice_mode:
		view = G.T("slice at w", "сечение при w")
	else:
		view = (MODES_BG if G.lang == "bg" else MODES_EN)[focused.mode]
	var tt := []
	for i in 6:
		if focused.turns[i] != 0: tt.append("%s %+d°" % [P4.PLANE_NAMES[i], focused.turns[i] * 15])
	var s := "%s · %s" % [nm, view]
	if not tt.is_empty(): s += "\n" + G.T("turns: ", "завъртания: ") + ", ".join(tt)
	return s
