## "Enter 4D Space": a genuine 4D world in R^4 seen by a 4D observer.
## The observer has a 4D position and an orthonormal SO(4) frame (R, U, F, A).
## View modes: "4D Eye" = 4D perspective onto a 3D retina (shown as an orbitable translucent
## volume, after Hanson & Heng 1992 / Hinton), and "Slice" = the observer's own 3D hyperplane
## a = 0 (oriented by the frame, like 4D Toys / Miegakure). All projection and slicing runs on
## the GPU (shaders/realm4d_*.gdshader); this script builds the 4D meshes once and drives the frame.
class_name Realm4D
extends Node3D

signal exit_requested

const SH_ADD := preload("res://shaders/realm4d_add.gdshader")
const SH_SOLID := preload("res://shaders/realm4d_solid.gdshader")
const SH_OPAQUE := preload("res://shaders/realm4d_opaque.gdshader")
const START_POS := Vector4(0, 1.6, 8, 0)

var active := false
var built := false
var lite := false
var pos := START_POS
# horizontal frame (yaw + 4D turns act here) and pitch on top of it
var Rh := Vector4(1, 0, 0, 0)
var Uh := Vector4(0, 1, 0, 0)
var Fh := Vector4(0, 0, -1, 0)
var Ah := Vector4(0, 0, 0, 1)
var pitch := 0.0
var R := Rh; var U := Uh; var F := Fh; var A := Ah
var view := 0                        # 0 = 4D Eye (retina), 1 = Slice
var fog := true
var orbit_yaw := 0.75
var orbit_pitch := 0.38
var orbit_dist := 4.2
var auto_orbit := false
var touch_orbit := false
var cam: Camera3D
var env: Environment
var frame_node: MeshInstance3D
var eye_root: Node3D
var slice_root: Node3D
var mats: Array[ShaderMaterial] = []
var dyn: Array = []                  # {mats, pos, rot, spin:[[plane, speed]...]}
var crystals: Array = []             # {pos, mats, nodes, got}
var box_c := Vector4(5, 1.2, -1, 0)
const BOX_H := 1.0
const BOX_WALL := 0.06
const BOX_T := 0.12
var room_lo := Vector4(-3, 0, -13, -3)
var room_hi := Vector4(3, 4, -7, 3)
var room_seen := {}
var hud: CanvasLayer
var panel: PanelContainer
var info: Label
var gizmo: Control
var director: Director
var ui: UI
var _t := 0.0
var _rdrag := false
var _music_prev := 0.0
var _prog := {}

# ------------------------------------------------------------------ setup
func _ready() -> void:
	visible = false
	cam = Camera3D.new(); cam.fov = 50.0; cam.near = 0.05; cam.far = 400.0; add_child(cam)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.028)
	env.glow_enabled = true; env.glow_intensity = 0.55; env.glow_bloom = 0.04; env.glow_hdr_threshold = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	eye_root = Node3D.new(); add_child(eye_root)
	slice_root = Node3D.new(); add_child(slice_root)
	_build_hud()

func _mat(shader: Shader, kind: int = -1) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = shader
	if kind >= 0: m.set_shader_parameter("kind", kind)
	mats.append(m)
	return m

func _inst(parent: Node3D, mesh: ArrayMesh, m: ShaderMaterial) -> MeshInstance3D:
	if mesh == null: return null
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	parent.add_child(mi)
	return mi

## Adds one 4D object group: glowing edges + faint faces in the Eye; slice outline + cells in Slice.
## Returns the materials so dynamic objects can get their own rotation/position.
func _add_group(items_e: Array, items_t: Array, items_c: Array, opaque := false, face_k := 1.0) -> Array:
	var out := []
	var me := _mat(SH_ADD, 0); _inst(eye_root, Realm4DGeo.build(items_e, "edge"), me); out.append(me)
	if not items_t.is_empty():
		var ft := []
		var st := []
		for it in items_t:
			var col: Color = it[1]
			if col.a * face_k > 0.001: ft.append([it[0], Color(col, col.a * face_k)])
			st.append([it[0], Color(col, 0.9)])
		if not ft.is_empty():
			var mf := _mat(SH_ADD, 1)
			_inst(eye_root, Realm4DGeo.build(ft, "tri"), mf); out.append(mf)
		var ms := _mat(SH_ADD, 2); _inst(slice_root, Realm4DGeo.build(st, "slice"), ms); out.append(ms)
	if not items_c.is_empty():
		var mc := _mat(SH_OPAQUE if opaque else SH_SOLID)
		_inst(slice_root, Realm4DGeo.build(items_c, "tet"), mc); out.append(mc)
	return out

func build() -> void:
	if built: return
	built = true
	var t0 := Time.get_ticks_msec()
	lite = G.touch_platform or G.touch_active() or bool(G.settings.get("low_gfx", false))
	seed(4)
	# --- static world, merged into one group per material
	var E := []; var T := []; var C := []
	var grid: Dictionary = Realm4DGeo.ground(12.0, 3.0)
	E.append([grid["e"], Color(0.2, 0.6, 1.0, 0.55)])
	T.append([grid["t"], Color(0.25, 0.65, 1.0, 0.0)])     # faces invisible in the Eye; their slice = floor grid
	var pil := Realm4DGeo.empty()
	for p in [Vector3(-6.5, 2, -3.5), Vector3(6.5, 2, -3.5), Vector3(-6.5, 2, 3.5), Vector3(6.5, 2, 3.5),
			Vector3(-7, -16, 0), Vector3(7, -16, 0), Vector3(-4, -22, 2.5), Vector3(4, -22, -2.5)]:
		Realm4DGeo.merge(pil, Realm4DGeo.box(Vector4(p.x, 2.5, p.y, p.z), Vector4(0.3, 2.5, 0.3, 0.3)))
	E.append([pil["e"], Color(0.55, 1.0, 0.95, 0.8)]); T.append([pil["t"], Color(0.4, 0.95, 0.9, 0.05)]); C.append([pil["c"], Color(0.25, 0.75, 0.75, 0.55)])
	var room: Dictionary = Realm4DGeo.box_minmax(room_lo, room_hi)
	E.append([room["e"], Color(1.0, 0.35, 0.85, 1.0)]); T.append([room["t"], Color(1.0, 0.35, 0.85, 0.035)]); C.append([room["c"], Color(0.9, 0.3, 0.8, 0.13)])
	var tr: Dictionary = Realm4DGeo.tree(Vector4(9, 0, -9, -2.5))
	E.append([tr["e"], Color(0.45, 1.0, 0.45, 0.8)]); T.append([tr["t"], Color(0.4, 1.0, 0.4, 0.035)]); C.append([tr["c"], Color(0.3, 0.8, 0.35, 0.6)])
	var cl: Dictionary = Realm4DGeo.clifford(Vector4(-8, 3.4, -6, 0), 1.7, 16 if lite else 24)
	E.append([cl["e"], Color(1.0, 0.75, 0.3, 0.75)]); T.append([cl["t"], Color(1.0, 0.7, 0.25, 0.05)])
	var hs2: Dictionary = Realm4DGeo.poly("24cell", Vector4.ONE * 1.1, Vector4(-12, 2.2, -15, 2.5))
	E.append([hs2["e"], Color(0.6, 0.85, 1.0, 0.8)]); T.append([hs2["t"], Color(0.5, 0.8, 1.0, 0.03)]); C.append([hs2["c"], Color(0.4, 0.6, 0.95, 0.35)])
	_add_group(E, T, C)
	# a hypersphere (3-sphere) approximated by the 600-cell's 120 vertices on it; dense, so dimmer
	var hs: Dictionary = Realm4DGeo.poly("600cell", Vector4.ONE * 2.3, Vector4(0, 3.6, -20, 0), false)
	for m in _add_group([[hs["e"], Color(0.45, 0.65, 1.0, 0.8)]], [[hs["t"], Color(0.4, 0.55, 1.0, 0.0)]], []):
		m.set_shader_parameter("energy", 0.45)
	# the sealed 3D box: six thin walls that only exist for |w| < BOX_T
	var bx := Realm4DGeo.empty()
	for ax in 3:
		for sg in [-1.0, 1.0]:
			var c := box_c; var h := Vector4(BOX_H, BOX_H, BOX_H, BOX_T)
			c[ax] += sg * BOX_H; h[ax] = BOX_WALL
			Realm4DGeo.merge(bx, Realm4DGeo.box(c, h))
	_add_group([[bx["e"], Color(1.0, 0.7, 0.3, 0.4)]], [[bx["t"], Color(1.0, 0.65, 0.25, 0.012)]], [[bx["c"], Color(0.85, 0.55, 0.22, 1.0)]], true)
	# --- the six regular 4-polytopes, slowly rotating in double rotations
	var defs := [["5cell", Vector4(-9, 3, -25, -2), Color(1.0, 0.45, 0.3)], ["tesseract", Vector4(-5.5, 3, -28, 2), Color(0.35, 0.9, 1.0)],
		["16cell", Vector4(-2, 3, -30, -3), Color(1.0, 0.85, 0.3)], ["24cell", Vector4(2, 3, -30, 3), Color(0.55, 1.0, 0.5)],
		["600cell", Vector4(5.5, 3, -28, -1.5), Color(0.6, 0.6, 1.0)], ["120cell", Vector4(9, 3, -25, 1.5), Color(1.0, 0.5, 0.9)]]
	for i in defs.size():
		var d: Array = defs[i]
		var big: bool = d[0] == "600cell" or d[0] == "120cell"
		var g: Dictionary = Realm4DGeo.poly(d[0], Vector4.ONE * 1.5, Vector4.ZERO, not big)
		var col: Color = d[2]
		var ms := _add_group([[g["e"], Color(col, 0.9)]], [[g["t"], Color(col, 0.0 if big else 0.03)]], [[g["c"], Color(col * 0.8, 0.5)]])
		if big:
			for m in ms: m.set_shader_parameter("energy", 0.5)
		dyn.append({"mats": ms, "pos": d[1], "rot": Projection.IDENTITY, "spin": [[i % 6, 0.23 + 0.04 * i], [5 - (i % 6), 0.17]]})
	# --- four w-crystals (small 16-cells) to collect
	var cps := [Vector4(-4, 1.5, 0, 3.0), box_c, Vector4(0, 2.0, -10, 2.3), Vector4(0, 1.6, 8, 8.0)]
	var got: Array = _got()
	for i in cps.size():
		var g: Dictionary = Realm4DGeo.poly("16cell", Vector4.ONE * 0.38)
		var col := Color(0.25, 1.0, 0.85)
		var ms := _add_group([[g["e"], Color(col, 1.0)]], [[g["t"], Color(col, 0.12)]], [[g["c"], Color(0.3, 1.0, 0.85, 0.85)]])
		for m in ms: m.set_shader_parameter("energy", 1.5)
		var c := {"pos": cps[i], "mats": ms, "got": got.has(i), "rot": Projection.IDENTITY}
		crystals.append(c)
		dyn.append({"mats": ms, "pos": cps[i], "rot": Projection.IDENTITY, "spin": [[2, 0.9], [3, 0.7]], "crystal": i})
	# retina cube frame
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for a in 3:
		for s1 in [-1.0, 1.0]:
			for s2 in [-1.0, 1.0]:
				var p0 := Vector3.ZERO; var p1 := Vector3.ZERO
				p0[a] = -1.0; p1[a] = 1.0
				p0[(a + 1) % 3] = s1; p1[(a + 1) % 3] = s1
				p0[(a + 2) % 3] = s2; p1[(a + 2) % 3] = s2
				im.surface_add_vertex(p0 * 1.004); im.surface_add_vertex(p1 * 1.004)
	im.surface_end()
	frame_node = MeshInstance3D.new(); frame_node.mesh = im
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.5, 0.8, 1.0, 0.35); fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frame_node.material_override = fm
	eye_root.add_child(frame_node)
	# axis triad at a retina corner: r (right), u (up), a (ana) — the retina's third axis is ana, not depth
	var ax := ImmediateMesh.new()
	ax.surface_begin(Mesh.PRIMITIVE_LINES)
	var o := Vector3(-1, -1, -1) * 1.004
	for k in 3:
		var d := Vector3.ZERO; d[k] = 0.45
		ax.surface_set_color(Color(1.0, 0.45, 0.9) if k == 2 else Color(0.8, 0.95, 1.0))
		ax.surface_add_vertex(o); ax.surface_add_vertex(o + d)
	ax.surface_end()
	var axn := MeshInstance3D.new(); axn.mesh = ax
	var am := StandardMaterial3D.new(); am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; am.vertex_color_use_as_albedo = true
	axn.material_override = am; eye_root.add_child(axn)
	for k in 3:
		var lb := Label3D.new(); lb.text = ["r", "u", "a  (ana)"][k]; lb.font_size = 32; lb.pixel_size = 0.0028
		var d := Vector3.ZERO; d[k] = 0.58
		lb.position = o + d; lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.no_depth_test = true
		lb.modulate = Color(1.0, 0.5, 0.92) if k == 2 else Color(0.8, 0.95, 1.0, 0.9)
		eye_root.add_child(lb)
	var lab2 := Label3D.new(); lab2.text = G.T("4D EYE · 3D retina", "4D ОКО · 3D ретина"); lab2.position = Vector3(0, -1.14, 1.0); lab2.font_size = 30; lab2.pixel_size = 0.003
	lab2.modulate = Color(0.6, 0.9, 1.0, 0.75); lab2.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lab2.no_depth_test = true
	eye_root.add_child(lab2)
	_apply_view()
	print("[realm] built in %d ms lite=%s mats=%d" % [Time.get_ticks_msec() - t0, lite, mats.size()])

# ------------------------------------------------------------------ enter / exit
func enter() -> void:
	build()
	active = true
	visible = true
	hud.visible = true
	cam.current = true
	_music_prev = G.player_w
	_load_progress()
	_apply_view()
	_test_args()
	if not G.lessons_done.has("realm") and not OS.get_cmdline_user_args().has("--rquiet"):
		director.play("realm")
	print("[realm] enter pos=%s" % pos)

## test hooks: --rpos=x,y,z,w --rturn=zw:0.8,yaw:0.3 --rpitch=deg --rview=1 --rorbit=yaw,pitch,dist --rnofog
func _test_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() < 2 and kv[0] != "rnofog": continue
		match kv[0]:
			"rpos":
				var c := kv[1].split(","); pos = Vector4(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
			"rturn":
				for t in kv[1].split(","):
					var pa := t.split(":"); turn(pa[0], float(pa[1]))
			"rpitch": pitch = deg_to_rad(float(kv[1]))
			"rview": view = int(kv[1]); _apply_view()
			"rorbit":
				var c := kv[1].split(","); orbit_yaw = float(c[0]); orbit_pitch = float(c[1]); orbit_dist = float(c[2])
			"rnofog": fog = false

func leave() -> void:
	active = false
	visible = false
	hud.visible = false
	cam.current = false
	G.player_w = _music_prev
	_rdrag = false
	print("[realm] leave")

func reset_orientation() -> void:
	var h := Vector2(Fh.x, Fh.z)
	var yaw := atan2(-h.x, -h.y) if h.length() > 0.2 else 0.0
	Rh = Vector4(cos(yaw), 0, -sin(yaw), 0)
	Fh = Vector4(-sin(yaw), 0, -cos(yaw), 0)
	Uh = Vector4(0, 1, 0, 0); Ah = Vector4(0, 0, 0, 1)
	pitch = 0.0
	G.toast.emit(G.T("Orientation levelled (ana = +w again)", "Ориентацията е изправена (ана = +w)"))

func toggle_view() -> void:
	view = 1 - view
	_apply_view()
	G.play_sfx("ui", -10.0)
	G.toast.emit(G.T("View: 4D Eye (3D retina)", "Изглед: 4D око (3D ретина)") if view == 0 else G.T("View: Slice (your 3D hyperplane)", "Изглед: сечение (твоята 3D хиперравнина)"))
	print("[realm] view=%d" % view)

func _apply_view() -> void:
	if eye_root: eye_root.visible = view == 0
	if slice_root: slice_root.visible = view == 1
	if cam: cam.fov = 50.0 if view == 0 else 72.0

# ------------------------------------------------------------------ frame maths
static func _rot_pair(a: Vector4, b: Vector4, ang: float) -> Array:
	var c := cos(ang); var s := sin(ang)
	return [a * c + b * s, b * c - a * s]

func turn(plane: String, ang: float) -> void:
	var r: Array
	match plane:
		"yaw": r = _rot_pair(Fh, Rh, ang); Fh = r[0]; Rh = r[1]
		"xw": r = _rot_pair(Rh, Ah, ang); Rh = r[0]; Ah = r[1]
		"yw": r = _rot_pair(Uh, Ah, ang); Uh = r[0]; Ah = r[1]
		"zw": r = _rot_pair(Fh, Ah, ang); Fh = r[0]; Ah = r[1]

func _orthonormalize() -> void:
	var m := P4.orthonormalize(Projection(Rh, Uh, Fh, Ah))
	Rh = m.x; Uh = m.y; Fh = m.z; Ah = m.w

func _frame() -> void:
	var c := cos(pitch); var s := sin(pitch)
	R = Rh; A = Ah
	F = Fh * c + Uh * s
	U = Uh * c - Fh * s

func touch_look(rel: Vector2) -> void:
	if touch_orbit and view == 0:
		orbit_yaw -= rel.x * 1.2; orbit_pitch = clamp(orbit_pitch + rel.y * 1.2, -1.3, 1.3)
	else:
		turn("yaw", rel.x); pitch = clamp(pitch - rel.y, -1.45, 1.45)

func _unhandled_input(e: InputEvent) -> void:
	if not active or G.paused: return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			_rdrag = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			orbit_dist = clamp(orbit_dist - 0.2, 2.2, 7.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			orbit_dist = clamp(orbit_dist + 0.2, 2.2, 7.0)
	elif e is InputEventMouseMotion:
		if _rdrag and view == 0:
			orbit_yaw -= e.relative.x * 0.006
			orbit_pitch = clamp(orbit_pitch + e.relative.y * 0.006, -1.3, 1.3)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var k: float = float(G.settings["sens"]) * 0.01
			turn("yaw", e.relative.x * k)
			pitch = clamp(pitch - e.relative.y * k, -1.45, 1.45)
	elif e.is_action_pressed("cam"):
		toggle_view()
	elif e.is_action_pressed("r_fog"):
		fog = not fog
		G.toast.emit(G.T("4D depth fog: on", "4D мъгла: вкл.") if fog else G.T("4D depth fog: off", "4D мъгла: изкл."))
	elif e.is_action_pressed("r_orbit"):
		auto_orbit = not auto_orbit
	elif e.is_action_pressed("rot_reset"):
		reset_orientation()
	elif e.is_action_pressed("r_exit"):
		exit_requested.emit()

func _box_blocked(p: Vector4) -> bool:
	if absf(p.w - box_c.w) > BOX_T + 0.2: return false
	var d := maxf(absf(p.x - box_c.x), maxf(absf(p.y - box_c.y), absf(p.z - box_c.z)))
	return d > BOX_H - BOX_WALL - 0.25 and d < BOX_H + BOX_WALL + 0.25

func _process(delta: float) -> void:
	if not active: return
	_t += delta
	# --- movement and 4D turns
	var spd := 3.0 * (2.0 if Input.is_action_pressed("run") else 1.0)
	var mv := F * (Input.get_action_strength("fwd") - Input.get_action_strength("back")) \
		+ R * (Input.get_action_strength("right") - Input.get_action_strength("left")) \
		+ U * (Input.get_action_strength("jump") - Input.get_action_strength("crouch")) \
		+ A * (Input.get_action_strength("ana") - Input.get_action_strength("kata"))
	if mv.length() > 1.0: mv = mv.normalized()
	var np := pos + mv * spd * delta
	np.y = maxf(np.y, 0.35)
	if _box_blocked(np) and not _box_blocked(pos): np = pos
	pos = np
	var tr := 1.1 * delta
	turn("xw", (Input.get_action_strength("t_xw_p") - Input.get_action_strength("t_xw_m")) * tr)
	turn("yw", (Input.get_action_strength("t_yw_p") - Input.get_action_strength("t_yw_m")) * tr)
	turn("zw", (Input.get_action_strength("t_zw_p") - Input.get_action_strength("t_zw_m")) * tr)
	turn("yaw", Input.get_axis("look_left", "look_right") * delta * 1.8)
	_orthonormalize()
	_frame()
	# --- retina camera orbit (Eye) / fixed view (Slice)
	if auto_orbit: orbit_yaw += delta * 0.25
	if view == 0:
		var o := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_dist
		var tgt := Vector3(0, -0.45, 0) if G.touch_active() else Vector3(0, -0.12, 0)   # lift the retina above the subtitles
		cam.transform = Transform3D(Basis.IDENTITY, o + tgt).looking_at(tgt, Vector3.UP)
	else:
		cam.transform = Transform3D.IDENTITY
	# --- uniforms
	var basis := Projection(R, U, F, A)
	var fd := 22.0 if fog else 1e6
	for m in mats:
		m.set_shader_parameter("cam_basis", basis)
		m.set_shader_parameter("cam_pos", pos)
		m.set_shader_parameter("fog_dist", fd)
		m.set_shader_parameter("fog_on", 1.0 if fog else 0.0)
	for d in dyn:
		var rot: Projection = d["rot"]
		for sp in d["spin"]:
			rot = P4.rot_plane_idx(sp[0], sp[1] * delta) * rot
		d["rot"] = P4.orthonormalize(rot)
		var p: Vector4 = d["pos"]
		if d.has("crystal"): p += Vector4(0, sin(_t * 1.7 + d["crystal"]) * 0.12, 0, 0)
		for m in d["mats"]:
			m.set_shader_parameter("obj_rot", d["rot"])
			m.set_shader_parameter("obj_pos", p)
	# --- music follows how far the frame has turned into w (and how far you are along w)
	var tilt := sqrt(maxf(0.0, 1.0 - A.w * A.w))
	G.player_w = 2.5 * clampf(maxf(tilt, absf(pos.w) / 6.0), 0.0, 1.0)
	_tasks()
	_update_hud()

# ------------------------------------------------------------------ activities
func _load_progress() -> void:
	var got: Array = _got()
	for i in crystals.size():
		crystals[i]["got"] = got.has(i)
		for m in crystals[i]["mats"]: m.set_shader_parameter("alpha_mul", 0.0 if crystals[i]["got"] else 1.0)
		for m in crystals[i]["mats"]: m.set_shader_parameter("energy", 0.0 if crystals[i]["got"] else 1.5)
	room_seen = {}
	for k in G.settings.get("realm_room_cells", []): room_seen[int(k)] = true

func _got() -> Array:
	var out := []
	for x in G.settings.get("realm_crystals", []): out.append(int(x))
	return out

func n_crystals() -> int:
	var n := 0
	for c in crystals:
		if c["got"]: n += 1
	return n

func _tasks() -> void:
	for i in crystals.size():
		var c: Dictionary = crystals[i]
		if c["got"]: continue
		if (pos - c["pos"]).length() < 0.95:
			c["got"] = true
			for m in c["mats"]:
				m.set_shader_parameter("energy", 0.0); m.set_shader_parameter("alpha_mul", 0.0)
			var got: Array = _got()
			got.append(i); G.settings["realm_crystals"] = got; G.save_settings_only()
			G.play_sfx("crystal")
			G.toast.emit(G.T("w-crystal %d/4" % n_crystals(), "w-кристал %d/4" % n_crystals()))
			print("[realm] crystal %d (%d/4)" % [i, n_crystals()])
			if n_crystals() == 4: director.play("realm_done")
			else: director.bark("realm_crystal")
	# looking into the sealed box from the w direction (Eye view, gaze tilted into w)
	if not bool(G.settings.get("realm_box", false)) and view == 0:
		var dv := box_c - pos
		var cf := dv.dot(F)
		if cf > 0.5 and dv.length() < 13.0 and absf(F.w) > 0.45:
			var rr := Vector3(dv.dot(R), dv.dot(U), dv.dot(A)) * (1.1 / cf)
			if maxf(absf(rr.x), maxf(absf(rr.y), absf(rr.z))) < 0.9:
				G.settings["realm_box"] = true; G.save_settings_only()
				G.play_sfx("success", -6.0)
				director.play("realm_box")
				print("[realm] box seen from w")
	# tesseract room: which of its 8 cubic cells are you next to?
	var inside := true
	for k in 4:
		if pos[k] < room_lo[k] - 0.2 or pos[k] > room_hi[k] + 0.2: inside = false
	if inside:
		var best := -1; var bv := 0.0
		for k in 4:
			var h := (room_hi[k] - room_lo[k]) * 0.5
			var v := (pos[k] - (room_hi[k] + room_lo[k]) * 0.5) / h
			if absf(v) > bv: bv = absf(v); best = k * 2 + (1 if v > 0 else 0)
		if bv > 0.55 and not room_seen.has(best):
			room_seen[best] = true
			G.settings["realm_room_cells"] = room_seen.keys(); G.save_settings_only()
			G.play_sfx("ui", -4.0)
			G.toast.emit(G.T("Room cell %s visited (%d/8)" % [_cell_name(best), room_seen.size()], "Клетка %s (%d/8)" % [_cell_name(best), room_seen.size()]))
			if room_seen.size() == 8: director.play("realm_room")

func _cell_name(i: int) -> String:
	return ("−+"[i % 2]) + "xyzw"[i / 2]

func objective() -> String:
	var bx := "✓" if bool(G.settings.get("realm_box", false)) else "0/1"
	return G.T("4D SPACE · w-crystals %d/4 · see into the sealed box from w: %s · tesseract-room cells %d/8",
		"4D ПРОСТРАНСТВО · w-кристали %d/4 · погледни в затворената кутия от w: %s · клетки на стаята-тесеракт %d/8") % [n_crystals(), bx, room_seen.size()]

func hints() -> String:
	if G.touch_active():
		return ""
	return G.T("WASD move · Space/Ctrl up/down · E/Q ana/kata (±w) · mouse look\n1/2 turn xw · 3/4 yw · 5/6 zw · 0 level · V Eye/Slice · G fog\nright-drag / wheel / O orbit the retina · Esc menu · Backspace exit",
		"WASD движение · Space/Ctrl горе/долу · E/Q ана/ката (±w) · мишка поглед\n1/2 завой xw · 3/4 yw · 5/6 zw · 0 изправи · V око/сечение · G мъгла\nдесен бутон / колелце / O орбита на ретината · Esc меню · Backspace изход")

# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	hud = CanvasLayer.new(); hud.layer = 9; hud.visible = false; add_child(hud)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.02, 0.04, 0.09, 0.72); sb.border_color = Color(1.0, 0.4, 0.85, 0.6)
	sb.set_border_width_all(1); sb.set_corner_radius_all(8); sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new(); panel.add_child(v)
	info = Label.new(); info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	v.add_child(info)
	gizmo = Control.new(); gizmo.custom_minimum_size = Vector2(196, 104); gizmo.draw.connect(_draw_gizmo)
	v.add_child(gizmo)
	hud.add_child(panel)

func place_hud(touch: bool, vp: Vector2) -> void:
	if panel == null: return
	panel.reset_size()
	if touch:
		panel.scale = Vector2.ONE * 0.8
		panel.position = Vector2(14, vp.y * 0.30) if vp.y > vp.x else Vector2(14, 120)
	else:
		panel.scale = Vector2.ONE
		panel.position = Vector2(vp.x - panel.size.x - 14, 14)

func _update_hud() -> void:
	var vtxt := G.T("4D Eye (3D retina)", "4D око (3D ретина)") if view == 0 else G.T("Slice (local a = 0)", "Сечение (локално a = 0)")
	info.text = "(x, y, z, w) = (%.1f, %.1f, %.1f, %.1f)\n%s%s" % [pos.x, pos.y, pos.z, pos.w, vtxt, ("" if fog else G.T(" · no fog", " · без мъгла"))]
	gizmo.queue_redraw()
	place_hud(G.touch_active(), get_viewport().get_visible_rect().size)
	if ui:
		ui.objective_text = objective()

## SO(4) orientation indicator: rows = your axes (R, U, F, A), columns = world x, y, z, w.
## Cell colour shows the component (warm = +, cool = −); identity = diagonal.
func _draw_gizmo() -> void:
	var f := ThemeDB.fallback_font
	var cols := ["x", "y", "z", "w"]
	var rows := [["R", R], ["U", U], ["F", F], ["A", A]]
	var cs := 18.0; var ox := 26.0; var oy := 16.0
	for j in 4:
		gizmo.draw_string(f, Vector2(ox + j * (cs + 3) + 5, 12), cols[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.85, 1.0, 0.9) if j < 3 else Color(1.0, 0.5, 0.9))
	for i in 4:
		var vec: Vector4 = rows[i][1]
		gizmo.draw_string(f, Vector2(4, oy + i * (cs + 3) + 14), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.95, 1.0))
		for j in 4:
			var v: float = vec[j]
			var c := Color(1.0, 0.55, 0.25) if v >= 0.0 else Color(0.3, 0.6, 1.0)
			var r := Rect2(ox + j * (cs + 3), oy + i * (cs + 3), cs, cs)
			gizmo.draw_rect(r, Color(0.1, 0.12, 0.2, 0.8))
			var k := absf(v)
			gizmo.draw_rect(Rect2(r.position + r.size * (1.0 - k) * 0.5, r.size * k), Color(c, 0.4 + 0.6 * k))
	# little dial: where world-w points in your (R, A) plane
	var dc := Vector2(158, 58); var rad := 30.0
	gizmo.draw_arc(dc, rad, 0, TAU, 40, Color(0.5, 0.7, 1.0, 0.5), 1.5, true)
	var wv := Vector2(R.w, -A.w) * rad
	gizmo.draw_line(dc, dc + Vector2(0, -rad), Color(1, 1, 1, 0.25), 1.0)
	gizmo.draw_line(dc, dc + wv, Color(1.0, 0.45, 0.9), 3.0, true)
	gizmo.draw_string(f, dc + Vector2(-26, rad + 14), G.T("w in view", "w в изгледа"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.6, 0.9, 0.9))
