# ============================================================
# CHICANE 3D — player_car.gd
# Player vehicle: transmission-driven arcade handling with
# per-class personalities, surface grip, ABS/TC, drift model,
# analog + keyboard steering, and rich audio/vfx feedback.
# ============================================================
class_name PlayerCar
extends VehicleBase

signal impact(severity: float, world_pos: Vector3, other: Node)

var race: Node = null
var trans: Transmission
var handling := {"grip": 1.0, "rear_grip": 1.0, "steer": 1.0, "downforce": 1.0, "mass": 1.0}

var nitro := 1.0
var nitro_heat := 0.0
var overheated := false
var nitro_on := false
var turbo_t := 0.0
var warp_t := 0.0               # v9.5 — warp speed remaining (3x velocity)
var drifting := false
var drift_time := 0.0
var controls_enabled := true
var track_idx := 0
var progress := 0.0
var lateral := 0.0
var airborne := false
var accel_g := 0.0                  # smoothed longitudinal g for the camera
var backfire_t := 0.0
var reversing := false
var _prev_vel := Vector3.ZERO
var _prev_speed := 0.0
var _was_nitro := false
var _was_throttle := false
var _flip_t := 0.0
var _flip_warned := false
var _skid_timer := 0.0
var _steer_target := 0.0

var chase: ChaseCam

func setup_player(id: String, cfg: Dictionary, police := false) -> void:
	setup(id, P.car_stats(id), cfg.get("paint", "e8192c"), cfg.get("finish", "gloss"), police, cfg.get("skin", ""))
	body_entered.connect(_on_body_entered)
	trans = Transmission.new()
	var def := D.car_def(id)
	trans.setup(str(def.get("cls", "Supercar")), stats)
	trans.tc_enabled = P.data.diff != "hard" and bool(S.g("assist_tc"))
	trans.manual = str(S.g("trans_mode")) == "manual"
	_apply_class_personality(str(def.get("cls", "Supercar")))
	chase = ChaseCam.new()

func _apply_class_personality(cls: String) -> void:
	# distinct feel per class — not just different top speeds
	if "Drift" in cls:
		handling = {"grip": 0.98, "rear_grip": 0.84, "steer": 1.22, "downforce": 0.75, "mass": 0.96}
	elif "Grand" in cls:
		handling = {"grip": 1.04, "rear_grip": 1.05, "steer": 0.85, "downforce": 1.4, "mass": 1.14}
	elif "Track" in cls:
		handling = {"grip": 1.12, "rear_grip": 1.02, "steer": 1.08, "downforce": 1.3, "mass": 0.94}
	elif "Hybrid" in cls:
		handling = {"grip": 1.05, "rear_grip": 1.0, "steer": 1.0, "downforce": 1.1, "mass": 1.02}
	elif "Muscle" in cls:
		# heavy nose, loose tail, loves a powerslide
		handling = {"grip": 0.96, "rear_grip": 0.88, "steer": 0.95, "downforce": 0.85, "mass": 1.10}
	elif "Prototype" in cls or "Experimental" in cls:
		# featherweight aero experiment — glued down, razor steering
		handling = {"grip": 1.10, "rear_grip": 1.04, "steer": 1.15, "downforce": 1.55, "mass": 0.88}
	elif "Compact" in cls:
		# small, light, honest — momentum matters
		handling = {"grip": 1.02, "rear_grip": 1.0, "steer": 1.10, "downforce": 0.7, "mass": 0.82}
	else:
		handling = {"grip": 1.0, "rear_grip": 1.0, "steer": 1.0, "downforce": 1.0, "mass": 1.0}
	mass *= handling.mass
	# stiffer suspension for track cars, softer for GT
	for w in wheels:
		w.suspension_stiffness = 60.0 * (1.15 if handling.downforce > 1.2 else 0.92 if handling.mass > 1.1 else 1.0)

func _ready() -> void:
	if chase and chase.get_parent() == null:
		get_parent().add_child.call_deferred(chase)
		chase.setup.call_deferred(self)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_prev_vel = linear_velocity
	if race == null: return
	_update_track_position()
	_drive(delta)
	_audio(delta)
	var spd := kmh()
	accel_g = lerpf(accel_g, (spd - _prev_speed) / maxf(delta, 0.001) / 35.0, delta * 6.0)
	_prev_speed = spd

func _update_track_position() -> void:
	var loc: Dictionary = TrackGen.locate(race.samples, global_position, track_idx, race.is_loop)
	track_idx = loc.idx
	progress = loc.d
	lateral = loc.x

func _surface_grip() -> float:
	var g: float = handling.grip
	if absf(lateral) > TrackGen.ROAD_HALF + 0.6: g *= 0.74           # dirt shoulder
	if D.ZONES[race.zone_key].get("wet", false): g *= 0.90           # rain-slick
	if spike_t > 0.0: g *= 0.45                                      # shredded tyres
	if hp < 30.0: g *= 0.93                                          # bent suspension
	return g

func _drive(delta: float) -> void:
	var speed := kmh()
	var max_kmh: float = stats.kmh * (0.92 if hp < 40.0 else 1.0)
	if warp_t > 0.0:
		warp_t -= delta
		max_kmh *= 3.0
	# easy difficulty slowly patches you up while you're alive
	var regen := float(P.diff().get("regen", 0.0))
	if regen > 0.0 and not wrecked and hp > 0.0:
		hp = minf(hp + regen * delta, 100.0)
	if not controls_enabled or wrecked or stun_t > 0.0:
		engine_force = 0.0
		brake = 1.0 if wrecked else 0.3
		set_nitro_flames(false)
		set_brake_light(false)
		return

	var accel_in := Input.get_action_strength("accel")
	var brake_in := Input.get_action_strength("brake")
	var steer_in := Input.get_action_strength("left") - Input.get_action_strength("right")
	steer_in *= float(S.g("steer_sens"))
	var hb := Input.is_action_pressed("handbrake")

	# --- nitrous ---
	var want_nitro := Input.is_action_pressed("nitro") and nitro > 0.02 and not overheated
	if want_nitro and not nitro_on: SFX.play("nitro", -8.0)
	nitro_on = want_nitro
	if nitro_on:
		nitro = maxf(nitro - delta * 0.16 / (1.0 + stats.nitro * 0.05), 0.0)
		nitro_heat += delta * 0.22
		if nitro_heat >= 1.0:
			overheated = true
			nitro_on = false
			race.toast("NITRO OVERHEAT — cooling down!", "bad")
	else:
		nitro_heat = maxf(nitro_heat - delta * 0.4, 0.0)
		if overheated and nitro_heat < 0.35: overheated = false
		nitro = clampf(nitro + delta * 0.02 * (1.0 + race.risk * 0.01), 0.0, 1.0)

	# backfire pops on lift-off / nitro release
	var throttle_now := accel_in > 0.5
	if (_was_nitro and not nitro_on) or (_was_throttle and not throttle_now and speed > 170.0):
		backfire_t = 0.16
		SFX.blowoff()
	_was_nitro = nitro_on
	_was_throttle = throttle_now
	if backfire_t > 0.0: backfire_t -= delta
	set_nitro_flames(nitro_on or turbo_t > 0.0 or warp_t > 0.0 or backfire_t > 0.0)
	if turbo_t > 0.0: turbo_t -= delta

	# --- transmission drives the wheels ---
	if trans.manual:
		if Input.is_action_just_pressed("gear_up"): trans.shift_up()
		if Input.is_action_just_pressed("gear_down"): trans.shift_down(speed)
	var grip := _surface_grip()
	var reverse_request := brake_in > 0.4 and speed < 8.0
	var force := trans.update(delta, speed, accel_in, reverse_request, _grounded(), handling.rear_grip * grip)
	reversing = trans.gear == 0
	if trans.just_shifted:
		SFX.gear_shift()
		backfire_t = maxf(backfire_t, 0.1)
	if nitro_on: force *= 1.75 + stats.nitro * 0.035
	if turbo_t > 0.0: force *= 1.9
	if warp_t > 0.0: force *= 3.0
	if hp < 65.0: force *= 0.88
	var over_cap := speed > max_kmh * (1.22 if nitro_on else 1.0)
	if reversing:
		engine_force = force          # transmission returns positive; +Z drives backwards
		brake = 0.0
	else:
		engine_force = 0.0 if over_cap and force > 0.0 else -force
		# --- braking with ABS assist (toggleable) ---
		var abs_mul := 1.0
		if brake_in > 0.3 and bool(S.g("assist_abs")):
			var front_skid := minf(wheels[0].get_skidinfo(), wheels[1].get_skidinfo())
			if front_skid < 0.25: abs_mul = 0.55
		brake = brake_in * 30.0 * abs_mul * (0.85 if D.ZONES[race.zone_key].get("wet", false) else 1.0) \
			+ (0.6 if accel_in == 0.0 and brake_in == 0.0 else 0.0)
	set_brake_light(brake_in > 0.25 and not reversing)
	set_reverse_light(reversing)

	# --- steering: analog, speed-sensitive, quick return to centre ---
	var max_steer: float = lerpf(0.42, 0.07, clampf(speed / 260.0, 0.0, 1.0)) \
		* (1.0 + stats.hand * 0.012) * handling.steer
	var rate: float = (2.6 + stats.hand * 0.12) * (2.0 if absf(steer_in) < 0.05 else 1.0)
	_steer_target = steer_in * max_steer
	steering = move_toward(steering, _steer_target, delta * rate)
	if hp < 25.0:
		steering += sin(Time.get_ticks_msec() * 0.02) * 0.012   # bent chassis wobble

	# --- grip application (front/rear balance + surfaces) ---
	var front_grip: float = (3.3 + stats.hand * 0.22) * grip
	var rear_grip: float = (3.15 + stats.hand * 0.22) * grip * handling.rear_grip
	if hb and speed > 55.0:
		rear_grip = (0.85 + stats.drift * 0.05) * grip
		brake = maxf(brake, 0.4)
	if spike_t <= 0.0:
		wheels[0].wheel_friction_slip = front_grip
		wheels[1].wheel_friction_slip = front_grip
		wheels[2].wheel_friction_slip = rear_grip
		wheels[3].wheel_friction_slip = rear_grip

	# --- drift model ---
	var flat_vel := Vector3(linear_velocity.x, 0, linear_velocity.z)
	var slip := 0.0
	if flat_vel.length() > 8.0:
		var fwd := -global_transform.basis.z
		slip = rad_to_deg(fwd.signed_angle_to(flat_vel.normalized(), Vector3.UP))
	var was_drifting := drifting
	drifting = absf(slip) > 12.0 and speed > 55.0 and _grounded() and not reversing
	if drifting:
		drift_time += delta
		race.on_drift_tick(delta, absf(slip), speed)
		# countersteer assist scales with drift stat — helps hold, never steals control
		apply_torque(Vector3.UP * -signf(slip) * mass * (1.2 + stats.drift * 0.09) \
			* clampf(absf(slip) / 45.0, 0.0, 1.0) * float(S.g("assist_steer")))
		# throttle widens the angle slightly
		if accel_in > 0.6:
			apply_torque(Vector3.UP * signf(slip) * mass * 0.5)
	elif was_drifting:
		race.on_drift_end(drift_time)
		drift_time = 0.0

	# tyre squeal + smoke + skid marks from real wheel slip
	var worst_skid := 1.0
	for w in wheels:
		if w.is_in_contact(): worst_skid = minf(worst_skid, w.get_skidinfo())
	var slip_amt := clampf(1.0 - worst_skid, 0.0, 1.0)
	SFX.squeal(slip_amt if _grounded() else 0.0)
	if slip_amt > 0.45 and _grounded():
		_skid_timer -= delta
		if _skid_timer <= 0.0 and race.skids:
			_skid_timer = 0.045
			var fwd2 := -global_transform.basis.z
			for wi in [2, 3]:
				race.skids.add_mark(wheels[wi].global_position - Vector3.UP * wheels[wi].wheel_radius * 0.9, fwd2)
	if trans.spinning or (drifting and randf() < 0.5):
		pass   # smoke handled by vehicle_base particles

	# --- downforce & stability assist (toggleable) ---
	var v2 := linear_velocity.length_squared()
	var assist: float = 0.7 if P.data.diff == "hard" else 1.0
	if not bool(S.g("assist_stab")): assist *= 0.72
	apply_central_force(Vector3.DOWN * v2 * 0.5 * handling.downforce * assist)
	airborne = not _grounded()
	if absf(lateral) > TrackGen.ROAD_HALF + 2.0 and _grounded():
		apply_central_force(-flat_vel * mass * 0.32)
		if speed > 60.0: S.vibrate(0.25, 0.0, 0.12)

	# anti-flip + roof prompt
	var up_dot := global_transform.basis.y.dot(Vector3.UP)
	if up_dot < 0.4 and speed < 30.0:
		apply_torque(global_transform.basis.z.cross(Vector3.UP) * mass * 14.0)
	if up_dot < 0.3 and speed < 20.0:
		_flip_t += delta
		if _flip_t > 1.5 and not _flip_warned:
			_flip_warned = true
			race.toast("FLIPPED — press X to reset", "warn")
	else:
		_flip_t = 0.0
		_flip_warned = false

	if Input.is_action_just_pressed("reset"):
		reset_to_track()
	if Input.is_action_just_pressed("camera"):
		chase.cycle_mode()

func _grounded() -> bool:
	for w in wheels:
		if w.is_in_contact(): return true
	return false

# Reset onto the road at the first sample ahead that is clear of traffic.
func reset_to_track() -> void:
	var idx := mini(track_idx, race.samples.size() - 1)
	for attempt in 8:
		var cand := clampi(idx + attempt * 4, 0, race.samples.size() - 1)
		var s: Dictionary = race.samples[cand]
		var blocked := false
		for v in race.all_vehicles():
			if is_instance_valid(v) and v != self and v is Node3D \
					and v.global_position.distance_to(s.pos) < 9.0:
				blocked = true
				break
		if not blocked:
			global_transform = Transform3D(Basis.looking_at(s.fwd, s.up), s.pos + Vector3.UP * 1.0)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			track_idx = cand
			return
	var s2: Dictionary = race.samples[idx]
	global_transform = Transform3D(Basis.looking_at(s2.fwd, s2.up), s2.pos + Vector3.UP * 1.5)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func reset_to_track_at(d: float) -> void:
	track_idx = clampi(int(d / TrackGen.SAMPLE), 0, race.samples.size() - 1)
	reset_to_track()

func _audio(_delta: float) -> void:
	if wrecked:
		SFX.engine(0.1, false)
		SFX.wind(0.0)
		SFX.turbo(0.0)
		return
	var load := Input.get_action_strength("accel")
	SFX.engine(trans.rpm * (1.1 if nitro_on else 1.0), true, load)
	SFX.wind(kmh())
	SFX.turbo(clampf((trans.rpm - 0.35) * 1.4, 0.0, 1.0) * load if (nitro_on or turbo_t > 0.0 or trans.gear >= 3) else 0.0)

func _on_body_entered(body: Node) -> void:
	if race == null: return
	if body is StaticBody3D and not body.has_meta("roadblock") and not body.has_meta("chevron") and body.name != "Rails":
		return
	var other_vel := Vector3.ZERO
	if body is RigidBody3D: other_vel = body.linear_velocity
	var rel := (_prev_vel - other_vel).length()
	if rel < 3.0: return
	if body.name == "Rails": rel *= 0.35
	var to_other := Vector3.ZERO
	if body is Node3D:
		to_other = (body.global_position - global_position)
	var impact_pos := global_position + to_other.normalized() * 1.4 + Vector3.UP * 0.5
	impact.emit(rel, impact_pos, body)

func use_turbo() -> void:
	turbo_t = 1.8
	apply_central_impulse(-global_transform.basis.z * mass * 6.0)

# v9.5 — warp speed: 10 seconds at triple velocity
func start_warp(dur := 10.0) -> void:
	warp_t = dur
	if is_inside_tree():
		apply_central_impulse(-global_transform.basis.z * mass * 9.0)

# v9.5 — god mode: no damage, no EMP stun, no shredded tyres
func take_impact(world_pos: Vector3, dir: Vector3, severity: float, dmg_scale := 1.0) -> float:
	if bool(S.g("god_mode")): return 0.0
	return super.take_impact(world_pos, dir, severity, dmg_scale)

func stun(duration: float) -> void:
	if bool(S.g("god_mode")): return
	super.stun(duration)

func spike() -> void:
	if bool(S.g("god_mode")): return
	super.spike()
