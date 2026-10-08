## Runs Aether's lessons line by line (subtitles + voice + cues + equations) as a robust state machine.
## P = pause/resume, T = replay line, N/Enter = next line, L = switch language (restarts the line).
class_name Director
extends Node

signal line_started(lesson_id: String, line: Dictionary)
signal line_cleared
signal lesson_started(lesson_id: String)
signal lesson_finished(lesson_id: String)
signal cue(lesson_id: String, cue_name: String)

const BARKS := ["respawn", "wlocked", "lock_hint", "lock_hint2"]

var voice: AudioStreamPlayer
var current := ""
var idx := -1
var t := 0.0
var dur := 0.0
var paused := false
var queue: Array[String] = []
var _gap := 0.0

func _ready() -> void:
	add_to_group("director")
	voice = AudioStreamPlayer.new(); voice.bus = "Voice"; add_child(voice)
	G.lang_changed.connect(func(): if current != "": _begin_line())

func is_busy() -> bool:
	return current != ""

func is_main_lesson(id: String) -> bool:
	return not BARKS.has(id)

func play(id: String) -> void:
	if not G.lessons.has(id): return
	if current == id or queue.has(id): return
	if current != "":
		if BARKS.has(id): return
		queue.append(id); return
	_start(id)

func bark(id: String) -> void:
	if current == "" : _start(id)

func _start(id: String) -> void:
	current = id; idx = -1; paused = false
	lesson_started.emit(id)
	_next()

func _next() -> void:
	idx += 1
	var lines: Array = G.lessons[current]["lines"]
	if idx >= lines.size():
		_finish(); return
	_begin_line()

func _begin_line() -> void:
	var ln: Dictionary = G.lessons[current]["lines"][idx]
	var path := "res://voice/%s/%s.mp3" % [G.lang, ln["id"]]
	dur = 1.2 + G.line_text(ln).length() * 0.062
	voice.stop()
	if ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		voice.stream = st
		voice.play()
		dur = st.get_length() + 0.75
	t = 0.0
	paused = false
	G.heard[ln["id"]] = true
	if ln.get("cue", "") != "":
		cue.emit(current, ln["cue"])
	print("[line] %s %s %.1fs" % [current, ln["id"], dur])
	line_started.emit(current, ln)
	G.play_sfx("line", -16.0)

func _finish() -> void:
	var id := current
	current = ""; idx = -1
	voice.stop()
	line_cleared.emit()
	if not BARKS.has(id):
		G.lessons_done[id] = true
	lesson_finished.emit(id)
	_gap = 0.6

func _process(delta: float) -> void:
	if current == "":
		if _gap > 0.0:
			_gap -= delta
		elif not queue.is_empty():
			_start(queue.pop_front())
		return
	if G.playing and not G.paused:
		if Input.is_action_just_pressed("pause_line"): toggle_pause()
		elif Input.is_action_just_pressed("replay"): _begin_line()
		elif Input.is_action_just_pressed("next_line"): _next(); return
	if paused or G.paused: return
	t += delta
	if t >= dur:
		_next()

func toggle_pause() -> void:
	paused = not paused
	voice.stream_paused = paused
	G.toast.emit(G.T("Aether paused (P to resume)", "Етер е на пауза (P за продължение)") if paused else G.T("Resumed", "Продължава"))

func current_line() -> Dictionary:
	if current == "" or idx < 0: return {}
	return G.lessons[current]["lines"][idx]
