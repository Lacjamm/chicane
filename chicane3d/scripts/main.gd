# ============================================================
# CHICANE 3D — main.gd
# Root orchestrator: menus <-> races, pause, radio.
# ============================================================
extends Node

var menus: Menus
var race: RaceManager = null
var paused := false
var pause_ui: CanvasLayer = null

func _ready() -> void:
	menus = Menus.new()
	add_child(menus)
	menus.launch_race.connect(_start_race)
	P.secret_unlocked.connect(func(sc): if menus.visible: menus.show_secret_popup(sc))
	SFX.set_station(P.data.station)
	# v8.1: auto-find model packs extracted ANYWHERE near the project and
	# copy them into place — no manual folder merging needed.
	var copied := _auto_install_models()
	var n_ok := 0
	for sid in D.MODEL_SKINS:
		if D.skin_ok(sid): n_ok += 1
	# v9.1: first time the packs are present, gift a model car and make it
	# the current ride — so your imported cars are what you actually drive.
	if n_ok > 0 and not P.data.flags.has("model_gift"):
		P.data.flags["model_gift"] = true
		if D.skin_ok("camaro_gs") and not P.owns("marauder"):
			P.give_car("marauder")
		if D.skin_ok("aventador") and not P.owns("tempesta"):
			P.give_car("tempesta")
		if P.owns("marauder"): P.data.cur = "marauder"
		elif P.owns("tempesta"): P.data.cur = "tempesta"
		P.save_game()
	if n_ok < D.MODEL_SKINS.size():
		var warn := Label.new()
		if copied > 0:
			warn.text = "✔ Installed %d car model pack(s) — your cars are ready right now." % copied
		else:
			warn.text = "⚠ CAR MODEL PACKS: %d/%d installed — put the extracted model-zip folders anywhere in or next to this game's folder and restart; the game will install them itself." % [n_ok, D.MODEL_SKINS.size()]
		warn.add_theme_font_size_override("font_size", 14)
		warn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		warn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		warn.offset_top = -30
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cl := CanvasLayer.new()
		cl.layer = 30
		cl.add_child(warn)
		add_child(cl)

func _start_race(ev: Dictionary, career: String) -> void:
	menus.visible = false
	race = RaceManager.new()
	add_child(race)
	race.start(ev, career)
	race.finished.connect(_on_race_finished.bind(career))

func _on_race_finished(summary: Dictionary, career: String) -> void:
	var mode: String = race.mode
	_teardown_race()
	menus.visible = true
	if mode in ["free", "roam"]:
		menus.show_menu()
	else:
		menus.show_results(summary, career)

func _teardown_race() -> void:
	if race and is_instance_valid(race):
		race.cleanup()
		race.queue_free()
	race = null
	if pause_ui:
		pause_ui.queue_free()
		pause_ui = null
	paused = false
	get_tree().paused = false
	Engine.time_scale = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radio"):
		var station := SFX.cycle_radio()
		if race and race.hud: race.hud.toast("📻 " + station, "")
	if event.is_action_pressed("pause") and race != null:
		_toggle_pause()

func _toggle_pause() -> void:
	if race == null or race.state == "done": return
	paused = not paused
	get_tree().paused = paused
	if paused:
		pause_ui = CanvasLayer.new()
		pause_ui.layer = 20
		pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		pause_ui.add_child(center)
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.05, 0.13, 0.97)
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(26)
		panel.add_theme_stylebox_override("panel", sb)
		center.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		panel.add_child(v)
		var t := Label.new()
		t.text = "PAUSED"
		t.add_theme_font_size_override("font_size", 40)
		v.add_child(t)
		var resume := Button.new()
		resume.text = "RESUME"
		resume.pressed.connect(_toggle_pause)
		v.add_child(resume)
		var restart := Button.new()
		restart.text = "RESTART EVENT"
		restart.pressed.connect(func():
			var ev: Dictionary = race.ev
			var career: String = race.career
			get_tree().paused = false
			paused = false
			_teardown_race()
			_start_race(ev, career))
		v.add_child(restart)
		var quit := Button.new()
		quit.text = "QUIT TO MENU"
		quit.pressed.connect(func():
			get_tree().paused = false
			paused = false
			_teardown_race()
			menus.visible = true
			menus.show_menu())
		v.add_child(quit)
		add_child(pause_ui)
		resume.grab_focus()
	else:
		if pause_ui:
			pause_ui.queue_free()
			pause_ui = null

# ============================================================
# v8.1 — model-pack auto-installer.
# Searches the project folder, its parent and grandparent (depth 4) for
# directories named after a known skin that contain scene.gltf — however
# the zips were extracted — and copies them into res://assets/models/.
# ============================================================
func _auto_install_models() -> int:
	var dest_root := ProjectSettings.globalize_path("res://assets/models")
	var proj := ProjectSettings.globalize_path("res://").rstrip("/")
	var roots := [proj, proj.get_base_dir(), proj.get_base_dir().get_base_dir()]
	var wanted := {}
	for sid in D.MODEL_SKINS:
		if not FileAccess.file_exists(str(D.MODEL_SKINS[sid].path)):
			wanted[sid] = true
	if wanted.is_empty(): return 0
	var copied := 0
	for root in roots:
		if wanted.is_empty(): break
		copied += _scan_packs(str(root), 0, wanted, dest_root)
	# v8.2: also read the model ZIPS directly — no extraction needed at all
	for root in roots:
		copied += _install_from_zips(str(root), dest_root)
	if copied > 0:
		print("Auto-installed %d model folder(s) into assets/models — restart to import." % copied)
	return copied

func _scan_packs(path: String, depth: int, wanted: Dictionary, dest_root: String) -> int:
	if depth > 4 or path.ends_with("/.godot") or path.ends_with("assets/models"): return 0
	var d := DirAccess.open(path)
	if d == null: return 0
	var copied := 0
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir() and not n.begins_with("."):
			var sub := path + "/" + n
			if wanted.has(n) and FileAccess.file_exists(sub + "/" + str(D.MODEL_SKINS[n].path).get_file()):
				if _copy_dir(sub, dest_root + "/" + n):
					copied += 1
					wanted.erase(n)
			else:
				copied += _scan_packs(sub, depth + 1, wanted, dest_root)
		n = d.get_next()
	d.list_dir_end()
	return copied

func _copy_dir(src: String, dst: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dst)
	var d := DirAccess.open(src)
	if d == null: return false
	d.list_dir_begin()
	var n := d.get_next()
	var okc := true
	while n != "":
		if n.begins_with("."):
			n = d.get_next(); continue
		if d.current_is_dir():
			if not _copy_dir(src + "/" + n, dst + "/" + n): okc = false
		else:
			var f := FileAccess.open(src + "/" + n, FileAccess.READ)
			if f:
				var out := FileAccess.open(dst + "/" + n, FileAccess.WRITE)
				if out: out.store_buffer(f.get_buffer(f.get_length()))
				else: okc = false
			else: okc = false
		n = d.get_next()
	d.list_dir_end()
	return okc

# v8.2 — pull models straight out of any chicane model zip lying in or next
# to the game folder (ZIPReader), so players never have to extract them.
func _install_from_zips(root: String, dest_root: String) -> int:
	var d := DirAccess.open(root)
	if d == null: return 0
	var got := 0
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.to_lower().ends_with(".zip") and "model" in n.to_lower():
			var zr := ZIPReader.new()
			if zr.open(root + "/" + n) == OK:
				var wrote := 0
				for f in zr.get_files():
					var k := f.find("assets/models/")
					if k >= 0 and not f.ends_with("/"):
						var rel := f.substr(k + 14)
						if rel == "": continue
						var dst := dest_root + "/" + rel
						if FileAccess.file_exists(dst): continue
						DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
						var out := FileAccess.open(dst, FileAccess.WRITE)
						if out:
							out.store_buffer(zr.read_file(f))
							wrote += 1
				zr.close()
				if wrote > 0:
					got += 1
					print("Installed models from ", n)
		n = d.get_next()
	d.list_dir_end()
	return got
