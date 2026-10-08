## All 2D UI: title screen, HUD (w gauge, objective, focus/rotation panel, subtitles, equations, hints),
## pause menu, settings, Research Log (every heard line + citations). Built in code.
class_name UI
extends CanvasLayer

signal new_game
signal continue_game
signal resume
signal quit_to_title
signal save_requested
signal load_requested
signal skip_requested
signal skip_hint
signal skip_anyway
signal skip_cancel
signal realm_requested

var director: Director
var manip: Manipulator
var theme_: Theme
var root: Control
var title: Control
var hud: Control
var pause_menu: Control
var settings_panel: Control
var log_panel: Control
var sub_panel: PanelContainer
var sub_speaker: Label
var sub_text: Label
var sub_refs: Label
var eq_panel: PanelContainer
var eq_tex: TextureRect
var w_label: Label
var w_marker: ColorRect
var w_bar: Control
var w_lock: Label
var w_ranges: Control
var objective: Label
var focus_panel: PanelContainer
var focus_label: Label
var plane_chips: Array[Label] = []
var hints: Label
var toast_label: Label
var crosshair: ColorRect
var continue_btn: Button
var log_list: ItemList
var log_text: RichTextLabel
var _toast_t := 0.0
var _log_ids: Array = []
var objective_text := ""
var touch: TouchUI
var w_panel: PanelContainer
var obj_panel: PanelContainer
var title_box: VBoxContainer
var pause_box: PanelContainer
var settings_box: PanelContainer
var settings_scroll: ScrollContainer
var settings_v: Container
var log_margin: MarginContainer
var rotate_hint: PanelContainer
var _touch_on := false
var skip_btn: Button
var skip_dialog: Control
var skip_label: Label
var skip_task := ""
var _rotate_t := 0.0
var _was_portrait := false
var _fs_shown := -1

const CYAN := Color(0.35, 0.92, 1.0)
const MAG := Color(1.0, 0.4, 0.85)

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_ = _make_theme()
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme_
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	touch = TouchUI.new(); touch.ui = self; touch.director = director; touch.manip = manip
	root.add_child(touch)
	_build_title()
	_build_pause()
	_build_settings()
	_build_log()
	G.toast.connect(show_toast)
	G.lang_changed.connect(_relabel)
	G.settings_changed.connect(_apply_settings)
	_build_rotate_hint()
	_build_skip()
	_relabel(); _apply_settings()
	show_title()
	get_viewport().size_changed.connect(_layout)
	G.touch_changed.connect(_layout)
	_layout.call_deferred()

# ------------------------------------------------------------------ theme
func _sb(bg: Color, border: Color, bw: int = 1, r: int = 8, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(r)
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://fonts/DejaVuSans.ttf")
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _sb(Color(0.015, 0.035, 0.07, 0.86), Color(0.3, 0.85, 1.0, 0.55)))
	t.set_stylebox("panel", "Panel", _sb(Color(0.015, 0.035, 0.07, 0.86), Color(0.3, 0.85, 1.0, 0.55)))
	t.set_stylebox("normal", "Button", _sb(Color(0.03, 0.08, 0.14, 0.9), Color(0.3, 0.85, 1.0, 0.5), 1, 6, 14))
	t.set_stylebox("hover", "Button", _sb(Color(0.06, 0.2, 0.3, 0.95), Color(0.4, 0.95, 1.0, 1.0), 2, 6, 14))
	t.set_stylebox("pressed", "Button", _sb(Color(0.1, 0.3, 0.4, 0.95), Color(1.0, 0.5, 0.9, 1.0), 2, 6, 14))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), Color(1.0, 0.5, 0.9, 0.8), 1, 6, 14))
	t.set_color("font_color", "Button", Color(0.85, 0.97, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Label", Color(0.88, 0.96, 1.0))
	t.set_stylebox("panel", "ItemList", _sb(Color(0.01, 0.02, 0.05, 0.9), Color(0.3, 0.85, 1.0, 0.35)))
	t.set_stylebox("selected", "ItemList", _sb(Color(0.08, 0.25, 0.35, 1.0), Color(0.4, 0.95, 1.0, 0.8), 1, 4, 4))
	t.set_stylebox("selected_focus", "ItemList", _sb(Color(0.08, 0.25, 0.35, 1.0), Color(0.4, 0.95, 1.0, 0.8), 1, 4, 4))
	var sbg := StyleBoxFlat.new(); sbg.bg_color = Color(0.3, 0.85, 1.0, 0.12); sbg.set_corner_radius_all(6)
	sbg.content_margin_left = 7; sbg.content_margin_right = 7
	var sgr := StyleBoxFlat.new(); sgr.bg_color = Color(0.35, 0.92, 1.0, 0.55); sgr.set_corner_radius_all(6)
	var sgh := sgr.duplicate(); sgh.bg_color = Color(1.0, 0.5, 0.9, 0.8)
	t.set_stylebox("scroll", "VScrollBar", sbg); t.set_stylebox("grabber", "VScrollBar", sgr)
	t.set_stylebox("grabber_highlight", "VScrollBar", sgh); t.set_stylebox("grabber_pressed", "VScrollBar", sgh)
	t.set_stylebox("normal", "RichTextLabel", _sb(Color(0.01, 0.02, 0.05, 0.9), Color(0.3, 0.85, 1.0, 0.35), 1, 6, 16))
	return t

func _label(txt: String, size: int = 18, col: Color = Color(0.88, 0.96, 1.0)) -> Label:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(txt: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(300, 46)
	b.pressed.connect(func(): G.play_sfx("ui", -6.0); cb.call())
	return b

# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	# objective (top-left)
	var op := PanelContainer.new(); op.position = Vector2(18, 16); op.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective = _label("", 18, Color(1.0, 0.92, 0.6)); objective.custom_minimum_size = Vector2(420, 0)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	op.add_child(objective); hud.add_child(op); obj_panel = op
	op.name = "ObjPanel"
	# w gauge (left)
	var wp := PanelContainer.new(); wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wp.custom_minimum_size = Vector2(120, 340); _place(wp, Control.PRESET_CENTER_LEFT, Vector2(18, -170))
	var wv := VBoxContainer.new(); wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_child(_center(_label("ana +w", 14, MAG)))
	w_bar = Control.new(); w_bar.custom_minimum_size = Vector2(90, 220)
	var track := ColorRect.new(); track.color = Color(0.3, 0.85, 1.0, 0.25); track.position = Vector2(41, 0); track.size = Vector2(8, 220)
	w_bar.add_child(track)
	w_ranges = Control.new(); w_bar.add_child(w_ranges)
	for i in 7:
		var tick := ColorRect.new(); tick.color = Color(0.6, 0.9, 1.0, 0.5); tick.size = Vector2(20 if i == 3 else 12, 2)
		tick.position = Vector2(45 - tick.size.x / 2, 220.0 * i / 6.0 - 1)
		w_bar.add_child(tick)
		var tl := _label("%+d" % (3 - i), 11, Color(0.6, 0.85, 1.0, 0.7)); tl.position = Vector2(62, 220.0 * i / 6.0 - 8)
		w_bar.add_child(tl)
	w_marker = ColorRect.new(); w_marker.color = Color(1, 1, 1); w_marker.size = Vector2(34, 6); w_marker.position = Vector2(28, 107)
	w_bar.add_child(w_marker)
	wv.add_child(w_bar)
	wv.add_child(_center(_label("kata −w", 14, CYAN)))
	w_label = _label("w = +0.00", 20, Color(1, 1, 1)); wv.add_child(_center(w_label))
	w_lock = _label("", 12, Color(1, 0.6, 0.5)); w_lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; w_lock.custom_minimum_size = Vector2(100, 0)
	w_lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(w_lock)
	wp.add_child(wv); hud.add_child(wp); w_panel = wp
	# focus panel (top-right)
	focus_panel = PanelContainer.new(); focus_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_panel.custom_minimum_size = Vector2(410, 0); _place(focus_panel, Control.PRESET_TOP_RIGHT, Vector2(-16, 16), Control.GROW_DIRECTION_BEGIN)
	var fv := VBoxContainer.new()
	focus_label = _label("", 16); focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; focus_label.custom_minimum_size = Vector2(380, 0)
	fv.add_child(focus_label)
	var chips := HBoxContainer.new(); chips.add_theme_constant_override("separation", 6)
	for i in 6:
		var c := _label("%d %s" % [i + 1, P4.PLANE_NAMES[i]], 15)
		chips.add_child(c); plane_chips.append(c)
	fv.add_child(chips)
	focus_panel.add_child(fv); hud.add_child(focus_panel)
	# equation panel (right)
	eq_panel = PanelContainer.new(); eq_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(eq_panel, Control.PRESET_CENTER_RIGHT, Vector2(-16, -190), Control.GROW_DIRECTION_BEGIN)
	eq_tex = TextureRect.new(); eq_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; eq_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	eq_tex.custom_minimum_size = Vector2(440, 160)
	eq_panel.add_child(eq_tex); eq_panel.visible = false; hud.add_child(eq_panel)
	# subtitles (bottom)
	sub_panel = PanelContainer.new(); sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_panel.custom_minimum_size = Vector2(860, 0)
	_place(sub_panel, Control.PRESET_CENTER_BOTTOM, Vector2(0, -22), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	var sv := VBoxContainer.new()
	sub_speaker = _label("AETHER", 15, CYAN)
	sub_text = _label("", 22); sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; sub_text.custom_minimum_size = Vector2(830, 0)
	sub_refs = _label("", 13, Color(0.75, 0.8, 1.0, 0.85)); sub_refs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sub_speaker); sv.add_child(sub_text); sv.add_child(sub_refs)
	sub_panel.add_child(sv); sub_panel.visible = false; hud.add_child(sub_panel)
	# hints (bottom-left)
	hints = _label("", 13, Color(0.75, 0.88, 1.0, 0.8))
	_place(hints, Control.PRESET_TOP_LEFT, Vector2(20, 104))
	hud.add_child(hints)
	# toast
	toast_label = _label("", 24, Color(1, 0.95, 0.7)); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast_label.custom_minimum_size = Vector2(1000, 0)
	_place(toast_label, Control.PRESET_CENTER_TOP, Vector2(0, 150), Control.GROW_DIRECTION_BOTH)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0)); toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(toast_label)
	crosshair = ColorRect.new(); crosshair.color = Color(1, 1, 1, 0.7); crosshair.size = Vector2(4, 4)
	_place(crosshair, Control.PRESET_CENTER, Vector2(-2, -2))
	hud.add_child(crosshair)

func _place(c: Control, preset: int, off: Vector2, gh: int = Control.GROW_DIRECTION_END, gv: int = Control.GROW_DIRECTION_END) -> void:
	c.set_anchors_preset(preset)
	c.grow_horizontal = gh; c.grow_vertical = gv
	c.offset_left = off.x; c.offset_right = off.x
	c.offset_top = off.y; c.offset_bottom = off.y

func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new(); cc.add_child(c); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE; return cc

# ------------------------------------------------------------------ title
func _build_title() -> void:
	title = Control.new(); title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	var grad := TextureRect.new(); grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new(); g.set_color(0, Color(0.0, 0.01, 0.03, 0.92)); g.set_color(1, Color(0.0, 0.01, 0.03, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0.0, 0.5); gt.fill_to = Vector2(0.75, 0.5)
	grad.texture = gt; grad.mouse_filter = Control.MOUSE_FILTER_IGNORE; grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.add_child(grad)
	var v := VBoxContainer.new(); v.position = Vector2(80, 80); v.add_theme_constant_override("separation", 12); title_box = v
	var t1 := _label("HYPERSPACE", 76, CYAN); t1.add_theme_font_override("font", load("res://fonts/DejaVuSans-Bold.ttf"))
	var t2 := _label("WALK", 76, MAG); t2.add_theme_font_override("font", load("res://fonts/DejaVuSans-Bold.ttf"))
	v.add_child(t1); v.add_child(t2)
	var sub := _label("", 20, Color(0.8, 0.9, 1.0)); sub.name = "Sub"; v.add_child(sub)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 18); v.add_child(sp)
	var nb := _btn("", func(): new_game.emit()); nb.name = "New"; v.add_child(nb)
	continue_btn = _btn("", func(): continue_game.emit()); continue_btn.name = "Cont"; v.add_child(continue_btn)
	var sb := _btn("", func(): open_settings()); sb.name = "Set"; v.add_child(sb)
	var lb := _btn("", func(): open_log()); lb.name = "Log"; v.add_child(lb)
	var lang := _btn("", func(): G.set_lang("bg" if G.lang == "en" else "en")); lang.name = "Lang"; v.add_child(lang)
	title.add_child(v)
	var foot := _label("", 14, Color(0.7, 0.8, 0.95, 0.8)); foot.name = "Foot"
	_place(foot, Control.PRESET_BOTTOM_LEFT, Vector2(80, -36), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	title.add_child(foot)

# ------------------------------------------------------------------ pause
func _build_pause() -> void:
	pause_menu = Control.new(); pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = Color(0, 0.01, 0.03, 0.6); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(dim)
	var p := PanelContainer.new(); _place(p, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH); pause_box = p
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10)
	var h := _label("", 34, CYAN); h.name = "H"; h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(h)
	for pair in [["Resume", func(): resume.emit()], ["Skip", func(): skip_requested.emit()], ["Realm", func(): realm_requested.emit()],
			["Settings", func(): open_settings()], ["Log", func(): open_log()],
			["Save", func(): save_requested.emit()], ["Load", func(): load_requested.emit()], ["Quit", func(): quit_to_title.emit()]]:
		var b := _btn("", pair[1]); b.name = pair[0]; v.add_child(b)
	p.add_child(v); pause_menu.add_child(p)
	pause_menu.visible = false
	root.add_child(pause_menu)

# ------------------------------------------------------------------ settings
var _set_rows := {}
var settings_cols: Array[VBoxContainer] = []
func _build_settings() -> void:
	settings_panel = Control.new(); settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = Color(0, 0.01, 0.03, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(dim)
	var p := PanelContainer.new(); p.custom_minimum_size = Vector2(600, 0); _place(p, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	settings_box = p
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	var h := _label("", 30, CYAN); h.name = "H"; h.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(h)
	var close := _btn("", func(): settings_panel.visible = false); close.name = "Close"; close.custom_minimum_size = Vector2(160, 44); top.add_child(close)
	pv.add_child(top)
	# two columns that wrap into one on narrow (portrait) screens
	var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 24); flow.add_theme_constant_override("v_separation", 10)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL; settings_v = flow
	var c1 := VBoxContainer.new(); c1.add_theme_constant_override("separation", 10)
	var c2 := VBoxContainer.new(); c2.add_theme_constant_override("separation", 8)
	settings_cols = [c1, c2]
	_slider_row(c1, "sens", 0.05, 0.8, 0.01)
	_slider_row(c1, "touch_sens", 0.3, 3.0, 0.05)
	_slider_row(c1, "subs", 16, 34, 1)
	_slider_row(c1, "music", 0, 1, 0.05)
	_slider_row(c1, "voice", 0, 1, 0.05)
	_slider_row(c1, "sfx", 0, 1, 0.05)
	var tb := _btn("", func():
		G.set_setting("touch_mode", (int(G.settings.get("touch_mode", 0)) + 1) % 3); _relabel())
	tb.name = "TouchMode"; c1.add_child(tb)
	var lb := _btn("", func(): G.set_lang("bg" if G.lang == "en" else "en")); lb.name = "Lang"; c1.add_child(lb)
	for k in ["reduced_motion", "colorblind", "subtitles", "hints", "low_gfx", "fps"]:
		var cb := CheckBox.new(); cb.button_pressed = bool(G.settings.get(k, false))
		cb.toggled.connect(func(on): G.set_setting(k, on))
		c2.add_child(cb); _set_rows[k] = cb
	flow.add_child(c1); flow.add_child(c2)
	settings_scroll = ScrollContainer.new(); settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.custom_minimum_size = Vector2(580, 600)
	settings_scroll.add_child(flow)
	pv.add_child(settings_scroll)
	p.add_child(pv); settings_panel.add_child(p)
	settings_panel.visible = false
	root.add_child(settings_panel)

func _slider_row(v: VBoxContainer, k: String, mn: float, mx: float, st: float) -> void:
	var h := HBoxContainer.new()
	var l := _label("", 17); l.custom_minimum_size = Vector2(190, 0); h.add_child(l)
	var s := HSlider.new(); s.min_value = mn; s.max_value = mx; s.step = st; s.value = float(G.settings[k])
	s.custom_minimum_size = Vector2(200, 30); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(val): G.set_setting(k, val))
	h.add_child(s); v.add_child(h)
	_set_rows[k] = l

# ------------------------------------------------------------------ research log
func _build_log() -> void:
	log_panel = Control.new(); log_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = Color(0, 0.01, 0.03, 0.8); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_panel.add_child(dim)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT); log_margin = m
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 40)
	var v := VBoxContainer.new()
	var top := HBoxContainer.new()
	var h := _label("", 30, CYAN); h.name = "H"; h.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(h)
	var close := _btn("", func(): log_panel.visible = false); close.name = "Close"; close.custom_minimum_size = Vector2(160, 40); top.add_child(close)
	v.add_child(top)
	var hb := HBoxContainer.new(); hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_list = ItemList.new(); log_list.custom_minimum_size = Vector2(330, 0)
	log_list.item_selected.connect(_show_log_entry)
	hb.add_child(log_list)
	log_text = RichTextLabel.new(); log_text.bbcode_enabled = true; log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.add_theme_font_size_override("normal_font_size", 18)
	log_text.add_theme_font_override("bold_font", load("res://fonts/DejaVuSans-Bold.ttf"))
	log_text.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	log_text.gui_input.connect(_log_drag)
	hb.add_child(log_text)
	v.add_child(hb)
	m.add_child(v); log_panel.add_child(m)
	log_panel.visible = false
	root.add_child(log_panel)

const LOG_ORDER := ["intro", "A", "door", "door_ok", "B", "C", "lock", "lock_hint", "lock_hint2", "lock_ok", "D", "E", "finale"]

func open_log() -> void:
	log_list.clear(); _log_ids = []
	for id in LOG_ORDER:
		var any := false
		for ln in G.lessons[id]["lines"]:
			if G.heard.has(ln["id"]): any = true
		if any:
			log_list.add_item(G.lesson_title(id)); _log_ids.append(id)
	log_list.add_item(G.T("★ All references", "★ Всички източници")); _log_ids.append("__refs")
	log_list.add_item(G.T("⌨ Controls", "⌨ Управление")); _log_ids.append("__controls")
	log_panel.visible = true
	log_list.select(0); _show_log_entry(0)

func _show_log_entry(i: int) -> void:
	var id: String = _log_ids[i]
	var t := ""
	if id == "__refs":
		t = "[b]%s[/b]\n\n" % G.T("References (all verified sources used in the game)", "Източници (всички проверени източници в играта)")
		for k in G.refs:
			var r: Dictionary = G.refs[k]
			t += "• %s\n   [color=#7fd8ff][url=%s]%s[/url][/color]\n\n" % [r["full"], r["url"], r["url"]]
	elif id == "__controls":
		t = controls_text()
	else:
		var used := []
		t = "[b]%s[/b]\n\n" % G.lesson_title(id)
		for ln in G.lessons[id]["lines"]:
			if not G.heard.has(ln["id"]): continue
			var marks := []
			for r in ln["refs"]:
				if not used.has(r): used.append(r)
				marks.append(str(used.find(r) + 1))
			t += "%s%s\n\n" % [G.line_text(ln), (" [color=#ffd36b][%s][/color]" % ",".join(marks)) if not marks.is_empty() else ""]
		if not used.is_empty():
			t += "[color=#9fb4d8]────────────[/color]\n"
			for j in used.size():
				var r: Dictionary = G.refs[used[j]]
				t += "[color=#ffd36b][%d][/color] %s  [color=#7fd8ff][url=%s]link[/url][/color]\n" % [j + 1, r["full"], r["url"]]
	log_text.text = t

func controls_text() -> String:
	return G.T("""[b]Controls[/b]

WASD / ↑↓ — walk     Mouse (click to capture) or ←→ — look
Shift — run     Space — jump     Z or Ctrl — crouch
V — first / third person
Q / E — move kata / ana along w (after Station I)
1–6 — choose rotation plane xy, xz, xw, yz, yw, zw (after Station III)
R / F — rotate the nearest 4D object ±15°     0 — reset it
X — slice at your w / projection     C — perspective / orthographic / stereographic
P — pause Aether     T — replay line     N / Enter — next line
L — English / Български     J or Tab — Research Log     H — hide hints     Esc — menu

Tip: in a browser, Ctrl+W closes the tab, so use Z to crouch.

[b]Touch (phones / tablets)[/b]

Left thumb — floating joystick (push to the rim to run)     Right side — drag to look
JUMP · CROUCH (toggle) · W+ / W− (hold; after Station I)
Plane · −15° · +15° · VIEW · SLICE (near a 4D object; after Station III)
Top row: ≡ menu · LOG · 1P/3P camera · Aether: II pause · ↺ replay · » next
Settings: Touch controls Auto / On / Off · Touch look sensitivity""",
"""[b]Управление[/b]

WASD / ↑↓ — ходене     Мишка (клик за захващане) или ←→ — оглеждане
Shift — тичане     Space — скок     Z или Ctrl — клякане
V — първо / трето лице
Q / E — движение „ката“ / „ана“ по w (след Станция I)
1–6 — равнина на въртене xy, xz, xw, yz, yw, zw (след Станция III)
R / F — завърта най-близкия 4D обект ±15°     0 — връщане
X — сечение при твоето w / проекция     C — перспективна / ортогонална / стереографска
P — пауза на Етер     T — повтори реплика     N / Enter — следваща
L — English / Български     J или Tab — Дневник     H — скрий подсказките     Esc — меню

Съвет: в браузър Ctrl+W затваря раздела, затова клякай със Z.

[b]Сензорен екран (телефон / таблет)[/b]

Ляв палец — плаващ джойстик (до ръба = тичане)     Дясна част — плъзни за поглед
СКОК · КЛЯК (превключва) · W+ / W− (задръж; след Станция I)
Равнина · −15° · +15° · ИЗГЛ · СЕЧ (до 4D обект; след Станция III)
Горе: ≡ меню · ДНЕВ · 1P/3P камера · Етер: II пауза · ↺ повтори · » следваща
Настройки: Сензорно управление Авто / Вкл. / Изкл. · Чувствителност при докосване""")

# ------------------------------------------------------------------ state changes
func show_title() -> void:
	title.visible = true; hud.visible = false; pause_menu.visible = false
	continue_btn.visible = G.has_save()

func show_game() -> void:
	title.visible = false; hud.visible = true; pause_menu.visible = false
	var V := get_viewport().get_visible_rect().size
	if _touch_on and V.y > V.x: _rotate_t = 8.0

func show_pause(on: bool) -> void:
	pause_menu.visible = on
	if on: _print_menus.call_deferred()
	if not on:
		settings_panel.visible = false; log_panel.visible = false

func open_settings() -> void:
	settings_panel.visible = true
	settings_panel.move_to_front()
	_layout()
	_center_settings.call_deferred()
	_print_menus.call_deferred()

func _center_settings() -> void:
	var V := get_viewport().get_visible_rect().size
	var sz := settings_box.get_combined_minimum_size()
	settings_box.size = sz
	settings_box.position = ((V - sz) / 2.0).max(Vector2(4, 4))

func any_panel_open() -> bool:
	return settings_panel.visible or log_panel.visible or pause_menu.visible or title.visible or skip_dialog.visible

func show_toast(t: String) -> void:
	toast_label.text = touchify(t); _toast_t = 4.5

const TOUCH_SUBS_EN := [["Use E / Q.", "Hold W+ / W−."], ["(1–6, R/F)", "(plane button, ±15°)"],
	["1–6 choose plane, R/F turn", "plane button, then ±15°"], ["E = ana (+w)   Q = kata (−w)", "W+ = ana (+w)   W− = kata (−w)"],
	["try C and X on the polytopes · J = Research Log", "try VIEW and SLICE near the polytopes · LOG = Research Log"],
	["(P to resume)", "(tap ▶ to resume)"]]
const TOUCH_SUBS_BG := [["Ползвай E / Q.", "Задръж W+ / W−."], ["(1–6, R/F)", "(бутон равнина, ±15°)"],
	["1–6 равнина, R/F завъртане", "бутон равнина, после ±15°"], ["E = ана (+w)   Q = ката (−w)", "W+ = ана (+w)   W− = ката (−w)"],
	["пробвай C и X върху политопите · J = дневник", "пробвай ИЗГЛ и СЕЧ до политопите · ДНЕВ = дневник"],
	["(P за продължение)", "(докосни ▶ за продължение)"]]

## On touch devices, swap keyboard references in objectives/toasts for the on-screen button names.
func touchify(t: String) -> String:
	if not _touch_on: return t
	for pr in (TOUCH_SUBS_BG if G.lang == "bg" else TOUCH_SUBS_EN): t = t.replace(pr[0], pr[1])
	return t

func set_line(lesson_id: String, ln: Dictionary) -> void:
	sub_panel.visible = bool(G.settings["subtitles"])
	var ttl := G.lesson_title(lesson_id)
	sub_speaker.text = "AETHER" + (("  ·  " + ttl) if ttl != "" else "")
	sub_text.text = G.line_text(ln)
	var r := []
	for k in ln["refs"]: r.append(G.refs[k]["short"])
	sub_refs.text = (G.T("Sources: ", "Източници: ") + " · ".join(r)) if not r.is_empty() else ""
	var en_txt: String = ln.get("en", "")
	if _touch_on and (en_txt.contains("Press ") or en_txt.contains("press ") or en_txt.contains(" key")):
		sub_refs.text = G.T("Touch: E = W+ · Q = W− · 1–6 = plane button · R/F = ±15° · C = VIEW · X = SLICE · J = LOG",
			"Сензорно: E = W+ · Q = W− · 1–6 = бутон равнина · R/F = ±15° · C = ИЗГЛ · X = СЕЧ · J = ДНЕВ") + ("\n" + sub_refs.text if sub_refs.text != "" else "")
	var eq: String = ln.get("eq", "")
	if eq != "":
		eq_tex.texture = load("res://eq/%s.png" % eq)
		eq_panel.visible = true
	else:
		eq_panel.visible = false

func clear_line() -> void:
	sub_panel.visible = false; eq_panel.visible = false

func _relabel() -> void:
	(title.find_child("Sub", true, false) as Label).text = G.T("A walk through four-dimensional space  ·  every fact cited", "Разходка в четириизмерното пространство  ·  всеки факт с източник")
	(title.find_child("New", true, false) as Button).text = G.T("New expedition", "Нова експедиция")
	continue_btn.text = G.T("Continue", "Продължи")
	(title.find_child("Set", true, false) as Button).text = G.T("Settings", "Настройки")
	(title.find_child("Log", true, false) as Button).text = G.T("Research Log", "Изследователски дневник")
	(title.find_child("Lang", true, false) as Button).text = "Language: English  ⇄  Български" if G.lang == "en" else "Език: Български  ⇄  English"
	(title.find_child("Foot", true, false) as Label).text = G.T("Made with Blender + Godot · voice: neural TTS · Click a button to begin (enables sound)", "Създадено с Blender + Godot · глас: невронен TTS · Натисни бутон, за да започнеш (включва звука)")
	(pause_menu.find_child("H", true, false) as Label).text = G.T("Paused", "Пауза")
	var names := {"Skip": ["Skip current task", "Пропусни задачата"], "Realm": ["Enter 4D Space", "Влез в 4D пространството"], "Resume": ["Resume", "Продължи"], "Settings": ["Settings", "Настройки"], "Log": ["Research Log", "Дневник"],
		"Save": ["Save game", "Запази"], "Load": ["Load game", "Зареди"], "Quit": ["Quit to title", "Към началото"]}
	for k in names:
		(pause_menu.find_child(k, true, false) as Button).text = G.T(names[k][0], names[k][1])
	(settings_panel.find_child("H", true, false) as Label).text = G.T("Settings", "Настройки")
	var sl := {"sens": ["Mouse sensitivity", "Чувствителност на мишката"], "subs": ["Subtitle size", "Размер на субтитрите"],
		"music": ["Music volume", "Музика"], "voice": ["Voice volume", "Глас"], "sfx": ["Effects volume", "Ефекти"],
		"touch_sens": ["Touch look sensitivity", "Поглед при докосване"]}
	for k in sl: (_set_rows[k] as Label).text = G.T(sl[k][0], sl[k][1])
	var cl := {"reduced_motion": ["Reduced motion (slower 4D turns)", "Намалено движение"],
		"colorblind": ["Colour-blind palette (blue/orange)", "Палитра за далтонисти"],
		"subtitles": ["Subtitles", "Субтитри"], "hints": ["Control hints", "Подсказки за управление"],
		"low_gfx": ["Performance mode (faster, simpler)", "Режим производителност"],
		"fps": ["Show FPS counter", "Покажи FPS"]}
	for k in cl: (_set_rows[k] as CheckBox).text = G.T(cl[k][0], cl[k][1])
	(settings_panel.find_child("Lang", true, false) as Button).text = "Language: English  ⇄  Български" if G.lang == "en" else "Език: Български  ⇄  English"
	(settings_panel.find_child("Close", true, false) as Button).text = G.T("Close", "Затвори")
	var tm: int = int(G.settings.get("touch_mode", 0))
	var tm_en: String = ["Auto", "On", "Off"][tm]; var tm_bg: String = ["Автоматично", "Включени", "Изключени"][tm]
	(settings_panel.find_child("TouchMode", true, false) as Button).text = G.T("Touch controls: ", "Сензорно управление: ") + G.T(tm_en, tm_bg)
	if _touch_on:
		(title.find_child("New", true, false) as Button).text = G.T("▶  Tap to start", "▶  Докосни, за да започнеш")
		(title.find_child("Foot", true, false) as Label).text = G.T("Tap to start · left thumb: move · right side: look · sound starts with your first tap", "Докосни, за да започнеш · ляв палец: движение · дясно: поглед · звукът тръгва с първото докосване")
	(rotate_hint.get_child(0) as Label).text = G.T("Rotate your device to landscape for the best view", "Завърти устройството хоризонтално за най-добър изглед")
	(log_panel.find_child("H", true, false) as Label).text = G.T("Research Log", "Изследователски дневник")
	(log_panel.find_child("Close", true, false) as Button).text = G.T("Close", "Затвори")
	if director and director.current != "":
		set_line(director.current, director.current_line())

func _apply_settings() -> void:
	sub_text.add_theme_font_size_override("font_size", int(G.settings["subs"]))
	hints.visible = bool(G.settings["hints"]) and not _touch_on

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.modulate.a = clamp(_toast_t, 0.0, 1.0)
	_rotate_t = maxf(_rotate_t - delta, 0.0)
	rotate_hint.visible = _touch_on and _rotate_t > 0.0 and get_viewport().get_visible_rect().size.y > get_viewport().get_visible_rect().size.x
	rotate_hint.modulate.a = clampf(_rotate_t, 0.0, 1.0)
	# the HTML fullscreen button (index.html head include) only shows on the title / pause screens
	var fs := 1 if (_touch_on and (title.visible or pause_menu.visible)) else 0
	if fs != _fs_shown and OS.has_feature("web"):
		_fs_shown = fs
		JavaScriptBridge.eval("var b=document.getElementById('hw-fs');if(b)b.style.visibility='%s';" % ("visible" if fs == 1 else "hidden"))
	if touch.player == null: touch.player = get_tree().get_first_node_in_group("player")
	if not hud.visible: return
	var w: float = G.player_w
	w_label.text = "w = %+.2f" % w
	w_marker.position.y = 110.0 - w / 3.0 * 110.0 - 3.0
	w_marker.color = CYAN.lerp(MAG, clamp(w / 6.0 + 0.5, 0.0, 1.0))
	w_lock.text = "" if G.w_unlocked else G.T("w locked", "w заключено")
	objective.text = touchify(objective_text)
	crosshair.visible = not get_tree().get_first_node_in_group("player").third_person
	var ft := manip.focus_text() if manip else ""
	focus_panel.visible = ft != ""
	if ft != "":
		focus_label.text = ft
		for i in 6:
			var on: bool = G.rot_unlocked and i == manip.plane
			plane_chips[i].add_theme_color_override("font_color", Color(1, 0.85, 0.3) if on else Color(0.6, 0.75, 0.9, 0.6 if G.rot_unlocked else 0.3))
	var h := G.T("WASD walk · mouse/←→ look · Shift run · Space jump · Z crouch · V camera", "WASD ходене · мишка/←→ поглед · Shift тичане · Space скок · Z клякане · V камера")
	if G.w_unlocked: h += "\n" + G.T("Q / E  move kata / ana along w", "Q / E  движение ката / ана по w")
	if G.rot_unlocked: h += "\n" + G.T("1–6 plane · R/F rotate 15° · 0 reset · X slice · C projection", "1–6 равнина · R/F 15° · 0 връщане · X сечение · C проекция")
	h += "\n" + G.T("P pause Aether · T replay · N next · L language · J log · Esc menu", "P пауза · T повтори · N следваща · L език · J дневник · Esc меню")
	hints.text = h

# ------------------------------------------------------------------ touch / responsive layout
func _build_rotate_hint() -> void:
	rotate_hint = PanelContainer.new(); rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label("", 18, Color(1, 0.92, 0.6)); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.custom_minimum_size = Vector2(300, 0)
	rotate_hint.add_child(l)
	_place(rotate_hint, Control.PRESET_CENTER, Vector2(0, 40), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	rotate_hint.visible = false
	root.add_child(rotate_hint)

func _log_drag(e: InputEvent) -> void:
	# drag-to-scroll for the Research Log (touch, or emulated mouse from touch)
	var dy := 0.0
	if e is InputEventScreenDrag: dy = e.relative.y
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) and e.device == InputEvent.DEVICE_ID_EMULATION: dy = e.relative.y
	if dy != 0.0:
		var sb := log_text.get_v_scroll_bar(); sb.value -= dy

func _update_scale() -> bool:
	# On phones the 1280x720 canvas would make text tiny: enlarge the UI so that one canvas unit is
	# at least ~0.8 CSS px (window pixels / devicePixelRatio).
	var win := Vector2(DisplayServer.window_get_size())
	var dpr: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	var s0: float = minf(win.x / 1280.0, win.y / 720.0)
	var f := 1.0
	if _touch_on and s0 > 0.0:
		f = clampf(0.8 * dpr / s0, 1.0, 4.0)
	if absf(get_window().content_scale_factor - f) > 0.01:
		get_window().content_scale_factor = f
		print("[touch] scale win=%s dpr=%.2f s0=%.3f factor=%.3f" % [win, dpr, s0, f])
		return true
	return false

var _in_layout := false
func _layout() -> void:
	if _in_layout: return
	_in_layout = true
	_touch_on = G.touch_active()
	if _update_scale():
		_in_layout = false
		_layout.call_deferred()       # canvas size changed; lay out again next frame
		return
	var V := get_viewport().get_visible_rect().size
	var portrait := V.y > V.x
	var ins := touch.safe_insets() if touch else Rect2()
	if _touch_on:
		obj_panel.position = Vector2(12 + ins.position.x, 10 + ins.position.y)
		objective.custom_minimum_size = Vector2(300 if not portrait else V.x * 0.55, 0)
		objective.add_theme_font_size_override("font_size", 15)
		w_panel.scale = Vector2.ONE * 0.55
		_place(w_panel, Control.PRESET_TOP_LEFT, Vector2(12 + ins.position.x, 96 + ins.position.y))
		focus_panel.custom_minimum_size = Vector2(320, 0); focus_label.custom_minimum_size = Vector2(300, 0)
		_place(focus_panel, Control.PRESET_TOP_RIGHT, Vector2(-14 - ins.size.x, touch.focus_y() + (64 if portrait else 0)), Control.GROW_DIRECTION_BEGIN)
		eq_panel.scale = Vector2.ONE * 0.62
		# scaled about its top-left corner: shift so the *visual* panel is centred (portrait) / left of the top-right buttons
		var ew: float = eq_panel.get_combined_minimum_size().x
		var cx: float = (V.x * 0.5) if portrait else 0.5 * ((ins.position.x + 340.0) + (V.x - ins.size.x - 390.0))
		_place(eq_panel, Control.PRESET_CENTER_TOP, Vector2(cx - V.x * 0.5 + ew * 0.5 - ew * 0.31, (230.0 if portrait else 50.0) + ins.position.y), Control.GROW_DIRECTION_BOTH)
		var sw: float = (V.x - 24.0) if portrait else minf(860.0, V.x - 500.0)
		sub_panel.custom_minimum_size = Vector2(sw, 0); sub_text.custom_minimum_size = Vector2(sw - 30, 0)
		_place(sub_panel, Control.PRESET_CENTER_BOTTOM, Vector2(0, -(250.0 if portrait else 10.0) - ins.size.y), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
		toast_label.custom_minimum_size = Vector2(minf(1000, V.x - 40), 0)
	else:
		obj_panel.position = Vector2(18, 16)
		objective.custom_minimum_size = Vector2(420, 0)
		objective.add_theme_font_size_override("font_size", 18)
		w_panel.scale = Vector2.ONE
		_place(w_panel, Control.PRESET_CENTER_LEFT, Vector2(18, -170))
		focus_panel.custom_minimum_size = Vector2(410, 0); focus_label.custom_minimum_size = Vector2(380, 0)
		_place(focus_panel, Control.PRESET_TOP_RIGHT, Vector2(-16, 16), Control.GROW_DIRECTION_BEGIN)
		eq_panel.scale = Vector2.ONE
		_place(eq_panel, Control.PRESET_CENTER_RIGHT, Vector2(-16, -190), Control.GROW_DIRECTION_BEGIN)
		sub_panel.custom_minimum_size = Vector2(860, 0); sub_text.custom_minimum_size = Vector2(830, 0)
		_place(sub_panel, Control.PRESET_CENTER_BOTTOM, Vector2(0, -22), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
		toast_label.custom_minimum_size = Vector2(1000, 0)
	# menus: shrink to fit short / narrow screens
	var tms := title_box.get_combined_minimum_size()
	var tsc: float = minf(1.0, minf((V.y - 60.0) / maxf(tms.y, 1.0), (V.x - 48.0) / maxf(tms.x, 1.0)))
	title_box.scale = Vector2.ONE * tsc
	title_box.position = Vector2((80 if tsc >= 1.0 else 24) + ins.position.x, (80 if tsc >= 1.0 else (60 if portrait and _touch_on else 14)) + ins.position.y)
	var foot := title.find_child("Foot", true, false) as Label
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(minf(1100.0, V.x - 48.0), 0)
	_place(foot, Control.PRESET_BOTTOM_LEFT, Vector2(24 + ins.position.x if _touch_on else 80, -14 - ins.size.y if _touch_on else -36), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	if portrait and _touch_on and not _was_portrait: _rotate_t = 12.0
	_was_portrait = portrait
	var psc: float = minf(1.0, (V.y - 30.0) / 540.0)
	pause_box.scale = Vector2.ONE * psc
	pause_box.pivot_offset = pause_box.size / 2
	var swid: float = minf(1000.0, V.x - 60.0)
	var two: bool = swid >= 2.0 * 430.0 + 76.0
	var colw: float = (swid - 76.0) / 2.0 if two else swid - 30.0
	for c in settings_cols: c.custom_minimum_size = Vector2(colw, 0)
	var ch: float = 0.0
	for c in settings_cols:
		var hh: float = c.get_combined_minimum_size().y
		ch = maxf(ch, hh) if two else ch + hh + 10.0
	var sh: float = minf(ch + 8.0, V.y - 130.0)
	settings_scroll.custom_minimum_size = Vector2(swid, sh)
	settings_box.custom_minimum_size = Vector2(swid + 24, 0)
	settings_box.reset_size()
	for side in ["left", "right", "top", "bottom"]:
		log_margin.add_theme_constant_override("margin_" + side, 40 if not _touch_on else 14)
	log_list.custom_minimum_size = Vector2(330 if V.x > 900 else 170, 0)
	_apply_settings()
	_relabel()
	obj_panel.reset_size(); focus_panel.reset_size(); sub_panel.reset_size()
	if touch: touch.layout()
	_in_layout = false
	_print_menus.call_deferred()

func _print_menus() -> void:
	await get_tree().process_frame
	var V := get_viewport().get_visible_rect().size
	var out := []
	for pair in [["new", title.find_child("New", true, false)], ["tlog", title.find_child("Log", true, false)],
			["tset", title.find_child("Set", true, false)], ["resume", pause_menu.find_child("Resume", true, false)],
			["psettings", pause_menu.find_child("Settings", true, false)], ["pquit", pause_menu.find_child("Quit", true, false)],
			["sclose", settings_panel.find_child("Close", true, false)], ["stouch", settings_panel.find_child("TouchMode", true, false)]]:
		var c: Control = pair[1]
		var r := c.get_global_rect()
		out.append("%s=%s" % [pair[0], r.get_center().round()])
	print("[touch] menus vp=%s %s" % [V.round(), " ".join(out)])

# ------------------------------------------------------------------ skip puzzle / task
func _build_skip() -> void:
	skip_btn = _btn("", func(): skip_requested.emit())
	skip_btn.custom_minimum_size = Vector2(250, 44)
	_place(skip_btn, Control.PRESET_CENTER_TOP, Vector2(0, 96), Control.GROW_DIRECTION_BOTH)
	skip_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	skip_btn.visible = false; skip_btn.focus_mode = Control.FOCUS_NONE
	hud.add_child(skip_btn)
	skip_dialog = Control.new(); skip_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = Color(0, 0.01, 0.03, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_dialog.add_child(dim)
	var p := PanelContainer.new(); _place(p, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10)
	var h := _label("", 28, CYAN); h.name = "H"; h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(h)
	skip_label = _label("", 17, Color(1.0, 0.92, 0.6)); skip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skip_label.custom_minimum_size = Vector2(420, 0); skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(skip_label)
	for pair in [["Hint", func(): skip_hint.emit()], ["Anyway", func(): skip_anyway.emit()], ["Cancel", func(): skip_cancel.emit()]]:
		var b := _btn("", pair[1]); b.name = pair[0]; v.add_child(b)
	p.add_child(v); skip_dialog.add_child(p)
	skip_dialog.visible = false
	root.add_child(skip_dialog)

## kind: "" (hidden), "lesson", "puzzle", "walk"
func set_skip(kind: String) -> void:
	skip_btn.visible = kind != "" and hud.visible
	if kind == "": return
	var key := "" if _touch_on else "  [K]"
	match kind:
		"lesson": skip_btn.text = G.T("Skip lesson", "Пропусни урока") + key
		"puzzle": skip_btn.text = G.T("Skip puzzle", "Пропусни загадката") + key
		_: skip_btn.text = G.T("Skip ahead", "Прескочи напред") + key

func open_skip_dialog(task_text: String) -> void:
	skip_label.text = touchify(task_text)
	var k := not _touch_on
	(skip_dialog.find_child("H", true, false) as Label).text = G.T("Stuck?", "Заседна ли?")
	(skip_dialog.find_child("Hint", true, false) as Button).text = G.T("Ask Aether for a hint", "Подсказка от Етер") + ("  [1]" if k else "")
	(skip_dialog.find_child("Anyway", true, false) as Button).text = G.T("Skip anyway (solve it)", "Пропусни (реши я)") + ("  [2]" if k else "")
	(skip_dialog.find_child("Cancel", true, false) as Button).text = G.T("Cancel", "Отказ") + ("  [Esc]" if k else "")
	skip_dialog.visible = true
	skip_dialog.move_to_front()
