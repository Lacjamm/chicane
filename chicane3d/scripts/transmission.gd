# ============================================================
# CHICANE 3D — transmission.gd
# Engine + gearbox simulation: torque curves, 6 speeds + reverse,
# shift power cuts, engine braking, launch traction control.
# Owned by any vehicle; pure logic, no nodes.
# ============================================================
class_name Transmission
extends RefCounted

# Fraction of top speed each gear reaches at redline
const GEAR_SPEEDS := [0.20, 0.33, 0.47, 0.63, 0.81, 1.03]
const SHIFT_UP := 0.94
const SHIFT_DOWN := 0.42
const SHIFT_TIME := 0.17

var gear := 1                 # 1..6, 0 = reverse
var rpm := 0.15               # 0..1 normalised
var shifting := 0.0           # >0 while power is cut
var spinning := false         # launch wheelspin flag
var just_shifted := false     # one-frame flag for audio/vfx
var engine_class := "balanced"
var top_kmh := 320.0
var power := 5000.0           # base drive force N
var tc_enabled := true
var manual := false           # v5: player-selected manual gearbox

func shift_up() -> void:
	if not manual or shifting > 0.0 or gear < 1 or gear >= 6: return
	gear += 1
	shifting = SHIFT_TIME
	just_shifted = true

func shift_down(speed_kmh: float) -> void:
	if not manual or shifting > 0.0 or gear <= 1: return
	# downshift protection — refuse a shift that would over-rev the engine
	var would: float = speed_kmh / maxf(top_kmh * GEAR_SPEEDS[gear - 2], 1.0)
	if would < 1.06:
		gear -= 1
		shifting = SHIFT_TIME * 0.7
		just_shifted = true

func setup(cls: String, stats: Dictionary) -> void:
	top_kmh = stats.kmh
	power = 3800.0 + stats.acc * 800.0
	if "Drift" in cls or "Muscle" in cls: engine_class = "punchy"
	elif "Grand" in cls: engine_class = "broad"
	elif "Track" in cls or "Secret Track" in cls or "Prototype" in cls or "Experimental" in cls: engine_class = "peaky"
	elif "Hybrid" in cls: engine_class = "hybrid"
	else: engine_class = "balanced"

# Normalised torque at normalised rpm — the engine's personality.
func torque_at(r: float) -> float:
	r = clampf(r, 0.0, 1.1)
	match engine_class:
		"peaky":   return 0.35 + 0.75 * clampf(sin(PI * clampf((r - 0.15) / 0.95, 0.0, 1.0)), 0.0, 1.0)
		"broad":   return 0.72 + 0.28 * sin(PI * clampf(r * 1.1, 0.0, 1.0))
		"hybrid":  return clampf(1.05 - r * 0.25, 0.55, 1.05)     # instant torque, tapers up top
		"punchy":  return 0.5 + 0.6 * sin(PI * clampf((r - 0.05) / 0.8, 0.0, 1.0))
		_:         return 0.55 + 0.45 * sin(PI * clampf(r, 0.0, 1.0))

# Returns signed drive force. reverse_request = brake held near standstill.
func update(delta: float, speed_kmh: float, throttle: float, reverse_request: bool,
		grounded: bool, rear_grip := 1.0) -> float:
	just_shifted = false
	spinning = false
	if shifting > 0.0:
		shifting -= delta
	# --- reverse gear ---
	if reverse_request and speed_kmh < 8.0:
		gear = 0
	if gear == 0:
		rpm = clampf(speed_kmh / (top_kmh * 0.12), 0.1, 1.0)
		if throttle > 0.1 and speed_kmh < 4.0:
			gear = 1     # back to drive
		elif reverse_request:
			return power * 0.45   # applied backwards by the caller
		else:
			gear = 1
	# --- rpm from speed within current gear ---
	var gear_top: float = top_kmh * GEAR_SPEEDS[gear - 1]
	rpm = clampf(speed_kmh / maxf(gear_top, 1.0), 0.0, 1.12)
	if speed_kmh < 3.0: rpm = maxf(rpm, 0.12 + throttle * 0.25)
	# --- automatic shifts (skipped in manual mode) ---
	if shifting <= 0.0 and not manual:
		if rpm > SHIFT_UP and gear < 6:
			gear += 1
			shifting = SHIFT_TIME
			just_shifted = true
			rpm = clampf(speed_kmh / (top_kmh * GEAR_SPEEDS[gear - 1]), 0.0, 1.0)
		elif rpm < SHIFT_DOWN and gear > 1 and speed_kmh > 8.0:
			gear -= 1
			shifting = SHIFT_TIME * 0.7
			rpm = clampf(speed_kmh / (top_kmh * GEAR_SPEEDS[gear - 1]), 0.0, 1.0)
	# --- drive force ---
	if not grounded: return 0.0
	if shifting > 0.0: return power * 0.08 * throttle    # brief cut
	if throttle <= 0.02:
		# engine braking, stronger at high rpm and low gears
		return -power * 0.10 * rpm * (1.3 - float(gear) * 0.12) * signf(speed_kmh)
	var ratio_mult: float = lerpf(2.1, 0.85, float(gear - 1) / 5.0)
	var force := power * torque_at(rpm) * ratio_mult * throttle
	# manual-mode rev limiter: bouncing off the top of a held gear
	if manual and rpm > 1.08:
		force *= 0.22
	# launch traction control: first-gear power capped by rear grip
	if gear == 1 and speed_kmh < 40.0:
		var cap := power * (1.15 + rear_grip * 0.5)
		if force > cap:
			spinning = not tc_enabled
			force = cap if tc_enabled else force * 0.82
	return force

func gear_label() -> String:
	return "R" if gear == 0 else str(gear)
