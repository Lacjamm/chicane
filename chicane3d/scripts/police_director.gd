# ============================================================
# CHICANE 3D — police_director.gd
# Coordinates the pursuit: spawn cadence, unit roles by heat,
# box-in flanking, and interceptors ahead (always with warning).
# ============================================================
class_name PoliceDirector
extends Node

var race: Node
var spawn_t := 6.0
var _flank_t := 0.0

func setup(r: Node) -> void:
	race = r

func max_cops(heat: int) -> int:
	if heat >= 10: return 6
	if heat >= 8: return 5
	if heat >= 6: return 4
	if heat >= 4: return 3
	if heat >= 2: return 2
	return 1

func cop_car_for_heat(heat: int) -> String:
	if heat >= 9: return "cop5"
	if heat >= 7: return "cop4"
	if heat >= 4: return "cop3"
	if heat >= 2: return "cop2"
	return "cop1"

func _role_for_spawn(heat: int, alive: Array) -> String:
	var have_ram := alive.any(func(c): return c.cop_role == "ram")
	var have_spike := alive.any(func(c): return c.cop_role == "spike")
	if heat >= 8 and randf() < 0.3: return "intercept"
	if heat >= 6 and not have_spike and randf() < 0.4: return "spike"
	if heat >= 4 and not have_ram and randf() < 0.5: return "ram"
	return "chase"

func update(delta: float) -> void:
	if race == null or not race.wanted or race.heat <= 0 or race.career == "cop": return
	var diff := P.diff()
	spawn_t -= delta
	var alive: Array = race.cops.filter(func(c): return is_instance_valid(c) and not c.dead and not c.wrecked)
	if spawn_t <= 0.0 and alive.size() < max_cops(race.heat):
		var role := _role_for_spawn(race.heat, alive)
		race.spawn_cop(cop_car_for_heat(race.heat), role)
		spawn_t = maxf(1.2, (6.5 if race.mode in ["escape", "free"] else 9.0) - race.heat * 0.55)
	# --- box-in coordination: two close cops split to either flank ---
	_flank_t -= delta
	if _flank_t <= 0.0:
		_flank_t = 1.5
		var close := alive.filter(func(c):
			return absf(c.progress - race.player.progress) < 35.0 and c.cop_role == "chase")
		if close.size() >= 2:
			close[0].flank = -1.0
			close[1].flank = 1.0
			for i in range(2, close.size()):
				close[i].flank = 0.0
		else:
			for c in close:
				c.flank = 0.0
