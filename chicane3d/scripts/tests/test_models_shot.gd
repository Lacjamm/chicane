# Visual verification of installed model-skin packs: lays every installed
# skin out in a grid (wheelsets mounted like the garage preview does),
# snaps one overview PNG to shots/ and exits. Needs a rendering context —
# run it non-headless (window flashes briefly; use xvfb-run in containers).
extends Node

const COLS := 5
const SPACING := Vector3(5.0, 0.0, 7.0)

func _ready() -> void:
	var world := Node3D.new()
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(120, 120)
	world.add_child(floor_mesh)
	var n := 0
	var installed: Array = []
	for sid in D.MODEL_SKINS:
		if D.skin_ok(sid): installed.append(sid)
	for sid in installed:
		var v := CarFactory.build_model_visual(sid, {"len":4.6,"wid":2.0,"nose":1.0,"tail":0.6,"wing":0.3})
		if v.has_meta("wheelsets"):
			var sets: Dictionary = v.get_meta("wheelsets")
			for k in sets:
				var sn: Node3D = sets[k].node
				v.add_child(sn)
				sn.position = Vector3(sets[k].centre.x, 0.10, sets[k].centre.z)
		var col := n % COLS
		var row := n / COLS
		v.position = Vector3((col - (COLS - 1) * 0.5) * SPACING.x, 0.0, row * SPACING.z)
		v.rotation_degrees.y = 205.0   # three-quarter view, nose toward camera
		world.add_child(v)
		var lbl := Label3D.new()
		lbl.text = sid
		lbl.font_size = 64
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = v.position + Vector3(0, 2.2, 0)
		world.add_child(lbl)
		n += 1
	print("grid: %d installed skins" % n)
	var rows := ceili(float(n) / COLS)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 14.0, -12.0)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.0, rows * SPACING.z * 0.42))
	cam.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/models_grid.png")
	print("SNAP models_grid (%d skins)" % n)
	get_tree().quit()
