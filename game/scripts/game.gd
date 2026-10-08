## Global state (autoload "G"): progress, settings, content, save/load, audio helpers.
extends Node

signal changed
signal lang_changed
signal settings_changed
signal touch_changed
signal toast(text: String)

const SAVE_PATH := "user://hyperspace_walk_save.json"
const W_MIN := -3.0
const W_MAX := 3.0

var player_w := 0.0
var w_unlocked := false
var rot_unlocked := false
var gate_open := false
var lessons_done := {}
var heard := {}            # line id -> true (Research Log)
var lang := "en"
var playing := false       # in-game (not title)
var paused := false
var settings := {"sens": 0.25, "subs": 22, "reduced_motion": false, "colorblind": false, "subtitles": true,
	"music": 0.7, "voice": 1.0, "sfx": 0.8, "hints": true, "low_gfx": false, "fps": false,
	"touch_mode": 0, "touch_sens": 1.0, "perf_auto_done": false}

var content := {}
var lessons := {}
var refs := {}
var sfx := {}
var _music3: AudioStreamPlayer
var _music4: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/content.json", FileAccess.READ)
	content = JSON.parse_string(f.get_as_text())
	refs = content["refs"]
	for l in content["lessons"]:
		lessons[l["id"]] = l
	_setup_inputs()
	_setup_audio()
	load_settings_only()
	touch_platform = _detect_touch_platform()
	print("[touch] platform=%s touchscreen=%s" % [touch_platform, DisplayServer.is_touchscreen_available()])
	if touch_platform and not bool(settings.get("perf_auto_done", false)):
		settings["low_gfx"] = true; settings["perf_auto_done"] = true
		save_settings_only()

# ---------------------------------------------------------------- touch detection
var touch_platform := false   # phone/tablet browser (or coarse-pointer touchscreen)
var touch_seen := false       # a real touch happened this session

func _detect_touch_platform() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var coarse = JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches", true)
		return bool(coarse)
	return false

func touch_active() -> bool:
	var m: int = int(settings.get("touch_mode", 0))
	if m == 1: return true
	if m == 2: return false
	return touch_platform or touch_seen

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed and not touch_seen:
		touch_seen = true
		touch_changed.emit()
	elif e is InputEventKey and e.pressed and not e.echo and touch_seen and not touch_platform:
		touch_seen = false          # desktop with a touchscreen: back to keyboard/mouse
		touch_changed.emit()

# ---------------------------------------------------------------- input map
func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _setup_inputs() -> void:
	_key("fwd", [KEY_W, KEY_UP]); _key("back", [KEY_S, KEY_DOWN])
	_key("left", [KEY_A]); _key("right", [KEY_D])
	_key("look_left", [KEY_LEFT]); _key("look_right", [KEY_RIGHT])
	_key("jump", [KEY_SPACE]); _key("run", [KEY_SHIFT]); _key("crouch", [KEY_CTRL, KEY_Z])
	_key("ana", [KEY_E]); _key("kata", [KEY_Q])
	_key("cam", [KEY_V]); _key("lang", [KEY_L]); _key("log", [KEY_J, KEY_TAB])
	_key("pause_line", [KEY_P]); _key("replay", [KEY_T]); _key("next_line", [KEY_N, KEY_ENTER])
	_key("rot_plus", [KEY_R]); _key("rot_minus", [KEY_F]); _key("rot_reset", [KEY_0])
	_key("slice", [KEY_X]); _key("proj", [KEY_C]); _key("hints", [KEY_H]); _key("menu", [KEY_ESCAPE]); _key("skip", [KEY_K])
	for i in 6:
		_key("plane%d" % (i + 1), [KEY_1 + i])

# ---------------------------------------------------------------- content helpers
func line_text(ln: Dictionary) -> String:
	return ln.get(lang, ln.get("en", ""))

func lesson_title(id: String) -> String:
	var l: Dictionary = lessons.get(id, {})
	return l.get("title_" + lang, l.get("title_en", ""))

func T(en: String, bg: String) -> String:
	return bg if lang == "bg" else en

func set_lang(l: String) -> void:
	lang = l
	lang_changed.emit()
	save_settings_only()

func rot_speed_scale() -> float:
	return 0.3 if settings["reduced_motion"] else 1.0

func palette() -> Array:
	# Default cyan->magenta w-depth cue; colour-blind safe: Okabe-Ito blue->orange.
	if settings["colorblind"]:
		return [Color(0.0, 0.62, 1.0), Color(1.0, 0.62, 0.0)]
	return [Color(0.25, 0.95, 1.0), Color(1.0, 0.3, 0.85)]

func set_setting(k: String, v) -> void:
	settings[k] = v
	if k == "touch_mode": touch_changed.emit()
	_apply_volumes()
	settings_changed.emit()
	save_settings_only()

# ---------------------------------------------------------------- save / load
func reset_progress() -> void:
	player_w = 0.0; w_unlocked = false; rot_unlocked = false; gate_open = false
	lessons_done = {}; heard = {}
	changed.emit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(player_pos: Vector3, yaw: float) -> void:
	var d := {"w": player_w, "w_unlocked": w_unlocked, "rot_unlocked": rot_unlocked, "gate_open": gate_open,
		"lessons_done": lessons_done, "heard": heard, "lang": lang, "settings": settings,
		"pos": [player_pos.x, player_pos.y, player_pos.z], "yaw": yaw}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()

func load_game() -> Dictionary:
	if not has_save(): return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return {}
	player_w = float(d.get("w", 0.0)); w_unlocked = bool(d.get("w_unlocked", false))
	rot_unlocked = bool(d.get("rot_unlocked", false)); gate_open = bool(d.get("gate_open", false))
	lessons_done = d.get("lessons_done", {}); heard = d.get("heard", {})
	lang = d.get("lang", lang)
	var s: Dictionary = d.get("settings", {})
	for k in s: settings[k] = s[k]
	_apply_volumes()
	changed.emit(); lang_changed.emit(); settings_changed.emit()
	return d

func save_settings_only() -> void:
	var f := FileAccess.open("user://hyperspace_walk_settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"lang": lang, "settings": settings}))

func load_settings_only() -> void:
	var p := "user://hyperspace_walk_settings.json"
	if not FileAccess.file_exists(p): return
	var d = JSON.parse_string(FileAccess.open(p, FileAccess.READ).get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	lang = d.get("lang", "en")
	var s: Dictionary = d.get("settings", {})
	for k in s: settings[k] = s[k]
	_apply_volumes()

# ---------------------------------------------------------------- audio
func _setup_audio() -> void:
	_music3 = AudioStreamPlayer.new(); _music4 = AudioStreamPlayer.new()
	for p in [_music3, _music4]:
		p.bus = "Music"; add_child(p)
	_music3.stream = load("res://audio/pad_3d.ogg")
	_music4.stream = load("res://audio/pad_4d.ogg")
	for n in ["unlock", "success", "ui", "line", "wstep", "door", "step", "fall"]:
		sfx[n] = load("res://audio/%s.ogg" % n)
	for i in 6:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); _sfx_pool.append(p)
	_apply_volumes()

func start_music() -> void:
	if not _music3.playing:
		_music3.volume_db = -8.0; _music4.volume_db = -60.0
		_music3.play(); _music4.play()

func play_sfx(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx.has(n): return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = sfx[n]; p.volume_db = vol_db; p.pitch_scale = pitch; p.play(); return

func _apply_volumes() -> void:
	var m := AudioServer.get_bus_index("Music")
	if m >= 0:
		AudioServer.set_bus_volume_db(m, linear_to_db(max(float(settings["music"]), 0.0001)))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(max(float(settings["voice"]), 0.0001)))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(max(float(settings["sfx"]), 0.0001)))

func _process(delta: float) -> void:
	if _music3 and _music3.playing:
		# Music crossfades from the "3D" layer to the "4D" layer as |w| grows.
		var k: float = clamp(abs(player_w) / 2.5, 0.0, 1.0)
		var t3: float = linear_to_db(max(1.0 - 0.85 * k, 0.001)) - 8.0
		var t4: float = linear_to_db(max(k, 0.001)) - 6.0
		_music3.volume_db = lerp(_music3.volume_db, t3, min(1.0, delta * 2.0))
		_music4.volume_db = lerp(_music4.volume_db, t4, min(1.0, delta * 2.0))
