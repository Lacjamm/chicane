# ============================================================
# CHICANE: FULL THROTTLE 3D — p.gd (autoload "P")
# Player profile, save/load, progression, secrets
# ============================================================
extends Node

const SAVE_PATH := "user://chicane_save.json"

var data: Dictionary = {}
signal secret_unlocked(car: Dictionary)

func _ready() -> void:
	load_game()

func fresh() -> Dictionary:
	return {
		"diff":"normal", "cash":20000, "rep":0, "cop_rep":0,
		"cars":{"falco":{"up":{}, "paint":"e8192c", "finish":"gloss"}},
		"cur":"falco", "cop_cur":"cop1",
		"wins":{}, "cop_wins":{}, "secrets":{}, "station":"throttle",
		"stats":{"races":0,"wins":0,"escapes":0,"busts":0,"takedowns":0,"best_speed":0,"best_drift":0,"bounty":0,"earned":0},
		"flags":{}, "volume":1.0, "seen_intro":false,
		# v4 — Velocity County open world (deterministic seed, discovery, barn finds, cameras)
		"roam":{"seed":20260803, "disc":"", "barns":{}, "cams":{}, "flags":{}},
	}

# The one seed for Velocity County — same seed, same world, every session.
func world_seed() -> int:
	if not (data.get("roam") is Dictionary): return 20260803
	return int(data.roam.get("seed", 20260803))

# Barn-find restoration: each finished event advances every recovered wreck;
# after 3 events the car is restored into the garage (cash if already owned).
func barn_tick() -> Array:
	var restored: Array = []
	if not (data.get("roam") is Dictionary): return restored
	var barns: Dictionary = data.roam.get("barns", {})
	for site in D.BARN_SITES:
		if str(barns.get(site.id, "")) != "found": continue
		var k: String = site.id + "_races"
		barns[k] = int(barns.get(k, 0)) + 1
		if int(barns[k]) >= 3:
			barns[site.id] = "done"
			if owns(site.car):
				data.cash += 40000
			else:
				give_car(site.car)
			restored.append(site.car)
	save_game()
	return restored

func load_game() -> void:
	data = fresh()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary and parsed.has("cars"):
			var base := fresh()
			base.merge(parsed, true)
			data = base

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func reset() -> void:
	data = fresh()
	save_game()

func diff() -> Dictionary: return D.DIFFICULTY[data.diff]
func racer_rank() -> int: return clampi(int(data.rep) / D.REP_PER_RANK + 1, 1, 10)
func cop_rank() -> int: return clampi(int(data.cop_rep) / D.COP_REP_PER_RANK + 1, 1, 10)

func owns(id: String) -> bool: return data.cars.has(id)

func car_cfg(id: String) -> Dictionary:
	if data.cars.has(id): return data.cars[id]
	return {"up":{}, "paint":"8a99a8", "finish":"gloss"}

# Effective stats after upgrades: {top, acc, hand, drift, str, nitro, empres, spkres, kmh}
func car_stats(id: String) -> Dictionary:
	var d := D.car_def(id)
	var s := {"top":d.top,"acc":d.acc,"hand":d.hand,"drift":d.drift,"str":d.str,"nitro":d.nitro,"empres":0.0,"spkres":0.0}
	if data.cars.has(id):
		var ups: Dictionary = data.cars[id].up
		for u in D.UPGRADES:
			var lvl: int = ups.get(u.id, 0)
			s[u.stat] = s.get(u.stat, 0.0) + lvl * u.per
			# trade-offs: upgrades shift the car's character, not just its numbers
			match u.id:
				"engine": s.hand -= lvl * 0.05
				"armour": s.acc -= lvl * 0.08
				"susp":   s.hand -= lvl * 0.06
				"tyres":  s.drift -= lvl * 0.10
	s["kmh"] = D.stat_to_kmh(s.top)
	return s

# Performance Rating — one number for quick comparisons
func car_pr(id: String) -> int:
	var s := car_stats(id)
	return int(round((s.top * 1.2 + s.acc + s.hand + s.drift * 0.5 + s.nitro * 0.5) * 9.0))

func completion_pct() -> int:
	var total := D.RACER_EVENTS.size() + D.COP_EVENTS.size() + D.SECRET_CARS.size()
	var done: int = data.wins.size() + data.cop_wins.size() + data.secrets.size()
	return int(round(float(done) / total * 100.0))

func give_car(id: String) -> void:
	if not data.cars.has(id):
		data.cars[id] = {"up":{}, "paint":D.PAINTS[randi() % D.PAINTS.size()], "finish":"gloss"}

func tier_unlocked(t: int) -> bool:
	if t <= 1: return true
	var prev := D.RACER_EVENTS.filter(func(e): return e.tier == t - 1)
	var won := prev.filter(func(e): return data.wins.has(e.id)).size()
	return won >= maxi(2, prev.size() - 1)

func cop_mission_unlocked(i: int) -> bool:
	if i == 0: return true
	return data.cop_wins.has(D.COP_EVENTS[i - 1].id)

func check_secrets() -> void:
	var w: Dictionary = data.wins
	var all_won := func(events: Array) -> bool:
		for e in events:
			if not w.has(e.id): return false
		return true
	var cond := {
		"allDrift": all_won.call(D.RACER_EVENTS.filter(func(e): return e.mode == "drift")),
		"neonSeries": all_won.call(D.RACER_EVENTS.filter(func(e): return e.zone == "neon")),
		"heat8escape": data.flags.has("heat8escape"),
		"maxRank": racer_rank() >= 10,
		"blackTrack": all_won.call(D.RACER_EVENTS.filter(func(e): return e.zone == "blacktrack")),
		"beatZero": w.has("r32"),
	}
	for sc in D.SECRET_CARS:
		if not data.secrets.has(sc.id) and cond.get(sc.unlock, false):
			data.secrets[sc.id] = true
			give_car(sc.id)
			secret_unlocked.emit(sc)
	save_game()
