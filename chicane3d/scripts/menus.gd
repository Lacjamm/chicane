# ============================================================
# CHICANE 3D — menus.gd
# All front-end UI: main menu, careers, garage (with live 3D
# preview), secrets, settings, results.
# ============================================================
class_name Menus
extends CanvasLayer

signal launch_race(ev: Dictionary, career: String)

const BG := Color(0.04, 0.03, 0.09)
const PANEL := Color(0.08, 0.07, 0.16, 0.96)
const CYAN := Color(0.18, 0.89, 1.0)
const PINK := Color(1.0, 0.17, 0.84)
const GOOD := Color(0.24, 0.86, 0.28)
const BAD := Color(1.0, 0.33, 0.4)
const WARN := Color(1.0, 0.83, 0.0)
const GREY := Color(0.6, 0.64, 0.75)

var root: Control
var preview_vp: SubViewport
var preview_car: Node3D
var garage_sel := ""

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	show_title()

func _clear() -> void:
	for c in root.get_children():
		c.queue_free()
	preview_car = null
	preview_vp = null

# controller/keyboard menu navigation: focus the first button on each screen
func _focus_first() -> void:
	await get_tree().process_frame
	var btn := _find_button(root)
	if btn: btn.grab_focus()

func _find_button(node: Node) -> Button:
	for c in node.get_children():
		if c is Button and not c.disabled:
			return c
		var found := _find_button(c)
		if found: return found
	return null

func _bg() -> void:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(r)

func _lbl(txt: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(txt: String, cb: Callable, accent := false, disabled := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.disabled = disabled
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PINK.darkened(0.35) if accent else Color(0.13, 0.12, 0.24)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate(); sbh.bg_color = sb.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("hover", sbh)
	if not disabled: b.pressed.connect(cb)
	if disabled: b.modulate.a = 0.45
	return b

func _panel(w: int = 900) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(w, 0)
	center.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return v

func _scroll_panel(w: int = 960, h: int = 620) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL; sb.set_corner_radius_all(14); sb.set_content_margin_all(18)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(w, h)
	center.add_child(pc)
	var outer := VBoxContainer.new()
	pc.add_child(outer)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v

# ================= TITLE =================
func show_title() -> void:
	_clear(); _bg()
	var v := _panel(760)
	var t1 := _lbl("CHICANE", 84, PINK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var t2 := _lbl("FULL THROTTLE 3D", 30, CYAN)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	var tag := _lbl("Velora Coast is waiting. Every race can become a chase.  ·  %s" % D.VERSION, 16, GREY)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	v.add_child(HSeparator.new())
	v.add_child(_btn("START ENGINE", func():
		if P.data.flags.has("diff_chosen"): show_menu()
		else: show_difficulty(), true))
	var hint := _lbl("WASD/arrows drive · SPACE handbrake · SHIFT nitrous · F/G/H weapons · Q inventory · Z warp · E EMP · T turbo\nC camera · X reset car · M radio · ESC pause", 13, GREY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

# ================= MAIN MENU =================
	_focus_first()

func show_menu() -> void:
	_clear(); _bg()
	var v := _panel(880)
	var head := HBoxContainer.new()
	head.add_child(_lbl("CHICANE ", 30, PINK))
	head.add_child(_lbl("FULL THROTTLE 3D", 30, CYAN))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_lbl("$%d" % int(P.data.cash), 26, GOOD))
	v.add_child(head)
	var ranks := _lbl("Racer: %s   ·   VCPD: %s   ·   Best: %d km/h   ·   Completion: %d%%   ·   %s [PR %d]" %
		[D.RACER_RANKS[P.racer_rank() - 1], D.COP_RANKS[P.cop_rank() - 1], int(P.data.stats.best_speed),
		P.completion_pct(), D.car_def(P.data.cur).name, P.car_pr(P.data.cur)], 15, GREY)
	v.add_child(ranks)
	v.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var wins: int = P.data.wins.size()
	grid.add_child(_btn("RACER CAREER  (%d/%d won)" % [wins, D.RACER_EVENTS.size()], show_racer.bind(), true))
	grid.add_child(_btn("COP CAREER  (%d/%d arrests)" % [P.data.cop_wins.size(), D.COP_EVENTS.size()], show_cop.bind()))
	grid.add_child(_btn("FREE DRIVE", show_free.bind()))
	grid.add_child(_btn("GARAGE  (%d cars)" % P.data.cars.size(), show_garage.bind()))
	grid.add_child(_btn("WEAPONS  (%s)" % " / ".join(P.loadout().map(func(wid): return D.WEAPONS[wid].name)), show_weapons.bind()))
	grid.add_child(_btn("LEVEL: %s" % D.DIFFICULTY[P.data.diff].label, show_difficulty.bind()))
	grid.add_child(_btn("SECRET CARS  (%d/%d)" % [P.data.secrets.size(), D.SECRET_CARS.size()], show_secrets.bind()))
	grid.add_child(_btn("SETTINGS", show_settings.bind()))

# ================= RACER CAREER =================
	_focus_first()

func show_racer() -> void:
	_clear(); _bg()
	var v := _scroll_panel()
	var head := HBoxContainer.new()
	head.add_child(_btn("< Back", show_menu.bind()))
	head.add_child(_lbl("  RACER CAREER", 28, PINK))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var rank := P.racer_rank()
	head.add_child(_lbl("%s  (%d REP)" % [D.RACER_RANKS[rank - 1], int(P.data.rep)], 17, WARN))
	v.add_child(head)
	v.add_child(_lbl("Driving: %s" % D.car_def(P.data.cur).name, 15, GREY))
	for tier in range(1, 8):
		var evs := D.RACER_EVENTS.filter(func(e): return e.tier == tier)
		if evs.is_empty(): continue
		var open := P.tier_unlocked(tier)
		var rec_pr := 260 + tier * 45
		var tier_hdr := _lbl(("— THE BLACK TRACK —" if tier == 7 else "— TIER %d —" % tier) +
			"  rec. PR %d" % rec_pr +
			("" if open else "  (locked: win more Tier %d events)" % (tier - 1)), 18, WARN if open else GREY)
		v.add_child(tier_hdr)
		for e in evs:
			var won: bool = P.data.wins.has(e.id)
			var txt := "%s%s  ·  %s  ·  %s  ·  $%d + %d REP%s" % [
				"[BOSS] " if e.mode == "boss" else "", e.name, e.mode.to_upper(),
				D.ZONES[e.zone].name, e.cash, e.rep, "   ✔ WON" if won else ""]
			var b := _btn(txt, show_prerace.bind(e), e.mode == "boss", not open)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if won: b.modulate = Color(0.75, 1.0, 0.78)
			v.add_child(b)
	_focus_first()

func show_prerace(e: Dictionary) -> void:
	_clear(); _bg()
	var v := _panel(720)
	if e.mode == "boss":
		var b: Dictionary = D.BOSSES[e.boss]
		var name_l := _lbl(b.name, 56, Color.from_string("#" + b.color, Color.WHITE))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_l)
		var tl := _lbl(b.title + "  ·  " + b.car_name, 17, GREY)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
		var taunt := _lbl("\"%s\"" % b.taunt, 16, Color.WHITE)
		taunt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		taunt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(taunt)
	else:
		var t := _lbl(e.name, 34, CYAN)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	var desc := _lbl(e.desc, 16, GREY)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var goal := {
		"sprint": "Finish 1st against %d rivals." % int(e.get("rivals", 0)),
		"circuit": "%d laps — finish 1st." % int(e.get("laps", 1)),
		"drag": "Beat your rival to the line. Manage nitrous heat perfectly.",
		"drift": "Score %d drift points before the route ends. SPACE + steer to slide." % int(e.get("target", 0)),
		"topspeed": "Hit %d km/h before the route ends. Nitrous is your friend." % int(e.get("target", 0)),
		"elim": "Last place is eliminated every 20 seconds. Survive.",
		"escape": "Fill the ESCAPE bar by losing the police. Don't get busted or wrecked.",
		"hotpursuit": "Finish 1st while the VCPD attacks everyone.",
		"boss": "One-on-one. Beat them to the line.",
		"timeattack": "Race the clock — checkpoints add time. Reach the finish before it runs out.",
		"speedtrap": "Five cameras score your speed. Combined total must beat %d km/h." % int(e.get("target", 0)),
		"duel": "A private one-on-one. Winner takes the bounty.",
	}.get(e.mode, "")
	var goal_l := _lbl("GOAL — " + goal, 16, WARN)
	goal_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(goal_l)
	var meta := _lbl("%s · %s%s" % [D.ZONES[e.zone].name, D.ZONES[e.zone].tag,
		("  ·  HEAT %d: %s" % [e.heat, D.HEAT_INFO[e.heat]]) if e.get("heat", 0) > 0 else ""], 14, GREY)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(meta)
	v.add_child(HSeparator.new())
	v.add_child(_btn("RACE", func(): launch_race.emit(e, "racer"), true))
	v.add_child(_btn("Back", show_racer.bind()))

# ================= COP CAREER =================
	_focus_first()

func show_cop() -> void:
	_clear(); _bg()
	var v := _scroll_panel()
	var head := HBoxContainer.new()
	head.add_child(_btn("< Back", show_menu.bind()))
	head.add_child(_lbl("  VCPD — COP CAREER", 28, Color(0.5, 0.7, 1.0)))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var rank := P.cop_rank()
	head.add_child(_lbl("%s  (%d MERIT)" % [D.COP_RANKS[rank - 1], int(P.data.cop_rep)], 16, WARN))
	v.add_child(head)
	var carrow := HBoxContainer.new()
	carrow.add_child(_lbl("Pursuit vehicle:  ", 15, GREY))
	for c in D.COP_CARS:
		var locked: bool = c.rank > rank
		var b := _btn("%s%s" % [c.name, "  [R%d]" % c.rank if locked else ""],
			func():
				P.data.cop_cur = c.id
				P.save_game()
				show_cop(), P.data.cop_cur == c.id, locked)
		carrow.add_child(b)
	v.add_child(carrow)
	v.add_child(_lbl("Weapons: [F]/[G]/[H] your loadout · [Q] inventory · [E] EMP · [K] spike strip · [R] roadblock · [T] turbo · SHIFT nitrous. Ram the suspect to 0%%.", 14, GREY))
	for i in D.COP_EVENTS.size():
		var m: Dictionary = D.COP_EVENTS[i]
		var open := P.cop_mission_unlocked(i)
		var won: bool = P.data.cop_wins.has(m.id)
		var b := _btn("%s  ·  %s  ·  Suspect: %s  ·  $%d%s" % [m.name, D.ZONES[m.zone].name,
			D.car_def(m.target).name, m.cash, "   ✔ ARRESTED" if won else ("" if open else "   [LOCKED]")],
			show_precop.bind(m), false, not open)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if won: b.modulate = Color(0.75, 0.85, 1.0)
		v.add_child(b)
	_focus_first()

func show_precop(m: Dictionary) -> void:
	_clear(); _bg()
	var v := _panel(720)
	var t := _lbl(m.name, 32, Color(0.5, 0.7, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := _lbl(m.desc, 16, GREY)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var g := _lbl("MISSION — Disable the suspect's %s (0%% condition) within %ds. Ram, EMP [E], spike [Q], roadblock [R]." %
		[D.car_def(m.target).name, int(m.time * 1.4)], 15, WARN)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(g)
	v.add_child(HSeparator.new())
	v.add_child(_btn("BEGIN PURSUIT", func(): launch_race.emit(m, "cop"), true))
	v.add_child(_btn("Back", show_cop.bind()))

# ================= FREE DRIVE =================
	_focus_first()

func show_free() -> void:
	_clear(); _bg()
	var v := _panel(700)
	var head := HBoxContainer.new()
	head.add_child(_btn("< Back", show_menu.bind()))
	head.add_child(_lbl("  FREE DRIVE", 28, CYAN))
	v.add_child(head)
	v.add_child(_lbl("Cruise any district. 200+ km/h past a speed camera raises Heat — escape to bank the bounty.", 14, GREY))
	# --- v4: the connected open world ---
	var world_ev := {"id":"roam", "zone":"coastal", "mode":"roam", "name":"Velocity County",
		"len":21.0, "heat":0, "cash":0, "rep":0, "tier":3}
	v.add_child(_btn("★ VELOCITY COUNTY — Open World  ·  every district, one connected road",
		func(): launch_race.emit(world_ev, "racer"), true))
	var disc_l := _lbl("Discover roads, claim barn-find wrecks, beat speed cameras, and start events right from the road (press EMP key at a marker).", 13, GREY)
	disc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(disc_l)
	v.add_child(HSeparator.new())
	for zk in D.ZONES:
		if zk == "blacktrack" and not P.data.wins.has("r29"): continue
		var z: Dictionary = D.ZONES[zk]
		var e := {"id":"fd_" + zk, "zone":zk, "mode":"free", "name":"Free Drive — " + z.name,
			"len":18.0, "heat":0, "cash":0, "rep":0, "tier":3}
		v.add_child(_btn("%s  ·  %s" % [z.name, z.tag], func(): launch_race.emit(e, "racer")))

# ================= GARAGE =================
	_focus_first()

# ================= DIFFICULTY (3 levels of play) =================
func show_difficulty() -> void:
	_clear(); _bg()
	var v := _panel(760)
	var t := _lbl("CHOOSE YOUR LEVEL", 34, PINK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_lbl("Changes AI skill, police heat, damage taken, weapon cooldowns,\nrespawn timers and payouts. Switch any time from here or Settings.", 13, GREY))
	v.add_child(HSeparator.new())
	for k in D.DIFFICULTY:
		var d: Dictionary = D.DIFFICULTY[k]
		var b := _btn("%s%s\n%s" % [d.label, "   ✔ CURRENT" if P.data.diff == k else "", d.desc],
			func():
				P.data.diff = k
				P.data.flags["diff_chosen"] = true
				P.save_game()
				SFX.play("ui_click", -6.0)
				show_menu(), P.data.diff == k)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if P.data.diff == k: b.modulate = Color(0.75, 1.0, 0.78)
		v.add_child(b)
	if P.data.flags.has("diff_chosen"):
		v.add_child(_btn("< Back", show_menu.bind()))
	_focus_first()

# ================= WEAPON LOADOUT =================
# Pick exactly 3 — clicking a 4th weapon swaps out the oldest pick.
func show_weapons() -> void:
	_clear(); _bg()
	var v := _scroll_panel()
	var head := HBoxContainer.new()
	head.add_child(_btn("< Back", show_menu.bind()))
	head.add_child(_lbl("  WEAPON LOADOUT", 28, PINK))
	v.add_child(head)
	v.add_child(_lbl("Choose 3 weapons for your slot keys [F] [G] [H]  (pad: LS-click / Y / RB). Unlimited ammo on everything. In a race, hit [Q] for your inventory.", 14, GREY))
	var lo := P.loadout()
	for wid in D.WEAPONS:
		var wd: Dictionary = D.WEAPONS[wid]
		var slot := lo.find(wid)
		var tag := "  —  SLOT %d [%s]" % [slot + 1, ["F", "G", "H"][slot]] if slot >= 0 else ""
		var b := _btn("%s%s\n%s" % [wd.name, tag, wd.desc], _toggle_weapon.bind(wid), slot >= 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if slot >= 0: b.modulate = Color(0.75, 1.0, 0.78)
		v.add_child(b)
	_focus_first()

func _toggle_weapon(wid: String) -> void:
	var lo := P.loadout()
	if wid in lo:
		if lo.size() > 1:
			lo.erase(wid)
	else:
		lo.append(wid)
		while lo.size() > 3:
			lo.pop_front()
	P.data.loadout = lo
	P.save_game()
	show_weapons()

func show_garage(sel := "") -> void:
	_clear(); _bg()
	garage_sel = sel if sel != "" else P.data.cur
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pc := PanelContainer.new()
	var sbb := StyleBoxFlat.new(); sbb.bg_color = PANEL; sbb.set_corner_radius_all(14); sbb.set_content_margin_all(18)
	pc.add_theme_stylebox_override("panel", sbb)
	pc.custom_minimum_size = Vector2(1150, 640)
	center.add_child(pc)
	var outer := VBoxContainer.new()
	pc.add_child(outer)
	var head := HBoxContainer.new()
	head.add_child(_btn("< Back", show_menu.bind()))
	head.add_child(_lbl("  GARAGE", 28, PINK))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_lbl("$%d" % int(P.data.cash), 24, GOOD))
	outer.add_child(head)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	outer.add_child(cols)
	# left: car list
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(330, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	for c in D.CARS:
		var own := P.owns(c.id)
		var b := _btn("%s\n%s" % [c.name, "OWNED" if own else "$%d" % c.price],
			show_garage.bind(c.id), garage_sel == c.id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if own: b.modulate = Color(0.8, 1.0, 0.85)
		list.add_child(b)
	list.add_child(_lbl("— SECRET —", 14, BAD))
	for c in D.SECRET_CARS:
		var got: bool = P.data.secrets.has(c.id)
		var b2 := _btn(c.name if got else "?????", show_garage.bind(c.id), garage_sel == c.id, not got)
		list.add_child(b2)
	# middle: 3D preview
	var vp_box := VBoxContainer.new()
	vp_box.custom_minimum_size = Vector2(360, 0)
	cols.add_child(vp_box)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(360, 300)
	vp_box.add_child(svc)
	preview_vp = SubViewport.new()
	preview_vp.transparent_bg = false
	svc.add_child(preview_vp)
	_build_preview()
	# right: detail
	var det_scroll := ScrollContainer.new()
	det_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(det_scroll)
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_scroll.add_child(det)
	_garage_detail(det)
	_focus_first()

func _build_preview() -> void:
	for c in preview_vp.get_children(): c.queue_free()
	var world := Node3D.new()
	preview_vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.72)
	env.ambient_light_energy = 1.2
	env.glow_enabled = true
	var we := WorldEnvironment.new(); we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.6
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(20, 20)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.09, 0.08, 0.15); fm.roughness = 0.3; fm.metallic = 0.5
	floor_mesh.material_override = fm
	world.add_child(floor_mesh)
	var cfg := P.car_cfg(garage_sel)
	var def := D.car_def(garage_sel)
	var shape: Dictionary = def.get("shape", {"len":4.6,"wid":2.0,"nose":1.0,"tail":0.6,"wing":0.5})
	var skin: String = cfg.get("skin", "")
	if (skin == "" or (skin != "proc" and not D.skin_ok(skin))) and def.has("skins"):
		skin = ""
		for s2 in def.skins:
			if D.skin_ok(str(s2)):
				skin = str(s2)
				break
	if skin != "" and skin != "proc" and D.skin_ok(skin):
		preview_car = CarFactory.build_model_visual(skin, shape)
		if preview_car.has_meta("wheelsets"):
			var sets: Dictionary = preview_car.get_meta("wheelsets")
			for k in sets:
				var sn: Node3D = sets[k].node
				preview_car.add_child(sn)
				sn.position = Vector3(sets[k].centre.x, 0.10, sets[k].centre.z)
	else:
		preview_car = CarFactory.build_visual(cfg.get("paint", "8a99a8"), cfg.get("finish", "gloss"),
			shape, garage_sel.begins_with("cop"))
		for p in [Vector3(-0.84, 0.36, -1.5), Vector3(0.84, 0.36, -1.5), Vector3(-0.84, 0.36, 1.55), Vector3(0.84, 0.36, 1.55)]:
			var w := CarFactory.wheel_visual(0.36)
			w.position = p
			preview_car.add_child(w)
	world.add_child(preview_car)
	var cam := Camera3D.new()
	cam.position = Vector3(4.2, 2.2, 5.2)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5, 0), Vector3.UP)
	world.add_child(cam)

func _process(delta: float) -> void:
	if preview_car and is_instance_valid(preview_car):
		preview_car.rotate_y(delta * 0.6)

func _garage_detail(det: VBoxContainer) -> void:
	var id := garage_sel
	var def := D.car_def(id)
	var own := P.owns(id)
	var is_secret: bool = D.SECRET_CARS.any(func(c): return c.id == id)
	var locked_secret: bool = is_secret and not P.data.secrets.has(id)
	det.add_child(_lbl(("?????" if locked_secret else def.name), 26, Color.WHITE))
	det.add_child(_lbl("%s   ·   PR %d" % [def.get("cls", "Police"), P.car_pr(id)], 14, GREY))
	if locked_secret:
		var sc = D.SECRET_CARS.filter(func(c): return c.id == id)[0]
		det.add_child(_lbl("CLASSIFIED — " + sc.hint, 15, BAD))
		return
	var s := P.car_stats(id)
	for row in [["Top Speed", s.top, "%d km/h" % int(s.kmh)], ["Acceleration", s.acc, "%.1f" % s.acc],
			["Handling", s.hand, "%.1f" % s.hand], ["Drift", s.drift, "%.1f" % s.drift],
			["Strength", s.str, "%.1f" % s.str], ["Nitrous", s.nitro, "%.1f" % s.nitro]]:
		var h := HBoxContainer.new()
		var nl := _lbl(row[0], 14, GREY); nl.custom_minimum_size.x = 110
		h.add_child(nl)
		var bar := ProgressBar.new()
		bar.max_value = 12.0; bar.value = row[1]; bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		h.add_child(_lbl(" " + str(row[2]), 14, Color.WHITE))
		det.add_child(h)
	if own:
		if P.data.cur == id:
			det.add_child(_lbl("✔ CURRENT RIDE", 16, GOOD))
		else:
			det.add_child(_btn("DRIVE THIS", func():
				P.data.cur = id
				P.save_game()
				show_garage(id), true))
		det.add_child(_lbl("UPGRADES", 16, CYAN))
		for u in D.UPGRADES:
			var lvl: int = P.data.cars[id].up.get(u.id, 0)
			var cost := D.up_cost(u, lvl)
			var h2 := HBoxContainer.new()
			var un := _lbl("%s  %s  [%s]" % [u.name, u.desc, "●".repeat(lvl) + "○".repeat(D.MAX_UP - lvl)], 14, Color.WHITE)
			un.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h2.add_child(un)
			if lvl >= D.MAX_UP:
				h2.add_child(_lbl("MAX", 14, GOOD))
			else:
				h2.add_child(_btn("$%d" % cost, func():
					if P.data.cash >= cost:
						P.data.cash -= cost
						P.data.cars[id].up[u.id] = lvl + 1
						P.save_game()
						SFX.play("ui_click")
						show_garage(id), false, P.data.cash < cost))
			det.add_child(h2)
		# v5 — bodywork picker for cars with imported model skins
		# v7 — only offer bodywork whose model files are actually installed
		var avail: Array = []
		if def.has("skins"):
			for s3 in def.skins:
				if D.skin_ok(str(s3)): avail.append(s3)
		if def.has("skins") and avail.is_empty():
			# v8: LOUD notice — this car has real imported models that are not installed
			var warn := _lbl("⚠ REAL CAR MODEL NOT INSTALLED\nThis car uses your imported 3D models. Extract ALL the\n\"chicane_..._models_...\" zips into the SAME folder as the game\n(so assets/models/ exists), restart, and it appears automatically.", 13, BAD)
			warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			det.add_child(warn)
		if not avail.is_empty():
			det.add_child(_lbl("BODYWORK", 16, CYAN))
			var opts: Array = avail
			opts.append("proc")
			var cur_skin: String = P.data.cars[id].get("skin", "")
			if cur_skin == "" or (cur_skin != "proc" and not D.skin_ok(cur_skin)):
				cur_skin = str(opts[0])
			var cur_i: int = maxi(opts.find(cur_skin), 0)
			var srow := HBoxContainer.new()
			var pick := func(step: int):
				var ni: int = ((cur_i + step) % opts.size() + opts.size()) % opts.size()
				P.data.cars[id]["skin"] = opts[ni]
				P.save_game()
				SFX.play("ui_click")
				show_garage(id)
			srow.add_child(_btn("<", func(): pick.call(-1)))
			var sname: String = "Procedural body" if cur_skin == "proc" \
				else str(D.MODEL_SKINS.get(cur_skin, {}).get("name", cur_skin))
			var sl := _lbl("  %s  (%d/%d)  " % [sname, cur_i + 1, opts.size()], 15, Color.WHITE)
			srow.add_child(sl)
			srow.add_child(_btn(">", func(): pick.call(1)))
			det.add_child(srow)
		var model_active: bool = not avail.is_empty() and P.data.cars[id].get("skin", "") != "proc"
		if model_active:
			det.add_child(_lbl("Paint & finish come with the bodywork on this model.", 13, GREY))
		if not model_active:
			det.add_child(_lbl("PAINT", 16, CYAN))
			var paint_row := HBoxContainer.new()
			for hexc in D.PAINTS:
				var b := Button.new()
				b.custom_minimum_size = Vector2(30, 30)
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color.from_string("#" + hexc, Color.RED)
				sb.set_corner_radius_all(6)
				b.add_theme_stylebox_override("normal", sb)
				b.add_theme_stylebox_override("hover", sb)
				b.add_theme_stylebox_override("pressed", sb)
				b.pressed.connect(func():
					P.data.cars[id].paint = hexc
					P.save_game()
					show_garage(id))
				paint_row.add_child(b)
			det.add_child(paint_row)
			var fin_row := HBoxContainer.new()
			for f in D.FINISHES:
				fin_row.add_child(_btn(f.capitalize(), func():
					P.data.cars[id].finish = f
					P.save_game()
					show_garage(id), P.data.cars[id].finish == f))
			det.add_child(fin_row)
	elif is_secret:
		det.add_child(_lbl("Unlocked — free in your garage.", 14, GOOD))
	else:
		# v9.4: every car is free to drive — pick whatever you want.
		det.add_child(_btn("DRIVE THIS — FREE", func():
			P.give_car(id)
			P.data.cur = id
			P.save_game()
			SFX.play("ui_win", -6.0)
			show_garage(id), true))
		det.add_child(_lbl("All cars are unlocked — jump in and drive.", 13, GREY))

# ================= SECRETS =================
func show_secrets() -> void:
	_clear(); _bg()
	var v := _panel(760)
	var head := HBoxContainer.new()
	head.add_child(_btn("< Back", show_menu.bind()))
	head.add_child(_lbl("  SECRET CARS", 28, BAD))
	v.add_child(head)
	for c in D.SECRET_CARS:
		var got: bool = P.data.secrets.has(c.id)
		v.add_child(_lbl("%s  %s" % ["🔓" if got else "🔒", c.name if got else "?????"], 18,
			GOOD if got else GREY))
		v.add_child(_lbl("    " + c.hint, 14, GREY))

# ================= SETTINGS =================
	_focus_first()

func show_settings() -> void:
	_clear(); _bg()
	var v := _scroll_panel(760, 640)
	var head := HBoxContainer.new()
	head.add_child(_btn("< Back", show_menu.bind()))
	head.add_child(_lbl("  SETTINGS", 28, CYAN))
	v.add_child(head)
	v.add_child(_lbl("Difficulty", 16, WARN))
	var drow := HBoxContainer.new()
	for k in D.DIFFICULTY:
		drow.add_child(_btn(D.DIFFICULTY[k].label, func():
			P.data.diff = k
			P.save_game()
			show_settings(), P.data.diff == k))
	v.add_child(drow)
	v.add_child(_lbl(D.DIFFICULTY[P.data.diff].desc, 12, GREY))
	v.add_child(_lbl("Audio", 16, WARN))
	_slider(v, "Master volume", "vol_master", 0.0, 1.0)
	_slider(v, "Music volume", "vol_music", 0.0, 1.0)
	_slider(v, "Engine volume", "vol_engine", 0.0, 1.0)
	_slider(v, "Effects volume", "vol_fx", 0.0, 1.0)
	var srow := HBoxContainer.new()
	srow.add_child(_btn("Sound on", func():
		SFX.muted = false
		show_settings(), not SFX.muted))
	srow.add_child(_btn("Muted", func():
		SFX.muted = true
		SFX.stop_race_audio()
		show_settings(), SFX.muted))
	v.add_child(srow)
	v.add_child(_lbl("Video", 16, WARN))
	var qrow := HBoxContainer.new()
	qrow.add_child(_lbl("Quality:  ", 14, GREY))
	for qi in 3:
		qrow.add_child(_btn(["Low", "Medium", "High"][qi], func():
			S.set_s("quality", qi)
			show_settings(), int(S.g("quality")) == qi))
	v.add_child(qrow)
	_slider(v, "Brightness", "brightness", 0.6, 1.6)
	_slider(v, "Field of view offset", "fov", -10.0, 15.0)
	_slider(v, "Camera shake", "cam_shake", 0.0, 1.0)
	_slider(v, "Chase camera distance", "cam_dist", 0.75, 1.45)
	_slider(v, "Chase camera height", "cam_height", 0.75, 1.45)
	v.add_child(_lbl("Driving", 16, WARN))
	var trow := HBoxContainer.new()
	trow.add_child(_lbl("Transmission:  ", 14, GREY))
	for tm in ["auto", "manual"]:
		trow.add_child(_btn("Automatic" if tm == "auto" else "Manual (B / V)", func():
			S.set_s("trans_mode", tm)
			show_settings(), str(S.g("trans_mode")) == tm))
	v.add_child(trow)
	for a in [["ABS brakes", "assist_abs"], ["Traction control", "assist_tc"],
			["Stability assist", "assist_stab"], ["Rain effects", "rain_fx"]]:
		var arow := HBoxContainer.new()
		arow.add_child(_lbl(str(a[0]) + ":  ", 14, GREY))
		for on in [true, false]:
			arow.add_child(_btn("On" if on else "Off", func():
				S.set_s(a[1], on)
				show_settings(), bool(S.g(a[1])) == on))
		v.add_child(arow)
	_slider(v, "Countersteer assist", "assist_steer", 0.0, 1.0)
	var strow := HBoxContainer.new()
	strow.add_child(_btn("Speed streaks: %s" % ("ON" if S.g("speed_streaks") else "OFF"), func():
		S.set_s("speed_streaks", not S.g("speed_streaks"))
		show_settings()))
	v.add_child(strow)
	v.add_child(_lbl("Controls", 16, WARN))
	_slider(v, "Steering sensitivity", "steer_sens", 0.5, 1.5)
	_slider(v, "Controller deadzone", "deadzone", 0.05, 0.4, true)
	var vrow := HBoxContainer.new()
	vrow.add_child(_btn("Vibration: %s" % ("ON" if S.g("vibration") else "OFF"), func():
		S.set_s("vibration", not S.g("vibration"))
		show_settings()))
	v.add_child(vrow)
	v.add_child(_lbl("Gameplay", 16, WARN))
	_slider(v, "Traffic density", "traffic", 0.0, 1.5)
	var grow := HBoxContainer.new()
	grow.add_child(_btn("God mode: %s" % ("ON" if S.g("god_mode") else "OFF"), func():
		S.set_s("god_mode", not S.g("god_mode"))
		show_settings()))
	grow.add_child(_btn("Radar: %s" % ("ON" if S.g("radar") else "OFF"), func():
		S.set_s("radar", not S.g("radar"))
		show_settings()))
	v.add_child(grow)
	v.add_child(_lbl("God mode: your car takes no damage, EMP stuns or spike strips. Radar: nearby-car blips above the damage bar.", 12, GREY))
	v.add_child(_lbl("Radio", 16, WARN))
	var rrow := HBoxContainer.new()
	for r in D.RADIO:
		rrow.add_child(_btn(r.name, func():
			P.data.station = r.id
			SFX.set_station(r.id)
			P.save_game()
			show_settings(), P.data.station == r.id))
	v.add_child(rrow)
	v.add_child(HSeparator.new())
	v.add_child(_lbl("Keyboard: WASD/arrows · SPACE handbrake · SHIFT nitrous · F/G/H weapon slots · Q inventory · Z warp · Y nuke police (EASY) · E EMP · K spikes · R roadblock · T turbo · C camera · X reset · M radio · ESC pause", 12, GREY))
	v.add_child(_lbl("Controller: RT throttle · LT brake · Left stick steer · X handbrake · A nitrous · LS-click/Y/RB weapon slots · D-pad left warp · B turbo · LB spikes · Back camera · D-pad up reset · Start pause", 12, GREY))
	v.add_child(_btn("RESET ALL PROGRESS", _confirm_reset.bind()))
	_focus_first()

func _confirm_reset() -> void:
	_clear(); _bg()
	var v := _panel(520)
	var warn := _lbl("Delete ALL progress?", 26, BAD)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(warn)
	v.add_child(_lbl("Every car, upgrade, win and record will be wiped.", 14, GREY))
	v.add_child(_btn("YES — WIPE EVERYTHING", func():
		P.reset()
		S._migrate()
		show_menu(), true))
	v.add_child(_btn("Cancel", show_settings.bind()))
	_focus_first()

func _slider(parent: VBoxContainer, label: String, key: String, mn: float, mx: float, live_deadzone := false) -> void:
	var row := HBoxContainer.new()
	var l := _lbl(label, 14, GREY)
	l.custom_minimum_size.x = 210
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = 0.05
	sl.value = float(S.g(key))
	sl.custom_minimum_size = Vector2(280, 24)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := _lbl("%.2f" % float(S.g(key)), 13, Color.WHITE)
	sl.value_changed.connect(func(v2):
		S.set_s(key, v2)
		val.text = "%.2f" % v2
		if live_deadzone: S.apply_deadzone())
	row.add_child(sl)
	row.add_child(val)
	parent.add_child(row)
func show_results(s: Dictionary, career: String) -> void:
	_clear(); _bg()
	var v := _panel(640)
	var t := _lbl(s.title, 52, GOOD if s.win else BAD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _lbl(s.sub, 16, GREY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	v.add_child(HSeparator.new())
	for line in s.lines:
		var h := HBoxContainer.new()
		var a := _lbl(line[0], 15, GREY); a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(_lbl(str(line[1]), 15, Color.WHITE))
		v.add_child(h)
	var pay := HBoxContainer.new()
	var pl := _lbl("Cash earned", 16, GREY); pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pay.add_child(pl)
	pay.add_child(_lbl("+$%d" % int(s.payout), 16, GOOD))
	v.add_child(pay)
	var rep := HBoxContainer.new()
	var rl := _lbl("Merit" if career == "cop" else "Reputation", 16, GREY)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep.add_child(rl)
	rep.add_child(_lbl("+%d" % int(s.rep), 16, GOOD))
	v.add_child(rep)
	if s.win and not s.first:
		v.add_child(_lbl("(repeat win — reduced rewards)", 12, GREY))
	v.add_child(HSeparator.new())
	v.add_child(_btn("CONTINUE", func():
		if career == "cop": show_cop()
		else: show_racer(), true))
	v.add_child(_btn("Main Menu", show_menu.bind()))
	_focus_first()

func show_secret_popup(sc: Dictionary) -> void:
	var l := _lbl("SECRET CAR UNLOCKED — %s" % sc.name, 22, WARN)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_top = 90
	l.offset_left = -300
	l.offset_right = 300
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	SFX.play("ui_win", -4.0)
	get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())
