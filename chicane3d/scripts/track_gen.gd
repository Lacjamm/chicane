# ============================================================
# CHICANE 3D — track_gen.gd
# Procedural roads: Curve3D layout + ribbon meshes + zone scenery.
# ============================================================
class_name TrackGen

const ROAD_HALF := 7.5      # asphalt half width (4 lanes)
const STEP := 20.0          # layout step (m)
const SAMPLE := 6.0         # mesh sample spacing (m)

# Returns { root, curve, length, samples:[{pos, fwd, right, up}], loop }
static func generate(zone_key: String, length_km: float, seed_v: int, opts := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var zone: Dictionary = D.ZONES[zone_key]
	var curve := Curve3D.new()
	curve.bake_interval = 4.0

	var pos := Vector3.ZERO
	var heading := 0.0
	var pitch_h := 0.0
	var target_len := length_km * 1000.0
	var straight: bool = opts.get("straight", false)
	var curviness: float = opts.get("curviness",
		1.5 if zone_key == "mountain" else 1.15 if zone_key == "neon" else 0.65 if zone_key == "coastal"
		else 0.5 if zone_key == "desert" else 1.25 if zone_key == "blacktrack" else 0.9)
	var hilliness: float = 1.5 if zone_key == "mountain" else 0.7 if zone_key == "coastal" else 0.45

	var dist := 0.0
	curve.add_point(pos)
	# launch straight
	for i in 6:
		pos += Vector3(sin(heading), 0, -cos(heading)) * STEP
		dist += STEP
		curve.add_point(pos)
	while dist < target_len:
		var r := rng.randf()
		var n := rng.randi_range(6, 16)
		var curv := 0.0
		var grade := 0.0
		if not straight:
			if r < 0.60:
				curv = rng.randf_range(-1.0, 1.0) * 0.055 * curviness
				if absf(curv) < 0.012: curv = 0.0
				grade = rng.randf_range(-1.0, 1.0) * 0.035 * hilliness
			elif r < 0.75 and curviness > 1.0:
				# chicane: S-bend
				var c := rng.randf_range(0.045, 0.075) * curviness * (1 if rng.randf() < 0.5 else -1)
				for k in 5:
					heading += c; pos += Vector3(sin(heading), pitch_h * STEP * 0.0, -cos(heading)) * STEP
					pos.y += pitch_h * STEP; dist += STEP; curve.add_point(pos)
				for k in 2:
					pos += Vector3(sin(heading), 0, -cos(heading)) * STEP; pos.y += pitch_h * STEP
					dist += STEP; curve.add_point(pos)
				curv = -c; n = 5
			else:
				grade = rng.randf_range(-1.0, 1.0) * 0.05 * hilliness
		for k in n:
			heading += curv
			pitch_h = clampf(pitch_h + grade * 0.2, -0.09, 0.09)
			pitch_h *= 0.985
			pos += Vector3(sin(heading), 0, -cos(heading)) * STEP
			pos.y = clampf(pos.y + pitch_h * STEP, 0.0, 60.0)
			dist += STEP
			curve.add_point(pos)
			if dist >= target_len: break

	var baked_len := curve.get_baked_length()
	# sample transforms
	var samples: Array = []
	var d := 0.0
	while d < baked_len:
		var p := curve.sample_baked(d)
		var p2 := curve.sample_baked(minf(d + 2.0, baked_len))
		var fwd := (p2 - p)
		if fwd.length() < 0.001: fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var up := right.cross(fwd).normalized()
		samples.append({"pos": p, "fwd": fwd, "right": right, "up": up, "d": d})
		d += SAMPLE

	var root := Node3D.new()
	root.name = "Track"
	_build_road(root, samples, zone_key, zone)
	_build_scenery(root, samples, zone_key, zone, rng)
	_build_ground(root, zone_key, zone, baked_len)
	if zone_key in ["coastal", "neon", "blacktrack"] and samples.size() > 200:
		_build_tunnel(root, samples, zone_key, rng)
	_finish_arch(root, samples, baked_len)

	return {"root": root, "curve": curve, "length": baked_len, "samples": samples}

# ---------- road surface + physics ----------
static func _ribbon(samples: Array, x0: float, x1: float, y0: float, y1: float,
		col: Color, step := 1) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(col)
	var i := 0
	while i < samples.size() - step:
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + step]
		var a0: Vector3 = a.pos + a.right * x0 + a.up * y0
		var a1: Vector3 = a.pos + a.right * x1 + a.up * y1
		var b0: Vector3 = b.pos + b.right * x0 + b.up * y0
		var b1: Vector3 = b.pos + b.right * x1 + b.up * y1
		var va: float = a.d * 0.004
		var vb: float = b.d * 0.004
		st.set_normal(a.up); st.set_uv(Vector2(0, va)); st.add_vertex(a0)
		st.set_normal(a.up); st.set_uv(Vector2(1, va)); st.add_vertex(a1)
		st.set_normal(b.up); st.set_uv(Vector2(1, vb)); st.add_vertex(b1)
		st.set_normal(a.up); st.set_uv(Vector2(0, va)); st.add_vertex(a0)
		st.set_normal(b.up); st.set_uv(Vector2(1, vb)); st.add_vertex(b1)
		st.set_normal(b.up); st.set_uv(Vector2(0, vb)); st.add_vertex(b0)
		i += step
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi

static func _dashed(samples: Array, x: float, col: Color, on := 2, off := 2) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(col)
	var i := 0
	while i < samples.size() - 1:
		if (i / on) % ((on + off) / on + 1) == 0 if false else (i % (on + off)) < on:
			var a: Dictionary = samples[i]
			var b: Dictionary = samples[i + 1]
			for pair in [[x - 0.09, x + 0.09]]:
				var a0: Vector3 = a.pos + a.right * pair[0] + a.up * 0.03
				var a1: Vector3 = a.pos + a.right * pair[1] + a.up * 0.03
				var b0: Vector3 = b.pos + b.right * pair[0] + b.up * 0.03
				var b1: Vector3 = b.pos + b.right * pair[1] + b.up * 0.03
				st.set_normal(a.up); st.add_vertex(a0)
				st.set_normal(a.up); st.add_vertex(a1)
				st.set_normal(b.up); st.add_vertex(b1)
				st.set_normal(a.up); st.add_vertex(a0)
				st.set_normal(b.up); st.add_vertex(b1)
				st.set_normal(b.up); st.add_vertex(b0)
		i += 1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi

static func _build_road(root: Node3D, samples: Array, zone_key: String, zone: Dictionary) -> void:
	var wet: bool = zone.get("wet", false)
	var asphalt_col := Color(0.18, 0.18, 0.20) if not wet else Color(0.14, 0.14, 0.18)
	var road := _ribbon(samples, -ROAD_HALF, ROAD_HALF, 0.0, 0.0, asphalt_col)
	road.name = "Asphalt"
	var rm: StandardMaterial3D = road.material_override
	if wet:
		rm.roughness = 0.25; rm.metallic = 0.4
	# procedural asphalt micro-detail: noise normal map + roughness breakup
	var nn := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fn.frequency = 0.9
	nn.noise = fn
	nn.width = 256; nn.height = 256
	nn.as_normal_map = true
	nn.bump_strength = 2.4
	nn.seamless = true
	rm.normal_enabled = true
	rm.normal_texture = nn
	rm.uv1_scale = Vector3(6.0, 240.0, 1.0)
	var rt := NoiseTexture2D.new()
	var fn2 := FastNoiseLite.new()
	fn2.frequency = 0.3
	rt.noise = fn2
	rt.width = 256; rt.height = 256
	rt.seamless = true
	rm.roughness_texture = rt
	root.add_child(road)
	# shoulders
	root.add_child(_ribbon(samples, -ROAD_HALF - 1.6, -ROAD_HALF, -0.04, 0.0, Color(0.22, 0.21, 0.20)))
	root.add_child(_ribbon(samples, ROAD_HALF, ROAD_HALF + 1.6, 0.0, -0.04, Color(0.22, 0.21, 0.20)))
	# terrain skirts falling away from the road
	var gcol: Color = zone.ground
	root.add_child(_ribbon(samples, -ROAD_HALF - 26.0, -ROAD_HALF - 1.6, -3.2, -0.04, gcol, 2))
	root.add_child(_ribbon(samples, ROAD_HALF + 1.6, ROAD_HALF + 26.0, -0.04, -3.2, gcol, 2))
	# lane markings
	root.add_child(_dashed(samples, 0.0, Color(0.95, 0.92, 0.75)))
	root.add_child(_dashed(samples, -ROAD_HALF * 0.5, Color(0.85, 0.87, 0.9), 2, 3))
	root.add_child(_dashed(samples, ROAD_HALF * 0.5, Color(0.85, 0.87, 0.9), 2, 3))
	# solid edge lines
	root.add_child(_ribbon(samples, -ROAD_HALF + 0.25, -ROAD_HALF + 0.42, 0.02, 0.02, Color(0.9, 0.9, 0.9)))
	root.add_child(_ribbon(samples, ROAD_HALF - 0.42, ROAD_HALF - 0.25, 0.02, 0.02, Color(0.9, 0.9, 0.9)))
	# physics: collision along road + skirts (one big concave shape from road ribbon)
	var body := StaticBody3D.new()
	body.name = "RoadBody"
	var shape := CollisionShape3D.new()
	var faces := PackedVector3Array()
	var i := 0
	while i < samples.size() - 1:
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + 1]
		var a0: Vector3 = a.pos + a.right * (-ROAD_HALF - 26.0) + a.up * -3.2
		var a1: Vector3 = a.pos + a.right * (ROAD_HALF + 26.0) + a.up * -3.2
		var am: Vector3 = a.pos + a.right * (-ROAD_HALF - 1.0)
		var an: Vector3 = a.pos + a.right * (ROAD_HALF + 1.0)
		var b0: Vector3 = b.pos + b.right * (-ROAD_HALF - 26.0) + b.up * -3.2
		var b1: Vector3 = b.pos + b.right * (ROAD_HALF + 26.0) + b.up * -3.2
		var bm: Vector3 = b.pos + b.right * (-ROAD_HALF - 1.0)
		var bn: Vector3 = b.pos + b.right * (ROAD_HALF + 1.0)
		for tri in [[a0, am, b0], [am, bm, b0], [am, an, bm], [an, bn, bm], [an, a1, bn], [a1, b1, bn]]:
			faces.append(tri[0]); faces.append(tri[1]); faces.append(tri[2])
		i += 1
	var conc := ConcavePolygonShape3D.new()
	conc.set_faces(faces)
	conc.backface_collision = true   # drivable regardless of winding
	shape.shape = conc
	body.add_child(shape)
	root.add_child(body)
	# guardrails on curves (visual + physical)
	_guardrails(root, samples, zone_key)

static func _guardrails(root: Node3D, samples: Array, zone_key: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new(); box.size = Vector3(0.12, 0.5, SAMPLE + 0.4)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.7, 0.72, 0.75); mat.metallic = 0.8; mat.roughness = 0.4
	box.material = mat
	mm.mesh = box
	var xs: Array = []
	var rail_body := StaticBody3D.new(); rail_body.name = "Rails"
	for i in range(0, samples.size() - 1):
		var s: Dictionary = samples[i]
		for side in [-1.0, 1.0]:
			if zone_key == "blacktrack" or zone_key == "mountain" or absf(_curvature(samples, i)) > 0.004:
				var basis := Basis.looking_at(-s.fwd, s.up)
				var xf := Transform3D(basis, s.pos + s.right * side * (ROAD_HALF + 1.2) + s.up * 0.5)
				xs.append(xf)
				if i % 3 == 0:
					var cs := CollisionShape3D.new()
					var bs := BoxShape3D.new(); bs.size = Vector3(0.3, 1.2, SAMPLE * 3.2)
					cs.shape = bs
					cs.transform = Transform3D(basis, s.pos + s.right * side * (ROAD_HALF + 1.35) + s.up * 0.5)
					rail_body.add_child(cs)
	mm.instance_count = xs.size()
	for i in xs.size(): mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)
	root.add_child(rail_body)

static func _curvature(samples: Array, i: int) -> float:
	if i < 2 or i > samples.size() - 3: return 0.0
	var f1: Vector3 = samples[i - 2].fwd
	var f2: Vector3 = samples[i + 2].fwd
	return f1.signed_angle_to(f2, Vector3.UP)

# ---------- scenery ----------
static func _mm_scatter(root: Node3D, mesh: Mesh, transforms: Array, colors := []) -> void:
	if transforms.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if colors.size() > 0: mm.set_instance_color(i, colors[i % colors.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)

static func _build_scenery(root: Node3D, samples: Array, zone_key: String, zone: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind: String = zone.scenery
	# recognisable landmarks at fixed fractions of the route
	if kind == "desert":
		_landmark_gas_station(root, samples[int(samples.size() * 0.45)])
	elif kind == "docks":
		_landmark_ship(root, samples[int(samples.size() * 0.55)])
	elif kind == "airport":
		_landmark_jet(root, samples[int(samples.size() * 0.5)])
	var every := 3
	var xs_a: Array = []; var cols_a: Array = []
	var xs_b: Array = []; var cols_b: Array = []
	# telephone poles marching along desert & coastal highways (Silver Creek style)
	if kind == "desert" or kind == "coastal":
		var poles: Array = []
		var bars: Array = []
		for i in range(0, samples.size(), 8):
			var s: Dictionary = samples[i]
			var base: Vector3 = s.pos + s.right * (ROAD_HALF + 5.0) + Vector3.UP * -0.5
			poles.append(Transform3D(Basis(), base + Vector3.UP * 3.5))
			bars.append(Transform3D(Basis.looking_at(-s.fwd, s.up), base + Vector3.UP * 6.4))
		var pm := CylinderMesh.new(); pm.top_radius = 0.09; pm.bottom_radius = 0.13; pm.height = 7.0
		var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.28, 0.2, 0.13); pmat.roughness = 1.0
		pm.material = pmat
		_mm_scatter(root, pm, poles)
		var bm := BoxMesh.new(); bm.size = Vector3(1.8, 0.09, 0.09)
		bm.material = pmat
		_mm_scatter(root, bm, bars)
	for i in range(0, samples.size(), every):
		var s: Dictionary = samples[i]
		for side in [-1.0, 1.0]:
			if rng.randf() > 0.72: continue
			var off := ROAD_HALF + rng.randf_range(14.0, 42.0)
			var base: Vector3 = s.pos + s.right * side * off + Vector3.UP * -3.0
			var yaw := rng.randf_range(0, TAU)
			match kind:
				"city":
					var h := rng.randf_range(12.0, 46.0)
					var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(rng.randf_range(6, 12), h, rng.randf_range(6, 12))), base + Vector3.UP * h * 0.5)
					xs_a.append(xf)
					cols_a.append([Color(1, 0.17, 0.84), Color(0.18, 0.89, 1), Color(1, 0.83, 0)][rng.randi_range(0, 2)])
				"desert":
					if rng.randf() < 0.5:
						xs_a.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.7, 1.6)), base))  # cactus
					else:
						xs_b.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(1.5, 4.0)), base)) # rock
				"mountain":
					xs_a.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.8)), base))     # pine
					if rng.randf() < 0.2:
						xs_b.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(6, rng.randf_range(8, 22), 6)), base))   # cliff block
				"airport":
					if rng.randf() < 0.25:
						xs_a.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(rng.randf_range(10, 18), rng.randf_range(5, 9), rng.randf_range(10, 16))), base)) # hangar
					else:
						xs_b.append(Transform3D(Basis(Vector3.UP, 0), s.pos + s.right * side * (ROAD_HALF + 3.0) + Vector3.UP * 0.4)) # runway light
				"coastal":
					if side > 0: xs_a.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), base))  # palm inland
				"docks":
					xs_a.append(Transform3D(Basis(Vector3.UP, yaw * 0.1).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), base))  # container
					cols_a.append([Color(0.7, 0.25, 0.16), Color(0.16, 0.43, 0.7), Color(0.17, 0.54, 0.3), Color(0.79, 0.56, 0.17)][rng.randi_range(0, 3)])
				"blacktrack":
					xs_a.append(Transform3D(Basis(Vector3.UP, 0), s.pos + s.right * side * (ROAD_HALF + 2.2) + Vector3.UP * 1.2)) # carbon wall
	match kind:
		"city":
			var bm := BoxMesh.new(); bm.size = Vector3.ONE
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.05, 0.05, 0.09); m.roughness = 0.7
			m.emission_enabled = true
			var noise := NoiseTexture2D.new()
			var fn := FastNoiseLite.new(); fn.frequency = 8.0
			noise.noise = fn; noise.width = 64; noise.height = 64
			m.emission_texture = noise
			m.emission = Color(0.9, 0.85, 1.0); m.emission_energy_multiplier = 0.22
			m.albedo_color = Color(0.10, 0.10, 0.16)
			bm.material = m
			_mm_scatter(root, bm, xs_a)
		"desert":
			var cac := CapsuleMesh.new(); cac.radius = 0.3; cac.height = 3.0
			var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.2, 0.45, 0.2); cac.material = cm
			_mm_scatter(root, cac, xs_a)
			var rock := SphereMesh.new(); rock.radius = 1.0; rock.height = 1.4
			var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.45, 0.25, 0.15); rm.roughness = 1.0; rock.material = rm
			_mm_scatter(root, rock, xs_b)
		"mountain":
			var pine := CylinderMesh.new(); pine.top_radius = 0.0; pine.bottom_radius = 1.6; pine.height = 6.0
			var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.10, 0.26, 0.17); pine.material = pm
			_mm_scatter(root, pine, xs_a)
			var cliff := BoxMesh.new(); cliff.size = Vector3.ONE
			var clm := StandardMaterial3D.new(); clm.albedo_color = Color(0.23, 0.25, 0.28); clm.roughness = 1.0; cliff.material = clm
			_mm_scatter(root, cliff, xs_b)
		"airport":
			var hang := BoxMesh.new(); hang.size = Vector3.ONE
			var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.24, 0.27, 0.31); hang.material = hm
			_mm_scatter(root, hang, xs_a)
			var lightm := SphereMesh.new(); lightm.radius = 0.16; lightm.height = 0.32
			lightm.material = CarFactory.emissive(Color(1, 0.82, 0.24), 1.2)
			_mm_scatter(root, lightm, xs_b)
		"coastal":
			var palm := CylinderMesh.new(); palm.top_radius = 0.12; palm.bottom_radius = 0.22; palm.height = 6.0
			var pmm := StandardMaterial3D.new(); pmm.albedo_color = Color(0.35, 0.24, 0.13); palm.material = pmm
			_mm_scatter(root, palm, xs_a)
		"docks":
			var cont := BoxMesh.new(); cont.size = Vector3(6.0, 2.6, 2.5)
			var com := StandardMaterial3D.new(); com.vertex_color_use_as_albedo = true; com.roughness = 0.8
			cont.material = com
			_mm_scatter(root, cont, xs_a, cols_a)
		"blacktrack":
			var wall := BoxMesh.new(); wall.size = Vector3(0.4, 2.4, SAMPLE * 3.2)
			wall.material = CarFactory.emissive(Color(1, 0.0, 0.2), 0.4)
			_mm_scatter(root, wall, xs_a)

static func _build_ground(root: Node3D, zone_key: String, zone: Dictionary, length: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	var m := StandardMaterial3D.new()
	m.albedo_color = zone.ground
	m.roughness = 1.0
	plane.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(0, -3.6, -length * 0.35)
	root.add_child(mi)
	# safety net: solid ground so nothing can fall out of the world
	var gb := StaticBody3D.new()
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(9000, 1.0, 9000)
	gcs.shape = gbs
	gcs.position = Vector3(0, -4.2, -length * 0.35)
	gb.add_child(gcs)
	root.add_child(gb)
	if zone_key == "coastal":
		var sea := PlaneMesh.new(); sea.size = Vector2(9000, 9000)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.1, 0.35, 0.5); sm.roughness = 0.1; sm.metallic = 0.6
		sea.material = sm
		var smi := MeshInstance3D.new(); smi.mesh = sea
		smi.position = Vector3(-260, -6.0, -length * 0.35)
		root.add_child(smi)

# A stretch of enclosed tunnel with ceiling lights (Sunset Drive style)
static func _build_tunnel(root: Node3D, samples: Array, zone_key: String, rng: RandomNumberGenerator) -> void:
	var start := rng.randi_range(int(samples.size() * 0.3), int(samples.size() * 0.6))
	var length := mini(34, samples.size() - start - 10)
	if length < 16: return
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.42, 0.43, 0.46) if zone_key != "blacktrack" else Color(0.1, 0.1, 0.12)
	wall_mat.roughness = 0.7
	var walls := MultiMesh.new()
	walls.transform_format = MultiMesh.TRANSFORM_3D
	var wb := BoxMesh.new(); wb.size = Vector3(0.8, 6.5, SAMPLE + 0.5); wb.material = wall_mat
	walls.mesh = wb
	var roofs := MultiMesh.new()
	roofs.transform_format = MultiMesh.TRANSFORM_3D
	var rb := BoxMesh.new(); rb.size = Vector3((ROAD_HALF + 2.0) * 2.0, 0.7, SAMPLE + 0.5); rb.material = wall_mat
	roofs.mesh = rb
	var lights := MultiMesh.new()
	lights.transform_format = MultiMesh.TRANSFORM_3D
	var lb := BoxMesh.new(); lb.size = Vector3(1.6, 0.08, 0.5)
	lb.material = CarFactory.emissive(Color(1.0, 0.95, 0.8), 2.2)
	lights.mesh = lb
	var wx: Array = []; var rx: Array = []; var lx: Array = []
	var body := StaticBody3D.new(); body.name = "Rails"    # tunnel walls hit like rails
	for k in length:
		var s: Dictionary = samples[start + k]
		var basis := Basis.looking_at(-s.fwd, s.up)
		for side in [-1.0, 1.0]:
			wx.append(Transform3D(basis, s.pos + s.right * side * (ROAD_HALF + 1.7) + s.up * 3.2))
			if k % 3 == 0:
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new(); bs.size = Vector3(0.9, 6.5, SAMPLE * 3.2)
				cs.shape = bs
				cs.transform = Transform3D(basis, s.pos + s.right * side * (ROAD_HALF + 1.7) + s.up * 3.2)
				body.add_child(cs)
		rx.append(Transform3D(basis, s.pos + s.up * 6.6))
		if k % 4 == 0:
			lx.append(Transform3D(basis, s.pos + s.up * 6.1))
	walls.instance_count = wx.size()
	for i in wx.size(): walls.set_instance_transform(i, wx[i])
	roofs.instance_count = rx.size()
	for i in rx.size(): roofs.set_instance_transform(i, rx[i])
	lights.instance_count = lx.size()
	for i in lx.size(): lights.set_instance_transform(i, lx[i])
	for mmm in [walls, roofs, lights]:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mmm
		root.add_child(mi)
	root.add_child(body)

static func _finish_arch(root: Node3D, samples: Array, length: float) -> void:
	if samples.size() < 4: return
	var s: Dictionary = samples[samples.size() - 2]
	var arch := Node3D.new()
	arch.name = "FinishArch"
	for side in [-1.0, 1.0]:
		var pil := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.6, 7.0, 0.6)
		pil.mesh = pb; pil.material_override = CarFactory.trim_material()
		pil.position = s.pos + s.right * side * (ROAD_HALF + 1.0) + Vector3.UP * 3.5
		arch.add_child(pil)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new(); bb.size = Vector3(ROAD_HALF * 2 + 3.0, 1.0, 0.6)
	beam.mesh = bb
	beam.material_override = CarFactory.emissive(Color(0.18, 0.89, 1.0), 1.1)
	beam.position = s.pos + Vector3.UP * 7.0
	beam.basis = Basis.looking_at(-s.fwd, Vector3.UP)
	arch.add_child(beam)
	root.add_child(arch)

# Track query helper — progress + lateral offset with a cached hint.
static func locate(samples: Array, pos: Vector3, hint_idx: int, loop := false) -> Dictionary:
	var n := samples.size()
	var best_i := hint_idx
	var best_d := 1e18
	for k in range(-30, 61):
		var i: int
		if loop:
			i = ((hint_idx + k) % n + n) % n
		else:
			i = clampi(hint_idx + k, 0, n - 1)
		var dd: float = samples[i].pos.distance_squared_to(pos)
		if dd < best_d: best_d = dd; best_i = i
	# fallback full scan if hint is badly wrong
	if best_d > 90.0 * 90.0:
		for i in range(0, n, 4):
			var dd2: float = samples[i].pos.distance_squared_to(pos)
			if dd2 < best_d: best_d = dd2; best_i = i
	var s: Dictionary = samples[best_i]
	var rel: Vector3 = pos - s.pos
	return {"idx": best_i, "d": s.d + rel.dot(s.fwd), "x": rel.dot(s.right), "s": s}

# ---------- TRUE CLOSED CIRCUITS ----------
# An irregular smoothed ring with elevation — a real lap-able loop.
static func generate_loop(zone_key: String, length_km: float, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var zone: Dictionary = D.ZONES[zone_key]
	var circumference := length_km * 1000.0
	var base_r := circumference / TAU
	var amps: Array = []
	for k in range(2, 6):
		amps.append([k, rng.randf_range(0.06, 0.16) * base_r, rng.randf_range(0.0, TAU)])
	var hill_amp := (14.0 if zone_key == "mountain" else 6.0)
	var hill_ph := rng.randf_range(0.0, TAU)
	var pts: Array = []
	var t := 0.0
	while t < TAU:
		var r := base_r
		for a in amps:
			r += a[1] * sin(a[0] * t + a[2])
		pts.append(Vector3(cos(t) * r, maxf(hill_amp * (sin(2.0 * t + hill_ph) * 0.5 + 0.5), 0.0), sin(t) * r))
		var dpdt := Vector3(-sin(t) * r, 0, cos(t) * r).length()
		t += SAMPLE / maxf(dpdt, 1.0)
	var n := pts.size()
	var samples: Array = []
	for i in n:
		var nxt: Vector3 = pts[(i + 1) % n]
		var fwd: Vector3 = (nxt - pts[i])
		if fwd.length() < 0.001: fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		samples.append({"pos": pts[i], "fwd": fwd, "right": right,
			"up": right.cross(fwd).normalized(), "d": float(i) * SAMPLE})
	var total := float(n) * SAMPLE
	# meshes need the seam closed: build with a wrapped sentinel sample
	var closed := samples.duplicate()
	var seam: Dictionary = samples[0].duplicate()
	seam.d = total
	closed.append(seam)
	var root := Node3D.new()
	root.name = "Track"
	_build_road(root, closed, zone_key, zone)
	_build_scenery(root, closed, zone_key, zone, rng)
	_build_ground(root, zone_key, zone, base_r * 2.0)
	_start_line(root, samples[0])
	return {"root": root, "curve": null, "length": total, "samples": samples}

static func _start_line(root: Node3D, s: Dictionary) -> void:
	var line := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(ROAD_HALF * 2.0, 0.06, 1.6)
	line.mesh = bm
	line.material_override = CarFactory.emissive(Color(0.95, 0.95, 0.95), 0.8)
	root.add_child(line)
	line.transform = Transform3D(Basis.looking_at(s.fwd, s.up), s.pos + Vector3.UP * 0.03)
	for side in [-1.0, 1.0]:
		var pil := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.5, 6.0, 0.5)
		pil.mesh = pb; pil.material_override = CarFactory.trim_material()
		root.add_child(pil)
		pil.position = s.pos + s.right * side * (ROAD_HALF + 1.0) + Vector3.UP * 3.0


static func _landmark_gas_station(root: Node3D, s: Dictionary) -> void:
	var base: Vector3 = s.pos + s.right * (ROAD_HALF + 14.0) + Vector3.UP * -0.4
	var canopy := MeshInstance3D.new()
	var cb := BoxMesh.new(); cb.size = Vector3(14, 0.5, 8)
	canopy.mesh = cb
	canopy.material_override = CarFactory.emissive(Color(1.0, 0.35, 0.2), 0.6)
	canopy.position = base + Vector3.UP * 5.0
	root.add_child(canopy)
	for off in [Vector3(-5, 2.5, -3), Vector3(5, 2.5, -3), Vector3(-5, 2.5, 3), Vector3(5, 2.5, 3)]:
		var pil := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.5, 5.0, 0.5)
		pil.mesh = pb; pil.material_override = CarFactory.trim_material()
		pil.position = base + off
		root.add_child(pil)
	var shop := MeshInstance3D.new()
	var sb := BoxMesh.new(); sb.size = Vector3(10, 3.5, 6)
	shop.mesh = sb
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.75, 0.7, 0.6)
	shop.material_override = sm
	shop.position = base + Vector3(0, 1.75, 10)
	root.add_child(shop)

static func _landmark_ship(root: Node3D, s: Dictionary) -> void:
	var base: Vector3 = s.pos + s.right * (ROAD_HALF + 42.0) + Vector3.UP * -2.0
	var hull := MeshInstance3D.new()
	var hb := BoxMesh.new(); hb.size = Vector3(18, 9, 70)
	hull.mesh = hb
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.5, 0.15, 0.12); hm.roughness = 0.8
	hull.material_override = hm
	hull.position = base + Vector3.UP * 4.5
	root.add_child(hull)
	var bridge := MeshInstance3D.new()
	var bb := BoxMesh.new(); bb.size = Vector3(12, 10, 10)
	bridge.mesh = bb
	var bm2 := StandardMaterial3D.new(); bm2.albedo_color = Color(0.85, 0.85, 0.88)
	bridge.material_override = bm2
	bridge.position = base + Vector3(0, 13, -22)
	root.add_child(bridge)

static func _landmark_jet(root: Node3D, s: Dictionary) -> void:
	var base: Vector3 = s.pos + s.right * (ROAD_HALF + 26.0) + Vector3.UP * 0.5
	var fus := MeshInstance3D.new()
	var fb := CapsuleMesh.new(); fb.radius = 2.2; fb.height = 34.0
	fus.mesh = fb
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.82, 0.85, 0.9); fm.metallic = 0.6; fm.roughness = 0.35
	fus.material_override = fm
	fus.rotation_degrees.x = 90
	fus.position = base + Vector3.UP * 3.4
	root.add_child(fus)
	var wing := MeshInstance3D.new()
	var wb := BoxMesh.new(); wb.size = Vector3(30, 0.4, 6)
	wing.mesh = wb; wing.material_override = fm
	wing.position = base + Vector3.UP * 3.0
	root.add_child(wing)
	var tail := MeshInstance3D.new()
	var tb := BoxMesh.new(); tb.size = Vector3(0.4, 7, 5)
	tail.mesh = tb; tail.material_override = fm
	tail.position = base + Vector3(0, 6, 15)
	root.add_child(tail)

# ============================================================
# VELOCITY COUNTY — one seeded, connected open world.
# A ~21 km ring highway that crosses every district in order,
# with per-sector styling, gateway arches, landmarks and
# deterministic discovery sites. Same seed → same county.
# ============================================================
const WORLD_ORDER := ["coastal", "neon", "docks", "airport", "desert", "mountain"]

static func generate_world(seed_v: int, opts := {}) -> Dictionary:
	var bare: bool = opts.get("bare", false)   # samples/sectors only (tests)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var circumference := 21000.0
	var base_r := circumference / TAU
	# global gentle shape + per-sector character
	var amps: Array = []
	for k in range(2, 5):
		amps.append([k, rng.randf_range(0.04, 0.09) * base_r, rng.randf_range(0.0, TAU)])
	var sector_wiggle := {"coastal": 0.02, "neon": 0.05, "docks": 0.04, "airport": 0.012,
		"desert": 0.018, "mountain": 0.085}
	var sector_hill := {"coastal": 4.0, "neon": 2.0, "docks": 2.0, "airport": 0.5,
		"desert": 3.0, "mountain": 22.0}
	var wig_ph := rng.randf_range(0.0, TAU)
	var pts: Array = []
	var zones: Array = []
	var t := 0.0
	while t < TAU:
		var sector_f := t / TAU * 6.0
		var sector_i := int(sector_f) % 6
		var zone: String = WORLD_ORDER[sector_i]
		var next_zone: String = WORLD_ORDER[(sector_i + 1) % 6]
		# blend sector character across the last 15% of each sector so the
		# road never steps sideways or jumps in height at a district border
		var edge := smoothstep(0.85, 1.0, sector_f - floorf(sector_f))
		var wig: float = lerpf(sector_wiggle[zone], sector_wiggle[next_zone], edge)
		var hill: float = lerpf(sector_hill[zone], sector_hill[next_zone], edge)
		var r := base_r
		for a in amps:
			r += a[1] * sin(a[0] * t + a[2])
		r += wig * base_r * sin(11.0 * t + wig_ph) * sin(17.0 * t)
		var h: float = hill * (sin(3.0 * t + wig_ph) * 0.5 + 0.5)
		pts.append(Vector3(cos(t) * r, maxf(h, 0.0), sin(t) * r))
		zones.append(zone)
		var dpdt := Vector3(-sin(t) * r, 0, cos(t) * r).length()
		t += SAMPLE / maxf(dpdt, 1.0)
	var n := pts.size()
	var samples: Array = []
	for i in n:
		var nxt: Vector3 = pts[(i + 1) % n]
		var fwd: Vector3 = (nxt - pts[i])
		if fwd.length() < 0.001: fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		samples.append({"pos": pts[i], "fwd": fwd, "right": right,
			"up": right.cross(fwd).normalized(), "d": float(i) * SAMPLE, "zone": zones[i]})
	var total := float(n) * SAMPLE
	# sector ranges
	var sectors: Array = []
	var start_i := 0
	for i in range(1, n + 1):
		if i == n or samples[i].zone != samples[start_i].zone:
			sectors.append({"zone": samples[start_i].zone, "i0": start_i, "i1": i - 1,
				"d0": samples[start_i].d, "d1": samples[i - 1].d})
			start_i = i
	# closed sentinel for meshes
	var closed := samples.duplicate()
	var seam: Dictionary = samples[0].duplicate()
	seam.d = total
	closed.append(seam)
	var root := Node3D.new()
	root.name = "World"
	if bare:
		return {"root": root, "curve": null, "length": total, "samples": samples, "sectors": sectors}
	_build_road(root, closed, "coastal", D.ZONES["coastal"])
	# per-sector scenery + landmarks + gateway arch
	for sec in sectors:
		var zone_d: Dictionary = D.ZONES[sec.zone]
		var slice: Array = samples.slice(sec.i0, sec.i1 + 1)
		if slice.size() > 8:
			var srng := RandomNumberGenerator.new()
			srng.seed = seed_v + hash(sec.zone)
			_build_scenery(root, slice, sec.zone, zone_d, srng)
			_district_gate(root, samples[sec.i0], sec.zone, zone_d)
			var mid: Dictionary = slice[slice.size() / 2]
			match zone_d.scenery:
				"desert": _landmark_gas_station(root, mid)
				"docks": _landmark_ship(root, mid)
				"airport": _landmark_jet(root, mid)
	# neutral county ground + coastal sea patch
	var plane := PlaneMesh.new()
	plane.size = Vector2(base_r * 4.0, base_r * 4.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.14, 0.16, 0.13)
	gm.roughness = 1.0
	plane.material = gm
	var gmi := MeshInstance3D.new()
	gmi.mesh = plane
	gmi.position = Vector3(0, -3.6, 0)
	root.add_child(gmi)
	var gb := StaticBody3D.new()
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(base_r * 4.0, 1.0, base_r * 4.0)
	gcs.shape = gbs
	gcs.position = Vector3(0, -4.2, 0)
	gb.add_child(gcs)
	root.add_child(gb)
	for sec in sectors:
		if sec.zone == "coastal":
			var mid2: Dictionary = samples[(sec.i0 + sec.i1) / 2]
			var sea := PlaneMesh.new()
			sea.size = Vector2(3000, 3000)
			var smt := StandardMaterial3D.new()
			smt.albedo_color = Color(0.1, 0.35, 0.5)
			smt.roughness = 0.1; smt.metallic = 0.6
			sea.material = smt
			var smi := MeshInstance3D.new()
			smi.mesh = sea
			smi.position = mid2.pos + mid2.right * 1400.0 + Vector3.UP * -6.0
			root.add_child(smi)
	return {"root": root, "curve": null, "length": total, "samples": samples, "sectors": sectors}

static func _district_gate(root: Node3D, s: Dictionary, zone_key: String, zone: Dictionary) -> void:
	var col: Color = zone.get("sun", Color.WHITE)
	for side in [-1.0, 1.0]:
		var pil := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.7, 8.0, 0.7)
		pil.mesh = pb; pil.material_override = CarFactory.trim_material()
		root.add_child(pil)
		pil.position = s.pos + s.right * side * (ROAD_HALF + 1.4) + Vector3.UP * 4.0
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new(); bb.size = Vector3(ROAD_HALF * 2.0 + 4.0, 1.2, 0.7)
	beam.mesh = bb
	beam.material_override = CarFactory.emissive(col, 0.9)
	root.add_child(beam)
	beam.transform = Transform3D(Basis.looking_at(-s.fwd, s.up), s.pos + Vector3.UP * 8.0)
	var lbl := Label3D.new()
	lbl.text = str(zone.name).to_upper()
	lbl.font_size = 220
	lbl.modulate = Color(1, 1, 1)
	lbl.outline_size = 24
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	root.add_child(lbl)
	lbl.transform = Transform3D(Basis.looking_at(s.fwd, s.up), s.pos + Vector3.UP * 8.0 - s.fwd * 0.6)

# derelict restoration car body at a barn-find site
static func build_derelict(paint: String) -> Node3D:
	var visual := CarFactory.build_visual(paint, "matte", {"len": 4.5, "wid": 2.0, "nose": 0.9, "tail": 0.6, "wing": 0.0}, false)
	visual.rotation_degrees = Vector3(0, 35, 4)
	# strip lights glow, dull it down
	for child in visual.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = child.material_override
			if m.emission_enabled: m.emission_energy_multiplier = 0.0
			m.roughness = 0.95
	return visual