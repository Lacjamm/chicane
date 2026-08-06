# ============================================================
# CHICANE 3D — chase_cam.gd
# Spring-damped chase camera with speed FOV, brake dive,
# drift framing, impact shake, road vibration, wall avoidance,
# and chase / far / hood / bumper modes.
# ============================================================
class_name ChaseCam
extends Node3D

var player: VehicleBody3D
var cam: Camera3D
var mode := 0                       # 0 chase, 1 far, 2 hood, 3 bumper
var _vel := Vector3.ZERO            # spring velocity
var _shake_amp := 0.0
var _shake_t := 0.0
var _fov_base := 68.0
var _look_offset := 0.0             # lateral drift framing

const MODES := [
	{"back": 6.2, "up": 2.5, "fov": 68.0},
	{"back": 9.6, "up": 3.6, "fov": 64.0},
	{"back": -0.35, "up": 1.06, "fov": 74.0},   # hood
	{"back": -2.0, "up": 0.55, "fov": 78.0},    # bumper
]

func setup(p: VehicleBody3D) -> void:
	player = p
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()

func cycle_mode() -> void:
	mode = (mode + 1) % MODES.size()
	_vel = Vector3.ZERO

func shake(amp: float) -> void:
	var s: float = S.g("cam_shake")
	_shake_amp = maxf(_shake_amp, amp * s)
	_shake_t = 0.4

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player): return
	var m: Dictionary = MODES[mode]
	var basis := player.global_transform.basis
	var fwd := -basis.z
	var speed: float = player.linear_velocity.length() * 3.6
	var flat_vel := Vector3(player.linear_velocity.x, 0, player.linear_velocity.z)

	# accelerating pulls the camera back slightly, braking compresses it forward
	var long_g := 0.0
	if "accel_g" in player: long_g = player.accel_g
	# v5: player-adjustable chase distance/height (chase modes only)
	var dist_mul: float = float(S.g("cam_dist")) if mode < 2 else 1.0
	var height_mul: float = float(S.g("cam_height")) if mode < 2 else 1.0
	var back: float = m.back * dist_mul + clampf(long_g * 0.35, -0.7, 0.45)

	# drift framing: swing toward the outside of the slide
	var slip := 0.0
	if flat_vel.length() > 8.0:
		slip = rad_to_deg(fwd.signed_angle_to(flat_vel.normalized(), Vector3.UP))
	_look_offset = lerpf(_look_offset, clampf(slip * 0.035, -1.6, 1.6), delta * 3.0)

	# v7: hold Look Back (TAB / right-stick click) to check behind you
	var looking_back := Input.is_action_pressed("lookback") and mode < 2
	if looking_back:
		fwd = -fwd
	if mode >= 2:
		# rigid cockpit cameras
		var pos: Vector3 = player.global_position + basis.y * m.up + basis.z * m.back
		global_transform = Transform3D(basis, pos)
	else:
		var target: Vector3 = player.global_position - fwd * back + Vector3.UP * m.up * height_mul \
			+ basis.x * _look_offset * 0.4
		# critically-damped spring
		var stiffness := 26.0
		var damping := 10.0
		var to_target: Vector3 = target - global_position
		_vel += (to_target * stiffness - _vel * damping) * delta
		global_position += _vel * delta
		# wall avoidance: pull in if something blocks the view
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 1.2, global_position)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit:
			global_position = hit.position + (player.global_position - hit.position).normalized() * 0.3
		# v8: hard cap — spring lag can never pull the camera too far back
		var to_cam := global_position - player.global_position
		var flat := Vector3(to_cam.x, 0, to_cam.z)
		var maxd: float = back * 1.12
		if flat.length() > maxd:
			var fl2 := flat.normalized() * maxd
			global_position = player.global_position + Vector3(fl2.x, to_cam.y, fl2.z)
		var look_at_pos := player.global_position + fwd * 8.0 + Vector3.UP * 1.15 \
			+ basis.x * _look_offset
		var look_basis := Basis.looking_at(look_at_pos - global_position, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(look_basis, 1.0 - pow(0.00008, delta))

	# shake + road vibration
	var shake_off := Vector3.ZERO
	if _shake_t > 0.0:
		_shake_t -= delta
		shake_off += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_amp * 0.05 * (_shake_t / 0.4)
		if _shake_t <= 0.0: _shake_amp = 0.0
	var vib: float = clampf((speed - 120.0) / 380.0, 0.0, 0.5) * float(S.g("cam_shake"))
	shake_off.y += sin(Time.get_ticks_msec() * 0.09) * 0.012 * vib
	cam.position = shake_off

	# FOV: speed + nitrous + user offset
	var nitro_kick := 0.0
	if "nitro_on" in player and player.nitro_on: nitro_kick = 8.0
	var fov: float = m.fov + clampf(speed * 0.05, 0.0, 24.0) + nitro_kick + float(S.g("fov"))
	cam.fov = lerpf(cam.fov, fov, delta * 5.0)
