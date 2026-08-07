# ============================================================
# CHICANE 3D — weapons.gd
# The player's pick-3 weapon loadout (D.WEAPONS / P.loadout()).
# Owned by RaceManager; slot keys are wpn1/wpn2/wpn3 (F/G/H).
# All weapons have unlimited ammo — cooldowns only. Every kill
# routes through race.destroy_vehicle so the 10s respawn applies.
# ============================================================
class_name Weapons
extends Node

var race: Node = null
var slots: Array = []
var cds := [0.0, 0.0, 0.0]
var active := {}                 # weapon id -> seconds remaining (sword/chainsaw/ball)
var _bombs: Array = []           # {node, t}
var _tracers: Array = []         # {node, t}
var _blades: Array = []
var _saw: Node3D = null
var _ball: Node3D = null
var _ball_angle := 0.0
var _flame_fx: GPUParticles3D = null
var _flame_t := 0.0

func setup(r: Node) -> void:
	race = r
	slots = P.loadout()
	if "emp" in slots:
		race.w_emp = 99          # roster EMP is unlimited like everything else

func update(delta: float) -> void:
	for i in 3:
		cds[i] = maxf(cds[i] - delta, 0.0)
	_tick_active(delta)
	_tick_bombs(delta)
	_tick_fx(delta)
	if race.player == null or not race.player.controls_enabled:
		return
	for i in slots.size():
		var wid: String = slots[i]
		var w: Dictionary = D.WEAPONS[wid]
		var act := "wpn%d" % (i + 1)
		var want: bool = Input.is_action_pressed(act) if w.hold else Input.is_action_just_pressed(act)
		if want and cds[i] <= 0.0:
			fire_slot(i)

# Also called directly by the test bot.
func fire_slot(i: int) -> void:
	if i < 0 or i >= slots.size(): return
	var wid: String = slots[i]
	if cds[i] > 0.0: return
	cds[i] = float(D.WEAPONS[wid].cd)
	match wid:
		"missile":  race._fire_missile()
		"emp":      race._fire_emp()
		"gun":      _fire_gun()
		"bomb":     _drop_bomb()
		"flame":    _fire_flame()
		"freeze":   _fire_freeze()
		"shock":    _fire_shock()
		"sword":    _activate("sword")
		"chainsaw": _activate("chainsaw")
		"ball":     _activate("ball")

# ---------- targeting helpers ----------
func _nearest_ahead(max_d: float, max_lat: float, cars_only := false) -> Node3D:
	var best: Node3D = null
	var best_gap := 1e9
	for v in race.all_vehicles():
		if not is_instance_valid(v): continue
		if v is VehicleBase and v.wrecked: continue
		if v is TrafficCar and (v.hit_free or cars_only): continue
		var gap: float = v.progress - race.player.progress
		if race.is_loop:
			gap = fposmod(gap + race.length * 0.5, race.length) - race.length * 0.5
		if gap > -8.0 and gap < max_d and absf(v.lateral - race.player.lateral) < max_lat:
			if absf(gap) < best_gap:
				best_gap = absf(gap)
				best = v
	return best

func _local_to_player(v: Node3D) -> Vector3:
	return race.player.global_transform.affine_inverse() * v.global_position

# ---------- machine guns ----------
func _fire_gun() -> void:
	var p: Node3D = race.player
	var muzzle: Vector3 = p.global_position + -p.global_transform.basis.z * 2.2 + Vector3.UP * 0.7
	var target := _nearest_ahead(130.0, 9.0)
	var hit_pos: Vector3 = muzzle + -p.global_transform.basis.z * 60.0
	if target != null:
		hit_pos = target.global_position + Vector3.UP * 0.5
		if target is AICar:
			target.take_impact(hit_pos, (hit_pos - muzzle).normalized(), 7.0, 1.2)
			if target.hp <= 0.0:
				race.destroy_vehicle(target, hit_pos)
		elif target is TrafficCar:
			var hits: int = target.get_meta("gun_hits", 0) + 1
			target.set_meta("gun_hits", hits)
			if hits >= 6:
				race.destroy_vehicle(target, hit_pos)
	_tracer(muzzle, hit_pos)
	SFX.play("shift", -18.0)

func _tracer(from: Vector3, to: Vector3) -> void:
	var seg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, from.distance_to(to))
	seg.mesh = bm
	seg.material_override = CarFactory.emissive(Color(1.0, 0.85, 0.3), 3.0)
	race.add_child(seg)
	seg.global_position = (from + to) * 0.5
	if absf((to - from).normalized().dot(Vector3.UP)) < 0.99:
		seg.look_at(to, Vector3.UP)
	_tracers.append({"node": seg, "t": 0.06})

# ---------- bombs ----------
func _drop_bomb() -> void:
	var p: Node3D = race.player
	var b := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.12)
	mat.metallic = 0.7
	mat.roughness = 0.3
	mi.material_override = mat
	b.add_child(mi)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.2, 0.1)
	glow.omni_range = 3.0
	glow.light_energy = 1.5
	b.add_child(glow)
	race.add_child(b)
	b.global_position = p.global_position + p.global_transform.basis.z * 3.2 + Vector3.UP * 0.4
	_bombs.append({"node": b, "t": 1.6})
	SFX.play("ui_click", -10.0)

func _tick_bombs(delta: float) -> void:
	for i in range(_bombs.size() - 1, -1, -1):
		var e: Dictionary = _bombs[i]
		if not is_instance_valid(e.node):
			_bombs.remove_at(i)
			continue
		e.t -= delta
		var boom: bool = e.t <= 0.0
		if not boom:
			for v in race.all_vehicles():
				if is_instance_valid(v) and v != race.player \
						and v.global_position.distance_to(e.node.global_position) < 3.2:
					boom = true
					break
		if boom:
			race.missile_blast(e.node.global_position)
			e.node.queue_free()
			_bombs.remove_at(i)

# ---------- flamethrower ----------
func _fire_flame() -> void:
	var p: Node3D = race.player
	if _flame_fx == null or not is_instance_valid(_flame_fx):
		_flame_fx = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 0, -1)
		pm.spread = 9.0
		pm.initial_velocity_min = 26.0
		pm.initial_velocity_max = 34.0
		pm.gravity = Vector3(0, 2.0, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.6
		pm.color = Color(1.0, 0.5, 0.1, 0.85)
		_flame_fx.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.5, 0.5)
		var qm := StandardMaterial3D.new()
		qm.albedo_color = Color(1.0, 0.55, 0.12, 0.85)
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.vertex_color_use_as_albedo = true
		quad.material = qm
		_flame_fx.draw_pass_1 = quad
		_flame_fx.lifetime = 0.5
		_flame_fx.amount = 90
		_flame_fx.position = Vector3(0, 0.6, -2.2)
		p.add_child(_flame_fx)
	_flame_fx.emitting = true
	_flame_t = 0.25
	for v in race.all_vehicles():
		if not is_instance_valid(v) or v == race.player: continue
		var l := _local_to_player(v)
		if l.z < 0.0 and l.z > -17.0 and absf(l.x) < -l.z * 0.5 + 1.6:
			if v is AICar and not v.wrecked:
				v.take_impact(v.global_position, -race.player.global_transform.basis.z, 8.0, 1.4)
				if v.hp <= 0.0:
					race.destroy_vehicle(v, v.global_position)
			elif v is TrafficCar and not v.hit_free:
				var burn: int = v.get_meta("burn", 0) + 1
				v.set_meta("burn", burn)
				if burn >= 5:
					race.destroy_vehicle(v, v.global_position)

# ---------- freeze ray ----------
func _fire_freeze() -> void:
	var target := _nearest_ahead(110.0, 10.0, true)   # AI cars only
	if target == null or not (target is AICar):
		race.toast("Freeze ray — no target in range", "warn")
		return
	var p: Node3D = race.player
	_tracer(p.global_position + Vector3.UP * 0.7, target.global_position + Vector3.UP * 0.6)
	_tracers[_tracers.size() - 1].node.material_override = CarFactory.emissive(Color(0.5, 0.85, 1.0), 3.0)
	target.stun(4.0)
	target.linear_velocity *= 0.15
	# ice shell that melts off with the stun
	var ice := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.3, 1.5, 4.9)
	ice.mesh = bm
	var im := StandardMaterial3D.new()
	im.albedo_color = Color(0.6, 0.85, 1.0, 0.35)
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.roughness = 0.05
	im.metallic = 0.3
	ice.material_override = im
	ice.position = Vector3(0, 0.75, 0)
	target.add_child(ice)
	var tw := ice.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(im, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(ice.queue_free)
	race.toast("FROZEN SOLID!", "good")
	SFX.play("glass", -6.0)

# ---------- shockwave ----------
func _fire_shock() -> void:
	var p: Node3D = race.player
	var pos: Vector3 = p.global_position
	for v in race.all_vehicles():
		if not is_instance_valid(v) or v == p: continue
		var d: float = v.global_position.distance_to(pos)
		if d > 14.0: continue
		var dir: Vector3 = (v.global_position - pos + Vector3.UP * 2.0).normalized()
		if v is AICar:
			v.take_impact(v.global_position, dir, 15.0, 1.0)
			v.apply_central_impulse(dir * v.mass * 9.0)
			if v.hp <= 0.0 and not v.wrecked:
				race.destroy_vehicle(v, pos)
		elif v is TrafficCar and not v.hit_free:
			v.hit_free = true
			v.freeze = false
			v.linear_velocity = dir * 14.0
			v.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-5, 5), randf_range(-3, 3))
	if p.chase: p.chase.shake(6.0)
	race._blast_visual(pos + Vector3.UP * 0.5)
	SFX.play("emp", -4.0)

# ---------- timed melee weapons: blades / chainsaw / wrecking ball ----------
func _activate(wid: String) -> void:
	active[wid] = float(D.WEAPONS[wid].dur)
	SFX.play("shift", -8.0)
	var p: Node3D = race.player
	match wid:
		"sword":
			for side in [-1.0, 1.0]:
				var blade := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(1.7, 0.06, 0.5)
				blade.mesh = bm
				blade.material_override = CarFactory.emissive(Color(0.8, 0.9, 1.0), 2.0)
				blade.position = Vector3(side * 1.7, 0.55, 0.0)
				p.add_child(blade)
				_blades.append(blade)
			race.toast("BLADE WINGS OUT!", "good")
		"chainsaw":
			_saw = MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(1.8, 0.5, 0.9)
			(_saw as MeshInstance3D).mesh = sm
			(_saw as MeshInstance3D).material_override = CarFactory.emissive(Color(1.0, 0.35, 0.1), 2.0)
			_saw.position = Vector3(0, 0.5, -2.6)
			p.add_child(_saw)
			race.toast("CHAINSAW REVVED!", "good")
		"ball":
			_ball = MeshInstance3D.new()
			var ballm := SphereMesh.new()
			ballm.radius = 0.9
			ballm.height = 1.8
			(_ball as MeshInstance3D).mesh = ballm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.18, 0.18, 0.2)
			mat.metallic = 0.9
			mat.roughness = 0.35
			(_ball as MeshInstance3D).material_override = mat
			race.add_child(_ball)
			_ball_angle = 0.0
			race.toast("WRECKING BALL!", "good")

func _tick_active(delta: float) -> void:
	for wid in active.keys():
		active[wid] -= delta
		if active[wid] <= 0.0:
			active.erase(wid)
			_clear_weapon_fx(wid)
			continue
		match wid:
			"sword":
				_melee_kill(func(l: Vector3) -> bool:
					return absf(l.x) < 3.4 and absf(l.x) > 0.6 and absf(l.z) < 3.2)
			"chainsaw":
				_melee_kill(func(l: Vector3) -> bool:
					return l.z < 1.0 and l.z > -4.8 and absf(l.x) < 2.2)
			"ball":
				if _ball and is_instance_valid(_ball) and race.player:
					_ball_angle += delta * 3.4
					var off := Vector3(cos(_ball_angle), 0.0, sin(_ball_angle)) * 5.5
					_ball.global_position = race.player.global_position + off + Vector3.UP * 0.8
					for v in race.all_vehicles():
						if is_instance_valid(v) and v != race.player \
								and v.global_position.distance_to(_ball.global_position) < 2.6:
							race.destroy_vehicle(v, _ball.global_position)

func _melee_kill(zone_check: Callable) -> void:
	for v in race.all_vehicles():
		if not is_instance_valid(v) or v == race.player: continue
		if v is VehicleBase and v.wrecked: continue
		if v is TrafficCar and v.hit_free: continue
		if v.global_position.distance_to(race.player.global_position) > 7.0: continue
		if zone_check.call(_local_to_player(v)):
			race.destroy_vehicle(v, v.global_position)

func _clear_weapon_fx(wid: String) -> void:
	match wid:
		"sword":
			for b in _blades:
				if is_instance_valid(b): b.queue_free()
			_blades.clear()
		"chainsaw":
			if _saw and is_instance_valid(_saw): _saw.queue_free()
			_saw = null
		"ball":
			if _ball and is_instance_valid(_ball): _ball.queue_free()
			_ball = null

func _tick_fx(delta: float) -> void:
	if _flame_fx and is_instance_valid(_flame_fx):
		_flame_t -= delta
		if _flame_t <= 0.0:
			_flame_fx.emitting = false
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i].t -= delta
		if _tracers[i].t <= 0.0:
			if is_instance_valid(_tracers[i].node): _tracers[i].node.queue_free()
			_tracers.remove_at(i)
