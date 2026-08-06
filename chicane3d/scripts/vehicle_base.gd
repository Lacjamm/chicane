# ============================================================
# CHICANE 3D — vehicle_base.gd
# Shared VehicleBody3D: procedural visuals, wheels, damage,
# BeamNG-style deformation, detachable panels, fire/smoke.
# ============================================================
class_name VehicleBase
extends VehicleBody3D

var car_id := ""
var stats := {}                 # top, acc, hand, drift, str, nitro, kmh...
var visual: Node3D
var wheels: Array[VehicleWheel3D] = []
var is_police := false

var hp := 100.0                 # 0 = wrecked
var stun_t := 0.0               # EMP stun remaining
var spike_t := 0.0              # spiked tyres remaining
var wrecked := false
var last_impact_t := 0.0

var smoke: GPUParticles3D
var fire: GPUParticles3D
var flame_l: GPUParticles3D
var flame_r: GPUParticles3D

var _flash_t := 0.0
var _detached := {}

func kmh() -> float:
	return linear_velocity.length() * 3.6

func setup(id: String, s: Dictionary, paint: String, finish: String, police := false, skin := "") -> void:
	car_id = id
	stats = s
	is_police = police
	var def := D.car_def(id)
	var shape: Dictionary = def.get("shape", {"len":4.6,"wid":2.0,"nose":1.0,"tail":0.6,"wing":0.5})
	mass = 1150.0 + s.get("str", 5.0) * 90.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.25, 0.05)
	contact_monitor = true
	max_contacts_reported = 6

	# v5: cars with imported model skins use them by default ("proc" = procedural)
	# v7: if the model files are not installed, fall back to the procedural
	# body silently — the game must stay fully playable without model packs.
	var use_skin := skin
	if (use_skin == "" or (use_skin != "proc" and not D.skin_ok(use_skin))) and def.has("skins"):
		use_skin = ""
		for s2 in def.skins:
			if D.skin_ok(str(s2)):
				use_skin = str(s2)
				break
	if use_skin != "" and use_skin != "proc" and D.skin_ok(use_skin):
		visual = CarFactory.build_model_visual(use_skin, shape)
	else:
		visual = CarFactory.build_visual(paint, finish, shape, police)
	add_child(visual)

	# chassis collision
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(shape.wid, 0.85, shape.len * 0.94)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	add_child(cs)

	# wheels
	var wl: float = shape.len
	var ww: float = shape.wid
	for w in [
		{"n":"wfl", "p":Vector3(-ww*0.42, 0.35, -wl*0.33), "steer":true,  "trac":false},
		{"n":"wfr", "p":Vector3( ww*0.42, 0.35, -wl*0.33), "steer":true,  "trac":false},
		{"n":"wrl", "p":Vector3(-ww*0.42, 0.35,  wl*0.34), "steer":false, "trac":true},
		{"n":"wrr", "p":Vector3( ww*0.42, 0.35,  wl*0.34), "steer":false, "trac":true},
	]:
		var wheel := VehicleWheel3D.new()
		wheel.name = w.n
		wheel.position = Vector3(w.p.x, 0.30, w.p.z)
		wheel.use_as_steering = w.steer
		wheel.use_as_traction = w.trac
		wheel.wheel_radius = 0.36
		wheel.wheel_rest_length = 0.28
		wheel.suspension_travel = 0.32
		wheel.suspension_stiffness = 60.0
		wheel.suspension_max_force = 30000.0
		wheel.damping_compression = 4.0
		wheel.damping_relaxation = 5.0
		wheel.wheel_friction_slip = 3.2 + stats.get("hand", 6.0) * 0.22
		var wsets: Dictionary = visual.get_meta("wheelsets") if visual.has_meta("wheelsets") else {}
		if wsets.has(w.n):
			wheel.add_child(wsets[w.n].node)   # imported wheels spin + steer on the hub
		elif not visual.has_meta("model_skin"):
			wheel.add_child(CarFactory.wheel_visual(0.36))
		# model skins without splittable wheels keep their baked-in wheels
		add_child(wheel)
		wheels.append(wheel)

	_make_particles()

func _make_particles() -> void:
	smoke = _particles(Color(0.35, 0.35, 0.38, 0.5), 1.6, 24, Vector3(0, 1.5, 0), 2.2)
	smoke.position = Vector3(0, 0.6, -1.4)
	add_child(smoke)
	fire = _particles(Color(1.0, 0.45, 0.08, 0.85), 0.5, 40, Vector3(0, 2.4, 0), 0.9)
	fire.position = Vector3(0, 0.6, -1.4)
	add_child(fire)
	flame_l = _particles(Color(0.45, 0.62, 1.0, 0.9), 0.14, 24, Vector3(0, 0, 2.2), 0.22)
	flame_l.position = Vector3(-0.3, 0.32, 2.35)
	flame_l.local_coords = true   # flames stay glued to the exhaust
	add_child(flame_l)
	flame_r = flame_l.duplicate()
	flame_r.position.x = 0.3
	add_child(flame_r)

func _particles(col: Color, life: float, amount: int, vel: Vector3, scale_max: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = vel.normalized() if vel.length() > 0 else Vector3.UP
	mat.initial_velocity_min = vel.length() * 0.6
	mat.initial_velocity_max = vel.length() * 1.4
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = scale_max * 0.4
	mat.scale_max = scale_max
	mat.spread = 25.0
	mat.color = col
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.26)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = col
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	quad.material = qm
	p.draw_pass_1 = quad
	p.lifetime = life
	p.amount = amount
	p.emitting = false
	return p

func _physics_process(delta: float) -> void:
	last_impact_t += delta
	if stun_t > 0.0:
		stun_t -= delta
		engine_force = 0.0
		visual.visible = fmod(Time.get_ticks_msec() / 90.0, 2.0) > 0.9 if stun_t > 0.2 else true
	else:
		visual.visible = true
	if spike_t > 0.0:
		spike_t -= delta
		for w in wheels:
			w.wheel_friction_slip = 1.2
		if spike_t <= 0.0:
			for w in wheels:
				w.wheel_friction_slip = 3.2 + stats.get("hand", 6.0) * 0.22
	# state-driven particles
	smoke.emitting = hp < 55.0 and not wrecked
	fire.emitting = hp < 22.0 or wrecked
	if is_police:
		_flash_t += delta
		var bar := visual.get_node_or_null("lightbar")
		if bar:
			var phase := int(_flash_t * 6.0) % 2 == 0
			var red: MeshInstance3D = bar.get_node("red")
			var blue: MeshInstance3D = bar.get_node("blue")
			red.material_override.emission_energy_multiplier = 5.0 if phase else 0.4
			blue.material_override.emission_energy_multiplier = 0.4 if phase else 5.0
			var flash: OmniLight3D = bar.get_node("flash")
			flash.light_color = Color(1, 0.1, 0.1) if phase else Color(0.15, 0.3, 1)

# ---- damage / destruction ----
# Returns actual damage applied.
func take_impact(world_pos: Vector3, dir: Vector3, severity: float, dmg_scale := 1.0) -> float:
	if wrecked: return 0.0
	var armour: float = 1.0 - stats.get("str", 5.0) * 0.035
	var dmg: float = clampf(severity * 0.55, 0.0, 26.0) * armour * dmg_scale
	hp = maxf(hp - dmg, 0.0)
	# crumple!
	var amount := clampf(severity / 30.0, 0.1, 1.4)
	CarFactory.deform(visual, world_pos, dir, amount)
	# light breakage by impact end
	if severity > 11.0:
		var local_z := (global_transform.affine_inverse() * world_pos).z
		if local_z < -0.5 and hp < 75.0: break_lights(true)
		elif local_z > 0.5 and hp < 75.0: break_lights(false)
	# progressive panel loss — BeamNG-style shedding
	if hp < 70.0 and severity > 9.0: _maybe_detach("fbumper", dir)
	if hp < 55.0 and severity > 9.0: _maybe_detach("wing", dir + Vector3.UP * 4.0)
	if hp < 40.0 and severity > 12.0: _maybe_detach("rbumper", dir)
	if hp < 30.0 and severity > 12.0: _maybe_detach("skirt_l" if randf() < 0.5 else "skirt_r", dir + Vector3.UP * 2.0)
	if hp < 20.0 and severity > 14.0: _maybe_detach("deck", dir + Vector3.UP * 5.0)
	# cracked windscreen once battered
	if hp < 50.0 and not _detached.has("_glass"):
		_detached["_glass"] = true
		var cab: MeshInstance3D = visual.get_node_or_null("cabin")
		if cab:
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(0.55, 0.62, 0.68, 0.95)
			gm.roughness = 0.45; gm.metallic = 0.3
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cab.material_override = gm
	last_impact_t = 0.0
	return dmg

func _maybe_detach(pname: String, impulse_dir: Vector3) -> void:
	if _detached.has(pname): return
	if randf() < 0.6:
		_detached[pname] = true
		CarFactory.detach(visual, pname, impulse_dir.normalized() * randf_range(4.0, 9.0) + Vector3.UP * 3.0)

func wreck() -> void:
	if wrecked: return
	wrecked = true
	engine_force = 0.0
	brake = 2.0
	for pname in ["wing", "fbumper", "rbumper", "deck"]:
		_maybe_detach(pname, Vector3(randf_range(-4, 4), 6, randf_range(-4, 4)))
	fire.emitting = true

func stun(duration: float) -> void:
	stun_t = maxf(stun_t, duration)

func spike() -> void:
	spike_t = 3.5
	linear_velocity *= 0.7

func set_nitro_flames(on: bool) -> void:
	flame_l.emitting = on
	flame_r.emitting = on

func set_brake_light(on: bool) -> void:
	var tl: MeshInstance3D = visual.get_node_or_null("taillights")
	if tl and tl.material_override is StandardMaterial3D:
		tl.material_override.emission_energy_multiplier = 4.5 if on else 1.6

func set_reverse_light(on: bool) -> void:
	var rl: MeshInstance3D = visual.get_node_or_null("revlights")
	if rl and rl.material_override is StandardMaterial3D:
		rl.material_override.emission_energy_multiplier = 3.0 if on else 0.0

func break_lights(front: bool) -> void:
	# smashed headlights kill the beams; smashed rear kills brake glow
	if front:
		for side in [-1, 1]:
			var beam: SpotLight3D = visual.get_node_or_null("beam_%d" % side)
			if beam: beam.light_energy *= 0.25
		var hl: MeshInstance3D = visual.get_node_or_null("headlights")
		if hl and hl.material_override is StandardMaterial3D:
			hl.material_override.emission_energy_multiplier = 0.4
	else:
		var tl: MeshInstance3D = visual.get_node_or_null("taillights")
		if tl and tl.material_override is StandardMaterial3D:
			tl.material_override.emission_energy_multiplier = 0.3
