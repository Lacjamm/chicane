# Converts the vendored Kenney Car Kit (CC0) GLB models into the per-skin
# scene.gltf folders that MODEL_SKINS expects (assets/models/<skin>/scene.gltf).
# Each skin gets its own hue-shifted copy of the shared palette texture so the
# 21 skins stay visually distinct even where they share a base body.
#
# Run from the repo root:
#   godot --headless --path chicane3d --script ../tools/convert_car_models.gd
extends SceneTree

# skin id -> source glb, hue shift (deg), saturation/value multipliers,
# and whether to bake a 180° yaw (skins whose d.gd yaw fix expects a
# nose--Z model; Kenney cars face +Z).
const MAP := {
	"jesko":        {"src": "race-future",      "hue": 0.0,   "smul": 1.0,  "vmul": 1.0},
	"jesko_attack": {"src": "race-future",      "hue": 150.0, "smul": 1.0,  "vmul": 1.0},
	"one1":         {"src": "race-future",      "hue": 60.0,  "smul": 1.0,  "vmul": 0.9},
	"tourbillon":   {"src": "race-future",      "hue": 210.0, "smul": 1.0,  "vmul": 1.0},
	"czinger":      {"src": "race-future",      "hue": 310.0, "smul": 1.0,  "vmul": 1.0},
	"agera_rs":     {"src": "race",             "hue": 0.0,   "smul": 1.0,  "vmul": 1.0},
	"agera_rs_cf":  {"src": "race",             "hue": 0.0,   "smul": 0.35, "vmul": 0.35},
	"agera11":      {"src": "race",             "hue": 40.0,  "smul": 1.0,  "vmul": 1.0},
	"divo":         {"src": "race",             "hue": 215.0, "smul": 1.0,  "vmul": 1.0},
	"bolide":       {"src": "race",             "hue": 330.0, "smul": 0.9,  "vmul": 1.0},
	"m720gt3":      {"src": "race",             "hue": 120.0, "smul": 1.0,  "vmul": 1.0},
	"aventador":    {"src": "sedan-sports",     "hue": 0.0,   "smul": 1.0,  "vmul": 1.0, "bake_yaw": true},
	"revuelto":     {"src": "sedan-sports",     "hue": 90.0,  "smul": 1.0,  "vmul": 1.0},
	"countach":     {"src": "sedan-sports",     "hue": 0.0,   "smul": 0.15, "vmul": 1.4, "bake_yaw": true},
	"i8":           {"src": "sedan-sports",     "hue": 250.0, "smul": 1.0,  "vmul": 1.0},
	"camaro_gs":    {"src": "hatchback-sports", "hue": 0.0,   "smul": 1.0,  "vmul": 1.0},
	"vw_lp":        {"src": "hatchback-sports", "hue": 130.0, "smul": 1.0,  "vmul": 1.0},
	"goblin":       {"src": "kart-oozi",        "hue": 0.0,   "smul": 1.0,  "vmul": 1.0, "bake_yaw": true},
	"firebird":     {"src": "kart-oopi",        "hue": 30.0,  "smul": 1.0,  "vmul": 1.0},
	"agera_r_cop":  {"src": "police",           "hue": 0.0,   "smul": 1.0,  "vmul": 1.0},
	"one1_cop":     {"src": "police",           "hue": 180.0, "smul": 1.0,  "vmul": 1.0},
}

func _initialize() -> void:
	var kit := ProjectSettings.globalize_path("res://").path_join("../tools/kenney_car_kit")
	var dest_root := ProjectSettings.globalize_path("res://assets/models")
	var fails := 0
	for sid in MAP:
		var m: Dictionary = MAP[sid]
		if _convert(kit.path_join(str(m.src) + ".glb"), dest_root.path_join(sid),
				float(m.hue), float(m.smul), float(m.vmul), bool(m.get("bake_yaw", false))):
			print("PASS  converted skin: %s (%s)" % [sid, m.src])
		else:
			print("FAIL  convert skin: %s" % sid)
			fails += 1
	print("== convert done, %d/%d ok ==" % [MAP.size() - fails, MAP.size()])
	quit(0 if fails == 0 else 1)

func _convert(src: String, dest_dir: String, hue: float, smul: float, vmul: float, bake_yaw: bool) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(src, state) != OK:
		push_error("cannot read " + src)
		return false
	var node := doc.generate_scene(state)
	if node == null:
		return false
	# karts ship with a driver figure — not wanted on a hypercar chassis
	var chr := node.find_child("character", true, false)
	if chr:
		chr.get_parent().remove_child(chr)
		chr.free()
	_recolor_materials(node, hue, smul, vmul)
	var root: Node3D = node
	if bake_yaw:
		root = Node3D.new()
		root.name = node.name + "_flipped"
		node.rotation.y = PI
		root.add_child(node)
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var out_doc := GLTFDocument.new()
	var out_state := GLTFState.new()
	var okc := out_doc.append_from_scene(root, out_state) == OK \
		and out_doc.write_to_filesystem(out_state, dest_dir.path_join("scene.gltf")) == OK
	root.queue_free()
	return okc

# Hue-rotate the shared palette texture; low-saturation pixels (tyres, glass,
# details) are left untouched so only the paint areas change.
func _recolor_materials(node: Node, hue: float, smul: float, vmul: float) -> void:
	if hue == 0.0 and smul == 1.0 and vmul == 1.0:
		return
	var done := {}
	for mat in _collect_materials(node, []):
		var bm := mat as BaseMaterial3D
		if bm == null or bm.albedo_texture == null or done.has(bm.albedo_texture):
			continue
		var img: Image = bm.albedo_texture.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.s < 0.2:
					continue
				img.set_pixel(x, y, Color.from_hsv(fposmod(c.h + hue / 360.0, 1.0),
					clampf(c.s * smul, 0.0, 1.0), clampf(c.v * vmul, 0.0, 1.0), c.a))
		var tex := ImageTexture.create_from_image(img)
		done[bm.albedo_texture] = true
		_swap_texture(node, bm.albedo_texture, tex)

func _collect_materials(node: Node, out: Array) -> Array:
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat and not out.has(mat):
				out.append(mat)
	for c in node.get_children():
		_collect_materials(c, out)
	return out

func _swap_texture(node: Node, from: Texture2D, to: Texture2D) -> void:
	for mat in _collect_materials(node, []):
		var bm := mat as BaseMaterial3D
		if bm and bm.albedo_texture == from:
			bm.albedo_texture = to
