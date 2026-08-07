# ============================================================
# CHICANE 3D — hud.gd  (NFS-HP style)
# Real rear-view mirror (second camera), analog dial speedo,
# route minimap, bounty feed, skill status stack, callouts.
# ============================================================
extends CanvasLayer

var race: RaceManager

const CYAN := Color(0.18, 0.89, 1.0)
const PINK := Color(1.0, 0.17, 0.84)
const GOOD := Color(0.24, 0.86, 0.28)
const BAD := Color(1.0, 0.33, 0.4)
const WARN := Color(1.0, 0.83, 0.0)
const GREY := Color(0.62, 0.68, 0.78)

var bounty_lbl: Label
var toasts_box: VBoxContainer
var route_lbl: Label
var mirror_vp: SubViewport
var mirror_cam: Camera3D
var pos_lbl: Label
var time_lbl: Label
var dist_lbl: Label
var heat_lbl: Label
var meters_box: VBoxContainer
var status_box: VBoxContainer
var callout_lbl: Label
var count_lbl: Label
var big_lbl: Label
var prompt_lbl: Label
var wrong_lbl: Label
var flash_rect: ColorRect
var bar_top: ColorRect
var bar_bot: ColorRect
var dmg_bar: ProgressBar
var wpn_lbl: Label
var nos_bar: ProgressBar
var dial: Control
var map_ctl: Control
var radar_ctl: Control
var _map_pts: PackedVector2Array = []

func bind(r: RaceManager) -> void:
	race = r
	_build()
	_build_map_points()

# ---------- construction ----------
func _mk_label(size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _mk_bar(col: Color, w := 160.0, h := 12.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.55); bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new(); fg.bg_color = col; fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

func _build() -> void:
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	bar_top = ColorRect.new(); bar_top.color = Color(0, 0, 0, 0.9)
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_top.custom_minimum_size.y = 64; bar_top.visible = false
	add_child(bar_top)
	bar_bot = ColorRect.new(); bar_bot.color = Color(0, 0, 0, 0.9)
	bar_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bot.offset_top = -64; bar_bot.visible = false
	add_child(bar_bot)

	# --- top-left: bounty + event feed ---
	var tl := VBoxContainer.new()
	tl.position = Vector2(18, 10)
	add_child(tl)
	var brow := HBoxContainer.new()
	bounty_lbl = _mk_label(30); bounty_lbl.text = "0"
	brow.add_child(bounty_lbl)
	var btag := _mk_label(13, GREY); btag.text = "  BOUNTY"
	brow.add_child(btag)
	tl.add_child(brow)
	toasts_box = VBoxContainer.new()
	toasts_box.add_theme_constant_override("separation", 1)
	tl.add_child(toasts_box)

	# --- top-center: REAL rear-view mirror ---
	var mid := VBoxContainer.new()
	mid.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mid.offset_left = -180; mid.offset_right = 180; mid.offset_top = 6
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(mid)
	route_lbl = _mk_label(11, GREY)
	route_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(route_lbl)
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.02, 0.02, 0.05)
	fsb.set_border_width_all(3); fsb.border_width_top = 6
	fsb.border_color = Color(0.75, 0.82, 0.92, 0.4)
	fsb.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", fsb)
	mid.add_child(frame)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(354, 74)
	frame.add_child(svc)
	mirror_vp = SubViewport.new()
	mirror_vp.size = Vector2i(354, 74)
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(mirror_vp)
	mirror_cam = Camera3D.new()
	mirror_cam.fov = 55.0
	mirror_vp.add_child(mirror_cam)

	# --- top-right: position / time / distance / heat ---
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -260; tr.offset_top = 10; tr.offset_right = -16
	add_child(tr)
	pos_lbl = _mk_label(30); pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(pos_lbl)
	time_lbl = _mk_label(21); time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(time_lbl)
	dist_lbl = _mk_label(15, GREY); dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(dist_lbl)
	heat_lbl = _mk_label(20, BAD); heat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(heat_lbl)
	meters_box = VBoxContainer.new()
	meters_box.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(meters_box)

	# --- center callout ---
	callout_lbl = _mk_label(30, Color.WHITE)
	callout_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	callout_lbl.offset_top = 250; callout_lbl.offset_left = -320; callout_lbl.offset_right = 320
	callout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(callout_lbl)

	# --- left: route minimap ---
	map_ctl = Control.new()
	map_ctl.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	map_ctl.custom_minimum_size = Vector2(150, 210)
	map_ctl.offset_left = 14; map_ctl.offset_top = -105
	map_ctl.draw.connect(_draw_map)
	add_child(map_ctl)
	# v9.5 — proximity radar: player-centred, rotates with the car
	radar_ctl = Control.new()
	radar_ctl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	radar_ctl.custom_minimum_size = Vector2(140, 140)
	radar_ctl.offset_left = 14; radar_ctl.offset_top = -246
	radar_ctl.draw.connect(_draw_radar)
	add_child(radar_ctl)

	# --- bottom-left: damage + weapons ---
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 18; bl.offset_top = -92; bl.offset_bottom = -14
	add_child(bl)
	var drow := HBoxContainer.new(); bl.add_child(drow)
	var dtag := _mk_label(12, GREY); dtag.text = "HEALTH "; dtag.custom_minimum_size.x = 60
	drow.add_child(dtag)
	dmg_bar = _mk_bar(GOOD, 220.0, 16.0); drow.add_child(dmg_bar)
	wpn_lbl = _mk_label(14, Color(0.6, 0.78, 0.9))
	bl.add_child(wpn_lbl)

	# --- bottom-right: status stack + dial + NOS bottle ---
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.offset_left = -420; br.offset_top = -260; br.offset_right = -14; br.offset_bottom = -12
	br.alignment = BoxContainer.ALIGNMENT_END
	add_child(br)
	status_box = VBoxContainer.new()
	status_box.alignment = BoxContainer.ALIGNMENT_END
	status_box.add_theme_constant_override("separation", 0)
	br.add_child(status_box)
	var cluster := HBoxContainer.new()
	cluster.alignment = BoxContainer.ALIGNMENT_END
	cluster.add_theme_constant_override("separation", 8)
	br.add_child(cluster)
	dial = Control.new()
	dial.custom_minimum_size = Vector2(176, 176)
	dial.draw.connect(_draw_dial)
	cluster.add_child(dial)
	nos_bar = _mk_bar(CYAN, 22, 120)
	nos_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	nos_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	cluster.add_child(nos_bar)

	count_lbl = _mk_label(150, WARN)
	count_lbl.set_anchors_preset(Control.PRESET_CENTER)
	count_lbl.offset_left = -200; count_lbl.offset_right = 200; count_lbl.offset_top = -160
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(count_lbl)
	wrong_lbl = _mk_label(44, BAD)
	wrong_lbl.text = "WRONG WAY"
	wrong_lbl.set_anchors_preset(Control.PRESET_CENTER)
	wrong_lbl.offset_left = -220; wrong_lbl.offset_right = 220; wrong_lbl.offset_top = -60
	wrong_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_lbl.visible = false
	add_child(wrong_lbl)
	big_lbl = _mk_label(52, PINK)
	big_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	big_lbl.offset_left = -320; big_lbl.offset_right = 320; big_lbl.offset_top = 140
	big_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_lbl.visible = false
	add_child(big_lbl)
	prompt_lbl = _mk_label(20, CYAN)
	prompt_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_lbl.offset_left = -380; prompt_lbl.offset_right = 380; prompt_lbl.offset_top = -170
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.visible = false
	add_child(prompt_lbl)

var _map_stride := 6

func _build_map_points() -> void:
	_map_pts.clear()
	if race.samples.is_empty(): return
	# adaptive stride keeps big worlds around ~300 points instead of 3500
	_map_stride = maxi(6, int(ceil(race.samples.size() / 300.0)))
	var minv := Vector2(1e18, 1e18)
	var maxv := Vector2(-1e18, -1e18)
	var raw: Array[Vector2] = []
	for i in range(0, race.samples.size(), _map_stride):
		var p: Vector3 = race.samples[i].pos
		var v := Vector2(p.x, p.z)
		raw.append(v)
		minv = minv.min(v); maxv = maxv.max(v)
	# two neighbour-average passes smooth the wiggle without changing the
	# point count, so progress -> point mapping stays exact
	for pass_i in 2:
		var sm: Array[Vector2] = raw.duplicate()
		for i in raw.size():
			if race.is_loop:
				sm[i] = (raw[(i - 1 + raw.size()) % raw.size()] + raw[i] * 2.0 + raw[(i + 1) % raw.size()]) * 0.25
			elif i > 0 and i < raw.size() - 1:
				sm[i] = (raw[i - 1] + raw[i] * 2.0 + raw[i + 1]) * 0.25
		raw = sm
	var span := (maxv - minv).max(Vector2.ONE * 0.001)
	var box := Vector2(150, 210) - Vector2(24, 24)
	var sc := minf(box.x / span.x, box.y / span.y)
	var off := (Vector2(150, 210) - span * sc) * 0.5
	for v in raw:
		_map_pts.append((v - minv) * sc + off)

# ---------- per-frame ----------
func _process(_delta: float) -> void:
	if race == null or race.player == null: return
	var P := race.player
	bounty_lbl.text = _fmt(int(race.bounty))
	route_lbl.text = str(D.ZONES[race.zone_key].name).to_upper()
	# mirror camera: sits above the car, looking straight back
	if is_instance_valid(mirror_cam):
		var basis := P.global_transform.basis
		var pos := P.global_position + basis.y * 1.5 - basis.z * -0.2
		mirror_cam.global_transform = Transform3D(
			Basis.looking_at(basis.z, Vector3.UP) if basis.z.length() > 0.1 else Basis(),
			pos)
	# position / time / distance
	var pos_modes := ["sprint", "circuit", "hotpursuit", "boss", "elim", "drag"]
	if mode_in(pos_modes):
		var p := race._position_of_player()
		var medal := "🥇" if p == 1 else "🥈" if p == 2 else "🥉" if p == 3 else "●"
		pos_lbl.text = medal + " " + RaceManager.ordinal(p)
	else:
		pos_lbl.text = ""
	time_lbl.text = "%d:%05.2f" % [int(race.t) / 60, fmod(race.t, 60.0)]
	var dist := ""
	match race.mode:
		"drift": dist = "%s / %s" % [_fmt(race.drift_score), _fmt(int(race.ev.get("target", 0)))]
		"topspeed": dist = "%d / %d km/h" % [int(race.best_speed), int(race.ev.get("target", 0))]
		"intercept":
			var hp_t := 0.0
			if race.target and is_instance_valid(race.target): hp_t = maxf(race.target.hp, 0.0)
			dist = "%ds · SUSPECT %d%%" % [int(maxf(race.time_left, 0.0)), int(hp_t)]
		"free": dist = "FREE DRIVE"
		"roam":
			dist = "%s · %d%% DISCOVERED" % [str(D.ZONES[race.zone_key].name).to_upper(),
				race.roam.disc_pct] if race.roam else "VELOCITY COUNTY"
		"escape": dist = "LOSE THE VCPD"
		"circuit":
			dist = "LAP %d/%d" % [mini(race.lap, race.laps), race.laps]
			if race.best_lap > 0.0:
				dist += "   BEST %.2fs" % race.best_lap
		_: dist = "%.1f km" % maxf((race.finish_d - P.progress) / 1000.0, 0.0)
	dist_lbl.text = dist
	heat_lbl.text = ("★".repeat(mini(race.heat, 10)) + "  HEAT %d" % race.heat) if race.wanted and race.heat > 0 else ""
	# stacked meters
	for c in meters_box.get_children(): c.queue_free()
	if race.laps > 1: _meter_line("LAP %d/%d" % [race.lap, race.laps], WARN)
	if race.mode == "elim": _meter_line("CULL %ds" % int(ceil(race.elim_t)), WARN)
	if (race.mode == "escape" or race.mode == "free") and race.wanted and race.escape > 0.02:
		var eb := _mk_bar(GOOD); eb.value = race.escape * 100.0; meters_box.add_child(eb)
	if race.busted > 0.03:
		var bb := _mk_bar(BAD); bb.value = race.busted * 100.0; meters_box.add_child(bb)
	# callout
	callout_lbl.text = race.pos_announce
	callout_lbl.modulate.a = clampf(race.pos_announce_t / 0.5, 0.0, 1.0)
	# bottom — health bar drains green → amber → red
	dmg_bar.value = P.hp
	var hb := dmg_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if hb:
		hb.bg_color = GOOD if P.hp > 55.0 else WARN if P.hp > 25.0 else BAD
	var pad: bool = S.last_device_pad
	var k_emp := "E"
	var k_turbo := "B" if pad else "T"
	var k_spike := "LB" if pad else "K"
	var k_block := "RB" if pad else "R"
	var slot_keys := ["LS", "Y", "RB"] if pad else ["F", "G", "H"]
	var w := []
	if race.weapons:
		for i in race.weapons.slots.size():
			var wid: String = race.weapons.slots[i]
			var wname: String = D.WEAPONS[wid].name.to_upper()
			var status: String = "∞" if race.weapons.cds[i] <= 0.0 else "…"
			if race.weapons.active.has(wid): status = "ACTIVE"
			w.append("[%s] %s %s" % [slot_keys[i], wname, status])
	var k_warp := "D◀" if pad else "Z"
	var warp_status: String = ("%.0fs" % ceilf(P.warp_t)) if P.warp_t > 0.0 else ("RDY" if race.cd_warp <= 0.0 else "…")
	w.append("[%s] WARP %s" % [k_warp, warp_status])
	w.append("[%s] EMP %s" % [k_emp, str(race.w_emp) if race.w_emp < 99 else ("RDY" if race.cd_emp <= 0 else "…")])
	w.append("[%s] TURBO %s" % [k_turbo, str(race.w_turbo) if race.w_turbo < 99 else ("RDY" if race.cd_turbo <= 0 else "…")])
	if bool(S.g("god_mode")):
		w.append("⚡GOD MODE")
	if race.career == "cop":
		w.append("[%s] SPIKE %d" % [k_spike, race.w_spike])
		w.append("[%s] BLOCK %d" % [k_block, race.w_block])
	w.append("[Q] INVENTORY")
	wpn_lbl.text = "   ".join(w)
	wrong_lbl.visible = race.wrong_way and int(race.t * 4.0) % 2 == 0
	# status stack
	for c in status_box.get_children(): c.queue_free()
	if race.slip_active: _status_line("SLIPSTREAMING %.2fs" % race.slip_t, Color(0.5, 0.85, 1.0))
	if race.oncoming_active: _status_line("ONCOMING %dm" % int(race.oncoming_m), WARN)
	if P.drifting: _status_line("DRIFTING %dm" % int(race.drift_m), PINK)
	if race.risk > 25.0: _status_line("RISK %d" % int(race.risk), Color(1.0, 0.55, 0.25))
	nos_bar.value = P.nitro * 100.0
	dial.queue_redraw()
	map_ctl.queue_redraw()
	radar_ctl.visible = bool(S.g("radar"))
	if radar_ctl.visible: radar_ctl.queue_redraw()
	if inv_panel and inv_panel.visible:
		_update_inventory()
	if flash_rect.color.a > 0.0:
		flash_rect.color.a = maxf(flash_rect.color.a - _delta * 3.0, 0.0)

func mode_in(list: Array) -> bool:
	return race.mode in list

func _meter_line(txt: String, col: Color) -> void:
	var l := _mk_label(15, col)
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meters_box.add_child(l)

func _status_line(txt: String, col: Color) -> void:
	var l := _mk_label(14, col)
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_child(l)

# ---------- custom draws ----------
func _draw_dial() -> void:
	if race == null or race.player == null: return
	var P := race.player
	var c := Vector2(88, 90)
	var rad := 80.0
	dial.draw_circle(c, rad, Color(0.02, 0.03, 0.07, 0.8))
	dial.draw_arc(c, rad, 0, TAU, 48, Color(1, 1, 1, 0.2), 2.0, true)
	var a0 := PI * 0.75
	var a1 := PI * 2.25
	dial.draw_arc(c, rad - 7, a0 + (a1 - a0) * 0.8, a1, 24, Color(1, 0.2, 0.25, 0.9), 5.0, true)
	for i in 13:
		var a := a0 + (a1 - a0) * i / 12.0
		var v := Vector2(cos(a), sin(a))
		var col := Color(1, 0.35, 0.4) if i >= 10 else Color(1, 1, 1, 0.75)
		dial.draw_line(c + v * (rad - 4), c + v * (rad - (16 if i % 3 == 0 else 10)), col, 2.5 if i % 3 == 0 else 1.2, true)
	var frac := clampf(P.kmh() / 480.0, 0.0, 1.0)
	var na := a0 + (a1 - a0) * frac
	var nv := Vector2(cos(na), sin(na))
	dial.draw_line(c - nv * 12, c + nv * (rad - 18), CYAN if P.nitro_on else Color(1, 0.2, 0.27), 3.5, true)
	dial.draw_circle(c, 5, Color.WHITE)
	var font := ThemeDB.fallback_font
	dial.draw_string(font, c + Vector2(-60, 46), str(int(P.kmh())), HORIZONTAL_ALIGNMENT_CENTER, 120, 30, CYAN if P.nitro_on else Color.WHITE)
	dial.draw_string(font, c + Vector2(-60, 62), "KM/H", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(1, 1, 1, 0.45))
	# tachometer arc driven by the real transmission
	if "trans" in P and P.trans:
		var rpm: float = clampf(P.trans.rpm, 0.0, 1.1)
		var ta0 := PI * 0.75
		var ta1 := ta0 + (PI * 1.5) * rpm
		var tach_col := Color(1.0, 0.25, 0.3) if rpm > 0.9 else CYAN
		dial.draw_arc(c, rad - 22, ta0, ta1, 30, tach_col, 4.0, true)
		var gear_s: String = P.trans.gear_label()
		var gcol := WARN if P.trans.shifting <= 0.0 else Color.WHITE
		dial.draw_string(font, c + Vector2(-60, -28), gear_s, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, gcol)
	else:
		dial.draw_string(font, c + Vector2(-60, -28), "N", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, WARN)

var _map_bg: StyleBoxFlat = null

func _draw_map() -> void:
	if _map_pts.size() < 2 or race == null: return
	if _map_bg == null:
		_map_bg = StyleBoxFlat.new()
		_map_bg.bg_color = Color(0.02, 0.02, 0.06, 0.42)
		_map_bg.set_corner_radius_all(12)
		_map_bg.border_color = Color(1, 1, 1, 0.10)
		_map_bg.set_border_width_all(1)
	map_ctl.draw_style_box(_map_bg, Rect2(Vector2.ZERO, Vector2(150, 210)))
	if race.mode == "roam":
		_draw_map_local()
		return
	var pts := _map_pts
	if race.is_loop:
		pts = _map_pts.duplicate()
		pts.append(_map_pts[0])          # visually close the ring
	map_ctl.draw_polyline(pts, Color(0, 0, 0, 0.65), 5.0, true)
	map_ctl.draw_polyline(pts, Color(0.92, 0.96, 1.0, 0.85), 2.0, true)
	var dot := func(prog: float, col: Color, r: float):
		var idx := clampi(int(prog / TrackGen.SAMPLE / float(_map_stride)), 0, _map_pts.size() - 1)
		map_ctl.draw_circle(_map_pts[idx], r, col)
	for rv in race.rivals:
		if is_instance_valid(rv) and not rv.dead: dot.call(rv.progress, Color(1.0, 0.45, 0.1), 3.0)
	for cp in race.cops:
		if is_instance_valid(cp) and not cp.dead:
			dot.call(cp.progress, Color(1, 0.15, 0.15) if int(race.t * 8.0) % 2 == 0 else Color(0.2, 0.35, 1), 3.0)
	dot.call(race.player.progress, GOOD, 4.5)

# v9.5 — proximity radar: player-centred blips for everything on the road.
# Rivals orange, cops blue, suspect red, traffic grey. Racers beyond range
# are pinned to the rim so you always know which way they are.
func _draw_radar() -> void:
	if race == null or race.player == null: return
	var c := Vector2(70, 70)
	var rad := 66.0
	var range_m := 90.0
	radar_ctl.draw_circle(c, rad, Color(0.02, 0.03, 0.07, 0.55))
	radar_ctl.draw_arc(c, rad, 0, TAU, 40, Color(0.5, 0.9, 0.5, 0.35), 1.5, true)
	radar_ctl.draw_arc(c, rad * 0.5, 0, TAU, 32, Color(0.5, 0.9, 0.5, 0.18), 1.0, true)
	# player: small triangle pointing up (radar rotates with the car)
	radar_ctl.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4.5, 5), c + Vector2(-4.5, 5)]), GOOD)
	var inv := race.player.global_transform.affine_inverse()
	for v in race.all_vehicles():
		if not is_instance_valid(v) or v == race.player: continue
		var l: Vector3 = inv * v.global_position
		var p := c + Vector2(l.x, l.z) * (rad / range_m)   # -z forward -> up
		var racer: bool = v is AICar
		if not racer and p.distance_to(c) > rad - 3.0:
			continue                        # traffic drops off the edge
		var col := Color(0.62, 0.64, 0.68)  # traffic grey
		if racer:
			col = Color(0.35, 0.55, 1.0) if v.role == AICar.Role.COP \
				else Color(1.0, 0.25, 0.2) if v.role == AICar.Role.TARGET \
				else Color(1.0, 0.55, 0.1)
			if v.wrecked: col = col.darkened(0.55)
		var out := p - c
		if out.length() > rad - 3.0:
			p = c + out.normalized() * (rad - 3.0)
			col.a = 0.55
		radar_ctl.draw_circle(p, 4.0 if racer else 2.8, col)

# Roam: zoomed local map — a readable window of road around the player
# with event markers (cyan), barn finds (gold) and speed cameras (yellow).
func _draw_map_local() -> void:
	var win := 1500.0                     # metres of road either side
	var pd: float = race.player.progress
	var n := race.samples.size()
	var step := maxi(1, int(win * 2.0 / TrackGen.SAMPLE / 120.0))
	var pts := PackedVector2Array()
	var minv := Vector2(1e18, 1e18)
	var maxv := Vector2(-1e18, -1e18)
	var i0 := int((pd - win) / TrackGen.SAMPLE)
	var i1 := int((pd + win) / TrackGen.SAMPLE)
	for i in range(i0, i1 + 1, step):
		var s: Dictionary = race.samples[((i % n) + n) % n]
		var v := Vector2(s.pos.x, s.pos.z)
		pts.append(v)
		minv = minv.min(v); maxv = maxv.max(v)
	if pts.size() < 2: return
	var span := (maxv - minv).max(Vector2.ONE * 0.001)
	var box := Vector2(150, 210) - Vector2(28, 28)
	var sc := minf(box.x / span.x, box.y / span.y)
	var off := (Vector2(150, 210) - span * sc) * 0.5
	var xf := func(w: Vector2) -> Vector2: return (w - minv) * sc + off
	var draw_pts := PackedVector2Array()
	for v in pts: draw_pts.append(xf.call(v))
	map_ctl.draw_polyline(draw_pts, Color(0, 0, 0, 0.65), 6.0, true)
	map_ctl.draw_polyline(draw_pts, Color(0.92, 0.96, 1.0, 0.9), 2.6, true)
	var on_map := func(d: float) -> bool:
		var gap: float = fposmod(d - pd + race.length * 0.5, race.length) - race.length * 0.5
		return absf(gap) < win
	var world_dot := func(d: float, col: Color, r: float):
		var s: Dictionary = race.samples[race.sample_index(d)]
		map_ctl.draw_circle(xf.call(Vector2(s.pos.x, s.pos.z)), r, col)
	if race.roam != null:
		for m in race.roam.markers:
			if on_map.call(m.d): world_dot.call(m.d, CYAN, 3.5)
		for b in race.roam.barns:
			if is_instance_valid(b.node) and on_map.call(b.d): world_dot.call(b.d, Color(1.0, 0.83, 0.0), 3.5)
		for c in race.roam.cameras:
			if on_map.call(c.d): world_dot.call(c.d, Color(1.0, 0.7, 0.2), 2.4)
	for cp in race.cops:
		if is_instance_valid(cp) and not cp.dead and on_map.call(cp.progress):
			world_dot.call(cp.progress, Color(1, 0.15, 0.15) if int(race.t * 8.0) % 2 == 0 else Color(0.2, 0.35, 1), 3.0)
	for rv in race.rivals:
		if is_instance_valid(rv) and not rv.dead and on_map.call(rv.progress):
			world_dot.call(rv.progress, Color(1.0, 0.45, 0.1), 3.0)
	# player: position + heading arrow
	var ppos: Vector2 = xf.call(Vector2(race.player.global_position.x, race.player.global_position.z))
	var fwd3 := -race.player.global_transform.basis.z
	var fwd2 := Vector2(fwd3.x, fwd3.z).normalized() * 7.0
	var side := Vector2(-fwd2.y, fwd2.x) * 0.55
	map_ctl.draw_colored_polygon(PackedVector2Array([ppos + fwd2, ppos - fwd2 * 0.5 + side, ppos - fwd2 * 0.5 - side]), GOOD)

# ---------- API used by race.gd ----------
func countdown(cd: float) -> void:
	var n := int(ceil(cd - 0.4))
	if cd <= 0.4:
		count_lbl.text = "GO!"
		count_lbl.add_theme_color_override("font_color", GOOD)
		get_tree().create_timer(0.8).timeout.connect(func(): count_lbl.text = "")
	elif n > 0:
		count_lbl.text = str(n)

# ---------- v9.6: weapon inventory overlay ([Q]) ----------
var inv_panel: PanelContainer = null
var inv_lbl: Label = null

func toggle_inventory() -> void:
	if inv_panel == null:
		_build_inventory()
	inv_panel.visible = not inv_panel.visible

func _build_inventory() -> void:
	inv_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.09, 0.92)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	sb.border_color = CYAN
	sb.set_border_width_all(1)
	inv_panel.add_theme_stylebox_override("panel", sb)
	inv_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	inv_panel.offset_left = -470
	inv_panel.offset_right = -20
	inv_panel.offset_top = -180
	var v := VBoxContainer.new()
	inv_panel.add_child(v)
	var title := _mk_label(22, CYAN)
	title.text = "WEAPON INVENTORY          [Q] close"
	v.add_child(title)
	inv_lbl = _mk_label(15)
	v.add_child(inv_lbl)
	var foot := _mk_label(12, GREY)
	foot.text = "Change your 3-weapon loadout in Main Menu → WEAPONS"
	v.add_child(foot)
	inv_panel.visible = false
	add_child(inv_panel)

func _update_inventory() -> void:
	var pad: bool = S.last_device_pad
	var keys := ["LS", "Y", "RB"] if pad else ["F", "G", "H"]
	var lines := []
	if race.weapons:
		for i in race.weapons.slots.size():
			var wid: String = race.weapons.slots[i]
			var wd: Dictionary = D.WEAPONS[wid]
			var status := "READY"
			if race.weapons.active.has(wid):
				status = "ACTIVE %ds" % int(ceil(race.weapons.active[wid]))
			elif race.weapons.cds[i] > 0.0:
				status = "%.1fs" % race.weapons.cds[i]
			lines.append("[%s] %s — %s\n      %s" % [keys[i], wd.name.to_upper(), status, wd.desc])
	lines.append("")
	var p := race.player
	var warp_s := ("ACTIVE %ds" % int(ceil(p.warp_t))) if p.warp_t > 0.0 \
		else ("READY" if race.cd_warp <= 0.0 else "%.0fs" % race.cd_warp)
	lines.append("[Z] WARP SPEED — %s   ·   10s at 3× velocity" % warp_s)
	lines.append("[E] EMP — %s   ·   [T] TURBO — %s" %
		["∞" if race.w_emp >= 99 else str(race.w_emp), "∞" if race.w_turbo >= 99 else str(race.w_turbo)])
	if race.career == "cop":
		lines.append("[K] SPIKES — %d   ·   [R] ROADBLOCK — %d" % [race.w_spike, race.w_block])
	inv_lbl.text = "\n".join(lines)

func toast(txt: String, cls := "") -> void:
	var l := _mk_label(15, GOOD if cls == "good" else BAD if cls == "bad" else WARN if cls == "warn" else Color.WHITE)
	l.text = txt
	toasts_box.add_child(l)
	if toasts_box.get_child_count() > 5:
		toasts_box.get_child(0).queue_free()
	get_tree().create_timer(2.6).timeout.connect(func(): if is_instance_valid(l): l.queue_free())

func big_message(txt: String) -> void:
	big_lbl.text = txt
	big_lbl.visible = true
	get_tree().create_timer(2.4, true, false, true).timeout.connect(func(): big_lbl.visible = false)

# v9.7 — "RESPAWN IN n" countdown after a RIP (count_lbl is sized for huge
# single digits, so shrink the font while it holds the longer message)
func respawn_count(t: float) -> void:
	if t <= 0.0:
		count_lbl.text = ""
		count_lbl.add_theme_color_override("font_color", WARN)
		count_lbl.add_theme_font_size_override("font_size", 150)
		return
	count_lbl.add_theme_color_override("font_color", BAD)
	count_lbl.add_theme_font_size_override("font_size", 46)
	count_lbl.text = "RESPAWN IN %d" % int(ceil(t))

func prompt(txt: String) -> void:
	# persistent on-road interaction prompt ("" hides it)
	prompt_lbl.text = txt
	prompt_lbl.visible = txt != ""

func flash(big: bool) -> void:
	flash_rect.color = Color(1, 0.3, 0.3, 0.35) if big else Color(1, 1, 1, 0.22)

func letterbox(on: bool) -> void:
	bar_top.visible = on
	bar_bot.visible = on

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0: out = "," + out
	return out
