# ============================================================
# CHICANE 3D — car_factory.gd
# Builds procedural hypercar visuals from panel meshes.
# Every panel is a unique ArrayMesh so it can crumple (BeamNG-style)
# and detach as rigid-body debris.
# ============================================================
class_name CarFactory

static func paint_material(hex: String, finish: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var col := Color.from_string("#" + hex, Color.RED)
	match finish:
		"matte":
			m.albedo_color = col; m.roughness = 0.85; m.metallic = 0.0
		"metallic":
			m.albedo_color = col; m.roughness = 0.35; m.metallic = 0.9
			m.metallic_specular = 0.7
		"carbon":
			m.albedo_color = Color(0.09, 0.09, 0.11); m.roughness = 0.4; m.metallic = 0.4
		"chrome":
			m.albedo_color = Color(0.9, 0.92, 0.95); m.roughness = 0.05; m.metallic = 1.0
		_: # gloss
			m.albedo_color = col; m.roughness = 0.15; m.metallic = 0.55
			m.clearcoat_enabled = true; m.clearcoat = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # lofted hulls must read solid from every angle
	return m

static func glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.075, 0.11)   # deep tinted glass — opaque, sorts cleanly
	m.roughness = 0.06; m.metallic = 0.85
	m.clearcoat_enabled = true; m.clearcoat = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func trim_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06); m.roughness = 0.6
	return m

static func emissive(col: Color, energy := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = energy
	return m

# Deformable panel: BoxMesh (subdivided) baked into a unique ArrayMesh,
# optionally tapered (front narrower = wedge silhouette).
static func panel(pname: String, size: Vector3, pos: Vector3, mat: Material,
		taper_front := 0.0, taper_down := 0.0, subdiv := 3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.subdivide_width = subdiv; box.subdivide_height = 1; box.subdivide_depth = subdiv
	var arrays := box.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if taper_front > 0.0 or taper_down > 0.0:
		for i in verts.size():
			var v := verts[i]
			var f := clampf((v.z / size.z) + 0.5, 0.0, 1.0)   # 1 at front (-z is forward: use -z)
			f = clampf((-v.z / size.z) + 0.5, 0.0, 1.0)
			v.x *= 1.0 - taper_front * f
			v.y -= taper_down * f * size.y
			verts[i] = v
		arrays[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = pname
	mi.mesh = am
	mi.material_override = mat
	mi.position = pos
	return mi

# ---------- smooth lofted hull (replaces the old box body) ----------
# Cross-sections swept nose→tail give a real curved supercar silhouette.
# Returns a unique ArrayMesh — dense vertices crumple beautifully.
static func build_hull(L: float, W: float, nose_drop: float, tail_h: float, cabin: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NS := 16          # sections along length
	var NR := 10          # points per half-ring
	var rings: Array = []
	for i in NS + 1:
		var t := float(i) / NS          # 0 = nose, 1 = tail
		var z := lerpf(-L * 0.5, L * 0.5, t)
		# body plan width: narrow nose, full width mid, slight tail taper
		var wfrac := 0.52 + 0.48 * sin(PI * clampf(t * 1.15, 0.0, 1.0))
		wfrac = maxf(wfrac, 0.55 if t > 0.85 else wfrac)
		var half_w := W * 0.5 * clampf(wfrac, 0.5, 1.0)
		# roof line: low nose rises over cockpit then falls to tail deck
		var roof := 0.30 + nose_drop * 0.0
		var cab_c := 0.52  # cockpit centre
		var cab_curve: float = exp(-pow((t - cab_c) / 0.21, 2.0))
		roof = lerpf(0.34 - nose_drop * 0.16, 0.34, clampf(t * 3.0, 0.0, 1.0))
		roof += cabin * 0.52 * cab_curve
		if t > 0.86: roof = lerpf(roof, 0.30 + tail_h * 0.25, (t - 0.86) / 0.14)
		var ring := PackedVector3Array()
		for j in NR + 1:
			var a := float(j) / NR      # 0 = bottom centre, 1 = top centre
			# profile: flat floor → vertical side → curved shoulder → roof
			var px: float
			var py: float
			if a < 0.18:
				px = half_w * (a / 0.18) * 0.96
				py = 0.12
			elif a < 0.55:
				px = half_w * (0.96 + 0.04 * sin(PI * (a - 0.18) / 0.37))
				py = 0.12 + (a - 0.18) / 0.37 * (roof * 0.55)
			else:
				var b := (a - 0.55) / 0.45
				px = half_w * (1.0 - pow(b, 1.7) * 0.9)
				py = 0.12 + roof * (0.55 + 0.45 * sin(b * PI * 0.5))
			ring.append(Vector3(px, py, z))
		rings.append(ring)
	# stitch rings (right side, then mirrored left)
	for side in [1.0, -1.0]:
		for i in NS:
			var r0: PackedVector3Array = rings[i]
			var r1: PackedVector3Array = rings[i + 1]
			for j in NR:
				var a0 := Vector3(r0[j].x * side, r0[j].y, r0[j].z)
				var a1 := Vector3(r0[j + 1].x * side, r0[j + 1].y, r0[j + 1].z)
				var b0 := Vector3(r1[j].x * side, r1[j].y, r1[j].z)
				var b1 := Vector3(r1[j + 1].x * side, r1[j + 1].y, r1[j + 1].z)
				if side > 0:
					st.add_vertex(a0); st.add_vertex(a1); st.add_vertex(b1)
					st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(b0)
				else:
					st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(a1)
					st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(b1)
	# nose + tail caps
	var nose_ring: PackedVector3Array = rings[0]
	var tail_ring: PackedVector3Array = rings[NS]
	for j in NR:
		for side in [1.0, -1.0]:
			var n0 := Vector3(nose_ring[j].x * side, nose_ring[j].y, nose_ring[j].z)
			var n1 := Vector3(nose_ring[j + 1].x * side, nose_ring[j + 1].y, nose_ring[j + 1].z)
			var nc := Vector3(0, 0.24, nose_ring[j].z)
			var t0 := Vector3(tail_ring[j].x * side, tail_ring[j].y, tail_ring[j].z)
			var t1 := Vector3(tail_ring[j + 1].x * side, tail_ring[j + 1].y, tail_ring[j + 1].z)
			var tc := Vector3(0, 0.3, tail_ring[j].z)
			if side > 0:
				st.add_vertex(nc); st.add_vertex(n1); st.add_vertex(n0)
				st.add_vertex(tc); st.add_vertex(t0); st.add_vertex(t1)
			else:
				st.add_vertex(nc); st.add_vertex(n0); st.add_vertex(n1)
				st.add_vertex(tc); st.add_vertex(t1); st.add_vertex(t0)
	st.generate_normals()
	return st.commit()

# Full car visual. shape: {len, wid, nose, tail, wing}; police adds lightbar/livery.
# Returns Node3D with named children; meta "panels" lists deformable MeshInstance3D.
static func build_visual(hex: String, finish: String, shape: Dictionary, police := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var L: float = shape.get("len", 4.6)
	var W: float = shape.get("wid", 2.0)
	var wing: float = shape.get("wing", 0.5)
	var body_mat := paint_material("f2f2f2" if police else hex, "gloss" if police else finish)
	var trim := trim_material()
	var panels: Array = []

	# main hull — smooth lofted supercar body
	var body := MeshInstance3D.new()
	body.name = "body"
	body.mesh = build_hull(L, W, shape.get("nose", 1.0), shape.get("tail", 0.6), 0.9)
	body.material_override = body_mat
	body.position = Vector3(0, 0.18, 0.0)
	root.add_child(body); panels.append(body)
	# curved glass canopy over the cockpit
	var canopy := MeshInstance3D.new()
	canopy.name = "cabin"
	var sph := SphereMesh.new()
	sph.radius = 1.0; sph.height = 1.4
	sph.radial_segments = 20; sph.rings = 10
	var cam := ArrayMesh.new()
	cam.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sph.surface_get_arrays(0))
	canopy.mesh = cam
	canopy.material_override = glass_material()
	canopy.scale = Vector3(W * 0.315, 0.30, L * 0.185)
	canopy.position = Vector3(0, 0.66, L * 0.02)
	root.add_child(canopy); panels.append(canopy)
	# rear deck vents (visual detail strip)
	var deck := panel("deck", Vector3(W * 0.62, 0.05, L * 0.16), Vector3(0, 0.62, L * 0.30), trim, 0.0, 0.0, 2)
	root.add_child(deck); panels.append(deck)
	# bumpers
	var fbump := panel("fbumper", Vector3(W * 0.98, 0.22, 0.28), Vector3(0, 0.26, -L * 0.5), trim, 0.15, 0.0, 2)
	root.add_child(fbump); panels.append(fbump)
	var rbump := panel("rbumper", Vector3(W * 0.98, 0.26, 0.24), Vector3(0, 0.30, L * 0.48), trim, 0.0, 0.0, 2)
	root.add_child(rbump); panels.append(rbump)
	# side skirts (deformable doors/sills)
	for side in [-1, 1]:
		var skirt := panel("skirt_%s" % ("l" if side < 0 else "r"),
			Vector3(0.12, 0.30, L * 0.5), Vector3(side * W * 0.46, 0.34, 0.0), body_mat, 0.1, 0.0, 2)
		root.add_child(skirt); panels.append(skirt)
	# spoiler
	if wing > 0.25:
		var wm := trim if finish != "carbon" else paint_material(hex, "carbon")
		var wing_mi := panel("wing", Vector3(W * 0.92, 0.05, 0.34), Vector3(0, 0.78 + wing * 0.22, L * 0.44), wm, 0.0, 0.0, 2)
		root.add_child(wing_mi); panels.append(wing_mi)
		for side in [-1, 1]:
			var pylon := MeshInstance3D.new()
			var pb := BoxMesh.new(); pb.size = Vector3(0.06, wing * 0.24 + 0.12, 0.16)
			pylon.mesh = pb; pylon.material_override = trim
			pylon.position = Vector3(side * W * 0.3, 0.66 + wing * 0.1, L * 0.44)
			pylon.name = "pylon_%d" % side
			root.add_child(pylon)
	# lights
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new(); hb.size = Vector3(W * 0.7, 0.06, 0.06)
	head.mesh = hb; head.material_override = emissive(Color(1, 1, 0.92), 3.0)
	head.position = Vector3(0, 0.38, -L * 0.49); head.name = "headlights"
	root.add_child(head)
	var tail := MeshInstance3D.new()
	var tb := BoxMesh.new(); tb.size = Vector3(W * 0.8, 0.07, 0.05)
	tail.mesh = tb; tail.material_override = emissive(Color(1, 0.08, 0.1), 1.6)
	tail.position = Vector3(0, 0.52, L * 0.5); tail.name = "taillights"
	root.add_child(tail)
	# reverse lights (lit only in reverse)
	var rev := MeshInstance3D.new()
	var rvb := BoxMesh.new(); rvb.size = Vector3(W * 0.24, 0.05, 0.04)
	rev.mesh = rvb; rev.material_override = emissive(Color(1, 1, 0.95), 0.0)
	rev.position = Vector3(0, 0.44, L * 0.5); rev.name = "revlights"
	root.add_child(rev)
	# side mirrors
	for side in [-1, 1]:
		var mir := MeshInstance3D.new()
		var mb := BoxMesh.new(); mb.size = Vector3(0.16, 0.08, 0.10)
		mir.mesh = mb; mir.material_override = paint_material(hex, finish) if not police else paint_material("f2f2f2", "gloss")
		mir.position = Vector3(side * W * 0.52, 0.72, -L * 0.08)
		mir.name = "mirror_%d" % side
		root.add_child(mir)
	# front splitter + rear diffuser
	var split := panel("splitter", Vector3(W * 0.96, 0.05, 0.34), Vector3(0, 0.12, -L * 0.47), trim, 0.1, 0.0, 2)
	root.add_child(split); panels.append(split)
	var diff := panel("diffuser", Vector3(W * 0.8, 0.10, 0.22), Vector3(0, 0.14, L * 0.46), trim, 0.0, 0.0, 2)
	root.add_child(diff); panels.append(diff)
	# exhaust tips
	for ex_x in [-0.16, 0.16]:
		var ex := MeshInstance3D.new()
		var ec := CylinderMesh.new(); ec.top_radius = 0.05; ec.bottom_radius = 0.05; ec.height = 0.12
		ex.mesh = ec
		var em := StandardMaterial3D.new(); em.albedo_color = Color(0.35, 0.3, 0.28); em.metallic = 0.9; em.roughness = 0.35
		ex.material_override = em
		ex.rotation_degrees.x = 90
		ex.position = Vector3(ex_x * W, 0.30, L * 0.5)
		root.add_child(ex)
	# wheel-arch flares — wheels read as inside the body, not floating
	for fx in [[-1, -0.33], [1, -0.33], [-1, 0.34], [1, 0.34]]:
		var arch := MeshInstance3D.new()
		var am2 := BoxMesh.new(); am2.size = Vector3(0.14, 0.30, 0.98)
		arch.mesh = am2
		arch.material_override = trim
		arch.position = Vector3(fx[0] * W * 0.485, 0.52, fx[1] * L)
		arch.name = "arch_%d_%d" % [fx[0], int(fx[1] * 100)]
		root.add_child(arch)
	# cockpit silhouette visible through the glass
	var seat := MeshInstance3D.new()
	var sb2 := BoxMesh.new(); sb2.size = Vector3(W * 0.24, 0.24, 0.4)
	seat.mesh = sb2; seat.material_override = trim
	seat.position = Vector3(-W * 0.16, 0.56, L * 0.06)
	root.add_child(seat)
	var swheel := MeshInstance3D.new()
	var tor := TorusMesh.new(); tor.inner_radius = 0.09; tor.outer_radius = 0.13
	swheel.mesh = tor; swheel.material_override = trim
	swheel.rotation_degrees.x = 70
	swheel.position = Vector3(-W * 0.16, 0.62, -L * 0.04)
	root.add_child(swheel)
	# headlight beams
	for side in [-1, 1]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(side * W * 0.3, 0.4, -L * 0.48)
		spot.rotation_degrees = Vector3(-4, 180, 0)
		spot.spot_range = 75.0; spot.spot_angle = 26.0
		spot.light_energy = 3.2; spot.light_color = Color(1, 0.97, 0.88)
		spot.name = "beam_%d" % side
		root.add_child(spot)

	if police:
		# blue stripe livery
		var stripe := panel("stripe", Vector3(W * 1.001, 0.14, L * 0.5), Vector3(0, 0.42, 0.05), paint_material("0a1f66", "gloss"), 0.22, 0.0, 2)
		root.add_child(stripe); panels.append(stripe)
		# lightbar
		var bar := Node3D.new(); bar.name = "lightbar"; bar.position = Vector3(0, 1.06, 0.1)
		var base := MeshInstance3D.new()
		var bb := BoxMesh.new(); bb.size = Vector3(W * 0.5, 0.09, 0.22)
		base.mesh = bb; base.material_override = trim
		bar.add_child(base)
		var red := MeshInstance3D.new()
		var rb := BoxMesh.new(); rb.size = Vector3(W * 0.22, 0.08, 0.2)
		red.mesh = rb; red.material_override = emissive(Color(1, 0.05, 0.05), 4.0)
		red.position.x = -W * 0.13; red.name = "red"
		bar.add_child(red)
		var blue := red.duplicate()
		blue.material_override = emissive(Color(0.1, 0.25, 1), 4.0)
		blue.position.x = W * 0.13; blue.name = "blue"
		bar.add_child(blue)
		var flash := OmniLight3D.new()
		flash.name = "flash"; flash.position.y = 0.4
		flash.light_energy = 2.0; flash.omni_range = 14.0
		bar.add_child(flash)
		root.add_child(bar)
		# bullbar
		var bull := MeshInstance3D.new()
		var ub := BoxMesh.new(); ub.size = Vector3(W * 0.9, 0.34, 0.12)
		bull.mesh = ub; bull.material_override = trim
		bull.position = Vector3(0, 0.34, -L * 0.52); bull.name = "bullbar"
		root.add_child(bull)

	root.set_meta("panels", panels)
	root.set_meta("shape", shape)
	return root

static func wheel_visual(radius: float) -> Node3D:
	var n := Node3D.new()
	var tyre := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 0.32; cyl.top_radius = radius; cyl.bottom_radius = radius
	tyre.mesh = cyl
	tyre.rotation_degrees = Vector3(0, 0, 90)
	var tm := StandardMaterial3D.new(); tm.albedo_color = Color(0.05, 0.05, 0.05); tm.roughness = 0.9
	tyre.material_override = tm
	n.add_child(tyre)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.height = 0.34; rc.top_radius = radius * 0.55; rc.bottom_radius = radius * 0.55
	rim.mesh = rc
	rim.rotation_degrees = Vector3(0, 0, 90)
	var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.30, 0.31, 0.34); rm.metallic = 0.85; rm.roughness = 0.42
	rim.material_override = rm
	n.add_child(rim)
	return n

# ---------- BeamNG-style impact crumpling ----------
# Displaces vertices of every panel within `radius` of the impact point
# along the impact direction, with falloff + jitter. Cumulative and permanent.
static func deform(visual: Node3D, world_pos: Vector3, world_dir: Vector3, amount: float, radius := 1.1) -> void:
	if not visual.has_meta("panels"): return
	for mi in visual.get_meta("panels"):
		if not is_instance_valid(mi): continue
		var am: ArrayMesh = mi.mesh
		if am == null or am.get_surface_count() == 0: continue
		var local_pos: Vector3 = mi.global_transform.affine_inverse() * world_pos
		var local_dir: Vector3 = (mi.global_transform.basis.inverse() * world_dir).normalized()
		var mdt := MeshDataTool.new()
		if mdt.create_from_surface(am, 0) != OK: continue
		var touched := false
		for i in mdt.get_vertex_count():
			var v := mdt.get_vertex(i)
			var dist := v.distance_to(local_pos)
			if dist < radius:
				var fall := (1.0 - dist / radius)
				var jitter := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.06 * amount
				mdt.set_vertex(i, v + local_dir * amount * fall * 0.42 + jitter * fall)
				touched = true
		if touched:
			am.clear_surfaces()
			mdt.commit_to_surface(am)

# Rip a named panel off as a physical debris body.
static func detach(visual: Node3D, pname: String, impulse: Vector3) -> void:
	var mi: MeshInstance3D = visual.get_node_or_null(pname)
	if mi == null: return
	var panels: Array = visual.get_meta("panels")
	panels.erase(mi)
	var body := RigidBody3D.new()
	body.mass = 12.0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = mi.get_aabb().size.clamp(Vector3(0.05, 0.05, 0.05), Vector3(3, 3, 3))
	shape.shape = bs
	body.add_child(shape)
	var xf := mi.global_transform
	mi.get_parent().remove_child(mi)
	mi.position = Vector3.ZERO; mi.rotation = Vector3.ZERO
	body.add_child(mi)
	visual.get_tree().current_scene.add_child(body)
	body.global_transform = xf
	body.linear_velocity = impulse
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	var timer := visual.get_tree().create_timer(8.0)
	timer.timeout.connect(func(): if is_instance_valid(body): body.queue_free())

# ============================================================
# v5 — imported 3D model skins (user-supplied GLTF car models)
# One shared loader: normalises orientation/scale, finds the four
# wheel clusters by name+position and splits them into hub-mounted
# wheelsets so imported wheels spin and steer with the physics.
# ============================================================
static var _skin_cache := {}

static func _skin_scene(path: String) -> PackedScene:
	if not _skin_cache.has(path):
		var ps: PackedScene = null
		if ResourceLoader.exists(path):
			ps = load(path)              # already imported by the editor
		else:
			# v9: RUNTIME import (GLTFDocument) — models work the moment the
			# files exist, no editor import pass, no restart needed.
			# v9.1: cache the packed scene to user:// so the slow parse only
			# ever happens ONCE per model (later loads are instant binary).
			var cache := "user://model_cache_" + path.get_base_dir().get_file() + ".scn"
			if FileAccess.file_exists(cache):
				ps = ResourceLoader.load(cache)
			if ps == null:
				var doc := GLTFDocument.new()
				var st := GLTFState.new()
				if doc.append_from_file(ProjectSettings.globalize_path(path), st) == OK:
					var node := doc.generate_scene(st)
					if node != null:
						ps = PackedScene.new()
						if ps.pack(node) != OK: ps = null
						else: ResourceSaver.save(ps, cache)
						node.queue_free()
		_skin_cache[path] = ps
	return _skin_cache[path]

static func _collect_meshes(node: Node, xf: Transform3D, out: Array) -> void:
	if node is Node3D:
		xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			out.append({"mi": node, "xf": xf})
	for c in node.get_children():
		_collect_meshes(c, xf, out)

static func _is_wheel_name(n: String) -> bool:
	var low := n.to_lower()
	if "steering" in low: return false
	var token := ""
	var tokens: Array = []
	for ch in low:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			token += ch
		else:
			if token != "": tokens.append(token)
			token = ""
	if token != "": tokens.append(token)
	for t in tokens:
		if t in ["tire", "tyre", "wheel", "rim", "rims", "caliper", "brake", "disc", "wheels"]:
			return true
		if t.begins_with("tire") or t.begins_with("tyre") or t.begins_with("wheel"):
			return true
	return false

static func build_model_visual(skin_id: String, shape: Dictionary) -> Node3D:
	var skin: Dictionary = D.MODEL_SKINS.get(skin_id, {})
	var root := Node3D.new()
	root.name = "Visual"
	root.set_meta("model_skin", skin_id)
	# defensive: never try to load an uninstalled model pack
	if not FileAccess.file_exists(str(skin.get("path", ""))):
		push_warning("Model skin '%s' not installed — using procedural body. (Install the model pack zips to enable it.)" % skin_id)
		return build_visual("8a99a8", "gloss", shape)
	var ps := _skin_scene(str(skin.get("path", "")))
	if ps == null or not ps.can_instantiate():
		push_warning("model skin missing: " + skin_id)
		return build_visual("8a99a8", "gloss", shape)
	var inst: Node3D = ps.instantiate()
	# multi-car packs: keep only the named subtree, drop its siblings
	var only := str(skin.get("only", ""))
	if only != "":
		var keep := inst.find_child(only, true, false)
		if keep != null:
			var par := keep.get_parent()
			for sib in par.get_children():
				if sib != keep:
					par.remove_child(sib)
					sib.free()
	var meshes: Array = []
	_collect_meshes(inst, Transform3D.IDENTITY, meshes)
	# drop baked shadow/glow planes — they stretch the AABB and float under the car
	var cleaned: Array = []
	for m in meshes:
		if "shadow" in str(m.mi.name).to_lower():
			(m.mi as MeshInstance3D).visible = false
		else:
			cleaned.append(m)
	meshes = cleaned
	if meshes.is_empty():
		root.add_child(inst)
		return root
	# combined AABB in the imported scene's space
	var aabb: AABB = (meshes[0].xf as Transform3D) * (meshes[0].mi.get_aabb() as AABB)
	for m in meshes:
		aabb = aabb.merge((m.xf as Transform3D) * (m.mi.get_aabb() as AABB))
	# orient: car length along Z, then per-skin yaw fix (nose must face -Z)
	var yaw := 0.0
	if aabb.size.x > aabb.size.z:
		yaw = 90.0
	# imported scenes face +Z; the game's forward is -Z (180° base flip)
	yaw += 180.0 + float(skin.get("yaw", 0.0))
	var rot := Basis(Vector3.UP, deg_to_rad(yaw))
	# recompute post-rotation AABB extents from the 8 corners
	var centre := aabb.get_center()
	var rmin := Vector3(1e18, 1e18, 1e18)
	var rmax := Vector3(-1e18, -1e18, -1e18)
	for i in 8:
		var corner := aabb.position + Vector3(
			aabb.size.x * float(i & 1), aabb.size.y * float((i >> 1) & 1), aabb.size.z * float((i >> 2) & 1))
		var p := rot * (corner - centre)
		rmin = rmin.min(p); rmax = rmax.max(p)
	var rsize := rmax - rmin
	var target_len: float = float(shape.get("len", 4.5)) * 1.04
	var s: float = target_len / maxf(rsize.z, 0.01)
	s *= float(skin.get("scale", 1.0))
	# container: rotate + scale + centre; vertical placement set after wheels
	var container := Node3D.new()
	container.name = "model"
	root.add_child(container)
	container.transform = Transform3D(rot.scaled(Vector3.ONE * s), Vector3.ZERO)
	container.add_child(inst)
	inst.position = -centre     # centre the model inside the container (pre-rotation space)
	# wheel clusters — root-space centres of wheel-named meshes
	var half_w := rsize.x * s * 0.5
	var half_l := rsize.z * s * 0.5
	var wheelish: Array = []
	for m in meshes:
		if not _is_wheel_name(str(m.mi.name)): continue
		var xf_root: Transform3D = container.transform * Transform3D(Basis.IDENTITY, -centre) * m.xf
		var c: Vector3 = xf_root * (m.mi.get_aabb() as AABB).get_center()
		if absf(c.x) < half_w * 0.30 or absf(c.z) < half_l * 0.18:
			continue          # centre-mounted (spare / interior) — leave on body
		wheelish.append({"m": m, "xf_root": xf_root, "c": c})
	# classify into the four corners first — only split if ALL four exist
	var corners := {"wfl": Vector3(-1, 0, -1), "wfr": Vector3(1, 0, -1), "wrl": Vector3(-1, 0, 1), "wrr": Vector3(1, 0, 1)}
	var grouped := {}
	for key in corners:
		var members: Array = []
		var csum := Vector3.ZERO
		for w in wheelish:
			var sgn: Vector3 = corners[key]
			if signf(w.c.x) == sgn.x and signf(w.c.z) == sgn.z:
				members.append(w)
				csum += w.c
		if not members.is_empty():
			grouped[key] = {"members": members, "centre": csum / members.size()}
	if grouped.size() == 4:
		var sets := {}
		var hub_y := 0.0
		for key in grouped:
			var cc: Vector3 = grouped[key].centre
			var set_node := Node3D.new()
			set_node.name = "wheelset_" + key
			for w in grouped[key].members:
				var mi: MeshInstance3D = w.m.mi
				mi.get_parent().remove_child(mi)
				set_node.add_child(mi)
				mi.transform = Transform3D(Basis.IDENTITY, -cc) * (w.xf_root as Transform3D)
			sets[key] = {"node": set_node, "centre": cc}
			hub_y += cc.y
		root.set_meta("wheelsets", sets)
		# drop the body so the average hub height matches the physics hubs (~0.10)
		container.position.y = 0.10 - hub_y / 4.0
	else:
		# leave the model intact and sit it on its tyres
		container.position.y = -(rmin.y * s) - 0.34
	return root
