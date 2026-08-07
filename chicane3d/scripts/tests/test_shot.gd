# Visual verification: sequential coroutine, capture PNG screenshots.
extends Node
var race: RaceManager

func _ready() -> void:
	_run()

func _run() -> void:
	# menu + garage
	var menus := Menus.new()
	add_child(menus)
	await _wait(1.2)
	await _snap("menu")
	menus.show_garage("saber")
	await _wait(2.0)
	await _snap("garage")
	menus.show_settings()
	await _wait(1.0)
	await _snap("settings")
	menus.queue_free()
	await _wait(0.3)
	# neon race
	race = RaceManager.new()
	add_child(race)
	race.start(D.RACER_EVENTS[0], "racer")
	Input.action_press("accel")
	await _wait(11.0)
	await _snap("race_neon")
	race.hud.toggle_inventory()
	await _wait(0.3)
	await _snap("inventory")
	race.hud.toggle_inventory()
	race.player.take_impact(race.player.global_position + Vector3(0.5, 0.6, -1.8), Vector3(0.3, 0.2, 0.9), 24.0, 1.0)
	CarFactory.detach(race.player.visual, "fbumper", Vector3(2, 5, 3))
	race.hud.flash(true)
	await _wait(0.4)
	await _snap("crash_deform")
	# force a death to capture the RIP! + respawn countdown
	race.player.hp = 0.0
	await _wait(1.6)
	await _snap("rip_countdown")
	race.cleanup(); race.queue_free()
	await _wait(0.3)
	# coastal
	race = RaceManager.new()
	add_child(race)
	race.start(D.RACER_EVENTS[5], "racer")
	Input.action_press("accel")
	await _wait(9.0)
	Input.action_press("nitro")
	await _wait(2.0)
	await _snap("race_coastal")
	race.cleanup(); race.queue_free()
	Input.action_release("nitro")
	await _wait(0.3)
	# desert cop pursuit
	race = RaceManager.new()
	add_child(race)
	race.start(D.COP_EVENTS[1], "cop")
	Input.action_press("accel")
	await _wait(10.0)
	await _snap("race_cop")
	race.cleanup(); race.queue_free()
	Input.action_release("accel")
	await _wait(0.3)
	# VELOCITY COUNTY — car close-up + three districts
	race = RaceManager.new()
	add_child(race)
	race.start({"id":"roam", "zone":"coastal", "mode":"roam", "name":"Velocity County",
		"len":21.0, "heat":0, "cash":0, "rep":0, "tier":3}, "racer")
	await _wait(1.5)
	await _snap("roam_car_closeup")     # stationary — verify solid opaque body
	Input.action_press("accel")
	await _wait(9.0)
	await _snap("roam_coastal")
	_tp = race.length * (1.5 / 6.0) + 200.0   # mid-Neon City (teleport in physics tick)
	await _wait(6.0)
	print("DBG neon prog=%.0f zone=%s" % [race.player.progress, race.roam.cur_zone])
	await _snap("roam_neon")
	_tp = race.length * (4.5 / 6.0) + 200.0   # mid-Crimson Desert
	await _wait(6.0)
	print("DBG desert prog=%.0f zone=%s" % [race.player.progress, race.roam.cur_zone])
	await _snap("roam_desert")
	get_tree().quit()

var _tp := -1.0

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

var _tick := 0

func _physics_process(_d: float) -> void:
	# keep the car centered whenever a race is live
	if race == null or not is_instance_valid(race) or race.player == null: return
	if race.state != "racing": return
	if _tp >= 0.0:
		race.player.reset_to_track_at(_tp)
		print("DBG teleported to d=%.0f -> pos=%v" % [_tp, race.player.global_position])
		_tp = -1.0
	var p := race.player
	_tick += 1
	if _tick % 120 == 0:
		var cam_pos := Vector3.ZERO
		var vp_cam := get_viewport().get_camera_3d()
		if vp_cam: cam_pos = vp_cam.global_position
		print("DBG zone=%s prog=%.0f lat=%.1f kmh=%.0f carpos=%v campos=%v" %
			[race.zone_key, p.progress, p.lateral, p.kmh(), p.global_position, cam_pos])
	var s: Dictionary = race.samples[clampi(p.track_idx + 3, 0, race.samples.size() - 1)]
	var fwd := -p.global_transform.basis.z
	var ang: float = fwd.signed_angle_to(s.fwd, Vector3.UP)
	var steer := clampf(ang * 1.4 + clampf(p.lateral * 0.12, -0.6, 0.6), -1.0, 1.0)
	if steer > 0.06:
		Input.action_press("left", clampf(steer, 0.0, 1.0)); Input.action_release("right")
	elif steer < -0.06:
		Input.action_press("right", clampf(-steer, 0.0, 1.0)); Input.action_release("left")
	else:
		Input.action_release("left"); Input.action_release("right")

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/%s.png" % name)
	print("SNAP ", name)
