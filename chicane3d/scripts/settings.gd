# ============================================================
# CHICANE 3D — settings.gd (autoload "S")
# Player settings: audio, video, controls, gameplay. Persisted
# inside the profile save with safe defaults / migration.
# ============================================================
extends Node

const DEFAULTS := {
	"vol_master": 1.0, "vol_music": 0.8, "vol_engine": 1.0, "vol_fx": 1.0,
	"fov": 0.0,               # extra FOV offset -10..+15
	"cam_shake": 1.0,         # 0..1 multiplier
	"deadzone": 0.15,
	"steer_sens": 1.0,        # 0.5..1.5
	"traffic": 1.0,           # density multiplier 0..1.5
	"quality": 1,             # 0 low, 1 medium, 2 high
	"vibration": true,
	"speed_streaks": true,
	# v5 — driving assists, transmission and camera preferences
	"trans_mode": "auto",     # "auto" | "manual"
	"assist_abs": true,
	"assist_tc": true,
	"assist_stab": true,
	"assist_steer": 1.0,      # countersteer assist strength 0..1
	"cam_dist": 1.0,          # chase camera distance multiplier
	"cam_height": 1.0,        # chase camera height multiplier
	"rain_fx": true,          # rain particles in wet districts
	"brightness": 1.0,        # v9.4 — world brightness multiplier 0.6..1.6
	"god_mode": false,        # v9.5 — player takes no damage/stun/spikes
	"radar": true,            # v9.5 — proximity radar blips on the HUD
}

var last_device_pad := false   # HUD prompt switching

func _ready() -> void:
	_migrate()
	apply_audio()
	apply_deadzone()

func apply_deadzone() -> void:
	for a in ["accel", "brake", "left", "right"]:
		if InputMap.has_action(a):
			InputMap.action_set_deadzone(a, float(g("deadzone")))

func _migrate() -> void:
	if not P.data.has("settings") or not (P.data.settings is Dictionary):
		P.data["settings"] = {}
	for k in DEFAULTS:
		if not P.data.settings.has(k):
			P.data.settings[k] = DEFAULTS[k]
	# other new save fields with safe defaults
	if not P.data.has("bests"): P.data["bests"] = {}      # event id -> best metric
	if not P.data.has("medals"): P.data["medals"] = {}    # event id -> "gold"/"silver"
	# v4 open world — migrate older saves without touching their progress
	if not (P.data.get("roam") is Dictionary):
		P.data["roam"] = {}
	var roam_defs := {"seed":20260803, "disc":"", "barns":{}, "cams":{}, "flags":{}}
	for k in roam_defs:
		if not P.data.roam.has(k):
			P.data.roam[k] = roam_defs[k]
	P.save_game()

func g(key: String):
	return P.data.settings.get(key, DEFAULTS.get(key))

func set_s(key: String, value) -> void:
	P.data.settings[key] = value
	P.save_game()
	if key.begins_with("vol_"): apply_audio()

func apply_audio() -> void:
	SFX.master_vol = g("vol_master")
	SFX.music_vol = g("vol_music")
	SFX.engine_vol = g("vol_engine")
	SFX.fx_vol = g("vol_fx")
	SFX.refresh_volumes()

# Quality preset helpers used by race/world builders
func shadows_enabled() -> bool: return int(g("quality")) >= 1
func glow_enabled() -> bool: return int(g("quality")) >= 1
func ssao_enabled() -> bool: return int(g("quality")) >= 2
func particle_scale() -> float: return [0.5, 1.0, 1.3][clampi(int(g("quality")), 0, 2)]
func msaa() -> int: return [0, 1, 2][clampi(int(g("quality")), 0, 2)]

func vibrate(weak: float, strong: float, dur: float) -> void:
	if not g("vibration"): return
	if not last_device_pad: return
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, clampf(weak, 0, 1), clampf(strong, 0, 1), dur)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.25: return
		last_device_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		last_device_pad = false
