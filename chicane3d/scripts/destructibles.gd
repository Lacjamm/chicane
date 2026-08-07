# ============================================================
# CHICANE 3D — destructibles.gd
# Shootable roadside buildings. Four types, each with its own
# death: glass towers shatter, concrete blocks crumble into
# rubble and dust, fuel tanks go up in a fireball that chains
# into a real weapon blast, neon signs short out and topple.
# Owned by RaceManager; every weapon routes damage through
# damage()/destroy().
# ============================================================
class_name Destructibles
extends Node3D

# hp = weapon hits to fell it (blasts and melee do 99)
const TYPES := {
	"tower": {"hp": 4, "label": "GLASS TOWER SHATTERED"},
	"block": {"hp": 6, "label": "BUILDING DEMOLISHED"},
	"tank":  {"hp": 2, "label": "FUEL TANK IGNITED"},
	"sign":  {"hp": 1, "label": "NEON SIGN SHORTED"},
}

var race: Node = null
var buildings: Array = []

func setup(r: Node) -> void:
	race = r
	var spacing := 190.0
	if race.mode == "roam": spacing = 420.0
	var d := 240.0
	var i := 0
	while d < race.length - 80.0 and buildings.size() < 140:
		_spawn(d, i)
		d += spacing * randf_range(0.7, 1.5)
		i += 1

func _spawn(d: float, i: int) -> void:
	var s: Dictionary = race.samples[race.sample_index(d)]
	var side := 1.0 if i % 2 == 0 else -1.0
	var t: String = TYPES.keys()[randi() % TYPES.size()]
	var b := StaticBody3D.new()
	b.set_meta("destructible", t)
	b.set_meta("bhp", int(TYPES[t].hp))
	var size := Vector3.ZERO
	match t:
		"tower":
			size = Vector3(6.0, randf_range(13.0, 22.0), 6.0)
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.25, 0.5, 0.65)
			glass.metallic = 0.8
			glass.roughness = 0.15
			glass.emission_enabled = true
			glass.emission = Color(0.3, 0.7, 0.9)
			glass.emission_energy_multiplier = 0.4
			b.add_child(_box(size, glass))
		"block":
			size = Vector3(8.0, randf_range(5.0, 9.0), 8.0)
			var conc := StandardMaterial3D.new()
			conc.albedo_color = Color(0.52, 0.5, 0.47)
			conc.roughness = 0.95
			b.add_child(_box(size, conc))
		"tank":
			size = Vector3(6.0, 7.0, 6.0)
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 3.0
			cyl.bottom_radius = 3.0
			cyl.height = 7.0
			mi.mesh = cyl
			var rust := StandardMaterial3D.new()
			rust.albedo_color = Color(0.75, 0.42, 0.12)
			rust.roughness = 0.6
			rust.metallic = 0.5
			mi.material_override = rust
			mi.position.y = 3.5
			b.add_child(mi)
			var stripe := _box(Vector3(6.1, 0.8, 6.1), CarFactory.emissive(Color(1.0, 0.15, 0.1), 1.2))
			stripe.position.y = 5.6
			b.add_child(stripe)
		"sign":
			size = Vector3(7.0, 9.0, 0.8)
			var pole := _box(Vector3(0.5, 5.0, 0.5), null)
			pole.position.y = 2.5
			b.add_child(pole)
			var neon := [Color(1, 0.2, 0.8), Color(0.2, 1, 0.9), Color(1, 0.8, 0.1), Color(0.4, 1, 0.3)]
			var board := _box(Vector3(7.0, 4.0, 0.6), CarFactory.emissive(neon[randi() % 4], 2.2))
			board.position.y = 7.0
			b.add_child(board)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	b.add_child(cs)
	b.set_meta("rad", maxf(size.x, size.z) * 0.5 + 1.2)
	add_child(b)
	var lat: float = side * (TrackGen.ROAD_HALF + randf_range(8.0, 16.0) + size.x * 0.5)
	b.global_transform = Transform3D(Basis.looking_at(s.fwd, s.up), s.pos + s.right * lat)
	buildings.append(b)

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if mat: mi.material_override = mat
	mi.position.y = size.y * 0.5
	return mi

func query_radius(pos: Vector3, r: float) -> Array:
	return buildings.filter(func(b):
		return is_instance_valid(b) and pos.distance_to(b.global_position) < r + float(b.get_meta("rad")))

func damage(b: StaticBody3D, amount: int, from: Vector3) -> void:
	if not is_instance_valid(b) or b.get_meta("destroyed", false): return
	var hp: int = b.get_meta("bhp") - amount
	b.set_meta("bhp", hp)
	if hp <= 0:
		destroy(b, from)

func destroy(b: StaticBody3D, from: Vector3) -> void:
	if not is_instance_valid(b) or b.get_meta("destroyed", false): return
	b.set_meta("destroyed", true)
	buildings.erase(b)
	var t: String = b.get_meta("destructible")
	race.buildings_destroyed += 1
	race.bounty += 100.0
	race.toast(str(TYPES[t].label) + " +100", "good")
	if race.player and b.global_position.distance_to(race.player.global_position) < 60.0 \
			and race.player.chase:
		race.player.chase.shake(5.0)
	# collision off right away so the falling shell can't wall anyone
	for c in b.get_children():
		if c is CollisionShape3D: c.set_deferred("disabled", true)
	match t:
		"tower":
			_shards(b.global_position + Vector3.UP * 6.0, Color(0.5, 0.85, 1.0), 90, 9.0)
			SFX.play("glass", -2.0)
			_collapse(b, from, 1.1)
		"block":
			_shards(b.global_position + Vector3.UP * 3.0, Color(0.6, 0.55, 0.48), 60, 6.0)
			_dust(b.global_position)
			_rubble(b.global_position, from)
			SFX.crash(true)
			_collapse(b, from, 1.4)
		"tank":
			# the big one: a real weapon blast — wrecks nearby cars and
			# chains into any neighbouring destructibles
			SFX.crash(true)
			race.missile_blast(b.global_position + Vector3.UP * 2.0)
			_shards(b.global_position + Vector3.UP * 4.0, Color(1.0, 0.55, 0.1), 80, 12.0)
			_collapse(b, from, 0.5)
		"sign":
			_shards(b.global_position + Vector3.UP * 7.0, Color(0.7, 0.9, 1.0), 50, 7.0)
			SFX.play("emp", -8.0)
			_topple(b, from)

# fall away from the impact and sink into the ground, then free
func _collapse(b: Node3D, from: Vector3, dur: float) -> void:
	var away := (b.global_position - from)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "global_position", b.global_position + Vector3.DOWN * 6.0 + away * 2.0, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "rotation", b.rotation + Vector3(away.z, 0.0, -away.x) * 0.4, dur)
	tw.tween_property(b, "scale", Vector3(1.05, 0.25, 1.05), dur)
	tw.chain().tween_callback(b.queue_free)

func _topple(b: Node3D, from: Vector3) -> void:
	var away := (b.global_position - from)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var tw := b.create_tween()
	tw.tween_property(b, "rotation", b.rotation + Vector3(away.z, 0.0, -away.x) * 1.5, 0.7) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_callback(b.queue_free)

func _shards(pos: Vector3, col: Color, amount: int, speed: float) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed * 1.4
	pm.gravity = Vector3(0, -14.0, 0)
	pm.scale_min = 0.15
	pm.scale_max = 0.5
	pm.color = col
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = col
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	quad.material = qm
	p.draw_pass_1 = quad
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.2
	p.amount = amount
	add_child(p)
	p.global_position = pos
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(p.queue_free)

func _dust(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 85.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	pm.color = Color(0.55, 0.5, 0.44, 0.55)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.55, 0.5, 0.44, 0.55)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	quad.material = qm
	p.draw_pass_1 = quad
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 2.2
	p.amount = 40
	add_child(p)
	p.global_position = pos + Vector3.UP * 1.5
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(p.queue_free)

func _rubble(pos: Vector3, from: Vector3) -> void:
	for i in 5:
		var deb := RigidBody3D.new()
		deb.mass = 40.0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * randf_range(0.8, 1.6)
		cs.shape = bs
		deb.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.47, 0.44)
		mat.roughness = 1.0
		mi.material_override = mat
		deb.add_child(mi)
		add_child(deb)
		deb.global_position = pos + Vector3(randf_range(-2, 2), randf_range(1, 4), randf_range(-2, 2))
		var away := (pos - from).normalized() if pos.distance_to(from) > 0.1 else Vector3.UP
		deb.linear_velocity = away * randf_range(3.0, 8.0) + Vector3.UP * randf_range(4.0, 9.0)
		deb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		var tw := deb.create_tween()
		tw.tween_interval(4.0)
		tw.tween_callback(deb.queue_free)
