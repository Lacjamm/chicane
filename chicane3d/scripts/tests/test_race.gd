# Headless smoke test: boots races with a bot driver, verifies state machine.
extends Node

var race: RaceManager
var phase := 0
var timer := 0.0
var log_t := 0.0
var results: Array = []
var _warped := false
var _demolished := false
var _impounded := false
var _nuked_cops := false
var _god_on := false
var _god_off := false
var _diff_was := "normal"

func _ready() -> void:
	print("TEST: boot ok — profile cash=", P.data.cash, " diff=", P.data.diff)
	_start_phase()

func _start_phase() -> void:
	timer = 0.0
	match phase:
		0: _launch(D.RACER_EVENTS[0], "racer")            # r01 sprint
		1: _launch(D.COP_EVENTS[0], "cop")                # c01 intercept
		2: _launch(D.RACER_EVENTS[3], "racer")            # r04 drift
		3: _launch(D.RACER_EVENTS[1], "racer")            # r02 TRUE CIRCUIT (loop)
		4: _launch({"id":"roam", "zone":"coastal", "mode":"roam", "name":"Velocity County",
			"len":21.0, "heat":0, "cash":0, "rep":0, "tier":3}, "racer")   # open world
		5:
			_wrap_up()

func _launch(ev: Dictionary, career: String) -> void:
	print("TEST: launching ", ev.id, " (", career, ")")
	race = RaceManager.new()
	add_child(race)
	race.start(ev, career)
	race.finished.connect(_on_finished, CONNECT_ONE_SHOT)

func _on_finished(summary: Dictionary) -> void:
	print("TEST RESULT[", phase, "]: ", race.result, " | ", summary.title, " | payout=", summary.payout,
		" | top=", int(race.best_speed), "km/h | dmg=", int(100.0 - race.player.hp), "%")
	if phase == 0:
		print("TEST missiles: fired=", race.missiles_fired, " respawns=", race.respawns_done,
			" queue=", race.respawn_queue.size(), " player_rips=", race.rips,
			" buildings_destroyed=", race.buildings_destroyed)
		results.append("buildings_ok" if race.buildings_destroyed >= 2 else "buildings_none")
		results.append("missile_ok" if race.missiles_fired > 0 and race.respawns_done > 0 else "missile_none")
	results.append(race.result)
	race.cleanup()
	race.queue_free()
	race = null
	_release_all()
	phase += 1
	call_deferred("_start_phase")

func _physics_process(delta: float) -> void:
	if race == null: return
	timer += delta
	log_t += delta
	if log_t > 5.0:
		log_t = 0.0
		var p := race.player
		var rp := ""
		for r in race.rivals:
			if is_instance_valid(r): rp += "%d " % int(r.progress)
		print("  t=%.0f state=%s prog=%.0f/%.0f lap=%d/%d gear=%s kmh=%.0f hp=%.0f lat=%.1f cops=%d rivals=[%s]" %
			[timer, race.state, p.progress, race.finish_d, race.lap, race.laps,
			p.trans.gear_label() if p.trans else "?", p.kmh(), p.hp, p.lateral, race.cops.size(), rp.strip_edges()])
	if race.state == "racing":
		_bot(delta)
		if race.mode == "roam":
			_roam_test()
	# safety timeout per phase (generous — RIP respawns can lengthen races)
	if timer > 320.0:
		print("TEST TIMEOUT phase ", phase, " — state=", race.state, " prog=", race.player.progress)
		results.append("timeout_harness")
		race.cleanup(); race.queue_free(); race = null
		_release_all()
		phase += 1
		call_deferred("_start_phase")

func _bot(_delta: float) -> void:
	var p := race.player
	Input.action_press("accel")
	# unlimited weapons: hammer the loadout through the first sprint to
	# exercise blow-ups and the 10s respawn path end-to-end
	if phase == 0 and timer > 5.0 and race.weapons:
		race.weapons.fire_slot(0)                        # missile (cd-gated)
		if int(timer) % 3 == 0: race.weapons.fire_slot(1)  # machine guns
		if int(timer) % 5 == 0: race.weapons.fire_slot(2)  # bomb
	# warp speed: engage once mid-sprint, verify the 3x cap unlocks
	if phase == 0 and not _warped and timer > 15.0 and race.cd_warp <= 0.0:
		_warped = true
		race.cd_warp = 25.0
		p.start_warp(10.0)
		print("TEST warp engaged at kmh=", int(p.kmh()))
	# impound warning: trigger it, then clear it with the easy-mode nuke
	if phase == 0 and not _impounded and timer > 24.0 and race.wanted:
		_impounded = true
		race._trigger_impound_warning()
		print("TEST impound warning started: %ds on the clock" % int(race.impound_t))
	if phase == 0 and _impounded and not _nuked_cops and timer > 28.0:
		_nuked_cops = true
		var was: String = P.data.diff
		P.data.diff = "easy"
		race._fire_nuke()
		P.data.diff = was
		var alive: int = race.cops.filter(func(c): return is_instance_valid(c) and not c.wrecked and not c.dead).size()
		print("TEST nuke: fired=", race.nukes_fired, " cops_alive_after=", alive,
			" impound_cleared=", race.impound_t == 0.0)
		results.append("nuke_ok" if race.nukes_fired > 0 and race.impound_t == 0.0 else "nuke_fail")
	# god mode toggle: flip it on (easy-only path), let the bot ram things
	# for a while with explosive touch, then flip it back off
	if phase == 0 and not _god_on and timer > 32.0:
		_god_on = true
		_diff_was = P.data.diff
		P.data.diff = "easy"
		race._toggle_god()
		print("TEST god mode on: ", S.g("god_mode"))
	if phase == 0 and _god_on and not _god_off and timer > 44.0:
		_god_off = true
		race._toggle_god()
		P.data.diff = _diff_was
		print("TEST god mode off: ", S.g("god_mode"), " god_kills=", race.god_kills)
		results.append("god_ok" if not S.g("god_mode") else "god_stuck")
	# destructibles: level one building of each reachable type deterministically
	if phase == 0 and not _demolished and timer > 20.0 and race.destructibles \
			and race.destructibles.buildings.size() > 1:
		_demolished = true
		var before: int = race.destructibles.buildings.size()
		race.destructibles.destroy(race.destructibles.buildings[0], p.global_position)
		race.destructibles.damage(race.destructibles.buildings[0], 99, p.global_position)
		print("TEST buildings: %d spawned, destroyed 2 -> %d left, counter=%d" %
			[before, race.destructibles.buildings.size(), race.buildings_destroyed])
	# steer toward a sensible lane / the target
	var want_lat := 2.0
	if race.mode == "intercept" and race.target and is_instance_valid(race.target):
		want_lat = race.target.lateral
		if race.target.progress - p.progress < 30.0:
			Input.action_press("nitro")
		if race.cd_emp <= 0.0 and race.target.progress - p.progress < 60.0:
			race._fire_emp()
	else:
		var curv := TrackGen._curvature(race.samples, p.track_idx)
		want_lat = clampf(-curv * 30.0, -4.0, 4.0)
	# traffic/vehicle avoidance — mirror of the rival AI logic
	var own_ms := p.kmh() / 3.6
	var blocked := false
	for other in race.all_vehicles():
		if not is_instance_valid(other): continue
		var op: float = other.progress if "progress" in other else -1e9
		var gap := op - p.progress
		var closing := own_ms
		if other is TrafficCar and other.oncoming: closing += other.speed_kmh / 3.6
		if gap > 0.0 and gap < 25.0 + closing * 1.5:
			var ox: float = other.lateral if "lateral" in other else 0.0
			if absf(ox - want_lat) < 2.6:
				want_lat = clampf(ox - 3.4 if ox > 0.0 else ox + 3.4, -5.5, 5.5)
			if gap < 35.0 and absf(ox - p.lateral) < 2.0:
				blocked = true
	if blocked:
		Input.action_press("brake", 0.5)
		Input.action_release("nitro")
	else:
		Input.action_release("brake")
	if absf(curvature_ahead()) > 0.055 and p.kmh() > 150.0:
		Input.action_press("brake", 0.6)
	# heading correction: compare car forward with road forward
	var s: Dictionary = race.samples[race.sample_index(p.progress + 20.0)]
	var fwd := -p.global_transform.basis.z
	var ang: float = fwd.signed_angle_to(s.fwd, Vector3.UP)
	# positive steering turns LEFT (toward -lateral), so excess +lateral needs +steer
	var steer := clampf(ang * 1.4 + clampf((p.lateral - want_lat) * 0.12, -0.6, 0.6), -1.0, 1.0)
	if steer > 0.06:
		Input.action_press("left", clampf(steer, 0.0, 1.0))
		Input.action_release("right")
	elif steer < -0.06:
		Input.action_press("right", clampf(-steer, 0.0, 1.0))
		Input.action_release("left")
	else:
		Input.action_release("left")
		Input.action_release("right")
	if race.mode != "intercept":
		if absf(curvature_ahead()) < 0.004 and p.nitro > 0.4:
			Input.action_press("nitro")
		else:
			Input.action_release("nitro")
	# drift mode: handbrake through corners
	if race.mode == "drift" and absf(curvature_ahead()) > 0.006 and p.kmh() > 90.0:
		Input.action_press("handbrake")
	else:
		Input.action_release("handbrake")
	# recover if flipped/stopped (never during the RIP respawn countdown)
	if p.kmh() < 4.0 and timer > 10.0 and not p.wrecked and int(timer * 60.0) % 240 == 0:
		p.reset_to_track()

func curvature_ahead() -> float:
	return TrackGen._curvature(race.samples, clampi(race.player.track_idx + 8, 0, race.samples.size() - 1))

# ---- open-world phase: cross a district, run an embedded event, discover road ----
var roam_zone0 := ""
var roam_crossed := false
var roam_sub_started := false
var roam_sub_done := false

func _roam_test() -> void:
	var rm: Roam = race.roam
	if rm == null: return
	if roam_zone0 == "":
		roam_zone0 = rm.cur_zone
		print("TEST roam: start zone=", roam_zone0, " sectors=", race.sectors.size(),
			" markers=", rm.markers.size(), " cams=", rm.cameras.size(), " barns=", rm.barns.size())
	if not roam_sub_started and timer > 4.0:
		roam_sub_started = true
		rm._start_event({"id":"t_sub", "mode":"timeattack", "len":0.5, "time":40.0,
			"gate_bonus":6.0, "cash":1500, "rep":25, "name":"Harness Time Attack"})
		print("TEST roam: embedded time attack started (", int(rm.sub_len), "m)")
	if roam_sub_started and not roam_sub_done and rm.sub_mode == "":
		roam_sub_done = true
		print("TEST roam: embedded event finished — wins has t_sub=", P.data.wins.has("t_sub"))
	if not roam_crossed and rm.cur_zone != roam_zone0:
		roam_crossed = true
		print("TEST roam: crossed district border ", roam_zone0, " → ", rm.cur_zone,
			" at prog=", int(race.player.progress))
	if roam_crossed and roam_sub_done:
		var pct := rm.discovery_pct()
		var cams_hit: int = P.data.roam.cams.size()
		print("TEST roam: discovery=", pct, "% cams_recorded=", cams_hit)
		var ok_roam: bool = pct > 0 and race.sectors.size() == 6
		results.append("roam_ok" if ok_roam else "roam_fail")
		race.cleanup(); race.queue_free(); race = null
		_release_all()
		phase += 1
		call_deferred("_start_phase")

func _release_all() -> void:
	for a in ["accel", "brake", "left", "right", "nitro", "handbrake"]:
		Input.action_release(a)

func _wrap_up() -> void:
	# non-race sanity checks
	P.data.cash = 999999
	P.give_car("saber")
	var s := P.car_stats("saber")
	assert(s.kmh > 300.0)
	for e in D.RACER_EVENTS.filter(func(ev): return ev.mode == "drift"):
		P.data.wins[e.id] = true
	P.check_secrets()
	print("TEST: secrets after all-drift wins → ", P.data.secrets.keys())
	print("TEST SUMMARY: ", results)
	var pass_ok: bool = results.size() >= 5 and not results.has("timeout_harness") \
		and not results.has("roam_fail") and not results.has("missile_none") \
		and not results.has("buildings_none") and not results.has("nuke_fail") \
		and not results.has("god_stuck")
	print("TEST ", "PASS" if pass_ok else "PARTIAL")
	get_tree().quit(0 if pass_ok else 1)
