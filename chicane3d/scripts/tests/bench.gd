# Performance benchmark: world generation time + runtime frame/physics cost.
# Run: godot --headless --path . scenes/tests/Bench.tscn   (also works with rendering)
extends Node
var race: RaceManager
var frames := 0
var t_accum := 0.0
var worst := 0.0
var gen_ms := 0.0

func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	var w := TrackGen.generate_world(P.world_seed())
	gen_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	w.root.free()
	race = RaceManager.new()
	add_child(race)
	race.start({"id":"roam","zone":"coastal","mode":"roam","name":"Bench","len":21.0,"heat":0,"cash":0,"rep":0,"tier":3}, "racer")
	Input.action_press("accel")

func _physics_process(delta: float) -> void:
	if race == null or race.state != "racing": return
	frames += 1
	t_accum += delta
	worst = maxf(worst, delta)
	if frames == 600:      # ~10s of simulation
		var bodies := 0
		var stack: Array = [race]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is PhysicsBody3D: bodies += 1
			stack.append_array(n.get_children())
		print("BENCH world_gen_ms=%.0f" % gen_ms)
		print("BENCH avg_physics_frame_ms=%.2f worst_ms=%.2f" % [t_accum / frames * 1000.0, worst * 1000.0])
		print("BENCH physics_bodies=%d samples=%d fps_now=%.0f" % [bodies, race.samples.size(), Engine.get_frames_per_second()])
		print("BENCH mem_static_mb=%.1f" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
		print("BENCH DONE")
		get_tree().quit()
