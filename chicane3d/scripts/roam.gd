# ============================================================
# CHICANE 3D — roam.gd
# Velocity County free-roam manager: district transitions,
# event markers with seamless on-road entry, road discovery,
# barn finds, speed cameras, danger jumps. Deterministic per seed.
# ============================================================
class_name Roam
extends Node3D

var race: RaceManager
var cur_zone := ""
var _env_lerp := 0.0
var _env_from: Dictionary = {}
var _env_to: Dictionary = {}

# markers / sites
var markers: Array = []            # {node, ev, d, career}
var cameras: Array = []            # {node, d, cd}
var barns: Array = []              # {node, d, id, car}
var jumps: Array = []              # {d}
var near_marker: Dictionary = {}
var _disc_t := 0.0
var _air_t := 0.0
var _was_air := false
var disc_pct := 0          # cached discovery % for the HUD

# embedded event state
var sub_mode := ""                 # "" = free roaming
var sub_ev: Dictionary = {}
var sub_origin := 0.0
var sub_len := 0.0
var sub_t := 0.0
var sub_rivals: Array = []
var sub_gate := 0
var sub_time := 0.0
var sub_traps: Array = []
var sub_trap_next := 0
var sub_drift0 := 0

const CAMERA_FRACS := [0.08, 0.25, 0.44, 0.63, 0.81]
const JUMP_FRACS := [0.18, 0.71]

func setup(r: RaceManager) -> void:
	race = r
	_build_markers()
	_build_cameras()
	_build_barns()
	_build_jumps()
	cur_zone = _zone_at(race.player.progress)
	race.zone_key = cur_zone
	disc_pct = discovery_pct()

func _zone_at(d: float) -> String:
	var idx := race.sample_index(d)
	return race.samples[idx].get("zone", "coastal")

# ---------- world sites ----------
func _marker_events() -> Array:
	# a curated on-road event per district (modes that run on the open ring)
	var picks: Array = []
	var used_zones := {}
	for e in D.RACER_EVENTS:
		if e.mode in ["sprint", "timeattack", "speedtrap", "drift", "escape"] \
				and not used_zones.has(e.zone) and e.zone != "blacktrack":
			used_zones[e.zone] = true
			picks.append(e)
	return picks

func _build_markers() -> void:
	for e in _marker_events():
		# place inside that district's sector
		for sec in race.sectors:
			if sec.zone == e.zone:
				var d: float = lerpf(sec.d0, sec.d1, 0.35)
				var s: Dictionary = race.samples[race.sample_index(d)]
				var node := Node3D.new()
				var pil := MeshInstance3D.new()
				var pb := CylinderMesh.new()
				pb.top_radius = 0.35; pb.bottom_radius = 0.55; pb.height = 7.0
				pil.mesh = pb
				pil.material_override = CarFactory.emissive(Color(0.18, 0.89, 1.0), 1.4)
				pil.position = Vector3.UP * 3.5
				node.add_child(pil)
				var lbl := Label3D.new()
				lbl.text = e.name + "\n[" + e.mode.to_upper() + "]"
				lbl.font_size = 96
				lbl.outline_size = 16
				lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lbl.position = Vector3.UP * 8.0
				node.add_child(lbl)
				add_child(node)
				node.global_position = s.pos + s.right * (TrackGen.ROAD_HALF + 3.0)
				markers.append({"node": node, "ev": e, "d": d})
				break

func _build_cameras() -> void:
	for f in CAMERA_FRACS:
		var d: float = race.length * f
		var s: Dictionary = race.samples[race.sample_index(d)]
		var node := Node3D.new()
		var pole := MeshInstance3D.new()
		var pm := BoxMesh.new(); pm.size = Vector3(0.2, 5.0, 0.2)
		pole.mesh = pm; pole.material_override = CarFactory.trim_material()
		pole.position = Vector3.UP * 2.5
		node.add_child(pole)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.8, 0.5, 0.5)
		box.mesh = bm
		box.material_override = CarFactory.emissive(Color(1.0, 0.85, 0.3), 1.0)
		box.position = Vector3.UP * 5.0
		node.add_child(box)
		add_child(node)
		node.global_position = s.pos + s.right * (TrackGen.ROAD_HALF + 1.2)
		cameras.append({"node": node, "d": d, "cd": 0.0})

func _build_barns() -> void:
	for site in D.BARN_SITES:
		if P.data.roam.barns.get(site.id, "") == "done":
			continue
		var d: float = race.length * site.frac
		var s: Dictionary = race.samples[race.sample_index(d)]
		var node := Node3D.new()
		var wreck := TrackGen.build_derelict("6a4a32")
		node.add_child(wreck)
		var lbl := Label3D.new()
		lbl.text = "?"
		lbl.font_size = 200
		lbl.modulate = Color(1.0, 0.83, 0.0)
		lbl.outline_size = 24
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3.UP * 4.0
		node.add_child(lbl)
		add_child(node)
		node.global_position = s.pos + s.right * (TrackGen.ROAD_HALF + 9.0) + Vector3.UP * 0.2
		barns.append({"node": node, "d": d, "id": site.id, "car": site.car})

func _build_jumps() -> void:
	for f in JUMP_FRACS:
		var d: float = race.length * f
		var s: Dictionary = race.samples[race.sample_index(d)]
		var body := StaticBody3D.new()
		var ramp := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(5.0, 2.2, 9.0)
		ramp.mesh = pm
		ramp.material_override = CarFactory.emissive(Color(1.0, 0.55, 0.1), 0.5)
		ramp.rotation_degrees = Vector3(0, 180, 0)
		ramp.position = Vector3.UP * 1.1
		body.add_child(ramp)
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([
			Vector3(-2.5, 0, -4.5), Vector3(2.5, 0, -4.5), Vector3(-2.5, 0, 4.5), Vector3(2.5, 0, 4.5),
			Vector3(-2.5, 2.2, 4.5), Vector3(2.5, 2.2, 4.5)])
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		body.global_transform = Transform3D(Basis.looking_at(-s.fwd, s.up), s.pos + s.right * 3.2)
		jumps.append({"d": d})

# ---------- per-frame ----------
func _physics_process(delta: float) -> void:
	if race == null or race.player == null or race.state != "racing": return
	var P2 := race.player
	_district_track(delta)
	_discovery(delta)
	_cameras_check(delta)
	_airtime(delta)
	_prompt_check()
	if sub_mode != "":
		_sub_update(delta)
	if Input.is_action_just_pressed("emp") and sub_mode == "" and not near_marker.is_empty():
		_start_event(near_marker.ev)

func _district_track(delta: float) -> void:
	var z := _zone_at(race.player.progress)
	if z != cur_zone:
		cur_zone = z
		race.zone_key = z          # surfaces/wet grip follow the district
		race.set_rain(D.ZONES[z].get("wet", false))
		race.hud.big_message("ENTERING  " + str(D.ZONES[z].name).to_upper())
		SFX.play("checkpoint", -6.0)
		_env_from = _capture_env()
		_env_to = _zone_env(z)
		_env_lerp = 0.001
	if _env_lerp > 0.0:
		_env_lerp = minf(_env_lerp + delta * 0.55, 1.0)
		_apply_env(_env_from, _env_to, _env_lerp)
		if _env_lerp >= 1.0: _env_lerp = 0.0

func _zone_env(zk: String) -> Dictionary:
	var zone: Dictionary = D.ZONES[zk]
	return {"top": zone.sky_top, "hor": zone.sky_hor, "sun": zone.sun, "energy": zone.sun_energy,
		"amb": zone.ambient, "fog": zone.fog, "fogd": zone.fog_density * 0.35}

func _capture_env() -> Dictionary:
	var e := race.world_env.environment
	var sky: ProceduralSkyMaterial = e.sky.sky_material
	return {"top": sky.sky_top_color, "hor": sky.sky_horizon_color, "sun": race.sun.light_color,
		"energy": race.sun.light_energy, "amb": e.ambient_light_energy,
		"fog": e.fog_light_color, "fogd": e.fog_density}

func _apply_env(a: Dictionary, b: Dictionary, t: float) -> void:
	var e := race.world_env.environment
	var sky: ProceduralSkyMaterial = e.sky.sky_material
	sky.sky_top_color = a.top.lerp(b.top, t)
	sky.sky_horizon_color = a.hor.lerp(b.hor, t)
	sky.ground_horizon_color = sky.sky_horizon_color * 0.6
	race.sun.light_color = a.sun.lerp(b.sun, t)
	race.sun.light_energy = lerpf(a.energy, b.energy, t)
	e.ambient_light_energy = lerpf(a.amb, b.amb, t)
	e.fog_light_color = a.fog.lerp(b.fog, t)
	e.fog_density = lerpf(a.fogd, b.fogd, t)

func _discovery(delta: float) -> void:
	_disc_t -= delta
	if _disc_t > 0.0: return
	_disc_t = 0.5
	var n := race.samples.size()
	var idx := race.sample_index(race.player.progress)
	var disc: Dictionary = P.data.roam
	var mask: PackedByteArray = _mask()
	var changed := false
	for k in range(-2, 3):
		var i := ((idx + k) % n + n) % n
		if not (mask[i >> 3] & (1 << (i & 7))):
			mask[i >> 3] |= (1 << (i & 7))
			changed = true
	if changed:
		disc.disc = Marshalls.raw_to_base64(mask)
		disc_pct = discovery_pct()
		_check_district_complete()

var _mask_cache: PackedByteArray = PackedByteArray()
func _mask() -> PackedByteArray:
	var n := race.samples.size()
	var bytes := (n >> 3) + 1
	if _mask_cache.size() != bytes:
		var stored: String = P.data.roam.get("disc", "")
		_mask_cache = Marshalls.base64_to_raw(stored) if stored != "" else PackedByteArray()
		if _mask_cache.size() != bytes:
			_mask_cache = PackedByteArray()
			_mask_cache.resize(bytes)
	return _mask_cache

func discovery_pct() -> int:
	var mask := _mask()
	var n := race.samples.size()
	var c := 0
	for i in n:
		if mask[i >> 3] & (1 << (i & 7)): c += 1
	return int(round(float(c) / n * 100.0))

func _check_district_complete() -> void:
	var mask := _mask()
	for sec in race.sectors:
		var flag: String = "disc_" + str(sec.zone)
		if P.data.roam.flags.get(flag, false): continue
		var all := true
		for i in range(sec.i0, sec.i1 + 1):
			if not (mask[i >> 3] & (1 << (i & 7))):
				all = false
				break
		if all:
			P.data.roam.flags[flag] = true
			P.data.cash += 15000
			race.toast("DISTRICT FULLY DISCOVERED — %s  +$15,000" % D.ZONES[sec.zone].name, "good")
			SFX.play("ui_win", -4.0)
			P.save_game()

func _cameras_check(delta: float) -> void:
	var pd := race.player.progress
	for cam in cameras:
		cam.cd = maxf(cam.cd - delta, 0.0)
		var gap: float = fposmod(pd - cam.d + race.length * 0.5, race.length) - race.length * 0.5
		if cam.cd <= 0.0 and gap > 0.0 and gap < 14.0:
			cam.cd = 25.0
			var v := race.player.kmh()
			var key := "cam_%d" % int(cam.d)
			var best: float = P.data.roam.cams.get(key, 0.0)
			race.hud.flash(false)
			if v > best:
				P.data.roam.cams[key] = v
				race.toast("SPEED CAMERA  %d km/h — NEW RECORD" % int(v), "good")
				race.bounty += v * 2.0
			else:
				race.toast("SPEED CAMERA  %d km/h  (best %d)" % [int(v), int(best)], "")
			if v > 200.0 and race.heat < 10:
				race.heat = clampi(race.heat + 1, 0, 10)
				race.wanted = true
			P.save_game()

func _airtime(delta: float) -> void:
	var air := race.player.airborne and race.player.kmh() > 60.0
	if air:
		_air_t += delta
	elif _was_air and _air_t > 0.45:
		var b := int(_air_t * 400.0)
		race.toast("AIR TIME  %.2fs  +%d" % [_air_t, b], "good")
		race.bounty += b
		race.add_risk(8.0)
		_air_t = 0.0
	elif not air:
		_air_t = 0.0
	_was_air = air

func _prompt_check() -> void:
	near_marker = {}
	if sub_mode != "":
		race.hud.prompt("")
		return
	var pd := race.player.progress
	for m in markers:
		var gap: float = absf(fposmod(pd - m.d + race.length * 0.5, race.length) - race.length * 0.5)
		if gap < 30.0 and race.player.kmh() < 70.0:
			near_marker = m
			var key := "Y" if S.last_device_pad else "E"
			race.hud.prompt("[%s]  START  %s" % [key, m.ev.name])
			return
	# barn claim
	for barn in barns:
		if not is_instance_valid(barn.node): continue
		if race.player.global_position.distance_to(barn.node.global_position) < 14.0:
			_claim_barn(barn)
			return
	race.hud.prompt("")

func _claim_barn(barn: Dictionary) -> void:
	if P.data.roam.barns.get(barn.id, "") != "": return
	P.data.roam.barns[barn.id] = "found"
	P.data.roam.barns[barn.id + "_races"] = 0
	race.hud.big_message("BARN FIND DISCOVERED")
	race.toast("Recovered a derelict %s — finish 3 events to restore it" % D.car_def(barn.car).name, "good")
	SFX.play("ui_win", -4.0)
	barn.node.queue_free()
	P.save_game()

# ---------- seamless embedded events ----------
func _start_event(e: Dictionary) -> void:
	sub_ev = e
	sub_mode = e.mode
	sub_origin = race.player.progress
	sub_len = minf(float(e.get("len", 5.0)) * 700.0, race.length * 0.45)
	sub_t = 0.0
	sub_gate = 0
	sub_drift0 = race.drift_score
	race.hud.prompt("")
	race.hud.big_message(str(e.name).to_upper())
	SFX.play("checkpoint", -2.0)
	match sub_mode:
		"sprint":
			for i in 3:
				var pool := D.CARS.filter(func(c): return c.id != P.data.cur)
				var rc: Dictionary = pool[(i * 5 + hash(e.id)) % pool.size()]
				var rv := AICar.new()
				rv.setup_ai(rc.id, AICar.Role.RIVAL, (0.9 + i * 0.05) * P.diff().ai,
					["ffd400", "3ddc47", "ff6a00"][i])
				rv.race = race
				rv.stats.kmh = minf(rv.stats.kmh, race.player.stats.kmh * 1.05)
				rv.lane = -2.8 if i % 2 == 0 else 2.8
				race.add_child(rv)
				race._place_on_road(rv, fposmod(sub_origin - 18.0 - i * 12.0, race.length), rv.lane)
				race.rivals.append(rv)
				sub_rivals.append(rv)
		"timeattack":
			sub_time = float(e.get("time", 45))
		"speedtrap":
			sub_traps = []
			sub_trap_next = 0
		"escape":
			race.heat = int(e.get("heat", 5))
			race.wanted = true
			race.toast("LOSE THE VCPD TO WIN", "bad")

func _rel_prog() -> float:
	return fposmod(race.player.progress - sub_origin, race.length)

func _sub_update(delta: float) -> void:
	sub_t += delta
	var rel := _rel_prog()
	match sub_mode:
		"sprint":
			if rel >= sub_len:
				var pos := 1
				for rv in sub_rivals:
					if is_instance_valid(rv) and not rv.dead \
							and fposmod(rv.progress - sub_origin, race.length) > rel:
						pos += 1
				_finish(pos == 1, "Finished %s" % Roam.ordinal2(pos))
			else:
				for rv in sub_rivals:
					if is_instance_valid(rv) and not rv.dead \
							and fposmod(rv.progress - sub_origin, race.length) >= sub_len:
						_finish(false, "A rival beat you to the line")
						return
		"timeattack":
			sub_time -= delta
			var gate_len := sub_len / 5.0
			if rel >= (sub_gate + 1) * gate_len and sub_gate < 4:
				sub_gate += 1
				sub_time += float(sub_ev.get("gate_bonus", 7.0))
				race.toast("CHECKPOINT +%.0fs" % float(sub_ev.get("gate_bonus", 7.0)), "good")
				SFX.play("checkpoint", -4.0)
			if sub_time <= 0.0:
				_finish(false, "The clock ran out")
			elif rel >= sub_len:
				_finish(true, "Beat the clock with %.1fs spare" % sub_time)
		"speedtrap":
			var fracs := [0.15, 0.35, 0.55, 0.75, 0.92]
			if sub_trap_next < 5 and rel >= sub_len * fracs[sub_trap_next]:
				sub_traps.append(race.player.kmh())
				sub_trap_next += 1
				race.hud.flash(false)
				race.toast("CAMERA %d:  %d km/h" % [sub_trap_next, int(race.player.kmh())], "good")
			if rel >= sub_len:
				var total := 0.0
				for v in sub_traps: total += v
				var target := float(sub_ev.get("target", 1100)) * 0.85
				_finish(total >= target, "Total %d / %d km/h" % [int(total), int(target)])
		"drift":
			if rel >= sub_len:
				var gained := race.drift_score - sub_drift0
				var target := int(sub_ev.get("target", 30000) * 0.6)
				_finish(gained >= target, "Drift %s / %s" % [str(gained), str(target)])
		"escape":
			if not race.wanted or race.heat <= 0:
				_finish(true, "You vanished into the county")

func on_escape_banked() -> void:
	if sub_mode == "escape":
		_finish(true, "Escaped clean — bounty banked")

func _finish(win: bool, detail: String) -> void:
	var e := sub_ev
	var first: bool = not P.data.wins.has(e.id)
	var payout := 0
	var rep := 0
	if win:
		payout = int(round(e.get("cash", 0) * P.diff().cash * (1.0 if first else 0.3)))
		rep = int(round(e.get("rep", 0) * (1.0 if first else 0.35)))
		P.data.wins[e.id] = true
		P.data.medals[e.id] = "gold" if first else P.data.medals.get(e.id, "silver")
		P.data.rep += rep
		P.data.stats.wins += 1
		race.hud.big_message("VICTORY  +$%d" % payout)
		SFX.play("ui_win", -2.0)
	else:
		payout = int(round(e.get("cash", 0) * 0.08))
		rep = int(round(e.get("rep", 0) * 0.08))
		P.data.rep += rep
		race.hud.big_message("DEFEATED")
		SFX.play("ui_lose", -4.0)
	race.toast(detail, "good" if win else "bad")
	P.data.cash += payout
	P.data.stats.races += 1
	for cid in P.barn_tick():
		race.toast("BARN FIND RESTORED — %s added to your garage!" % D.car_def(cid).name, "good")
		SFX.play("ui_win", -3.0)
	P.check_secrets()
	P.save_game()
	# clean up and hand the road back
	for rv in sub_rivals:
		if is_instance_valid(rv):
			race.rivals.erase(rv)
			rv.queue_free()
	sub_rivals.clear()
	if sub_mode != "escape":
		pass
	sub_mode = ""
	sub_ev = {}

static func ordinal2(n: int) -> String:
	return "1ST" if n == 1 else "2ND" if n == 2 else "3RD" if n == 3 else str(n) + "TH"
