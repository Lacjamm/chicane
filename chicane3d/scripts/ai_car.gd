# ============================================================
# CHICANE 3D — ai_car.gd
# AI driver on the same physics as the player: racing-line
# following, braking points, personalities, mistakes, slipstream,
# police roles (chase / ram-PIT / spike / intercept), suspects
# with nitrous and damage-degraded precision. No visible teleports.
# ============================================================
class_name AICar
extends VehicleBase

enum Role { RIVAL, COP, TARGET }

var race: Node = null
var role: int = Role.RIVAL
var cop_role := "chase"           # chase | ram | spike | intercept
var skill := 1.0
var paint_col := "8a99a8"         # remembered so a blown-up car can respawn identical
var lane := 0.0                   # personal lane bias around the racing line
var flank := 0.0                  # director-assigned box-in offset
var track_idx := 0
var progress := 0.0
var lateral := 0.0
var dead := false
var eliminated := false
var ram_cd := 0.0
var stuck_t := 0.0
var spike_cd := 0.0
var trans: Transmission
# personality
var aggression := 0.5
var line_accuracy := 1.0
var brake_confidence := 1.0
var mistake_rate := 0.1
var _mistake_t := 0.0             # >0 while making a mistake
var _mistake_steer := 0.0
var _next_mistake := 8.0
var _avoid_commit := 0.0
var _avoid_x := 0.0
var _nitro_cd := 0.0
var _nitro_t := 0.0
var _spike_deployed := false
var _last_prog := 0.0
var _stall_t := 0.0
var _prev_vel := Vector3.ZERO
var _frame_offset := 0

func setup_ai(id: String, ai_role: int, ai_skill: float, paint := "8a99a8", police := false) -> void:
	var def := D.car_def(id)
	var s := {"top": def.top, "acc": def.acc, "hand": def.hand, "drift": def.drift,
		"str": def.str, "nitro": def.nitro, "kmh": D.stat_to_kmh(def.top)}
	setup(id, s, paint, "gloss", police)
	role = ai_role
	skill = ai_skill
	paint_col = paint
	trans = Transmission.new()
	trans.setup(str(def.get("cls", "Supercar")), s)
	body_entered.connect(_on_body_entered)
	_frame_offset = randi() % 3
	# personality from a stable per-car hash
	var h := hash(id) ^ hash(int(ai_skill * 1000))
	aggression = 0.3 + float(h % 100) / 100.0 * 0.6
	line_accuracy = clampf(0.55 + skill * 0.45, 0.5, 1.05)
	brake_confidence = clampf(0.75 + skill * 0.3, 0.7, 1.12)
	mistake_rate = clampf(1.4 - skill, 0.06, 0.7)
	_next_mistake = randf_range(6.0, 18.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_prev_vel = linear_velocity
	if race == null or dead or wrecked:
		engine_force = 0.0
		brake = 3.0
		return
	if stun_t > 0.0: return
	ram_cd = maxf(ram_cd - delta, 0.0)
	spike_cd = maxf(spike_cd - delta, 0.0)
	_nitro_cd = maxf(_nitro_cd - delta, 0.0)
	if _nitro_t > 0.0:
		_nitro_t -= delta
		set_nitro_flames(_nitro_t > 0.0)

	var loc: Dictionary = TrackGen.locate(race.samples, global_position, track_idx, race.is_loop)
	track_idx = loc.idx
	progress = loc.d
	lateral = loc.x

	_mistakes(delta)
	var target := _target_point()
	var desired := _desired_speed()
	_steer_to(target, delta)
	_throttle_to(desired, delta)
	_stuck_check(delta)
	# same downforce rules as the player
	apply_central_force(Vector3.DOWN * linear_velocity.length_squared() * 0.55)
	var up_dot := global_transform.basis.y.dot(Vector3.UP)
	if up_dot < 0.5:
		apply_torque(global_transform.basis.z.cross(Vector3.UP) * mass * 18.0)

# --- believable errors: occasional late brakes / steering slips ---
func _mistakes(delta: float) -> void:
	if _mistake_t > 0.0:
		_mistake_t -= delta
		return
	_next_mistake -= delta * (1.5 if absf(TrackGen._curvature(race.samples, track_idx)) > 0.03 else 1.0)
	if _next_mistake <= 0.0:
		_next_mistake = randf_range(7.0, 22.0) / maxf(mistake_rate, 0.05)
		_mistake_t = randf_range(0.3, 0.7)
		_mistake_steer = randf_range(-0.35, 0.35)

func _target_point() -> Vector3:
	var look_ahead := clampf(kmh() * 0.30, 14.0, 55.0)
	if role == Role.COP and race.player and not race.player.wrecked:
		return _cop_target()
	var target_d := progress + look_ahead
	if race.is_loop: target_d = fmod(target_d, race.length)
	elif target_d >= race.length: target_d = race.length - 1.0
	var idx: int = race.sample_index(target_d)
	# racing line + personal bias + avoidance + mistakes
	var line_x: float = race.line_offset[idx] * line_accuracy if race.line_offset.size() > idx else 0.0
	var x := clampf(line_x + lane * (1.2 - line_accuracy * 0.5), -5.8, 5.8)
	x = _avoidance(x)
	if _mistake_t > 0.0: x += _mistake_steer * 6.0
	return _road_point(target_d, x)

func _cop_target() -> Vector3:
	var pc: PlayerCar = race.player
	var gap: float = pc.progress - progress
	match cop_role:
		"ram":
			# PIT attempt: aim for the rear quarter, then swing in
			if gap < 16.0 and gap > -4.0 and ram_cd <= 0.0:
				var side := 1.0 if pc.lateral < lateral else -1.0
				return pc.global_position + pc.global_transform.basis.x * side * 0.4 \
					+ pc.linear_velocity * 0.28
			if gap < 45.0:
				return pc.global_position + pc.linear_velocity * 0.4
		"spike":
			# get ahead, drop a strip, revert to chase
			if not _spike_deployed:
				if gap < -55.0:
					_spike_deployed = true
					race.deploy_cop_spike(progress - 8.0, lateral)
					cop_role = "chase"
				return _road_point(clampf(progress + 60.0, 0.0, race.length - 2.0), pc.lateral)
		"intercept":
			# waits ahead, joins the chase when the player arrives
			if gap > -140.0:
				cop_role = "chase"
			return _road_point(clampf(progress + 30.0, 0.0, race.length - 2.0), 0.0)
	# default chase: follow the road toward a point behind the player
	if hp < 30.0:
		return _road_point(clampf(pc.progress - 45.0, 0.0, race.length - 1.0), clampf(pc.lateral, -5.0, 5.0))
	if gap < 40.0 and gap > -10.0 and ram_cd <= 0.0:
		return pc.global_position + pc.linear_velocity * 0.35
	var d: float = clampf(pc.progress - 12.0, 0.0, race.length - 1.0)
	return _road_point(d, clampf(pc.lateral + flank * 2.6, -5.5, 5.5))

func _road_point(d: float, x: float) -> Vector3:
	var idx: int = race.sample_index(d)
	var s: Dictionary = race.samples[idx]
	return s.pos + s.right * x + Vector3.UP * 0.5

func _avoidance(want: float) -> float:
	# desperate suspects stop caring about traffic
	if role == Role.TARGET and hp < 40.0:
		return want
	# committed avoidance: pick a side and hold it briefly so the car
	# doesn't wobble between choices
	if _avoid_commit > 0.0:
		_avoid_commit -= get_physics_process_delta_time()
		return clampf(_avoid_x, -5.8, 5.8)
	var own_ms := kmh() / 3.6
	for other in race.all_vehicles():
		if other == self or not is_instance_valid(other): continue
		var op: float = other.progress if "progress" in other else -1e9
		var gap := op - progress
		var closing := own_ms
		if other is TrafficCar and other.oncoming: closing += other.speed_kmh / 3.6
		if gap > 0.0 and gap < 26.0 + closing * 1.35:
			var ox: float = other.lateral if "lateral" in other else 0.0
			if absf(ox - want) < 2.6:
				_avoid_x = clampf(ox - 3.2 if ox > 0.0 else ox + 3.2, -5.6, 5.6)
				_avoid_commit = 0.7
				return _avoid_x
	# suspects flee the player laterally
	if role == Role.TARGET and race.player:
		var pgap: float = progress - race.player.progress
		if pgap < 25.0 and pgap > -5.0 and absf(race.player.lateral - lateral) < 2.5:
			return -4.0 if race.player.lateral > 0.0 else 4.0
	return want

func _desired_speed() -> float:
	var max_kmh: float = stats.kmh * skill
	var band := 1.0
	if race.player and role == Role.RIVAL:
		var gap: float = race.player.progress - progress
		if race.mode == "boss":
			band = 1.10 if gap > 90.0 else 0.94 if gap < -90.0 else 1.01
		else:
			band = 1.04 if gap > 130.0 else 0.90 if gap < -200.0 else 1.0
	elif role == Role.TARGET and race.player:
		var gap2: float = progress - race.player.progress
		band = 0.88 if gap2 > 320.0 else 0.95 if gap2 > 45.0 else 1.03
		# suspect nitrous burst when the player closes in
		if gap2 < 25.0 and _nitro_cd <= 0.0 and kmh() > 90.0:
			_nitro_cd = 9.0
			_nitro_t = 1.4
			apply_central_impulse(-global_transform.basis.z * mass * 5.0)
	elif role == Role.COP:
		band = 1.05
		if hp < 30.0: band = 0.85     # damaged cops hang back
	var want := max_kmh * band
	if role == Role.COP and race.player:
		var behind: float = race.player.progress - progress
		if behind < 80.0 and behind > -20.0 and cop_role != "spike":
			want = minf(want, race.player.kmh() + 45.0)
	# corner speed from the precomputed line, scaled by confidence
	var ahead: int = race.sample_index(progress + clampf(kmh() * 0.22, 10.0, 46.0))
	if race.line_speed.size() > ahead:
		var corner: float = race.line_speed[ahead] * brake_confidence
		want = minf(want, corner)
	if _mistake_t > 0.0 and randf() < 0.4:
		want *= 0.85         # panic brake tap
	# slipstream pull when tucked behind another car
	for other in race.all_vehicles():
		if other == self or not is_instance_valid(other) or not ("progress" in other): continue
		var g2: float = other.progress - progress
		if g2 > 5.0 and g2 < 30.0 and absf((other.lateral if "lateral" in other else 0.0) - lateral) < 1.4:
			want += 12.0
			break
	if spike_t > 0.0: want *= 0.45
	# damaged suspects drive sloppier, not slower
	if role == Role.TARGET and hp < 60.0:
		lane = sin(Time.get_ticks_msec() * 0.001 * (2.0 + (100.0 - hp) * 0.03)) * (100.0 - hp) * 0.02
	return want

func _steer_to(target: Vector3, delta: float) -> void:
	var local := global_transform.affine_inverse() * target
	var angle := atan2(-local.x, -local.z)
	var max_steer := lerpf(0.4, 0.09, clampf(kmh() / 240.0, 0.0, 1.0))
	var err := clampf(angle * 0.7, -max_steer, max_steer)
	if _mistake_t > 0.0: err += _mistake_steer * 0.1
	steering = move_toward(steering, err, delta * (2.4 + skill * 0.8))

func _throttle_to(desired: float, delta: float) -> void:
	var speed := kmh()
	var grounded := false
	for w in wheels:
		if w.is_in_contact(): grounded = true; break
	var throttle := 1.0 if speed < desired - 4.0 else 0.0
	var force := trans.update(delta, speed, throttle, false, grounded, 1.0)
	if _nitro_t > 0.0: force *= 1.6
	if speed < desired - 4.0 and grounded:
		engine_force = -force
		brake = 0.0
	elif speed > desired + 12.0:
		engine_force = 0.0
		brake = 16.0 * brake_confidence
	else:
		engine_force = -force * 0.2 if grounded else 0.0
		brake = 0.4

# Recovery without visible teleports: gentle nudges when the player can
# see us; reposition only when far away or behind the camera.
func _stuck_check(delta: float) -> void:
	var stalled := false
	if kmh() < 7.0 and not wrecked:
		stuck_t += delta
		stalled = stuck_t > 3.0
	else:
		stuck_t = 0.0
	if absf(progress - _last_prog) < 8.0:
		_stall_t += delta
		if _stall_t > 6.0: stalled = true
	else:
		_last_prog = progress
		_stall_t = 0.0
	if not stalled or wrecked: return
	stuck_t = 0.0
	_stall_t = 0.0
	_last_prog = progress
	var visible_to_player := false
	if race.player and is_instance_valid(race.player):
		var to_me: Vector3 = global_position - race.player.global_position
		var pfwd: Vector3 = -race.player.global_transform.basis.z
		visible_to_player = to_me.length() < 150.0 and pfwd.dot(to_me.normalized()) > 0.1
	if visible_to_player:
		# on-screen: physical nudge back toward the road, never a teleport
		var idx: int = race.sample_index(progress + 6.0)
		var s: Dictionary = race.samples[idx]
		var dir: Vector3 = (s.pos + Vector3.UP * 0.5 - global_position).normalized()
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		apply_central_impulse(dir * mass * 8.0 + Vector3.UP * mass * 2.0)
		return
	# off-screen: quietly reposition at a clear spot
	for attempt in 6:
		var d := clampf(progress + 10.0 + attempt * 8.0, 0.0, race.length - 2.0)
		var idx2: int = race.sample_index(d)
		var s2: Dictionary = race.samples[idx2]
		var blocked := false
		for v in race.all_vehicles():
			if is_instance_valid(v) and v != self and v is Node3D \
					and v.global_position.distance_to(s2.pos) < 9.0:
				blocked = true
				break
		if not blocked:
			global_transform = Transform3D(Basis.looking_at(s2.fwd, s2.up),
				s2.pos + s2.right * clampf(lane, -4.0, 4.0) * 0.5 + Vector3.UP * 1.0)
			linear_velocity = s2.fwd * 22.0
			angular_velocity = Vector3.ZERO
			return

func _on_body_entered(body: Node) -> void:
	if race == null: return
	if body is StaticBody3D and not body.has_meta("roadblock") and not body.has_meta("chevron") and body.name != "Rails":
		return
	var other_vel := Vector3.ZERO
	if body is RigidBody3D: other_vel = body.linear_velocity
	var rel := (_prev_vel - other_vel).length()
	if rel < 4.0: return
	var dir := Vector3.ZERO
	if body is Node3D:
		dir = (global_position - body.global_position).normalized()
	var impact_scale := 0.28          # AI trade paint without self-destructing
	if body == race.player: impact_scale = 0.8
	take_impact(global_position - dir * 1.0 + Vector3.UP * 0.5, dir, rel * impact_scale)
	if role == Role.COP and body == race.player:
		ram_cd = 2.2 / P.diff().aggro
	race.on_ai_impact(self, body, rel)
	if hp <= 0.0 and not wrecked:
		wreck()
		race.on_ai_wrecked(self)
