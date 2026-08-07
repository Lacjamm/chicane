# ============================================================
# CHICANE 3D — missile.gd
# Player homing missile (unlimited ammo): locks the nearest car
# ahead and detonates on proximity. Damage/respawn is handled by
# RaceManager.missile_blast so the projectile stays dumb.
# ============================================================
class_name Missile
extends Node3D

const SPEED := 95.0            # m/s floor; launches faster than the shooter
const TURN_RATE := 4.2         # rad/s homing agility
const LIFETIME := 6.0
const HIT_RANGE := 3.2

var race: Node = null
var shooter: Node3D = null
var target: Node3D = null
var vel := Vector3.ZERO
var _life := LIFETIME

func setup(rm: Node, from: Node3D, tgt: Node3D) -> void:
	race = rm
	shooter = from
	target = tgt
	var fwd: Vector3 = -from.global_transform.basis.z
	vel = fwd * maxf(from.linear_velocity.length() + 45.0, SPEED)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.14
	cm.height = 1.1
	mi.mesh = cm
	mi.rotation_degrees.x = 90.0
	mi.material_override = CarFactory.emissive(Color(1.0, 0.55, 0.1), 2.5)
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.omni_range = 7.0
	light.light_energy = 2.0
	add_child(light)
	var trail := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 8.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.25
	pm.scale_max = 0.6
	pm.color = Color(1.0, 0.7, 0.25, 0.8)
	trail.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1.0, 0.7, 0.25, 0.8)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	quad.material = qm
	trail.draw_pass_1 = quad
	trail.lifetime = 0.55
	trail.amount = 60
	trail.position.z = 0.8
	trail.emitting = true
	add_child(trail)

func _physics_process(delta: float) -> void:
	if race == null or not is_instance_valid(race):
		queue_free()
		return
	_life -= delta
	if _life <= 0.0:
		_explode()
		return
	# drop the lock once the victim is already toast
	if target != null and (not is_instance_valid(target)
			or ("wrecked" in target and target.wrecked)
			or ("hit_free" in target and target.hit_free)):
		target = null
	if target != null:
		var aim: Vector3 = target.global_position + Vector3.UP * 0.5
		if target is RigidBody3D:
			aim += target.linear_velocity * 0.12
		var want := (aim - global_position).normalized()
		var cur := vel.normalized()
		var axis := cur.cross(want)
		var ang := cur.angle_to(want)
		if axis.length() > 0.001 and ang > 0.001:
			cur = cur.rotated(axis.normalized(), minf(ang, TURN_RATE * delta))
		vel = cur * vel.length()
	global_position += vel * delta
	if vel.length() > 0.01 and absf(vel.normalized().dot(Vector3.UP)) < 0.99:
		look_at(global_position + vel, Vector3.UP)
	for v in race.all_vehicles():
		if v == shooter or not is_instance_valid(v):
			continue
		if v is VehicleBase and v.wrecked:
			continue
		if global_position.distance_to(v.global_position + Vector3.UP * 0.5) < HIT_RANGE:
			_explode()
			return
	# slam into roadside buildings too
	if race.destructibles:
		for b in race.destructibles.query_radius(global_position, HIT_RANGE * 0.5):
			_explode()
			return

func _explode() -> void:
	if race != null and is_instance_valid(race):
		race.missile_blast(global_position)
	queue_free()
