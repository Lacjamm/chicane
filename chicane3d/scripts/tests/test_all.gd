# ============================================================
# CHICANE 3D — test_all.gd
# Fast validation suite: data integrity, track generation for
# every district, closed loops, car stats, racing line, saves.
# Run: godot --headless res://scenes/tests/TestAll.tscn
# ============================================================
extends Node

var fails := 0
var checks := 0

func ok(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  PASS  ", label)
	else:
		fails += 1
		print("  FAIL  ", label)

func _ready() -> void:
	print("== CHICANE VALIDATION SUITE ==")
	_check_events()
	_check_cars()
	_check_tracks()
	_check_racing_line()
	_check_world()
	_check_skins()
	_check_missiles()
	_check_save()
	print("== %d checks, %d failures ==" % [checks, fails])
	print("SUITE ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(0 if fails == 0 else 1)

func _check_events() -> void:
	print("- events -")
	for e in D.RACER_EVENTS:
		ok(D.ZONES.has(e.zone), "zone exists: %s (%s)" % [e.id, e.zone])
		if e.mode == "boss":
			ok(D.BOSSES.has(e.boss), "boss exists: %s" % e.id)
			ok(D.car_def(D.BOSSES[e.boss].car).id == D.BOSSES[e.boss].car, "boss car: %s" % e.id)
		if e.mode == "duel":
			ok(D.car_def(e.rival).id == e.rival, "duel rival car: %s" % e.id)
		if e.mode in ["drift", "topspeed", "speedtrap"]:
			ok(e.has("target"), "target present: %s" % e.id)
		if e.mode == "timeattack":
			ok(e.has("time"), "time present: %s" % e.id)
	for m in D.COP_EVENTS:
		ok(D.ZONES.has(m.zone), "cop zone: %s" % m.id)
		ok(D.car_def(m.target).id == m.target, "cop target car: %s" % m.id)
	for sc in D.SECRET_CARS:
		ok(sc.has("unlock") and sc.has("hint"), "secret meta: %s" % sc.id)
	for b in D.BOSSES:
		ok(D.BOSSES[b].car_reward == "" or D.car_def(D.BOSSES[b].car_reward).id == D.BOSSES[b].car_reward,
			"boss reward car: %s" % b)

func _check_cars() -> void:
	print("- cars -")
	for c in D.CARS + D.SECRET_CARS + D.COP_CARS:
		var s := P.car_stats(c.id)
		ok(s.kmh > 180.0 and s.kmh < 520.0, "kmh sane: %s (%.0f)" % [c.id, s.kmh])
		ok(is_finite(s.acc) and s.acc > 0.0, "acc sane: %s" % c.id)
	P.give_car("saber")
	P.data.cars["saber"].up = {"engine": 4, "armour": 4, "susp": 4, "tyres": 4}
	var s2 := P.car_stats("saber")
	ok(s2.top > 7.6 and s2.hand < 9.3 + 4 * 0.35, "upgrade trade-offs applied")
	ok(P.car_pr("falco") > 100 and P.car_pr("absolut") > P.car_pr("falco"), "PR ordering")
	P.data.cars.erase("saber")

func _check_tracks() -> void:
	print("- tracks -")
	for zk in D.ZONES:
		var t := TrackGen.generate(zk, 2.0, hash(zk))
		ok(t.samples.size() > 100, "track gen: %s (%d samples)" % [zk, t.samples.size()])
		ok(t.length > 1000.0, "track length: %s" % zk)
		t.root.free()
	for zk in ["neon", "mountain", "coastal"]:
		var t2 := TrackGen.generate_loop(zk, 3.0, hash(zk) + 7)
		var first: Vector3 = t2.samples[0].pos
		var last: Vector3 = t2.samples[-1].pos
		ok(first.distance_to(last) < TrackGen.SAMPLE * 3.0, "loop closes: %s (gap %.1fm)" % [zk, first.distance_to(last)])
		ok(t2.length > 2000.0, "loop length: %s" % zk)
		t2.root.free()

func _check_racing_line() -> void:
	print("- racing line -")
	var t := TrackGen.generate("mountain", 3.0, 99)
	var rl := RacingLine.build(t.samples, false)
	var ok_speed := true
	var ok_off := true
	for v in rl.speed:
		if v < 55.0 or v > 470.0: ok_speed = false
	for o in rl.offset:
		if absf(o) > 5.4: ok_off = false
	ok(ok_speed, "corner speeds within bounds")
	ok(ok_off, "line offsets within road")
	var has_slow := false
	for v in rl.speed:
		if v < 180.0: has_slow = true
	ok(has_slow, "braking zones exist on mountain track")
	t.root.free()

func _check_world() -> void:
	print("- velocity county (open world) -")
	var w := TrackGen.generate_world(P.world_seed(), {"bare": true})
	ok(w.samples.size() > 2000, "world size (%d samples, %.1f km)" % [w.samples.size(), w.length / 1000.0])
	var first: Vector3 = w.samples[0].pos
	var last: Vector3 = w.samples[-1].pos
	ok(first.distance_to(last) < TrackGen.SAMPLE * 3.0, "world ring closes (gap %.1fm)" % first.distance_to(last))
	# connectivity: consecutive samples are never far apart (one drivable road)
	var max_gap := 0.0
	for i in range(1, w.samples.size()):
		max_gap = maxf(max_gap, w.samples[i - 1].pos.distance_to(w.samples[i].pos))
	ok(max_gap < TrackGen.SAMPLE * 2.5, "road continuous (max gap %.1fm)" % max_gap)
	# every district present, in order, covering the whole ring
	var zones_seen: Array = []
	for sec in w.sectors:
		zones_seen.append(sec.zone)
	ok(zones_seen == TrackGen.WORLD_ORDER, "all districts in order: %s" % str(zones_seen))
	var covered: int = 0
	for sec in w.sectors:
		covered += sec.i1 - sec.i0 + 1
	ok(covered >= w.samples.size() - 6, "sectors cover the ring (%d/%d)" % [covered, w.samples.size()])
	# determinism: same seed → identical world
	var w2 := TrackGen.generate_world(P.world_seed(), {"bare": true})
	var same: bool = w2.samples.size() == w.samples.size()
	if same:
		for i in range(0, w.samples.size(), 97):
			if w.samples[i].pos.distance_to(w2.samples[i].pos) > 0.01:
				same = false
				break
	ok(same, "deterministic: same seed, same world")
	var w3 := TrackGen.generate_world(P.world_seed() + 1, {"bare": true})
	var diff: bool = w3.samples.size() != w.samples.size()
	if not diff:
		for i in range(0, w.samples.size(), 97):
			if w.samples[i].pos.distance_to(w3.samples[i].pos) > 1.0:
				diff = true
				break
	ok(diff, "different seed, different world")
	w.root.free(); w2.root.free(); w3.root.free()

func _check_skins() -> void:
	print("- model skins (optional asset packs) -")
	# registry consistency is REQUIRED; model files themselves are OPTIONAL
	# (the game must boot and play fully without the model pack zips)
	var installed := 0
	var missing: Array = []
	for sid in D.MODEL_SKINS:
		if D.skin_ok(sid): installed += 1
		else: missing.append(sid)
	print("  INFO  model packs: %d/%d skins installed%s" %
		[installed, D.MODEL_SKINS.size(), "" if missing.is_empty() else "  (missing: %s)" % ",".join(missing)])
	for c in D.CARS + D.COP_CARS:
		if c.has("skins"):
			for s in c.skins:
				ok(D.MODEL_SKINS.has(s), "car %s skin registered: %s" % [c.id, s])
	# every model-skin car must still produce a usable visual with NO packs:
	# an unavailable skin id must fall back to a procedural body, not crash
	var fb := CarFactory.build_model_visual("__not_installed__", {"len":4.6,"wid":2.0,"nose":1.0,"tail":0.6,"wing":0.5})
	ok(fb != null and fb.get_child_count() > 0, "missing model falls back to procedural body")
	fb.free()
	# if at least one pack is installed, build one end-to-end
	if installed > 0:
		var pick := ""
		for sid in ["i8", "camaro_gs", "vw_lp"]:
			if D.skin_ok(sid): pick = sid; break
		if pick == "":
			for sid in D.MODEL_SKINS:
				if D.skin_ok(sid): pick = sid; break
		var v := CarFactory.build_model_visual(pick, {"len":4.7,"wid":2.0,"nose":1.1,"tail":0.7,"wing":0.2})
		var n_mesh := 0
		var stack: Array = [v]
		# wheel meshes are split out into hub-mounted wheelsets (meta) — count those too
		if v.has_meta("wheelsets"):
			for k in v.get_meta("wheelsets"):
				stack.append(v.get_meta("wheelsets")[k].node)
		while not stack.is_empty():
			var nd: Node = stack.pop_back()
			if nd is MeshInstance3D: n_mesh += 1
			stack.append_array(nd.get_children())
		ok(n_mesh > 5, "model visual builds: %s (%d meshes)" % [pick, n_mesh])
		ok(v.has_meta("model_skin"), "model visual tagged for damage guards")
		if v.has_meta("wheelsets"):
			for k in v.get_meta("wheelsets"):
				v.get_meta("wheelsets")[k].node.free()
		v.free()
	ok(str(S.g("trans_mode")) in ["auto", "manual"], "transmission setting migrated")

func _check_missiles() -> void:
	print("- weapons (unlimited) + respawn -")
	var ms = load("res://scripts/missile.gd")
	ok(ms != null, "missile script loads")
	var m: Node3D = ms.new()
	ok(m is Node3D, "missile instantiates")
	m.free()
	var rm := RaceManager.new()
	ok(rm.RESPAWN_DELAY == 10.0, "blown-up cars respawn after 10s")
	ok(rm.cd_missile == 0.0, "missile ready at race start")
	rm.free()
	# traffic can be blown up (method exists without needing a live race)
	var tc := TrafficCar.new()
	ok(tc.has_method("blow_up"), "traffic supports blow_up")
	tc.free()
	# v9.4 pick-3 loadout
	for i in 3:
		ok(InputMap.has_action("wpn%d" % (i + 1)), "weapon slot %d input registered" % (i + 1))
	for wid in ["gun", "sword", "chainsaw", "ball", "bomb", "flame", "freeze", "missile", "emp", "shock"]:
		ok(D.WEAPONS.has(wid), "weapon in roster: %s" % wid)
	for wid in D.WEAPONS:
		ok(D.WEAPONS[wid].has("name") and D.WEAPONS[wid].has("cd") and D.WEAPONS[wid].has("desc"),
			"weapon def complete: %s" % wid)
	for wid in D.DEFAULT_LOADOUT:
		ok(D.WEAPONS.has(wid), "default loadout valid: %s" % wid)
	ok(P.loadout().size() == 3, "loadout resolves to exactly 3 weapons")
	var backup = P.data.get("loadout")
	P.data.loadout = ["nonsense", "flame", "flame"]
	var lo := P.loadout()
	ok(lo.size() == 3 and "flame" in lo and not "nonsense" in lo, "loadout sanitises bad saves")
	P.data.loadout = backup
	var ws = load("res://scripts/weapons.gd")
	ok(ws != null and ws.can_instantiate(), "weapons controller loads")
	var wnode: Node = ws.new()
	ok(wnode.has_method("fire_slot"), "weapons controller has fire_slot")
	wnode.free()
	# v9.5 — god mode, warp speed, radar
	ok(InputMap.has_action("warp"), "warp input registered")
	ok(S.DEFAULTS.has("god_mode") and S.DEFAULTS.god_mode == false, "god mode setting (default off)")
	ok(S.DEFAULTS.has("radar") and S.DEFAULTS.radar == true, "radar setting (default on)")
	ok(S.DEFAULTS.has("brightness"), "brightness setting exists")
	var pc := PlayerCar.new()
	ok(pc.has_method("start_warp"), "player supports warp speed")
	pc.start_warp(10.0)
	ok(pc.warp_t == 10.0, "warp lasts 10 seconds")
	# v9.7 — health bar + RIP respawn
	var rr := RaceManager.new()
	ok(rr.RIP_RESPAWN == 5.0, "RIP respawn countdown is 5s")
	rr.free()
	var vb := VehicleBase.new()
	ok(vb.has_method("rebuild_visual"), "vehicles can rebuild visuals on respawn")
	vb.free()
	# v9.6 — [Q] weapon inventory overlay
	ok(InputMap.has_action("inv"), "inventory input registered ([Q])")
	var hud_s = load("res://scripts/hud.gd")
	ok(hud_s != null and hud_s.can_instantiate(), "hud loads")
	var hh: Node = hud_s.new()
	ok(hh.has_method("toggle_inventory"), "hud has weapon inventory overlay")
	hh.free()
	var god_was: bool = S.g("god_mode")
	P.data.settings.god_mode = true
	pc.hp = 100.0
	pc.take_impact(Vector3.ZERO, Vector3.UP, 50.0, 1.0)
	pc.stun(2.0)
	pc.spike()
	ok(pc.hp == 100.0 and pc.stun_t == 0.0 and pc.spike_t == 0.0, "god mode blocks damage/stun/spikes")
	P.data.settings.god_mode = god_was
	pc.free()

func _check_save() -> void:
	print("- save / migration -")
	var backup := P.data.duplicate(true)
	P.data = P.fresh()
	P.data.erase("settings")   # simulate an old save
	P.data.erase("bests")
	P.data.erase("roam")       # simulate a pre-open-world save
	P.save_game()
	P.load_game()
	S._migrate()
	ok(P.data.has("settings") and P.data.settings.has("vol_master"), "settings migrated")
	ok(P.data.has("bests") and P.data.has("medals"), "new fields migrated")
	ok(P.data.has("roam") and P.data.roam.has("disc") and P.data.roam.has("barns") \
		and P.data.roam.has("cams") and int(P.data.roam.seed) == 20260803, "open-world save migrated")
	# barn restoration pipeline
	P.data.roam.barns["barn_desert"] = "found"
	P.data.roam.barns["barn_desert_races"] = 2
	var owned_before := P.owns("vulcan")
	var restored := P.barn_tick()
	ok(restored.has("vulcan") and P.data.roam.barns["barn_desert"] == "done" \
		and (owned_before or P.owns("vulcan")), "barn find restores after 3 events")
	P.data = backup
	P.save_game()
