# ============================================================
# CHICANE 3D — race.gd
# RaceManager: builds the world, runs modes, police heat,
# weapons, scoring, destruction events, results.
# ============================================================
class_name RaceManager
extends Node3D

signal finished(summary: Dictionary)

# --- config ---
var ev: Dictionary
var career := "racer"            # "racer" | "cop"
var mode := "sprint"
var zone_key := "neon"
var laps := 1

# --- track ---
var samples: Array = []
var length := 0.0
var finish_d := 0.0

# --- entities ---
var player: PlayerCar
var rivals: Array = []
var cops: Array = []
var target: AICar = null
var traffic: Array = []
var hazards: Node3D
var heli: Node3D

# --- state ---
var state := "countdown"          # countdown | racing | done
var cd_t := 3.9
var t := 0.0
var heat := 0
var wanted := false
var bounty := 0.0
var risk := 0.0
var escape := 0.0
var busted := 0.0
# v9.10 — first time the cops pin you, you get a warning instead of an
# instant impound; escape before it expires or get caught again and lose.
const IMPOUND_WARNING := 180.0
var impound_t := 0.0
# easy-mode panic button: [Y] nukes every police unit
var cd_nuke := 0.0
var nukes_fired := 0
# easy-mode [G] god toggle: while on, whatever touches the player explodes
var god_kills := 0
var drift_score := 0
var drift_combo := 1.0
var best_speed := 0.0
var lap := 1
var elim_t := 20.0
var time_left := 0.0
var esc_t := 0.0
var result := ""
var summary := {}
var slowmo_t := 0.0
var slowmo_cd := 0.0
# player death: RIP message + respawn countdown (seconds, Normal difficulty)
const RIP_RESPAWN := 5.0
var rip_t := 0.0
var rip_total := RIP_RESPAWN
var rips := 0
var cop_spawn_t := 6.0
var spike_trap_t := 9.0
var block_t := 16.0
var emp_lock := -1.0
var emp_lock_x := 0.0
var emp_t := 7.0
var cam_t := 9.0
var near_miss_flags := {}

# --- NFS-HP skill trackers ---
var slip_t := 0.0
var slip_mile := 0.0
var slip_active := false
var oncoming_m := 0.0
var oncoming_mile := 0.0
var oncoming_active := false
var drift_m := 0.0
var drift_mile := 0.0
var prev_pos := 0
var pos_announce := ""
var pos_announce_t := 0.0
var crash_escape_t := 0.0
var chev_t := 0.0
var _chev_marked := {}

# --- v3 systems ---
var skids: SkidMarks
var director: PoliceDirector
var line_offset: PackedFloat32Array = PackedFloat32Array()
var line_speed: PackedFloat32Array = PackedFloat32Array()
var is_loop := false
var wrong_way := false
var _wrong_way_t := 0.0
var drift_bank := 0
var lap_start_t := 0.0
var last_lap := 0.0
var best_lap := 0.0
var trap_speeds: Array = []       # speedtrap mode
var trap_next := 0
var ta_time := 0.0                # timeattack countdown
var _cp_flags: Array = []         # circuit checkpoints hit this lap

# --- v4 open world ---
var world_env: WorldEnvironment = null
var sun: DirectionalLight3D = null
var sectors: Array = []           # district sectors of Velocity County
var roam: Node = null             # free-roam manager (mode == "roam")

# --- v5 weather ---
var rain: GPUParticles3D = null

func set_rain(on: bool) -> void:
	if not bool(S.g("rain_fx")): on = false
	if on and rain == null:
		rain = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.DOWN
		pm.spread = 3.0
		pm.initial_velocity_min = 16.0
		pm.initial_velocity_max = 22.0
		pm.gravity = Vector3(0, -9.0, 0)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(26.0, 1.0, 26.0)
		rain.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.02, 0.46)
		var qm := StandardMaterial3D.new()
		qm.albedo_color = Color(0.65, 0.72, 0.85, 0.34)
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = qm
		rain.draw_pass_1 = quad
		rain.amount = int(420 * S.particle_scale())
		rain.lifetime = 1.4
		rain.preprocess = 1.0
		add_child(rain)
	elif not on and rain != null:
		rain.queue_free()
		rain = null

func sample_index(d: float) -> int:
	if is_loop:
		d = fposmod(d, maxf(length, 1.0))
	return clampi(int(d / TrackGen.SAMPLE), 0, samples.size() - 1)

# --- weapons ---
var w_emp := 2
var w_turbo := 3
var w_spike := 0
var w_block := 0
var cd_emp := 0.0
var cd_turbo := 0.0
var cd_spike := 0.0
var cd_block := 0.0
# missiles are unlimited — cooldown only
var cd_missile := 0.0
# warp speed: 10s at 3x velocity, then a recharge
var cd_warp := 0.0
var missiles_fired := 0
var respawns_done := 0
# blown-up cars come back after this long
const RESPAWN_DELAY := 10.0
var respawn_queue: Array = []

var hud: Node = null
var weapons: Node = null
var destructibles: Node = null
var buildings_destroyed := 0

func start(event: Dictionary, in_career: String) -> void:
	ev = event
	career = in_career
	zone_key = ev.zone
	mode = "intercept" if career == "cop" else ev.mode
	laps = ev.get("laps", 1)
	heat = ev.get("heat", 0)
	wanted = heat > 0
	if career == "cop":
		w_emp = 99; w_turbo = 99; w_spike = 6; w_block = 3
		time_left = float(ev.time)

	var seed_v: int = hash(ev.id)
	var km: float = ev.get("len", 6.0)
	if career == "cop": km = 14.0
	if mode == "free": km = 28.0   # v8: bigger district free-drive maps
	var track: Dictionary
	if mode == "roam":
		# VELOCITY COUNTY — one connected seeded world through every district
		track = TrackGen.generate_world(P.world_seed())
		is_loop = true
		sectors = track.sectors
	elif mode == "circuit":
		# genuine closed loop with laps and checkpoints
		track = TrackGen.generate_loop(zone_key, km, seed_v)
		is_loop = true
	else:
		track = TrackGen.generate(zone_key, km, seed_v,
			{"straight": mode == "drag", "curviness": 0.3 if mode == "topspeed" else -1.0}
			if mode in ["drag", "topspeed"] else {})
	samples = track.samples
	length = track.length
	finish_d = length - 40.0
	add_child(track.root)
	if mode != "roam":
		# v8: horizon ground so you never see the void past the roadside
		var hp := PlaneMesh.new()
		hp.size = Vector2(30000, 30000)
		var hm := StandardMaterial3D.new()
		var gcol: Color = D.ZONES[zone_key].get("ground", Color(0.14, 0.16, 0.13))
		hm.albedo_color = gcol * 0.75
		hm.roughness = 1.0
		hp.material = hm
		var hmi := MeshInstance3D.new()
		hmi.mesh = hp
		hmi.position = Vector3(0, -4.0, 0)
		add_child(hmi)
	# precomputed racing line shared by every AI driver
	var rl := RacingLine.build(samples, is_loop)
	line_offset = rl.offset
	line_speed = rl.speed
	skids = SkidMarks.new()
	add_child(skids)
	director = PoliceDirector.new()
	director.setup(self)
	add_child(director)
	# v9.8 — shootable roadside buildings
	destructibles = load("res://scripts/destructibles.gd").new()
	add_child(destructibles)
	destructibles.setup(self)
	if is_loop:
		_cp_flags = [false, false, false]
		lap_start_t = 0.0
	if mode == "timeattack":
		ta_time = float(ev.get("time", 60))
	if mode == "speedtrap":
		trap_speeds = []
		trap_next = 0
	_environment()
	set_rain(D.ZONES[zone_key].get("wet", false))
	_spawn_everyone()
	hazards = Node3D.new(); hazards.name = "Hazards"; add_child(hazards)
	hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	hud.bind(self)
	toast("Hit [Q] to bring up your weapon inventory", "")
	if P.data.diff == "easy" and career != "cop":
		hud.flash_hint("PRESS [G] FOR GOD MODE", 6.0)
	SFX.set_station(P.data.station)
	if mode == "roam":
		roam = load("res://scripts/roam.gd").new()
		add_child(roam)
		roam.setup(self)
	weapons = load("res://scripts/weapons.gd").new()
	add_child(weapons)
	weapons.setup(self)
	if mode in ["free", "roam"]:
		state = "racing"
		cd_t = 0.0

func _environment() -> void:
	var zone: Dictionary = D.ZONES[zone_key]
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# lift zone skies toward clean daylight tones (keeps each zone's hue)
	sm.sky_top_color = zone.sky_top.lerp(Color(0.45, 0.55, 0.72), 0.3)
	sm.sky_horizon_color = zone.sky_hor.lerp(Color(0.75, 0.8, 0.88), 0.3)
	sm.ground_bottom_color = zone.ground * 0.55
	sm.ground_horizon_color = (zone.sky_hor * 0.6).lerp(Color(0.6, 0.65, 0.7), 0.3)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.12          # visible sun disc with soft falloff
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# v9.11: third pass — lighter and CLEARER. Higher ambient floor and
	# exposure again, plus the sky itself is lifted toward daylight tones
	# so colours read clean instead of murky. Brightness slider stacks.
	var bright: float = clampf(float(S.g("brightness")), 0.6, 1.6)
	env.ambient_light_energy = clampf(zone.ambient * 2.6 + 0.55, 0.85, 2.8) * bright
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5 * bright
	env.glow_enabled = S.glow_enabled()
	env.glow_intensity = 0.3
	env.glow_bloom = 0.03
	env.ssao_enabled = S.ssao_enabled()
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][S.msaa()] as Viewport.MSAA
	env.fog_enabled = true
	env.fog_light_color = zone.fog.lerp(Color(0.7, 0.75, 0.8), 0.3)
	env.fog_density = zone.fog_density * 0.15   # v9.11: much clearer air
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.light_color = zone.sun.lerp(Color(1.0, 0.97, 0.9), 0.25)
	sun.light_energy = zone.sun_energy * 1.9 + 0.4
	sun.shadow_enabled = S.shadows_enabled()
	sun.rotation_degrees = Vector3(-18.0 if zone.night else -38.0, 40, 0)
	add_child(sun)

func _spawn_everyone() -> void:
	var diff := P.diff()
	# player
	player = PlayerCar.new()
	var pid: String = P.data.cop_cur if career == "cop" else P.data.cur
	player.setup_player(pid, P.car_cfg(pid), career == "cop")
	player.race = self
	add_child(player)
	_place_on_road(player, 30.0, -2.2 if mode == "drag" else 2.2)
	player.impact.connect(_on_player_impact)

	# rivals / boss / target
	var colors := ["ffd400", "3ddc47", "ff6a00", "7b4dff", "00e5d0", "ff3dbf"]
	if mode == "boss":
		var b: Dictionary = D.BOSSES[ev.boss]
		var boss := AICar.new()
		boss.setup_ai(b.car, AICar.Role.RIVAL, b.skill * diff.ai, b.color)
		boss.race = self
		boss.set_meta("boss", true)
		add_child(boss)
		_place_on_road(boss, 30.0, -2.2)
		rivals.append(boss)
	elif mode == "duel":
		var duel_car: String = ev.get("rival", "saber")
		var rival := AICar.new()
		rival.setup_ai(duel_car, AICar.Role.RIVAL, float(ev.get("skill", 1.0)) * diff.ai, "ffd400")
		rival.race = self
		add_child(rival)
		_place_on_road(rival, 30.0, -2.2)
		rivals.append(rival)
	elif mode == "intercept":
		target = AICar.new()
		target.setup_ai(ev.target, AICar.Role.TARGET, ev.skill * diff.ai, "e8192c")
		target.race = self
		add_child(target)
		_place_on_road(target, 110.0, 0.0)
		rivals.append(target)
	else:
		var n: int = ev.get("rivals", 0)
		var pool := D.CARS.filter(func(c): return c.price <= D.car_def(P.data.cur).price * 1.6 + 80000 and c.id != P.data.cur)
		if pool.is_empty(): pool = D.CARS.slice(0, 6)
		for i in n:
			var rc: Dictionary = pool[(i * 3 + hash(ev.id)) % pool.size()]
			var r := AICar.new()
			r.setup_ai(rc.id, AICar.Role.RIVAL, (0.90 + float(i) / maxf(n, 1) * 0.09) * diff.ai, colors[i % colors.size()])
			r.race = self
			r.stats.kmh = minf(r.stats.kmh, player.stats.kmh * 1.05)
			r.lane = -2.8 if i % 2 == 0 else 2.8
			add_child(r)
			# proper two-column starting grid with real gaps
			var grid_d := 30.0 - float(i / 2 + 1) * 16.0
			if is_loop and grid_d < 4.0:
				grid_d = length + grid_d          # wrap behind the start line
			_place_on_road(r, grid_d, r.lane)
			rivals.append(r)

	# traffic
	var want := _traffic_count()
	for i in want:
		var tc := TrafficCar.new()
		add_child(tc)
		tc.setup_traffic(self, 200.0 + i * 130.0, [-5.2, -2.2, 2.2, 5.2][i % 4],
			(i % 4) == 0 and allows_oncoming())
		traffic.append(tc)

func _traffic_count() -> int:
	var base := 8
	if mode in ["drag", "drift", "topspeed", "boss", "timeattack", "speedtrap", "duel"]:
		base = 3 if mode in ["boss", "duel"] else 0
	elif mode == "intercept": base = 4
	elif ev.get("tier", 3) <= 2: base = 4
	return int(round(base * float(S.g("traffic"))))

func allows_oncoming() -> bool:
	return zone_key in ["neon", "mountain", "coastal"] and mode != "intercept"

func _place_on_road(car: Node3D, d: float, x: float) -> void:
	var idx := clampi(int(d / TrackGen.SAMPLE), 0, samples.size() - 1)
	var s: Dictionary = samples[idx]
	car.global_transform = Transform3D(Basis.looking_at(s.fwd, s.up), s.pos + s.right * x + Vector3.UP * 1.0)
	if car is VehicleBase and "track_idx" in car:
		car.track_idx = idx

func all_vehicles() -> Array:
	var arr: Array = []
	arr.append_array(rivals.filter(func(r): return is_instance_valid(r) and not r.dead))
	arr.append_array(cops.filter(func(c): return is_instance_valid(c) and not c.dead))
	arr.append_array(traffic.filter(func(tc): return is_instance_valid(tc)))
	return arr

# ============ MAIN LOOP ============
func _physics_process(delta: float) -> void:
	if state == "done": return
	slowmo_cd = maxf(slowmo_cd - delta / maxf(Engine.time_scale, 0.05), 0.0)
	if slowmo_t > 0.0:
		slowmo_t -= delta / maxf(Engine.time_scale, 0.05)
		if slowmo_t <= 0.0:
			Engine.time_scale = 1.0
			hud.letterbox(false)
	t += delta
	if state == "countdown":
		player.controls_enabled = false
		cd_t -= delta
		hud.countdown(cd_t)
		if cd_t <= 0.0:
			state = "racing"
			player.controls_enabled = true
			SFX.play("checkpoint", -4.0)
		return
	if rip_t > 0.0:
		rip_t -= delta / maxf(Engine.time_scale, 0.05)
		if rip_t <= rip_total - 1.6 and Engine.time_scale < 1.0:
			Engine.time_scale = 1.0     # slow-mo only for the death beat
			hud.letterbox(false)
		hud.respawn_count(rip_t)
		if rip_t <= 0.0:
			_respawn_player()
		return

	best_speed = maxf(best_speed, player.kmh())
	risk = maxf(risk - delta * 2.2, 0.0)
	if rain != null and player != null:
		rain.global_position = player.global_position + player.linear_velocity * 0.55 + Vector3.UP * 11.0
	_weapons_input(delta)
	_respawns(delta)
	_police(delta)
	_impound(delta)
	_near_miss_check()
	_skills(delta)
	_mode_logic(delta)
	if player.hp <= 0.0 and not player.wrecked:
		_start_wreck()
	if is_loop and mode != "roam":
		_update_laps()
	if mode != "roam":
		_wrong_way_check(delta)

# ============ IMPACTS / DESTRUCTION ============
func _on_player_impact(severity: float, world_pos: Vector3, other: Node) -> void:
	if state != "racing": return
	if other is StaticBody3D and other.has_meta("chevron"):
		smash_chevron(other)          # breakable — bounty, zero damage
		return
	# god mode: anything that touches the player explodes
	if bool(S.g("god_mode")):
		if other is AICar and not other.wrecked:
			destroy_vehicle(other, world_pos)
			_blast_visual(world_pos)
			god_kills += 1
			return
		elif other is TrafficCar and not other.hit_free:
			destroy_vehicle(other, world_pos)
			_blast_visual(world_pos)
			god_kills += 1
			return
		elif other is StaticBody3D and other.has_meta("destructible") and destructibles:
			destructibles.destroy(other, player.global_position)
			god_kills += 1
			return
	var dir := (player.global_position - world_pos).normalized()
	if dir.length() < 0.5: dir = global_transform.basis.z
	var dmg_scale: float = P.diff().dmg
	if other is StaticBody3D and other.has_meta("roadblock"):
		dmg_scale *= 1.6
		bounty += 350.0
		toast("ROADBLOCK IMPACT!", "bad")
	var dealt := player.take_impact(world_pos, -dir, severity, dmg_scale)
	if severity > 6.0:
		SFX.crash(severity > 16.0)
		hud.flash(severity > 16.0)
		if player.chase: player.chase.shake(clampf(severity * 0.5, 2.0, 10.0))
		S.vibrate(clampf(severity / 30.0, 0.1, 0.8), clampf(severity / 22.0, 0.1, 1.0), 0.3)
	# a hard hit breaks the drift chain
	if player.drifting and severity > 8.0 and drift_bank > 150:
		drift_bank = 0
		drift_combo = 1.0
		toast("DRIFT LOST", "bad")
	if severity > 15.0 and slowmo_cd <= 0.0:
		_slowmo(0.9)
	if severity > 14.0 and player.hp > 0.0:
		crash_escape_t = 1.6
	if other is TrafficCar and dealt > 3.0:
		toast("Traffic collision!", "bad")

func on_traffic_hit(tc: Node, body: Node, rel: float) -> void:
	if body == player:
		bounty += 60.0
	elif body in rivals:
		pass  # rivals barrel through traffic — it slows them naturally via physics

func on_ai_impact(ai: AICar, body: Node, rel: float) -> void:
	if ai.role == AICar.Role.TARGET and body == player:
		var bonus: float = rel * 1.15 * (1.0 + player.stats.str * 0.04)
		ai.hp = maxf(ai.hp - bonus, 0.0)
		toast("RAM! Suspect at %d%%" % int(ai.hp), "good")
		SFX.crash(rel > 14.0)
	elif ai.role == AICar.Role.COP and body == player:
		bounty += 200.0
	elif ai.role == AICar.Role.RIVAL and body == player and rel > 8.0:
		bounty += 25.0
		toast("SHUNT +25", "good")

func on_ai_wrecked(ai: AICar) -> void:
	if ai.role == AICar.Role.COP:
		bounty += 800.0
		P.data.stats.takedowns += 1
		toast("POLICE TAKEDOWN! +$800 bounty", "good")
		SFX.crash(true)
	elif ai.role == AICar.Role.TARGET:
		pass  # arrest handled in mode logic

func _slowmo(dur: float) -> void:
	Engine.time_scale = 0.32
	slowmo_t = dur
	slowmo_cd = 9.0
	hud.letterbox(true)

# v9.7 — death is a setback, not a race-ender: RIP + respawn countdown
# (5s on Normal; difficulty shortens or stretches it)
func _start_wreck() -> void:
	player.wreck()
	player.controls_enabled = false
	Engine.time_scale = 0.35
	rip_total = float(P.diff().get("rip", RIP_RESPAWN))
	rip_t = rip_total
	rips += 1
	hud.letterbox(true)
	hud.big_message("RIP!")
	SFX.crash(true)

func _respawn_player() -> void:
	rip_t = 0.0
	Engine.time_scale = 1.0
	hud.letterbox(false)
	hud.respawn_count(0.0)
	player.hp = 100.0
	player.wrecked = false
	player.stun_t = 0.0
	player.spike_t = 0.0
	player.brake = 0.0
	player.nitro = maxf(player.nitro, 0.5)
	player.rebuild_visual()
	player.reset_to_track()
	player.controls_enabled = true
	toast("Respawned — go get 'em!", "good")
	SFX.play("checkpoint", -4.0)

# ============ WEAPONS ============
func _weapons_input(delta: float) -> void:
	cd_emp = maxf(cd_emp - delta, 0.0)
	cd_turbo = maxf(cd_turbo - delta, 0.0)
	cd_spike = maxf(cd_spike - delta, 0.0)
	cd_block = maxf(cd_block - delta, 0.0)
	cd_missile = maxf(cd_missile - delta, 0.0)
	cd_warp = maxf(cd_warp - delta, 0.0)
	cd_nuke = maxf(cd_nuke - delta, 0.0)
	# [Q] weapon inventory — available even while stunned/spun out
	if Input.is_action_just_pressed("inv") and hud:
		hud.toggle_inventory()
	if Input.is_action_just_pressed("nuke"): _fire_nuke()
	if Input.is_action_just_pressed("god"): _toggle_god()
	if not player.controls_enabled: return
	if Input.is_action_just_pressed("warp") and cd_warp <= 0.0:
		cd_warp = 25.0 * float(P.diff().get("wpncd", 1.0))
		player.start_warp(10.0)
		toast("WARP SPEED — 3× VELOCITY!", "good")
		SFX.play("turbo_loop", -6.0)
		if player.chase: player.chase.shake(4.0)
	# in roam, E near a marker starts the event instead of firing the EMP
	var emp_blocked: bool = roam != null and not roam.near_marker.is_empty()
	if Input.is_action_just_pressed("emp") and not emp_blocked: _fire_emp()
	if weapons: weapons.update(delta)   # the pick-3 loadout (wpn1/2/3)
	if Input.is_action_just_pressed("turbo") and w_turbo > 0 and cd_turbo <= 0.0:
		w_turbo -= 1; cd_turbo = 7.0
		player.use_turbo()
		toast("TURBO!", "good")
	if Input.is_action_just_pressed("spike") and career == "cop" and w_spike > 0 and cd_spike <= 0.0:
		w_spike -= 1; cd_spike = 4.0
		_drop_spikes(player.progress - 6.0, player.lateral, true)
		toast("Spike strip deployed", "good")
	if Input.is_action_just_pressed("block") and career == "cop" and w_block > 0 and cd_block <= 0.0 and target:
		w_block -= 1; cd_block = 18.0
		_spawn_roadblock(target.progress + 260.0, 3)
		toast("Roadblock inbound ahead of suspect", "good")

func _fire_emp() -> void:
	if w_emp <= 0 or cd_emp > 0.0: return
	cd_emp = 6.0
	SFX.play("emp", -4.0)
	var best: VehicleBase = null
	var best_d := 1e9
	for v in rivals + cops:
		if not is_instance_valid(v) or v.dead or v.wrecked: continue
		var gap: float = v.progress - player.progress
		if gap > -8.0 and gap < 70.0 and absf(v.lateral - player.lateral) < 7.0:
			if absf(gap) < best_d: best_d = absf(gap); best = v
	if best:
		w_emp -= 1
		best.stun(2.2)
		best.linear_velocity *= 0.5
		if best == target:
			target.hp = maxf(target.hp - 32.0, 0.0)
			toast("EMP HIT — suspect systems down!", "good")
		elif best in cops:
			best.hp = maxf(best.hp - 30.0, 0.0)
			bounty += 400.0
			toast("EMP HIT!", "good")
			if best.hp <= 0.0: best.wreck(); on_ai_wrecked(best)
		else:
			toast("EMP HIT!", "good")
	else:
		toast("EMP missed — no target in range", "warn")

# ============ IMPOUND WARNING ============
func _trigger_impound_warning() -> void:
	busted = 0.0
	impound_t = IMPOUND_WARNING
	player.stun(1.2)                      # they slap a boot warning on you
	hud.big_message("IMPOUND WARNING!")
	toast("3 MINUTES to lose the VCPD or your car is impounded!", "bad")
	SFX.play("siren_loop", -6.0)

func _impound(delta: float) -> void:
	if impound_t <= 0.0: return
	impound_t -= delta
	if not wanted or heat <= 0:
		impound_t = 0.0
		toast("Impound warning cleared — they lost the paperwork", "good")
		return
	if impound_t <= 0.0:
		_end("busted")

# ============ NUKE THE POLICE (easy mode only) ============
func _fire_nuke() -> void:
	if career == "cop": return
	if P.data.diff != "easy":
		toast("NUKE is EASY-level equipment only", "warn")
		return
	if cd_nuke > 0.0: return
	cd_nuke = 45.0
	nukes_fired += 1
	hud.flash(true)
	SFX.crash(true)
	var n := 0
	for c in cops.duplicate():
		if is_instance_valid(c) and not c.wrecked and not c.dead:
			missile_blast(c.global_position)
			n += 1
	busted = 0.0
	impound_t = 0.0
	player.reset_to_track()               # back to the middle of the road
	hud.big_message("NUKED THE POLICE!")
	toast("POLICE NUKED — %d unit%s vaporised!" % [n, "" if n == 1 else "s"], "good")
	if player.chase: player.chase.shake(12.0)

# ============ GOD MODE TOGGLE (easy mode, [G]) ============
func _toggle_god() -> void:
	if P.data.diff != "easy":
		toast("GOD MODE hotkey is EASY-level only (see Settings)", "warn")
		return
	var on: bool = not bool(S.g("god_mode"))
	S.set_s("god_mode", on)
	if on:
		# straight path to the finish: back to the middle of the road,
		# facing the right way — then nothing can touch you
		player.reset_to_track()
		hud.big_message("GOD MODE ON")
		toast("Untouchable — anything that touches you EXPLODES", "good")
		SFX.play("emp", -4.0)
	else:
		hud.big_message("GOD MODE OFF")
		toast("Back to mortal driving", "warn")

# ============ MISSILES (unlimited) ============
func _fire_missile() -> void:
	if cd_missile > 0.0: return
	cd_missile = 0.9
	missiles_fired += 1
	# lock the nearest live car ahead (rivals, cops, suspects, traffic)
	var best: Node3D = null
	var best_gap := 1e9
	for v in all_vehicles():
		if not is_instance_valid(v): continue
		if v is VehicleBase and v.wrecked: continue
		if v is TrafficCar and v.hit_free: continue
		var gap: float = v.progress - player.progress
		if is_loop:
			gap = fposmod(gap + length * 0.5, length) - length * 0.5
		if gap > -12.0 and gap < 220.0 and absf(v.lateral - player.lateral) < 15.0:
			if absf(gap) < best_gap:
				best_gap = absf(gap)
				best = v
	var m: Node3D = load("res://scripts/missile.gd").new()
	add_child(m)
	m.global_transform = player.global_transform
	m.global_position += -player.global_transform.basis.z * 2.6 + Vector3.UP * 0.8
	m.setup(self, player, best)
	SFX.play("blowoff", -6.0)

func missile_blast(pos: Vector3) -> void:
	SFX.crash(true)
	if player and is_instance_valid(player) and player.chase:
		player.chase.shake(8.0)
	for v in all_vehicles():
		if not is_instance_valid(v) or v == player: continue
		if v.global_position.distance_to(pos) < 8.0:
			destroy_vehicle(v, pos)
	if destructibles:
		for b in destructibles.query_radius(pos, 9.0):
			destructibles.destroy(b, pos)
	_blast_visual(pos)

# One-shot destruction used by every weapon — routes through the wreck +
# 10s-respawn pipeline regardless of what did the killing.
func destroy_vehicle(v: Node3D, pos: Vector3) -> void:
	var dir: Vector3 = v.global_position - pos + Vector3.UP * 1.5
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.UP
	var respawn_t := float(P.diff().get("enemy_respawn", RESPAWN_DELAY))
	if v is TrafficCar:
		if v.hit_free: return
		v.blow_up(pos)
		bounty += 60.0
		respawn_queue.append({"kind": "traffic", "t": respawn_t})
	elif v is AICar and not v.wrecked:
		v.take_impact(pos, dir, 40.0, 2.0)      # crumple, shed panels, kill lights
		v.hp = 0.0
		v.wreck()
		v.apply_central_impulse(dir * v.mass * 7.0 + Vector3.UP * v.mass * 5.0)
		v.angular_velocity += Vector3(randf_range(-3, 3), randf_range(-6, 6), randf_range(-3, 3))
		on_ai_wrecked(v)
		if v.role == AICar.Role.RIVAL and not v.has_meta("boss"):
			toast("RIVAL DESTROYED!", "good")
		# the intercept TARGET stays down — wrecking it is the arrest condition
		if v != target:
			respawn_queue.append({"kind": "ai", "node": v, "id": v.car_id, "role": v.role,
				"skill": v.skill, "paint": v.paint_col, "police": v.is_police,
				"cop_role": v.cop_role, "lane": v.lane, "d": v.progress,
				"boss": v.has_meta("boss"), "t": respawn_t})

func _respawns(delta: float) -> void:
	for i in range(respawn_queue.size() - 1, -1, -1):
		var e: Dictionary = respawn_queue[i]
		e.t -= delta
		if e.t > 0.0: continue
		respawn_queue.remove_at(i)
		if e.kind == "traffic":
			var tc := TrafficCar.new()
			add_child(tc)
			tc.setup_traffic(self, player.progress + randf_range(200.0, 500.0),
				[-5.2, -2.2, 2.2, 5.2][randi() % 4], false)
			traffic.append(tc)
		else:
			_respawn_ai(e)
		respawns_done += 1

func _respawn_ai(e: Dictionary) -> void:
	# the burning husk lingers for the delay, then the fresh car takes its place
	var old = e.node
	var idx := -1
	if is_instance_valid(old):
		idx = rivals.find(old)
		rivals.erase(old)
		cops.erase(old)
		old.queue_free()
	var car := AICar.new()
	car.setup_ai(e.id, e.role, e.skill, e.paint, e.police)
	car.race = self
	car.cop_role = e.cop_role
	if e.boss: car.set_meta("boss", true)
	add_child(car)
	var d: float
	if e.role == AICar.Role.COP:
		d = maxf(player.progress - randf_range(90.0, 160.0), 4.0)
		cops.append(car)
	else:
		d = e.d
		if is_loop: d = fposmod(d, maxf(length, 1.0))
		d = clampf(d, 4.0, length - 10.0)
		car.lane = e.lane
		if idx >= 0: rivals.insert(clampi(idx, 0, rivals.size()), car)
		else: rivals.append(car)
	_place_on_road(car, d, clampf(e.lane, -3.0, 3.0))
	car.linear_velocity = -car.global_transform.basis.z * 18.0

func _blast_visual(pos: Vector3) -> void:
	var boom := Node3D.new()
	add_child(boom)
	boom.global_position = pos
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.12, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	boom.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.15)
	light.omni_range = 18.0
	light.light_energy = 6.0
	boom.add_child(light)
	var tw := boom.create_tween().set_parallel(true)
	tw.tween_property(boom, "scale", Vector3.ONE * 6.5, 0.45).from(Vector3.ONE * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.tween_property(light, "light_energy", 0.0, 0.45)
	tw.chain().tween_callback(boom.queue_free)

func _drop_spikes(d: float, x: float, mine: bool) -> void:
	var strip := Area3D.new()
	strip.set_meta("mine", mine)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(5.0, 0.6, 1.0)
	cs.shape = bs
	strip.add_child(cs)
	var vis := MeshInstance3D.new()
	var vb := BoxMesh.new(); vb.size = Vector3(5.0, 0.12, 0.8)
	vis.mesh = vb
	vis.material_override = CarFactory.emissive(Color(1, 0.3, 0.3), 1.2)
	strip.add_child(vis)
	var idx := clampi(int(d / TrackGen.SAMPLE), 0, samples.size() - 1)
	var s: Dictionary = samples[idx]
	add_child(strip)
	strip.global_transform = Transform3D(Basis.looking_at(s.fwd, s.up), s.pos + s.right * clampf(x, -6.0, 6.0) + Vector3.UP * 0.3)
	strip.body_entered.connect(func(body):
		if body is VehicleBase and is_instance_valid(strip):
			var is_mine: bool = strip.get_meta("mine")
			if body == player and not is_mine:
				var res: float = player.stats.get("spkres", 0.0)
				if res >= 3.5:
					toast("Run-flats shrugged off the spikes", "good")
				else:
					player.spike()
					player.take_impact(player.global_position, Vector3.UP, 10.0 * (1.0 - res * 0.15), P.diff().dmg)
					toast("SPIKED! Tyres shredded", "bad")
					SFX.crash(false)
				strip.queue_free()
			elif body != player and is_mine:
				body.spike()
				if body == target:
					target.hp = maxf(target.hp - 30.0, 0.0)
					toast("Suspect hit spikes!", "good")
				strip.queue_free())
	get_tree().create_timer(30.0).timeout.connect(func(): if is_instance_valid(strip): strip.queue_free())

func _spawn_roadblock(d: float, count: int) -> void:
	var idx := clampi(int(d / TrackGen.SAMPLE), 0, samples.size() - 1)
	var s: Dictionary = samples[idx]
	var gap_lane := randi_range(0, 2)
	var lanes := [-4.5, 0.0, 4.5]
	for i in 3:
		if i == gap_lane and count < 5: continue
		var block := StaticBody3D.new()
		block.set_meta("roadblock", true)
		var vis := CarFactory.build_visual("f2f2f2", "gloss", {"len":4.7,"wid":2.0,"nose":0.9,"tail":0.7,"wing":0.3}, true)
		block.add_child(vis)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = Vector3(2.0, 1.2, 4.6)
		cs.shape = bs; cs.position.y = 0.6
		block.add_child(cs)
		hazards.add_child(block)
		var side_basis := Basis.looking_at(s.right, s.up)   # parked sideways
		block.global_transform = Transform3D(side_basis, s.pos + s.right * lanes[i] + Vector3.UP * 0.2)
	if count >= 2:
		_drop_spikes(d - 40.0, lanes[(gap_lane + 1) % 3], false)
	toast("ROADBLOCK AHEAD", "bad")

# ============ POLICE / HEAT ============
func spawn_cop(car_id: String, role := "chase") -> void:
	var diff := P.diff()
	var cop := AICar.new()
	cop.setup_ai(car_id, AICar.Role.COP, diff.cop * (1.0 + heat * 0.012), "f2f2f2", true)
	cop.race = self
	cop.cop_role = role
	add_child(cop)
	if role == "intercept":
		# always with warning, never dropped silently in the player's path
		var ahead := clampf(player.progress + randf_range(260.0, 360.0), 0.0, length - 10.0)
		_place_on_road(cop, ahead, randf_range(-3.0, 3.0))
		cop.linear_velocity = cop.global_transform.basis.z * 6.0
		toast("INTERCEPTOR AHEAD", "bad")
		SFX.play("emp", -14.0)
	else:
		_place_on_road(cop, maxf(player.progress - randf_range(90.0, 160.0), 4.0), randf_range(-4.0, 4.0))
		cop.linear_velocity = -cop.global_transform.basis.z * player.linear_velocity.length() * 0.9
	cops.append(cop)

func deploy_cop_spike(d: float, x: float) -> void:
	_drop_spikes(d, x, false)
	toast("SPIKE STRIP DEPLOYED AHEAD", "bad")

func _police(delta: float) -> void:
	if not wanted or heat <= 0 or career == "cop": return
	director.update(delta)
	var alive := cops.filter(func(c): return is_instance_valid(c) and not c.dead and not c.wrecked)
	# spike traps
	if heat >= 3:
		spike_trap_t -= delta
		if spike_trap_t <= 0.0:
			_drop_spikes(player.progress + randf_range(250.0, 420.0), randf_range(-5.0, 5.0), false)
			spike_trap_t = maxf(6.0, 18.0 - heat)
	# EMP lock
	if heat >= 4 and emp_lock < 0.0:
		emp_t -= delta
		var near := alive.any(func(c): return absf(c.progress - player.progress) < 90.0)
		if emp_t <= 0.0 and near:
			emp_lock = 1.4
			emp_lock_x = player.lateral
			toast("EMP LOCK — DODGE!", "bad")
			SFX.play("emp", -12.0)
			emp_t = maxf(5.0, 16.0 - heat * 1.1)
	if emp_lock >= 0.0:
		emp_lock -= delta
		if emp_lock < 0.0:
			if absf(player.lateral - emp_lock_x) > 3.0:
				toast("EMP dodged!", "good")
				add_risk(14.0)
				bounty += 300.0
			else:
				var stun_dur := maxf(0.4, 1.5 - player.stats.get("empres", 0.0) * 0.28)
				player.stun(stun_dur)
				player.linear_velocity *= 0.55
				toast("EMP HIT — systems down!", "bad")
				SFX.play("emp", -4.0)
	# roadblocks
	if heat >= 5:
		block_t -= delta
		if block_t <= 0.0:
			_spawn_roadblock(player.progress + 400.0, mini(5, heat - 3))
			block_t = maxf(9.0, 26.0 - heat * 1.6)
	# helicopter
	if heat >= 6 and heli == null:
		_spawn_heli()
	if heli:
		var hp_target: Vector3 = player.global_position + Vector3(sin(t * 0.6) * 26.0, 32.0, cos(t * 0.5) * 18.0)
		heli.global_position = heli.global_position.lerp(hp_target, delta * 1.2)
		heli.look_at(player.global_position, Vector3.UP)
	# bounty
	bounty += delta * (10.0 + heat * 8.0 + player.kmh() * 0.05)
	# nearest cop
	var nearest := 1e9
	for c in alive:
		nearest = minf(nearest, absf(c.progress - player.progress))
	SFX.siren(nearest < 300.0, clampf(1.0 - nearest / 300.0, 0.0, 1.0))
	# busted / escape
	if nearest < 22.0 and player.kmh() < 15.0:
		busted += delta / 2.4
		if busted >= 1.0:
			if impound_t > 0.0:
				_end("busted")            # caught again during the warning
			else:
				_trigger_impound_warning()
	else:
		busted = maxf(busted - delta * 0.8, 0.0)
	if mode in ["escape", "free", "roam"]:
		if nearest > 350.0 or alive.is_empty():
			escape += delta / 5.0
			if escape >= 1.0:
				if mode == "escape": _end("escaped")
				else: _bank_bounty_free()
		else:
			escape = maxf(escape - delta * 0.5, 0.0)

func _spawn_heli() -> void:
	heli = Node3D.new()
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new(); bm.radius = 1.2; bm.height = 6.0
	body.mesh = bm
	body.rotation_degrees.x = 90
	body.material_override = CarFactory.trim_material()
	heli.add_child(body)
	var rotor := MeshInstance3D.new()
	var rm := BoxMesh.new(); rm.size = Vector3(9.0, 0.06, 0.4)
	rotor.mesh = rm
	rotor.position.y = 1.6
	rotor.material_override = CarFactory.trim_material()
	rotor.name = "rotor"
	heli.add_child(rotor)
	var spot := SpotLight3D.new()
	spot.rotation_degrees.x = -90
	spot.spot_range = 60.0; spot.spot_angle = 16.0
	spot.light_energy = 8.0
	heli.add_child(spot)
	add_child(heli)
	heli.global_position = player.global_position + Vector3(0, 40, 30)
	toast("HELICOPTER TRACKING", "bad")

func _process(delta: float) -> void:
	if heli:
		var rotor := heli.get_node_or_null("rotor")
		if rotor: rotor.rotate_y(delta * 30.0)

func _bank_bounty_free() -> void:
	var b := int(bounty)
	P.data.cash += b
	P.data.stats.bounty += b
	P.data.stats.escapes += 1
	if heat >= 8: P.data.flags["heat8escape"] = true
	toast("ESCAPED! Bounty banked: $%d" % b, "good")
	SFX.play("ui_win", -4.0)
	wanted = false; heat = 0; bounty = 0.0; escape = 0.0
	for c in cops:
		if is_instance_valid(c): c.queue_free()
	cops.clear()
	P.check_secrets()
	P.save_game()
	if roam != null:
		roam.on_escape_banked()

# ============ SCORING HOOKS ============
func toast(txt: String, cls := "") -> void:
	if hud: hud.toast(txt, cls)

func add_risk(amt: float) -> void:
	risk = clampf(risk + amt, 0.0, 100.0)
	player.nitro = clampf(player.nitro + amt * 0.004, 0.0, 1.0)

func on_drift_tick(delta: float, slip: float, speed: float) -> void:
	# points bank while sliding — only banked on a CLEAN exit
	drift_bank += int(delta * (30.0 + slip * 2.2) * (1.0 + speed / 220.0) * drift_combo)

func on_drift_end(dur: float) -> void:
	if dur > 0.7 and drift_bank > 0:
		add_risk(8.0 + dur * 3.0)
		drift_combo = clampf(drift_combo + 0.5, 1.0, 5.0)
		drift_score += drift_bank
		var tier := "EXTREME DRIFT" if dur > 3.5 else "GREAT DRIFT" if dur > 2.0 else "GOOD DRIFT"
		toast("%s +%d  x%.1f" % [tier, drift_bank, drift_combo], "good")
		S.vibrate(0.2, 0.0, 0.15)
	drift_bank = 0

func _near_miss_check() -> void:
	if player.kmh() < 140.0: return
	for tc in traffic:
		if not is_instance_valid(tc) or tc.hit_free: continue
		var id: int = tc.get_instance_id()
		var gap: float = tc.progress - player.progress
		if gap < 2.0 and gap > -8.0 and not near_miss_flags.has(id):
			near_miss_flags[id] = true
			var lat := absf(tc.lateral - player.lateral)
			if lat > 1.9 and lat < 4.2:
				add_risk(12.0 if tc.oncoming else 7.0)
				bounty += 120.0 if tc.oncoming else 60.0
				toast("ONCOMING NEAR MISS +" if tc.oncoming else "Near miss +", "good")
		elif gap > 30.0:
			near_miss_flags.erase(id)

# ============ NFS-HP SKILL SYSTEMS ============
static func ordinal(n: int) -> String:
	return "1ST" if n == 1 else "2ND" if n == 2 else "3RD" if n == 3 else str(n) + "TH"

func _skills(delta: float) -> void:
	var P := player
	# ---- SLIPSTREAM: tucked in behind any car ahead ----
	var slip := false
	if P.kmh() > 130.0 and not P.drifting:
		for c in all_vehicles():
			if not is_instance_valid(c): continue
			var cp: float = c.progress if "progress" in c else -1e9
			var gap := cp - P.progress
			if gap > 6.0 and gap < 42.0 and absf((c.lateral if "lateral" in c else 0.0) - P.lateral) < 1.6:
				var cs: float = c.kmh() if c.has_method("kmh") else (c.speed_kmh if "speed_kmh" in c else 0.0)
				if cs > 40.0:
					slip = true
					break
	slip_active = slip
	if slip:
		slip_t += delta
		P.nitro = clampf(P.nitro + delta * 0.05, 0.0, 1.0)
		# draft pull only while there's still a cushion — no magnet rear-endings
		var nearest_gap := 1e9
		for c in all_vehicles():
			if not is_instance_valid(c) or not ("progress" in c): continue
			var g: float = c.progress - P.progress
			if g > 0.0: nearest_gap = minf(nearest_gap, g)
		if nearest_gap > 14.0:
			P.apply_central_force(-P.global_transform.basis.z * P.mass * 3.2)
		if slip_t - slip_mile >= 5.0:
			slip_mile = slip_t
			bounty += 100.0
			add_risk(6.0)
			toast("SLIPSTREAM %ds +100" % int(slip_t), "good")
	else:
		slip_t = 0.0
		slip_mile = 0.0
	# ---- ONCOMING: metres in the oncoming lane ----
	oncoming_active = allows_oncoming() and P.lateral < -2.0 and P.lateral > -7.2 and P.kmh() > 110.0
	if oncoming_active:
		oncoming_m += P.kmh() / 3.6 * delta
		if oncoming_m - oncoming_mile >= 100.0:
			oncoming_mile = floorf(oncoming_m / 100.0) * 100.0
			bounty += 50.0
			add_risk(5.0)
			toast("ONCOMING %dm +50" % int(oncoming_mile), "good")
	else:
		oncoming_m = 0.0
		oncoming_mile = 0.0
	# ---- DRIFT metres ----
	if P.drifting:
		drift_m += P.kmh() / 3.6 * delta
		if drift_m - drift_mile >= 100.0:
			drift_mile = floorf(drift_m / 100.0) * 100.0
			var b := 50 if drift_mile >= 250.0 else 10
			bounty += b
			toast("DRIFT %dm +%d" % [int(drift_mile), b], "good")
	else:
		drift_m = 0.0
		drift_mile = 0.0
	# ---- OVERTAKE callouts ----
	if mode in ["sprint", "circuit", "hotpursuit", "boss", "elim", "drag"]:
		var pos := _position_of_player()
		if prev_pos > 0 and pos < prev_pos:
			var bonus := 100 if pos == 1 else 80
			bounty += bonus
			add_risk(8.0)
			pos_announce = "TOOK %s  +%d" % [ordinal(pos), bonus]
			pos_announce_t = 2.2
			SFX.play("checkpoint", -8.0)
		prev_pos = pos
	if pos_announce_t > 0.0:
		pos_announce_t -= delta
	# ---- CRASH ESCAPE ----
	if crash_escape_t > 0.0:
		crash_escape_t -= delta
		if crash_escape_t <= 0.0 and P.hp > 0.0 and P.kmh() > 100.0:
			bounty += 100.0
			add_risk(10.0)
			toast("CRASH ESCAPE +100", "good")
	# ---- BREAKABLE CHEVRON SIGNS on bends ahead ----
	chev_t -= delta
	if chev_t <= 0.0:
		chev_t = 1.5
		var base_i := clampi(P.track_idx + 40, 2, samples.size() - 30)
		for n in range(0, 60, 4):
			var i := clampi(base_i + n, 2, samples.size() - 3)
			var key := i / 25
			var turn := TrackGen._curvature(samples, i)
			if absf(turn) > 0.05 and not _chev_marked.has(key):
				_chev_marked[key] = true
				var s: Dictionary = samples[i]
				var side := 1.0 if turn > 0.0 else -1.0
				for k in 3:
					var j := clampi(i + k * 4, 0, samples.size() - 1)
					var sj: Dictionary = samples[j]
					_spawn_chevron(sj, side, signf(turn))
				break

func _spawn_chevron(s: Dictionary, side: float, dir: float) -> void:
	var body := StaticBody3D.new()
	body.set_meta("chevron", true)
	var post := MeshInstance3D.new()
	var pb := BoxMesh.new(); pb.size = Vector3(0.12, 1.1, 0.12)
	post.mesh = pb; post.material_override = CarFactory.trim_material()
	post.position.y = 0.55
	body.add_child(post)
	var board := MeshInstance3D.new()
	var bb := BoxMesh.new(); bb.size = Vector3(1.7, 1.05, 0.1)
	board.mesh = bb
	board.material_override = CarFactory.emissive(Color(1.0, 0.82, 0.1), 0.5)
	board.position.y = 1.6
	body.add_child(board)
	var arrow := MeshInstance3D.new()
	var ab := PrismMesh.new(); ab.size = Vector3(0.7, 0.6, 0.06)
	arrow.mesh = ab
	arrow.material_override = CarFactory.trim_material()
	arrow.position = Vector3(0, 1.6, -0.09)
	arrow.rotation_degrees = Vector3(0, 0, 90.0 * dir)
	body.add_child(arrow)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(1.7, 2.2, 0.3)
	cs.shape = bs; cs.position.y = 1.1
	body.add_child(cs)
	hazards.add_child(body)
	body.global_transform = Transform3D(Basis.looking_at(s.fwd, s.up),
		s.pos + s.right * side * (TrackGen.ROAD_HALF + 0.6) + Vector3.UP * 0.02)

func smash_chevron(body: Node) -> void:
	if not is_instance_valid(body): return
	bounty += 50.0
	add_risk(4.0)
	toast("SIGN SMASH +50", "good")
	SFX.crash(false)
	# board flies off as debris
	for child in body.get_children():
		if child is MeshInstance3D and child.position.y > 1.0:
			var deb := RigidBody3D.new()
			deb.mass = 6.0
			var dcs := CollisionShape3D.new()
			var dbs := BoxShape3D.new(); dbs.size = Vector3(1.7, 1.05, 0.12)
			dcs.shape = dbs
			deb.add_child(dcs)
			var xf: Transform3D = child.global_transform
			child.get_parent().remove_child(child)
			child.position = Vector3.ZERO; child.rotation = Vector3.ZERO
			deb.add_child(child)
			get_tree().current_scene.add_child(deb)
			deb.global_transform = xf
			deb.linear_velocity = -player.global_transform.basis.z * player.linear_velocity.length() * 0.6 + Vector3.UP * 6.0
			deb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
			var tm := get_tree().create_timer(6.0)
			tm.timeout.connect(func(): if is_instance_valid(deb): deb.queue_free())
	body.queue_free()

# ============ MODES ============
func _total_progress(car: Node) -> float:
	var laps_done: int = car.get_meta("laps", 0)
	return laps_done * length + car.progress

func _position_of_player() -> int:
	var pos := 1
	var mine: float = _total_progress(player) if is_loop else player.progress
	for r in rivals:
		if is_instance_valid(r) and not r.dead and not r.eliminated:
			var theirs: float = _total_progress(r) if is_loop else r.progress
			if theirs > mine: pos += 1
	return pos

# ---- closed-circuit laps, checkpoints, timing ----
func _update_laps() -> void:
	var cars: Array = [player]
	cars.append_array(rivals.filter(func(r): return is_instance_valid(r) and not r.dead))
	for car in cars:
		var prev: float = car.get_meta("prev_d", car.progress)
		var diff := fposmod(car.progress - prev + length * 0.5, length) - length * 0.5
		# player checkpoint gates at quarter points (anti-cut)
		if car == player:
			for ci in 3:
				var gate := length * 0.25 * (ci + 1)
				if prev < gate and car.progress >= gate and absf(car.progress - gate) < 60.0:
					_cp_flags[ci] = true
		if prev > length * 0.75 and car.progress < length * 0.25 and diff > 0.0:
			# crossed the start/finish line forward
			if car == player:
				if _cp_flags.all(func(f): return f):
					lap += 1
					last_lap = t - lap_start_t
					if best_lap <= 0.0 or last_lap < best_lap:
						best_lap = last_lap
						if lap > 1: toast("BEST LAP  %.2fs" % best_lap, "good")
					lap_start_t = t
					car.set_meta("laps", int(car.get_meta("laps", 0)) + 1)
					SFX.play("checkpoint", -6.0)
					if lap == laps: toast("FINAL LAP", "warn")
				else:
					toast("CHECKPOINT MISSED — lap not counted", "bad")
				_cp_flags = [false, false, false]
			else:
				car.set_meta("laps", int(car.get_meta("laps", 0)) + 1)
		elif prev < length * 0.25 and car.progress > length * 0.75 and diff < 0.0:
			car.set_meta("laps", maxi(int(car.get_meta("laps", 0)) - 1, 0))
		car.set_meta("prev_d", car.progress)

func _wrong_way_check(delta: float) -> void:
	if player.kmh() < 30.0 or player.reversing:
		_wrong_way_t = maxf(_wrong_way_t - delta * 2.0, 0.0)
		wrong_way = false
		return
	var fwd := -player.global_transform.basis.z
	var road_fwd: Vector3 = samples[sample_index(player.progress)].fwd
	if fwd.dot(road_fwd) < -0.35:
		_wrong_way_t += delta
	else:
		_wrong_way_t = maxf(_wrong_way_t - delta * 2.0, 0.0)
	wrong_way = _wrong_way_t > 0.8

func _mode_logic(delta: float) -> void:
	match mode:
		"sprint", "hotpursuit", "boss", "duel":
			if player.progress >= finish_d:
				_end("win" if _position_of_player() == 1 else "lose")
				return
			for r in rivals:
				if is_instance_valid(r) and not r.dead and r.progress >= finish_d:
					_end("lose")
					return
			if mode == "hotpursuit":
				for r in rivals:
					if is_instance_valid(r) and not r.dead and randf() < delta * 0.014 * heat \
							and absf(r.progress - player.progress) > 200.0:
						r.dead = true
						toast("%s was busted by VCPD" % D.car_def(r.car_id).name, "")
		"circuit":
			if int(player.get_meta("laps", 0)) >= laps:
				_end("win" if _position_of_player() == 1 else "lose")
				return
			for r in rivals:
				if is_instance_valid(r) and not r.dead and int(r.get_meta("laps", 0)) >= laps:
					_end("lose")
					return
		"timeattack":
			ta_time -= delta
			var gate_len := length / 6.0
			var next_gate := (int(player.get_meta("ta_gate", 0)) + 1) * gate_len
			if player.progress >= next_gate and next_gate < finish_d:
				player.set_meta("ta_gate", int(player.get_meta("ta_gate", 0)) + 1)
				var bonus := float(ev.get("gate_bonus", 7.0))
				ta_time += bonus
				toast("CHECKPOINT +%.0fs" % bonus, "good")
				SFX.play("checkpoint", -4.0)
			if ta_time <= 0.0:
				_end("ta_out")
				return
			if player.progress >= finish_d:
				_end("win")
				return
		"speedtrap":
			var fracs := [0.15, 0.35, 0.55, 0.75, 0.92]
			if trap_next < fracs.size() and player.progress >= length * fracs[trap_next]:
				var v := player.kmh()
				trap_speeds.append(v)
				trap_next += 1
				hud.flash(false)
				toast("CAMERA %d:  %d km/h" % [trap_next, int(v)], "good")
				SFX.play("checkpoint", -4.0)
			if player.progress >= finish_d:
				var total := 0.0
				for v2 in trap_speeds: total += v2
				_end("win" if total >= float(ev.get("target", 1200)) else "lose")
				return
		"elim":
			elim_t -= delta
			if elim_t <= 0.0:
				elim_t = 20.0
				var field := rivals.filter(func(r): return is_instance_valid(r) and not r.dead)
				var last: AICar = null
				var last_d := 1e18
				for r in field:
					if r.progress < last_d: last_d = r.progress; last = r
				if player.progress < last_d:
					_end("eliminated")
					return
				if last:
					last.dead = true
					last.eliminated = true
					toast("%s ELIMINATED" % D.car_def(last.car_id).name, "warn")
					SFX.play("ui_lose", -8.0)
				if rivals.all(func(r): return not is_instance_valid(r) or r.dead):
					_end("win")
					return
			if player.progress >= finish_d:
				_end("win" if _position_of_player() == 1 else "lose")
		"drag":
			if player.progress >= finish_d:
				_end("win" if rivals.is_empty() or rivals[0].progress < player.progress else "lose")
			elif not rivals.is_empty() and is_instance_valid(rivals[0]) and rivals[0].progress >= finish_d:
				_end("lose")
		"drift":
			if player.progress >= finish_d:
				_end("win" if drift_score >= int(ev.target) else "lose")
		"topspeed":
			if player.progress >= finish_d:
				_end("win" if best_speed >= float(ev.target) else "lose")
		"escape":
			if player.progress >= length - 10.0:
				_end("escaped")   # outran the whole map
		"intercept":
			time_left -= delta
			if target == null or not is_instance_valid(target):
				_end("arrested"); return
			if target.hp <= 0.0 or target.wrecked:
				_end("arrested"); return
			if time_left <= 0.0:
				_end("timeout"); return
			var gap: float = target.progress - player.progress
			if gap > 550.0:
				esc_t += delta
				if esc_t > 10.0: _end("suspect_escaped")
			else:
				esc_t = maxf(esc_t - delta, 0.0)
			if target.progress >= length - 10.0:
				_end("suspect_escaped")
		"free":
			cam_t -= delta
			if cam_t <= 0.0:
				cam_t = randf_range(10.0, 18.0)
				if player.kmh() > 200.0:
					heat = clampi(heat + 1, 0, 10)
					wanted = true
					toast("SPEED CAMERA FLASH — Heat %d: %s" % [heat, D.HEAT_INFO[heat]], "bad")
					hud.flash(false)
					bounty += player.kmh() * 3.0
			if player.progress >= length - 20.0:
				player.reset_to_track_at(20.0)

# ============ END ============
func _end(res: String) -> void:
	if state == "done": return
	state = "done"
	result = res
	Engine.time_scale = 1.0
	var diff := P.diff()
	var win := res in ["win", "escaped", "arrested"]
	var first: bool = not (P.data.cop_wins if career == "cop" else P.data.wins).has(ev.id)
	var payout := 0
	var rep := 0
	var title := ""
	var sub := ""
	P.data.stats.races += 1
	match res:
		"win":
			title = "VICTORY"
			sub = "You won %s" % ev.name
			if mode == "boss":
				var b: Dictionary = D.BOSSES[ev.boss]
				sub = "You beat %s — %s" % [b.name, b.title]
		"escaped":
			title = "ESCAPED"
			sub = "You vanished into Velora Coast. Bounty banked."
			payout += int(bounty)
		"arrested":
			title = "SUSPECT ARRESTED"
			sub = "Target vehicle disabled and in custody."
		"lose": title = "DEFEATED"; sub = "Better luck next time."
		"eliminated": title = "ELIMINATED"; sub = "Last across the line at the cull."
		"busted":
			title = "BUSTED"
			sub = "The VCPD impounded your car. Bounty lost."
			P.data.stats.busts += 1
		"wrecked": title = "WRECKED"; sub = "Your car is totalled."
		"timeout": title = "TIME EXPIRED"; sub = "The suspect slipped away."
		"ta_out": title = "TIME UP"; sub = "The clock beat you to the line."
		"suspect_escaped": title = "SUSPECT ESCAPED"; sub = "You lost the target."
	if win:
		payout += int(round(ev.get("cash", 0) * diff.cash * (1.0 if first else 0.3)))
		rep = int(round(ev.get("rep", 0) * (1.0 if first else 0.35)))
		if mode == "boss" and first:
			var b: Dictionary = D.BOSSES[ev.boss]
			payout += b.cash
			if b.car_reward != "" and not P.owns(b.car_reward):
				P.give_car(b.car_reward)
				sub += " — %s added to your garage!" % D.car_def(b.car_reward).name
			if b.part != "":
				var ups: Dictionary = P.data.cars[P.data.cur].up
				ups[b.part] = clampi(ups.get(b.part, 0) + 1, 0, D.MAX_UP)
				sub += " Free upgrade installed!"
		P.data.medals[ev.id] = "gold" if first else P.data.medals.get(ev.id, "silver")
		if is_loop and best_lap > 0.0:
			var prev_best: float = P.data.bests.get(ev.id, 0.0)
			if prev_best <= 0.0 or best_lap < prev_best:
				P.data.bests[ev.id] = best_lap
		if career == "cop":
			P.data.cop_wins[ev.id] = true
			P.data.cop_rep += rep
			P.data.stats.takedowns += 1
		else:
			P.data.wins[ev.id] = true
			P.data.rep += rep
			P.data.stats.wins += 1
		if mode == "escape":
			P.data.stats.escapes += 1
			if heat >= 8: P.data.flags["heat8escape"] = true
		SFX.play("ui_win", -2.0)
	else:
		payout += int(round(ev.get("cash", 0) * 0.08))
		rep = int(round(ev.get("rep", 0) * 0.08))
		if career == "cop": P.data.cop_rep += rep
		else: P.data.rep += rep
		SFX.play("ui_lose", -4.0)
	P.data.cash += payout
	P.data.stats.earned += maxi(payout, 0)
	P.data.stats.best_speed = maxi(int(P.data.stats.best_speed), int(best_speed))
	if drift_score > 0: P.data.stats.best_drift = maxi(int(P.data.stats.best_drift), drift_score)
	if win and mode != "roam":
		for cid in P.barn_tick():
			sub += "  Barn find restored: %s!" % D.car_def(cid).name
	P.check_secrets()
	P.save_game()
	SFX.stop_race_audio()
	summary = {
		"title": title, "sub": sub, "payout": payout, "rep": rep, "win": win, "first": first,
		"lines": _summary_lines(),
	}
	await get_tree().create_timer(1.4).timeout
	finished.emit(summary)

func _summary_lines() -> Array:
	var l := []
	l.append(["Top speed", "%d km/h" % int(best_speed)])
	if drift_score > 0: l.append(["Drift score", str(drift_score)])
	if bounty > 0: l.append(["Bounty earned", "$%d" % int(bounty)])
	l.append(["Damage taken", "%d%%" % int(100.0 - player.hp)])
	if mode == "intercept" and target and is_instance_valid(target):
		l.append(["Suspect condition", "%d%%" % int(maxf(target.hp, 0.0))])
	l.append(["Time", "%.1fs" % t])
	return l

func cleanup() -> void:
	Engine.time_scale = 1.0
	SFX.stop_race_audio()
