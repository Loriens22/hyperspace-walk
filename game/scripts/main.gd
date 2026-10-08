## Entry point: builds world, player, Aether, stations, director, UI; handles game flow, triggers,
## checkpoints, pause, save/load. Test args (after --): --autostart --cp=<id> --unlockall --w=<f> --lesson=<id> --fp
extends Node3D

var world: World
var player: Player
var aether: Aether
var director: Director
var manip: Manipulator
var ui: UI
var title_cam: Camera3D
var st := {}
var gate: Node3D
var _title_t := 0.0
var _was_captured := false
var _cp_index := -1
var args := {}
var _fps_t := 0.0
var fps_label: Label

const CPS := [
	{"id": "hub", "z": 99.0, "pos": Vector3(0, 0.3, 3.5), "w": 0.0},
	{"id": "A", "z": -12.0, "pos": Vector3(0, 0.3, -14.0), "w": 0.0},
	{"id": "door", "z": -28.0, "pos": Vector3(0, 0.3, -29.6), "w": 2.0},
	{"id": "B", "z": -40.0, "pos": Vector3(0, 0.3, -41.0), "w": -999.0},
	{"id": "C", "z": -57.5, "pos": Vector3(0, 0.3, -58.5), "w": -999.0},
	{"id": "gal", "z": -76.5, "pos": Vector3(0, 0.3, -78.0), "w": -999.0},
	{"id": "E", "z": -99.5, "pos": Vector3(0, 0.3, -100.5), "w": -999.0},
]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	world = World.new(); add_child(world)
	_add_station("intro_hub", null, Vector3(0, 0, world.Z_HUB))
	_add_station("A", preload("res://scripts/station_a.gd"), Vector3(0, 0, world.Z_A))
	_add_station("B", preload("res://scripts/station_b.gd"), Vector3(0, 0, world.Z_B))
	_add_station("C", preload("res://scripts/station_c.gd"), Vector3(0, 0, world.Z_C))
	_add_station("D", preload("res://scripts/gallery.gd"), Vector3(0, 0, world.Z_GAL))
	_add_station("E", preload("res://scripts/station_e.gd"), Vector3(0, 0, world.Z_E))
	gate = Node3D.new(); gate.set_script(preload("res://scripts/gate.gd")); gate.position = Vector3(0, 0, -72.0)
	add_child(gate)
	player = Player.new(); player.position = Vector3(0, 0.3, 3.5); add_child(player)
	aether = Aether.new(); aether.player = player; add_child(aether)
	director = Director.new(); add_child(director)
	manip = Manipulator.new(); manip.player = player; add_child(manip)
	title_cam = Camera3D.new(); title_cam.fov = 60; title_cam.far = 900; add_child(title_cam)
	ui = UI.new(); ui.director = director; ui.manip = manip; add_child(ui)
	# main handles menu input while the tree is paused; everything else in the world pauses
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		if c != ui: c.process_mode = Node.PROCESS_MODE_PAUSABLE
	director.line_started.connect(func(id, ln): ui.set_line(id, ln); aether.speaking = true)
	director.line_cleared.connect(func(): ui.clear_line(); aether.speaking = false)
	director.lesson_started.connect(_on_lesson_started)
	director.lesson_finished.connect(_on_lesson_finished)
	director.cue.connect(func(id, c):
		for k in st: st[k].handle_cue(id, c))
	ui.new_game.connect(_new_game)
	ui.continue_game.connect(_continue)
	ui.resume.connect(func(): _set_paused(false))
	ui.quit_to_title.connect(_quit_to_title)
	ui.save_requested.connect(func(): _save(); G.toast.emit(G.T("Game saved", "Играта е запазена")))
	ui.load_requested.connect(func(): _set_paused(false); _continue())
	title_cam.current = true
	G.playing = false
	G.settings_changed.connect(_apply_gfx)
	_apply_gfx()
	fps_label = Label.new(); fps_label.position = Vector2(8, 700); fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.modulate = Color(0.6, 1, 0.7); ui.add_child(fps_label)
	if args.has("nogiants"):
		for g in world.giants: g.visible = false
	if args.has("nobubbles"):
		for b in world.bubbles: b.visible = false
	if args.has("noglow"): world.env.glow_enabled = false
	if args.has("noshadow"):
		for c in world.get_children():
			if c is DirectionalLight3D: c.shadow_enabled = false
	if args.has("nostations"):
		for k in st: st[k].visible = false
	print("[main] ready stations=%s" % [st.keys()])
	if args.has("autostart") or args.has("bot"):
		_new_game.call_deferred()
	if args.has("bot"):
		var b := Node.new(); b.set_script(load("res://scripts/bot.gd")); b.m = self; add_child(b)
		b.run.call_deferred()

func _apply_gfx() -> void:
	var low: bool = bool(G.settings.get("low_gfx", false))
	var vp := get_viewport()
	vp.scaling_3d_scale = 0.7 if low else 1.0
	for c in world.get_children():
		if c is DirectionalLight3D and c.light_energy > 1.0: c.shadow_enabled = not low
	for i in world.bubbles.size():
		world.bubbles[i].visible = (not low) or i % 2 == 0

func _add_station(id: String, script, pos: Vector3) -> void:
	if script == null: return
	var s := Node3D.new(); s.set_script(script); s.position = pos
	add_child(s); st[id] = s

# ------------------------------------------------------------------ flow
func _start_common() -> void:
	G.playing = true
	ui.show_game()
	player.cam.current = true
	aether.teleport_to_player()
	G.start_music()

func _new_game() -> void:
	G.reset_progress()
	player.global_position = Vector3(0, 0.3, 3.5); player.yaw = 0.0; player.velocity = Vector3.ZERO
	player.respawn_point = player.global_position; player.respawn_w = 0.0
	_cp_index = 0
	_start_common()
	if args.has("fp"): player.set_view(false)
	if args.has("unlockall"):
		for id in ["intro", "A", "door", "door_ok", "B", "C"]: G.lessons_done[id] = true
		G.w_unlocked = true; G.rot_unlocked = true
	if args.has("cp"):
		for i in CPS.size():
			if CPS[i]["id"] == args["cp"]:
				player.global_position = CPS[i]["pos"]; _cp_index = i
		if args["cp"] == "gate": player.global_position = Vector3(1.5, 0.3, -64.0)
	if args.has("w"): G.player_w = float(args["w"])
	if args.has("pos"):
		var c: PackedStringArray = args["pos"].split(",")
		player.global_position = Vector3(float(c[0]), float(c[1]), float(c[2]))
	if args.has("yaw"): player.yaw = deg_to_rad(float(args["yaw"]))
	if args.has("pitch"): player.pitch = deg_to_rad(float(args["pitch"]))
	if args.has("gate"): G.gate_open = true; gate._open(true)
	if args.has("donetill"):
		for id in ["intro", "A", "door", "door_ok", "B", "C", "lock", "lock_ok", "D", "E"]:
			G.lessons_done[id] = true
			if id == "A": G.w_unlocked = true
			if id == "C": G.rot_unlocked = true
			if id == "lock_ok": G.gate_open = true; gate._open(true)
			if id == args["donetill"]: break
	if args.has("lesson"):
		get_tree().create_timer(1.0).timeout.connect(func():
			director.play(args["lesson"])
			for i in int(args.get("skipto", "0")): director._next())
	elif not G.lessons_done.has("intro"):
		get_tree().create_timer(1.2).timeout.connect(func(): director.play("intro"))

func _continue() -> void:
	var d := G.load_game()
	if d.is_empty():
		_new_game(); return
	var p: Array = d.get("pos", [0, 0.3, 3.5])
	player.global_position = Vector3(p[0], p[1] + 0.2, p[2]); player.yaw = float(d.get("yaw", 0.0))
	player.respawn_point = player.global_position; player.respawn_w = G.player_w
	player.velocity = Vector3.ZERO
	if G.gate_open: gate._open(true)
	_cp_index = -1
	_start_common()
	G.toast.emit(G.T("Expedition resumed", "Експедицията продължава"))

func _quit_to_title() -> void:
	_save()
	_set_paused(false)
	G.playing = false
	director.queue.clear()
	if director.current != "": director._finish()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title_cam.current = true
	ui.show_title()

func _save() -> void:
	if G.playing: G.save_game(player.global_position, player.yaw)

func _set_paused(on: bool) -> void:
	G.paused = on
	get_tree().paused = on
	ui.show_pause(on)
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_captured = false

func _on_lesson_started(id: String) -> void:
	if st.has(id):
		aether.focus_point = st[id].focus_point()

func _on_lesson_finished(id: String) -> void:
	aether.focus_point = null
	for k in st: st[k].on_lesson_finished(id)
	if director.is_main_lesson(id):
		_save()
	if id == "E":
		director.play("finale")
	if id == "finale":
		G.play_sfx("success")
		G.toast.emit(G.T("EXPEDITION COMPLETE · thank you for exploring", "ЕКСПЕДИЦИЯТА Е ЗАВЪРШЕНА · благодаря ти"))

# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
	if not G.playing: return
	if e is InputEventMouseButton and e.pressed and not G.paused and not ui.any_panel_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e.is_action_pressed("menu"):
		if ui.log_panel.visible or ui.settings_panel.visible:
			ui.log_panel.visible = false; ui.settings_panel.visible = false
			if G.paused: ui.show_pause(true)
		else:
			_set_paused(not G.paused)
	elif e.is_action_pressed("lang"):
		G.set_lang("bg" if G.lang == "en" else "en")
		G.toast.emit("English" if G.lang == "en" else "Български")
	elif e.is_action_pressed("log"):
		if ui.log_panel.visible:
			ui.log_panel.visible = false; _set_paused(false)
		else:
			_set_paused(true); ui.pause_menu.visible = false; ui.open_log()
	elif e.is_action_pressed("hints"):
		G.set_setting("hints", not bool(G.settings["hints"]))

func _process(delta: float) -> void:
	_fps_t += delta
	if fps_label:
		fps_label.visible = bool(G.settings.get("fps", false))
		if fps_label.visible: fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if _fps_t > 10.0:
		_fps_t = 0.0
		print("[fps] focus=%s %d proc=%.1fms phys=%.1fms playing=%s paused=%s lesson=%s w=%.2f pos=%s" % [manip.focused.get_path() if manip.focused else "-", Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, G.playing, G.paused, director.current, G.player_w, player.global_position.snapped(Vector3.ONE * 0.1)])
	if G.paused:
		if G.playing and not ui.log_panel.visible and not ui.settings_panel.visible and not ui.pause_menu.visible:
			ui.show_pause(true)
		return
	if not G.playing:
		_title_t += delta * 0.08
		var c := Vector3(0, 2.6, -18.0)
		title_cam.global_position = c + Vector3(sin(_title_t) * 9.5, 1.6 + sin(_title_t * 0.7) * 0.8, cos(_title_t) * 9.5)
		title_cam.look_at(c + Vector3(0, 0.5, 0))
		return
	# pointer lock lost (browser Esc) -> pause menu
	var cap := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not cap and not G.paused:
		_set_paused(true)
	_was_captured = cap
	if director.current != "" and st.has(director.current):
		aether.focus_point = st[director.current].focus_point()
	_triggers()
	_checkpoints()
	ui.objective_text = _objective()

func _triggers() -> void:
	if director.is_busy() or not director.queue.is_empty(): return
	var p := player.global_position
	for id in ["A", "B", "C", "D", "E"]:
		var s = st[id]
		if s.available() and p.distance_to(s.global_position) < s.radius:
			if id == "D" and not G.gate_open: continue
			director.play(id); return
	if G.lessons_done.has("A") and not G.lessons_done.has("door") and p.z < -20.5 and p.z > -27.0:
		director.play("door"); return
	if G.lessons_done.has("A") and not G.lessons_done.has("door_ok") and p.z < -27.8:
		director.play("door_ok"); return

func _checkpoints() -> void:
	var p := player.global_position
	if not player.is_on_floor(): return
	for i in range(CPS.size() - 1, -1, -1):
		if i <= _cp_index: break
		if p.z < CPS[i]["z"]:
			_cp_index = i
			player.respawn_point = CPS[i]["pos"]
			player.respawn_w = G.player_w if float(CPS[i]["w"]) < -100.0 else float(CPS[i]["w"])
			break

func _objective() -> String:
	var d := G.lessons_done
	if not d.has("intro"): return G.T("Listen to Aether", "Слушай Етер")
	if not d.has("A"): return G.T("Walk to Station I ahead (glowing beacon)", "Иди до Станция I напред (светещият маяк)")
	if not d.has("door_ok"): return G.T("Get past the wall — it only exists for w ∈ [−0.6, +0.6]. Use E / Q.", "Мини стената – тя съществува само за w ∈ [−0,6, +0,6]. Ползвай E / Q.")
	if not d.has("B"): return G.T("Cross the bridge (exists for w ∈ [1.4, 2.6]) to Station II", "Мини моста (съществува за w ∈ [1,4, 2,6]) до Станция II")
	if not d.has("C"): return G.T("Continue to Station III", "Продължи към Станция III")
	if not G.gate_open: return G.T("Open the slice lock: make the tesseract's slice match the tall outline (1–6, R/F)", "Отключи портата: накарай сечението да съвпадне с високия контур (1–6, R/F)")
	if not d.has("D"): return G.T("Enter the gallery of the six regular polytopes", "Влез в галерията на шестте правилни политопа")
	if not d.has("E"): return G.T("Continue to Station V", "Продължи към Станция V")
	return G.T("Explore freely · try C and X on the polytopes · J = Research Log", "Изследвай свободно · пробвай C и X върху политопите · J = дневник")
