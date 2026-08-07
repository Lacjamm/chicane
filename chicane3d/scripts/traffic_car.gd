# ============================================================
# CHICANE 3D — traffic_car.gd
# Civilian traffic: frozen rigid bodies gliding along the road.
# A hard hit unfreezes them into full physics — BeamNG chaos.
# ============================================================
class_name TrafficCar
extends RigidBody3D

var race: Node = null
var speed_kmh := 80.0
var lane := 3.0
var progress := 0.0
var lateral := 0.0
var oncoming := false
var hit_free := false            # true once physics has taken over
var visual: Node3D
var _life_after_hit := 8.0

const COLORS := ["c8ccd2", "4a5560", "7a4a2a", "3a5a8a", "5a5a5a", "8a3a3a"]

var kind := "car"                 # car | van | truck
var _lane_change_t := 0.0
var _target_lane := 0.0
var _braking := false

func setup_traffic(rm: Node, start_d: float, in_lane: float, is_oncoming: bool) -> void:
	race = rm
	lane = in_lane
	_target_lane = in_lane
	oncoming = is_oncoming
	progress = start_d
	_lane_change_t = randf_range(6.0, 20.0)
	var roll := randf()
	kind = "truck" if roll < 0.12 else "van" if roll < 0.3 else "car"
	speed_kmh = randf_range(48.0, 70.0) if kind == "truck" else randf_range(55.0, 95.0)
	mass = 3200.0 if kind == "truck" else 1900.0 if kind == "van" else 1400.0
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 4
	var shape := {"len":4.3, "wid":1.85, "nose":0.6, "tail":0.6, "wing":0.0}
	match kind:
		"van": shape = {"len":4.8, "wid":2.0, "nose":0.4, "tail":0.9, "wing":0.0}
		"truck": shape = {"len":7.5, "wid":2.3, "nose":0.3, "tail":1.0, "wing":0.0}
	visual = CarFactory.build_visual(COLORS[randi() % COLORS.size()], "gloss", shape, false)
	visual.set_meta("shape", shape)
	if kind != "car":
		# boxy cargo body over the hull
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(shape.wid * 0.96, 1.5 if kind == "van" else 2.4, shape.len * 0.62)
		box.mesh = bm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.75, 0.74, 0.72) if kind == "truck" else Color(0.6, 0.62, 0.66)
		box.material_override = mm
		box.position = Vector3(0, (1.5 if kind == "van" else 2.4) * 0.5 + 0.5, shape.len * 0.12)
		visual.add_child(box)
	add_child(visual)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.85, 0.9, 4.1)
	cs.shape = bs
	cs.position.y = 0.5
	add_child(cs)
	# fake wheels (visual only — this is background traffic)
	for p in [Vector3(-0.8, 0.32, -1.4), Vector3(0.8, 0.32, -1.4), Vector3(-0.8, 0.32, 1.4), Vector3(0.8, 0.32, 1.4)]:
		var w := CarFactory.wheel_visual(0.33)
		w.position = p
		add_child(w)
	body_entered.connect(_on_hit)
	_place()

func _place() -> void:
	var idx := clampi(int(progress / TrackGen.SAMPLE), 0, race.samples.size() - 1)
	var s: Dictionary = race.samples[idx]
	var fwd: Vector3 = -s.fwd if oncoming else s.fwd
	global_transform = Transform3D(Basis.looking_at(fwd, s.up), s.pos + s.right * lane + Vector3.UP * 0.6)

func _physics_process(delta: float) -> void:
	if hit_free:
		_life_after_hit -= delta
		if _life_after_hit < 0.0 and race.player and (race.player.progress - progress) > 60.0:
			queue_free()
		return
	var dir := -1.0 if oncoming else 1.0
	var cruise := speed_kmh
	_braking = false
	# pull aside + slow for sirens during pursuits
	if race.wanted and race.heat > 0 and not oncoming:
		var cop_near := false
		for c in race.cops:
			if is_instance_valid(c) and not c.dead and absf(c.progress - progress) < 90.0:
				cop_near = true
				break
		if cop_near or absf(race.player.progress - progress) < 60.0:
			_target_lane = 6.0 * signf(lane if lane != 0.0 else 1.0)
			cruise *= 0.55
			_braking = true
	# panic swerve + brake when the player blasts past
	if race.player and is_instance_valid(race.player):
		var pgap: float = progress - race.player.progress
		if absf(pgap) < 14.0 and absf(race.player.lateral - lane) < 2.4 and race.player.kmh() > 150.0:
			_target_lane = clampf(lane + (2.2 if race.player.lateral < lane else -2.2), -6.0, 6.0)
			cruise *= 0.7
			_braking = true
	# occasional casual lane change
	_lane_change_t -= delta
	if _lane_change_t <= 0.0:
		_lane_change_t = randf_range(8.0, 22.0)
		var lanes := [-5.2, -2.2, 2.2, 5.2]
		_target_lane = lanes[randi() % 4] * (1.0 if not oncoming else 1.0)
		if oncoming: _target_lane = -absf(_target_lane)
	lane = move_toward(lane, _target_lane, delta * 1.6)
	if visual:
		var tl: MeshInstance3D = visual.get_node_or_null("taillights")
		if tl and tl.material_override is StandardMaterial3D:
			tl.material_override.emission_energy_multiplier = 4.0 if _braking else 1.2
	progress += dir * cruise / 3.6 * delta
	lateral = lane
	if progress < 4.0 or progress > race.length - 4.0:
		_respawn_ahead()
		return
	_place()
	# recycle far-behind traffic
	if race.player and race.player.progress - progress > 140.0:
		_respawn_ahead()

func _respawn_ahead() -> void:
	if race.player == null: return
	progress = race.player.progress + randf_range(180.0, 700.0)
	if progress > race.length - 10.0:
		progress = fmod(progress, maxf(race.length - 20.0, 30.0)) + 10.0
	lane = [-5.2, -2.2, 2.2, 5.2][randi() % 4]
	oncoming = lane < 0.0 and race.allows_oncoming() and randf() < 0.4
	speed_kmh = randf_range(55.0, 95.0)
	_place()

# Missile kill: physics takes over and the shell gets launched skyward.
# The regular _life_after_hit cleanup removes the carcass; RaceManager
# spawns a fresh replacement after its respawn delay.
func blow_up(from: Vector3) -> void:
	if hit_free: return
	hit_free = true
	freeze = false
	var dir := (global_position - from + Vector3.UP * 1.5).normalized()
	CarFactory.deform(visual, from, dir, 1.4)
	linear_velocity = dir * randf_range(9.0, 14.0) + Vector3.UP * 9.0
	angular_velocity = Vector3(randf_range(-4, 4), randf_range(-6, 6), randf_range(-4, 4))

func _on_hit(body: Node) -> void:
	if hit_free: return
	var rel := 0.0
	var vel := Vector3.ZERO
	if body is RigidBody3D:
		vel = body.linear_velocity
		rel = (vel - linear_velocity).length()
	if rel > 8.0:
		# physics takes over — get launched, crumple, spin
		hit_free = true
		freeze = false
		linear_velocity = vel * 0.65
		angular_velocity = Vector3(randf_range(-3, 3), randf_range(-5, 5), randf_range(-3, 3))
		var dir: Vector3 = (global_position - body.global_position).normalized()
		CarFactory.deform(visual, global_position - dir + Vector3.UP * 0.5, dir, clampf(rel / 22.0, 0.3, 1.4))
		if race: race.on_traffic_hit(self, body, rel)
