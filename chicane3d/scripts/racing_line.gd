# ============================================================
# CHICANE 3D — racing_line.gd
# Precomputes a racing line for a track: apex-cutting lateral
# offsets and physically-derived corner speeds with braking
# zones (backward pass). Built once per race, shared by all AI.
# ============================================================
class_name RacingLine
extends RefCounted

# Returns {offset: PackedFloat32Array, speed: PackedFloat32Array}
static func build(samples: Array, loop := false) -> Dictionary:
	var n := samples.size()
	var offset := PackedFloat32Array()
	var speed := PackedFloat32Array()
	offset.resize(n)
	speed.resize(n)
	if n < 8:
		for i in n: offset[i] = 0.0; speed[i] = 300.0
		return {"offset": offset, "speed": speed}
	# --- curvature (heading change over ~4 samples) ---
	var curv := PackedFloat32Array()
	curv.resize(n)
	for i in n:
		var i0 := (i - 2 + n) % n if loop else clampi(i - 2, 0, n - 1)
		var i1 := (i + 2) % n if loop else clampi(i + 2, 0, n - 1)
		var f0: Vector3 = samples[i0].fwd
		var f1: Vector3 = samples[i1].fwd
		curv[i] = f0.signed_angle_to(f1, Vector3.UP)
	# --- apex offsets: cut toward the inside of upcoming bends, smoothed ---
	for i in n:
		var look := 0.0
		for k in range(0, 14, 2):
			var j := (i + k) % n if loop else clampi(i + k, 0, n - 1)
			look += curv[j]
		offset[i] = clampf(-look * 9.0, -5.2, 5.2)
	offset = _smooth(offset, 6, loop)
	# --- corner speeds from curvature radius: v = sqrt(mu·g·r) ---
	var arc := TrackGen.SAMPLE * 4.0
	for i in n:
		var a := absf(curv[i])
		if a < 0.005:
			speed[i] = 460.0
		else:
			var radius := arc / a
			speed[i] = clampf(sqrt(11.0 * radius) * 3.6 * 1.30, 62.0, 460.0)
	# --- backward pass: braking zones (limit approach speed) ---
	var decel := 10.5   # m/s²
	var ds := TrackGen.SAMPLE
	var passes := 2 if loop else 1
	for _p in passes:
		for i in range(n - 1, -1, -1):
			var nxt := (i + 1) % n if loop else mini(i + 1, n - 1)
			var v_next: float = speed[nxt] / 3.6
			var v_max := sqrt(v_next * v_next + 2.0 * decel * ds) * 3.6
			speed[i] = minf(speed[i], v_max)
	speed = _smooth(speed, 3, loop)
	return {"offset": offset, "speed": speed}

static func _smooth(arr: PackedFloat32Array, radius: int, loop: bool) -> PackedFloat32Array:
	var n := arr.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var acc := 0.0
		var cnt := 0
		for k in range(-radius, radius + 1):
			var j := (i + k + n) % n if loop else clampi(i + k, 0, n - 1)
			acc += arr[j]
			cnt += 1
		out[i] = acc / cnt
	return out
