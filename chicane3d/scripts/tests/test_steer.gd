# Focused steering diagnostic — 30s of r01 with per-second telemetry.
extends Node
var race: RaceManager
var timer := 0.0
var log_t := 0.0

func _ready() -> void:
	race = RaceManager.new()
	add_child(race)
	race.start(D.RACER_EVENTS[5], "racer")

func _physics_process(delta: float) -> void:
	if race == null: return
	timer += delta
	log_t += delta
	if race.state == "racing":
		var p := race.player
		Input.action_press("accel")
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
		if log_t > 1.0:
			log_t = 0.0
			var curv := TrackGen._curvature(race.samples, p.track_idx)
			print("t=%4.1f prog=%5.0f lat=%6.2f kmh=%5.1f ang=%6.3f steer_cmd=%6.3f steering=%6.3f curv=%7.4f grounded=%s slip=%s" %
				[timer, p.progress, p.lateral, p.kmh(), ang, steer, p.steering, curv, str(p._grounded()), str(p.drifting)])
	if timer > 30.0:
		get_tree().quit()
