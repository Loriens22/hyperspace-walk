## Lesson C: rotations happen in planes; the six planes of R^4; simple rotation (xy looks 3D, xw turns the
## tesseract inside out), double rotation (xy & zw at different rates) and isoclinic rotation (equal rates).
extends Station

var tess: PolyView
var planes_lbl: Label3D
var mode_lbl: Label3D
var _active := []

func _ready() -> void:
	lesson_id = "C"; requires = "B"
	build_terminal("III · Rotation in 4D", "III · Въртене в 4D")
	focus_offset = Vector3(-1.6, 2.6, 1.0)
	tess = PolyView.new().setup("tesseract", 1.35)
	tess.position = Vector3(0, 2.8, 0)
	tess.width = 0.03; tess.dot_size = 0.065
	tess.rot = P4.rot_plane_idx(1, 0.45) * P4.rot_plane_idx(3, 0.3)
	tess.spin = [[2, 0.35], [4, 0.2]]
	tess.add_to_group("rotatable"); tess.set_meta("display", "tesseract {4,3,3}")
	add_child(tess)
	planes_lbl = Label3D.new(); planes_lbl.font_size = 56; planes_lbl.pixel_size = 0.005; planes_lbl.outline_size = 10
	planes_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; planes_lbl.position = Vector3(0, 5.0, 0)
	add_child(planes_lbl)
	mode_lbl = Label3D.new(); mode_lbl.font_size = 50; mode_lbl.pixel_size = 0.005; mode_lbl.outline_size = 10
	mode_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; mode_lbl.position = Vector3(0, 1.4, 0); mode_lbl.modulate = Color(1, 0.95, 0.6)
	add_child(mode_lbl)
	_show([2, 4], "")

func _show(act: Array, mode_text: String) -> void:
	_active = act
	var parts := []
	for i in 6:
		var n: String = P4.PLANE_NAMES[i]
		parts.append(("[%s]" % n) if act.has(i) else (" %s " % n))
	planes_lbl.text = "  ".join(parts)
	mode_lbl.text = mode_text

func handle_cue(lesson: String, c: String) -> void:
	if lesson != "C": return
	var base := P4.rot_plane_idx(1, 0.45) * P4.rot_plane_idx(3, 0.3)
	match c:
		"rot_none":
			tess.spin = []; tess.rot = base; _show([], G.T("6 rotation planes in ℝ⁴", "6 равнини на въртене в ℝ⁴"))
		"rot_xy":
			tess.rot = base; tess.spin = [[0, 0.7]]; _show([0], G.T("simple rotation in xy (w untouched)", "просто въртене в xy (w не се мени)"))
		"rot_xw":
			tess.rot = base; tess.spin = [[2, 0.6]]; _show([2], G.T("simple rotation in xw · fixed plane: yz", "просто въртене в xw · неподвижна равнина: yz"))
		"rot_double":
			tess.rot = base; tess.spin = [[0, 0.75], [5, 0.33]]; _show([0, 5], G.T("double rotation: xy at α̇ = 0.75, zw at β̇ = 0.33 rad/s", "двойно въртене: xy при α̇ = 0.75, zw при β̇ = 0.33 rad/s"))
		"rot_iso":
			tess.rot = base; tess.spin = [[0, 0.5], [5, 0.5]]; _show([0, 5], G.T("isoclinic rotation: α = β", "изоклинно въртене: α = β"))
		"unlock_rot":
			tess.spin = [[0, 0.3], [5, 0.3]]; tess.base_spin = tess.spin.duplicate()
			_show([], G.T("1–6 plane · R/F turn 15° · 0 reset · X slice · C projection", "1–6 равнина · R/F 15° · 0 връщане · X сечение · C проекция"))
			G.rot_unlocked = true
			G.play_sfx("unlock")
			G.toast.emit(G.T("4D ROTATION UNLOCKED  ·  1–6 choose plane, R/F turn", "4D ВЪРТЕНЕ ОТКЛЮЧЕНО  ·  1–6 равнина, R/F завъртане"))
			G.changed.emit()
