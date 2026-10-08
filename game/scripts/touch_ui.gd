## On-screen touch controls (phones/tablets). Everything maps onto the existing InputMap actions,
## so gameplay code is unchanged: a floating analog joystick (left), drag-to-look (right side,
## multi-touch safe by tracking touch indices) and neon buttons that send InputEventActions.
class_name TouchUI
extends Control

var player: Player
var manip: Manipulator
var director: Director
var ui: UI

const JOY_R := 85.0
const KNOB_R := 36.0
var joy_home := Vector2(150, 500)
var joy_base := Vector2(150, 500)
var joy_vec := Vector2.ZERO
var touches := {}            # index -> "joy" | "look" | button id
var buttons := {}            # id -> {pos, r, label, action, kind, color}
var crouch_on := false
var insets := Rect2()        # safe-area insets (left, top, right, bottom) in canvas units
var font: Font
var _active := false
var _held := {}              # action -> true (hold buttons currently down)
var _last := {}              # index -> last position (Godot web's drag .relative is unreliable with 2+ fingers)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://fonts/DejaVuSans-Bold.ttf")
	visible = false
	get_viewport().size_changed.connect(layout)
	layout.call_deferred()

# ------------------------------------------------------------------ layout
func safe_insets() -> Rect2:
	var ws := Vector2(DisplayServer.window_get_size())
	var sa := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	if ws.x <= 0 or sa.size.x <= 0 or sa.size.y <= 0: return Rect2()
	var k := vp / ws
	var l: float = clamp(sa.position.x, 0, ws.x * 0.2) * k.x
	var t: float = clamp(sa.position.y, 0, ws.y * 0.2) * k.y
	var r: float = clamp(ws.x - sa.end.x, 0, ws.x * 0.2) * k.x
	var b: float = clamp(ws.y - sa.end.y, 0, ws.y * 0.2) * k.y
	return Rect2(l, t, r, b)

func _b(id: String, p: Vector2, r: float, label: String, action: String, kind: String, col: Color) -> void:
	buttons[id] = {"pos": p, "r": r, "label": label, "action": action, "kind": kind, "color": col}

func layout() -> void:
	var V := get_viewport_rect().size
	insets = safe_insets()
	var L := insets.position.x + 14.0; var T := insets.position.y + 12.0
	var R := V.x - insets.size.x - 14.0; var B := V.y - insets.size.y - 14.0
	var portrait := V.y > V.x
	joy_home = Vector2(L + JOY_R + 26, B - JOY_R - 26)
	if joy_vec == Vector2.ZERO: joy_base = joy_home
	var cyan := Color(0.35, 0.92, 1.0); var mag := Color(1.0, 0.4, 0.85); var gold := Color(1.0, 0.85, 0.35)
	buttons.clear()
	var A := Vector2(R - 62, B - 62)                       # jump centre (thumb rest position)
	_b("jump", A, 56, G.T("JUMP", "СКОК"), "jump", "tap", cyan)
	_b("crouch", A + Vector2(-128, 14), 38, G.T("CROUCH", "КЛЯК"), "crouch", "toggle", cyan)
	_b("ana", A + Vector2(4, -134), 40, "W+", "ana", "hold", mag)
	_b("kata", A + Vector2(-104, -96), 40, "W−", "kata", "hold", cyan)
	# rotation cluster (after Station III, when a 4D object is in reach)
	var ry := A.y - (250.0 if not portrait else 236.0)
	_b("rot_plus", Vector2(R - 34, ry), 32, "+15°", "rot_plus", "tap", gold)
	_b("rot_minus", Vector2(R - 106, ry), 32, "−15°", "rot_minus", "tap", gold)
	_b("plane", Vector2(R - 178, ry), 32, "xy", "", "plane", gold)
	_b("proj", Vector2(R - 250, ry), 32, G.T("VIEW", "ИЗГЛ"), "proj", "tap", gold)
	_b("slice", Vector2(R - 322, ry), 32, G.T("SLICE", "СЕЧ"), "slice", "tap", gold)
	# top row: menu, log, camera; Aether controls while she speaks
	var ty := T + 30.0
	_b("menu", Vector2(R - 28, ty), 28, "≡", "menu", "tap", cyan)
	_b("log", Vector2(R - 90, ty), 28, G.T("LOG", "ДНЕВ"), "log", "tap", cyan)
	_b("cam", Vector2(R - 152, ty), 28, "1P/3P", "cam", "tap", cyan)
	var ax := R - 228.0; var ay := ty
	if portrait: ax = R - 28.0; ay = ty + 64.0          # second row in portrait (top-left holds the objective)
	_b("next", Vector2(ax, ay), 26, "»", "next_line", "tap", mag)
	_b("replay", Vector2(ax - 60, ay), 26, "↺", "replay", "tap", mag)
	_b("pause_line", Vector2(ax - 120, ay), 26, "II", "pause_line", "tap", mag)
	var dbg := []
	for id in buttons: dbg.append("%s=%s" % [id, buttons[id]["pos"].round()])
	print("[touch] layout vp=%s insets=%s joy=%s %s" % [V.round(), insets, joy_home.round(), " ".join(dbg)])

func focus_y() -> float:
	return insets.position.y + 12.0 + 64.0

# ------------------------------------------------------------------ visibility
func _btn_visible(id: String) -> bool:
	match id:
		"ana", "kata": return G.w_unlocked
		"rot_plus", "rot_minus", "plane", "proj": return G.rot_unlocked and manip != null and manip.focused != null
		"slice": return G.rot_unlocked and manip != null and manip.focused != null and not manip.focused.has_meta("lock")
		"next", "replay", "pause_line": return director != null and director.current != ""
	return true

func _should_show() -> bool:
	return G.touch_active() and G.playing and not G.paused and ui != null and not ui.any_panel_open()

func _process(_d: float) -> void:
	var show := _should_show()
	if show != _active:
		_active = show
		visible = show
		if not show: _release_all()
	if not show: return
	# keep the crouch toggle honest and refresh dynamic labels
	if buttons.has("plane") and manip:
		buttons["plane"]["label"] = P4.PLANE_NAMES[manip.plane]
	if buttons.has("pause_line") and director:
		buttons["pause_line"]["label"] = "▶" if director.paused else "II"
	queue_redraw()

func _release_all() -> void:
	for a in ["fwd", "back", "left", "right", "run"]:
		Input.action_release(a)
	for a in _held.keys():
		_send(a, false)
	_held.clear()
	if crouch_on:
		crouch_on = false; _send("crouch", false)
	touches.clear(); _last.clear()
	joy_vec = Vector2.ZERO; joy_base = joy_home

# ------------------------------------------------------------------ input
func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action; ev.pressed = pressed; ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

func _tap(action: String) -> void:
	_send(action, true)
	get_tree().create_timer(0.12, true).timeout.connect(func(): _send(action, false))

func _hit(p: Vector2) -> String:
	for id in buttons:
		if not _btn_visible(id): continue
		var b: Dictionary = buttons[id]
		if p.distance_to(b["pos"]) <= float(b["r"]) * 1.18: return id
	return ""

func _input(e: InputEvent) -> void:
	if not _active: return
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_last[st.index] = st.position
			var id := _hit(st.position)
			if id != "":
				touches[st.index] = id
				_press_button(id)
			elif _in_joy_zone(st.position) and not touches.values().has("joy"):
				touches[st.index] = "joy"
				joy_base = _clamp_base(st.position)
				_update_joy(st.position)
			else:
				touches[st.index] = "look"
			get_viewport().set_input_as_handled()
		elif touches.has(st.index):
			var role: String = touches[st.index]
			touches.erase(st.index); _last.erase(st.index)
			if role == "joy":
				joy_vec = Vector2.ZERO; joy_base = joy_home
				for a in ["fwd", "back", "left", "right", "run"]: Input.action_release(a)
			elif role != "look":
				_release_button(role)
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if not touches.has(sd.index): return
		var role: String = touches[sd.index]
		var rel: Vector2 = sd.position - _last.get(sd.index, sd.position)
		_last[sd.index] = sd.position
		if role == "joy":
			_update_joy(sd.position)
		elif role == "look" and player:
			var k: float = 0.0045 * float(G.settings.get("touch_sens", 1.0))
			rel = rel.limit_length(120.0)
			player.yaw -= rel.x * k
			player.pitch = clamp(player.pitch - rel.y * k, -1.35, 1.25)
		get_viewport().set_input_as_handled()

func _in_joy_zone(p: Vector2) -> bool:
	var V := get_viewport_rect().size
	return p.x < V.x * 0.42 and p.y > V.y * 0.30

func _clamp_base(p: Vector2) -> Vector2:
	var V := get_viewport_rect().size
	return Vector2(clamp(p.x, insets.position.x + JOY_R + 8, V.x * 0.45), clamp(p.y, V.y * 0.3, V.y - insets.size.y - JOY_R - 8))

func _update_joy(p: Vector2) -> void:
	var d := (p - joy_base) / JOY_R
	if d.length() > 1.0: d = d.normalized()
	joy_vec = d
	var v := d if d.length() > 0.12 else Vector2.ZERO
	_axis("right", maxf(v.x, 0.0)); _axis("left", maxf(-v.x, 0.0))
	_axis("back", maxf(v.y, 0.0)); _axis("fwd", maxf(-v.y, 0.0))
	if d.length() > 0.93: Input.action_press("run")
	else: Input.action_release("run")

func _axis(a: String, s: float) -> void:
	if s > 0.01: Input.action_press(a, s)
	else: Input.action_release(a)

func _press_button(id: String) -> void:
	var b: Dictionary = buttons[id]
	G.play_sfx("ui", -14.0)
	match String(b["kind"]):
		"hold":
			_held[b["action"]] = true; _send(b["action"], true)
		"tap":
			_tap(b["action"])
		"toggle":
			crouch_on = not crouch_on; _send(b["action"], crouch_on)
		"plane":
			if manip: _tap("plane%d" % ((manip.plane + 1) % 6 + 1))

func _release_button(id: String) -> void:
	if not buttons.has(id): return
	var b: Dictionary = buttons[id]
	if b["kind"] == "hold" and _held.has(b["action"]):
		_held.erase(b["action"]); _send(b["action"], false)

# ------------------------------------------------------------------ drawing
func _is_down(id: String) -> bool:
	if id == "crouch": return crouch_on
	return touches.values().has(id)

func _draw() -> void:
	# joystick
	var base_a := 0.55 if touches.values().has("joy") else 0.3
	draw_circle(joy_base, JOY_R, Color(0.02, 0.06, 0.12, base_a * 0.8))
	draw_arc(joy_base, JOY_R, 0, TAU, 64, Color(0.35, 0.92, 1.0, base_a + 0.2), 3.0, true)
	draw_arc(joy_base, JOY_R * 0.93, 0, TAU, 64, Color(1.0, 0.4, 0.85, base_a * 0.6), 1.5, true)
	var kp := joy_base + joy_vec * JOY_R
	draw_circle(kp, KNOB_R, Color(0.35, 0.92, 1.0, 0.35 if joy_vec.length() > 0.0 else 0.22))
	draw_arc(kp, KNOB_R, 0, TAU, 48, Color(0.75, 0.98, 1.0, 0.85), 2.5, true)
	if joy_vec.length() > 0.93:
		draw_string(font, joy_base + Vector2(-40, -JOY_R - 10), G.T("RUN", "ТИЧАНЕ"), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(1, 0.9, 0.5, 0.9))
	# buttons
	for id in buttons:
		if not _btn_visible(id): continue
		var b: Dictionary = buttons[id]
		var p: Vector2 = b["pos"]; var r: float = b["r"]; var col: Color = b["color"]
		var down := _is_down(id)
		draw_circle(p, r, Color(col.r * 0.25, col.g * 0.25, col.b * 0.3, 0.62) if down else Color(0.02, 0.05, 0.1, 0.42))
		draw_arc(p, r, 0, TAU, 48, Color(col, 0.95 if down else 0.7), 3.0 if down else 2.0, true)
		if down: draw_arc(p, r + 5, 0, TAU, 48, Color(col, 0.35), 4.0, true)
		var txt: String = b["label"]
		var fs := int(clamp(r * 0.5, 12, 22)) if txt.length() <= 3 else int(clamp(r * 0.36, 10, 17))
		draw_string(font, p + Vector2(-r, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color(0.92, 0.98, 1.0, 0.95))
