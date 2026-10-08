## Automated play-through used for testing only (enabled with the "--bot" user arg).
extends Node

var m  # main
var p: Player
var log_lines := []

func _say(s: String) -> void:
	print("[bot] %s | pos=%s w=%.2f lesson=%s done=%s" % [s, p.global_position.snapped(Vector3.ONE * 0.1), G.player_w, m.director.current, G.lessons_done.keys()])

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _skip_lesson(max_lines := 40) -> void:
	var n := 0
	while m.director.current != "" and n < max_lines:
		await _frames(20)
		if m.director.current != "": m.director._next()
		n += 1
	await _frames(60)

func _wait_lesson(id: String, frames := 400) -> bool:
	for i in frames:
		if m.director.current == id: return true
		await get_tree().process_frame
	return false

func _goto(t: Vector3, timeout_f := 1500) -> bool:
	for i in timeout_f:
		var d := t - p.global_position; d.y = 0
		if d.length() < 0.5:
			Input.action_release("fwd"); return true
		p.yaw = atan2(-d.x, -d.z)
		Input.action_press("fwd")
		await get_tree().physics_frame
	Input.action_release("fwd")
	return false

func _path(pts: Array, timeout_f := 1500) -> bool:
	for q in pts:
		if not await _goto(q, timeout_f): return false
	return true

func _set_w(target: float) -> void:
	var act := "ana" if target > G.player_w else "kata"
	for i in 900:
		if absf(G.player_w - target) < 0.08: break
		Input.action_press(act)
		await get_tree().physics_frame
	Input.action_release(act)
	await _frames(10)

func _tap(a: String) -> void:
	Input.action_press(a); await get_tree().process_frame; await get_tree().process_frame
	Input.action_release(a); await _frames(3)

func run() -> void:
	p = m.player
	await _wait_lesson("intro", 600)
	_say("start")
	await _skip_lesson()
	_say("intro skipped")
	var ok := await _path([Vector3(0, 0, -14), Vector3(1.2, 0, -16)]); _say("at A ok=%s" % ok)
	_say("A started=%s" % await _wait_lesson("A"))
	await _skip_lesson()
	_say("A done w_unlocked=%s" % G.w_unlocked)
	ok = await _path([Vector3(1.2, 0, -20), Vector3(0, 0, -23.0)]); _say("near door ok=%s" % ok)
	if await _wait_lesson("door", 200): await _skip_lesson()
	ok = await _goto(Vector3(0, 0, -28.5), 300); _say("try walking through wall at w=0 (expect blocked) ok=%s" % ok)
	await _set_w(2.0); _say("w set to 2")
	ok = await _goto(Vector3(0, 0, -29.6)); _say("past door ok=%s" % ok)
	if await _wait_lesson("door_ok", 200): await _skip_lesson()
	ok = await _goto(Vector3(0, 0, -40.5)); _say("crossed bridge ok=%s y=%.2f" % [ok, p.global_position.y])
	ok = await _goto(Vector3(1.2, 0, -42.0)); _say("at B ok=%s" % ok)
	_say("B started=%s" % await _wait_lesson("B"))
	await _skip_lesson()
	ok = await _path([Vector3(1.2, 0, -47), Vector3(0, 0, -55), Vector3(1.2, 0, -60.0)]); _say("at C ok=%s" % ok)
	_say("C started=%s" % await _wait_lesson("C"))
	await _skip_lesson()
	_say("C done rot_unlocked=%s" % G.rot_unlocked)
	ok = await _path([Vector3(1.2, 0, -64), Vector3(0, 0, -69), Vector3(0, 0, -71.5)], 400); _say("walk into gate (expect blocked) ok=%s gate_open=%s" % [ok, G.gate_open])
	ok = await _goto(Vector3(1.0, 0, -66.5)); _say("at lock ok=%s focus=%s" % [ok, m.manip.focus_text().replace("\n", " / ")])
	await _tap("plane5")
	for i in 3:
		await _tap("rot_plus"); await _frames(60)
	await _frames(120)
	_say("after yw x3 gate_open=%s" % G.gate_open)
	if m.director.current != "": await _skip_lesson()
	ok = await _path([Vector3(0, 0, -70), Vector3(0, 0, -76.0)]); _say("through gate ok=%s" % ok)
	ok = await _goto(Vector3(0, 0, -81.0)); _say("in gallery ok=%s" % ok)
	_say("D started=%s" % await _wait_lesson("D"))
	await _skip_lesson()
	ok = await _path([Vector3(1.5, 0, -89), Vector3(0, 0, -93), Vector3(0, 0, -97), Vector3(1.2, 0, -100.5)]); _say("at E ok=%s" % ok)
	_say("E started=%s" % await _wait_lesson("E"))
	await _skip_lesson()
	_say("finale started=%s" % await _wait_lesson("finale"))
	await _skip_lesson()
	# fall test
	ok = await _goto(Vector3(14.0, 0, -100.5), 500)
	await _frames(240)
	_say("after falling off (expect respawn near E)")
	m._save()
	_say("saved; BOT DONE")
	get_tree().quit()
