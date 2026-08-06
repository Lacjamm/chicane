# ============================================================
# CHICANE: FULL THROTTLE 3D — d.gd (autoload "D")
# Static game data: cars, zones, events, bosses, upgrades
# ============================================================
extends Node

const DIFFICULTY := {
	"easy":   {"label":"Cruise",  "ai":0.86, "cop":0.90, "aggro":0.7, "cash":1.25, "dmg":0.55, "desc":"Forgiving racing, big rewards. Great for younger drivers."},
	"normal": {"label":"Redline", "ai":1.00, "cop":1.00, "aggro":1.0, "cash":1.0,  "dmg":1.0,  "desc":"The intended Full Throttle experience."},
	"hard":   {"label":"Apex",    "ai":1.07, "cop":1.08, "aggro":1.4, "cash":1.15, "dmg":1.4,  "desc":"Ruthless rivals. Relentless police."},
}

# stats 1..10: top, acc, hand, drift, str, nitro   | shape: silhouette params for CarFactory
const CARS := [
	{"id":"falco",   "name":"Falco GT-S",       "cls":"Supercar",        "price":0,      "top":5.0,"acc":5.0,"hand":6.0,"drift":5.5,"str":5.0,"nitro":4.5,"heat":1, "shape":{"len":4.4,"wid":1.95,"nose":0.9,"tail":0.6,"wing":0.5}},
	{"id":"vipera",  "name":"Vipera Elemento",  "cls":"Drift Special",   "price":52000,  "top":5.8,"acc":6.5,"hand":7.0,"drift":9.5,"str":4.0,"nitro":5.5,"heat":2, "shape":{"len":4.3,"wid":2.0,"nose":1.1,"tail":0.5,"wing":0.7}},
	{"id":"nzo",     "name":"Scuderia NZO",     "cls":"Track Hypercar",  "price":68000,  "top":6.2,"acc":6.2,"hand":7.5,"drift":5.5,"str":5.0,"nitro":5.5,"heat":2, "shape":{"len":4.7,"wid":2.0,"nose":1.2,"tail":0.5,"wing":0.3}},
	{"id":"wraith",  "name":"Wraith 918-W",     "cls":"Hybrid Hypercar", "price":84000,  "top":6.4,"acc":7.5,"hand":7.5,"drift":5.0,"str":5.5,"nitro":6.0,"heat":3, "shape":{"len":4.6,"wid":1.95,"nose":1.0,"tail":0.7,"wing":0.4}},
	{"id":"solaris", "name":"Solaris P-One",    "cls":"Hybrid Hypercar", "price":105000, "top":6.8,"acc":7.8,"hand":7.8,"drift":6.0,"str":5.0,"nitro":7.0,"heat":3, "shape":{"len":4.6,"wid":2.0,"nose":1.1,"tail":0.6,"wing":0.6}},
	{"id":"tempesta","name":"Tempesta SVJ",     "cls":"Track Hypercar",  "price":128000, "top":7.0,"acc":7.2,"hand":8.2,"drift":6.5,"str":5.5,"nitro":6.5,"heat":4, "shape":{"len":4.8,"wid":2.1,"nose":1.3,"tail":0.5,"wing":0.8},
		"skins":["aventador","revuelto","countach"]},
	{"id":"zephyr",  "name":"Zephyr Cinque",    "cls":"Track Hypercar",  "price":150000, "top":7.2,"acc":7.0,"hand":8.5,"drift":7.5,"str":5.0,"nitro":6.5,"heat":4, "shape":{"len":4.4,"wid":2.0,"nose":1.2,"tail":0.6,"wing":0.9}},
	{"id":"vulcan",  "name":"Vulcan 16.4",      "cls":"Grand-Speed",     "price":180000, "top":8.2,"acc":7.0,"hand":6.0,"drift":4.0,"str":8.0,"nitro":7.0,"heat":5, "shape":{"len":4.5,"wid":2.0,"nose":0.8,"tail":0.8,"wing":0.2}},
	{"id":"saber",   "name":"Saber R-X",        "cls":"Track Hypercar",  "price":215000, "top":7.6,"acc":8.0,"hand":9.3,"drift":6.0,"str":4.5,"nitro":7.0,"heat":5, "shape":{"len":4.7,"wid":2.0,"nose":1.2,"tail":0.5,"wing":1.0}},
	{"id":"helios",  "name":"Helios FXX-E",     "cls":"Track Hypercar",  "price":250000, "top":7.8,"acc":8.2,"hand":9.0,"drift":6.5,"str":5.0,"nitro":7.5,"heat":6, "shape":{"len":4.9,"wid":2.1,"nose":1.3,"tail":0.4,"wing":0.9}},
	{"id":"regalia", "name":"Regalia RG-1",     "cls":"Hybrid Hypercar", "price":290000, "top":8.4,"acc":9.6,"hand":7.0,"drift":5.0,"str":6.0,"nitro":8.0,"heat":6, "shape":{"len":4.6,"wid":2.05,"nose":1.0,"tail":0.7,"wing":0.4}},
	{"id":"valkyra", "name":"Valkyra AV-Pro",   "cls":"Track Hypercar",  "price":340000, "top":8.4,"acc":8.8,"hand":9.6,"drift":5.5,"str":4.5,"nitro":8.0,"heat":7, "shape":{"len":4.7,"wid":2.0,"nose":1.4,"tail":0.4,"wing":1.0}},
	{"id":"monarch", "name":"Monarch One",      "cls":"Hybrid Hypercar", "price":400000, "top":8.6,"acc":9.0,"hand":9.2,"drift":6.0,"str":6.0,"nitro":8.5,"heat":8, "shape":{"len":4.8,"wid":2.05,"nose":1.2,"tail":0.5,"wing":0.7}},
	{"id":"cyclone", "name":"Cyclone Sport SS", "cls":"Grand-Speed",     "price":470000, "top":9.4,"acc":8.6,"hand":7.0,"drift":4.5,"str":8.5,"nitro":8.5,"heat":8, "shape":{"len":4.6,"wid":2.05,"nose":0.9,"tail":0.8,"wing":0.2}},
	{"id":"kestrel", "name":"Kestrel AG-RS",    "cls":"Grand-Speed",     "price":540000, "top":9.6,"acc":9.0,"hand":7.8,"drift":6.0,"str":6.5,"nitro":9.0,"heat":9, "shape":{"len":4.5,"wid":2.05,"nose":1.0,"tail":0.6,"wing":0.8}},
	{"id":"krait",   "name":"Krait J-90",       "cls":"Grand-Speed",     "price":640000, "top":9.8,"acc":9.4,"hand":8.4,"drift":6.0,"str":6.5,"nitro":9.5,"heat":10,"shape":{"len":4.6,"wid":2.05,"nose":1.1,"tail":0.6,"wing":0.9}},
	{"id":"aegir",   "name":"Aegir Konung",     "cls":"Megacar",         "price":480000, "top":9.6,"acc":9.2,"hand":8.6,"drift":6.0,"str":6.5,"nitro":9.0,"heat":8, "shape":{"len":4.5,"wid":2.05,"nose":1.0,"tail":0.6,"wing":0.6},
		"skins":["jesko","agera_rs","agera_rs_cf","agera11","one1","jesko_attack"]},
	{"id":"ion",     "name":"Ion GT-e",         "cls":"Hybrid Sports",   "price":98000,  "top":6.6,"acc":7.4,"hand":7.8,"drift":5.5,"str":5.5,"nitro":6.5,"heat":2, "shape":{"len":4.7,"wid":2.0,"nose":1.1,"tail":0.7,"wing":0.2},
		"skins":["i8"]},
	{"id":"talon",   "name":"Talon GT3-R",      "cls":"Track Racer",     "price":260000, "top":8.6,"acc":8.4,"hand":9.4,"drift":6.5,"str":6.0,"nitro":7.0,"heat":5, "shape":{"len":4.6,"wid":2.05,"nose":1.1,"tail":0.7,"wing":1.2},
		"skins":["m720gt3"]},
	{"id":"vitesse", "name":"Vitesse Royale",   "cls":"Hyper GT",        "price":420000, "top":9.4,"acc":9.0,"hand":8.2,"drift":5.5,"str":7.0,"nitro":8.5,"heat":7, "shape":{"len":4.6,"wid":2.05,"nose":1.0,"tail":0.7,"wing":0.8},
		"skins":["divo","bolide","tourbillon"]},
	{"id":"marauder","name":"Marauder GS-R",    "cls":"Muscle Racer",    "price":74000,  "top":6.8,"acc":7.0,"hand":6.6,"drift":7.5,"str":8.0,"nitro":6.0,"heat":3, "shape":{"len":4.8,"wid":2.0,"nose":1.2,"tail":0.8,"wing":0.4},
		"skins":["camaro_gs","firebird"]},
	{"id":"goblin",  "name":"Goblin V12",       "cls":"Track Hypercar",  "price":195000, "top":8.2,"acc":8.2,"hand":8.8,"drift":6.5,"str":5.5,"nitro":7.5,"heat":5, "shape":{"len":4.5,"wid":2.05,"nose":1.1,"tail":0.6,"wing":0.9},
		"skins":["goblin"]},
	{"id":"cinder",  "name":"Cinder 21C",       "cls":"Experimental Prototype", "price":380000, "top":9.2,"acc":9.4,"hand":9.0,"drift":5.5,"str":5.0,"nitro":8.5,"heat":7, "shape":{"len":4.5,"wid":2.0,"nose":1.2,"tail":0.6,"wing":1.0},
		"skins":["czinger"]},
	{"id":"wolf",    "name":"Wolf Compact",     "cls":"Compact",         "price":16000,  "top":4.6,"acc":5.0,"hand":6.8,"drift":5.0,"str":6.0,"nitro":4.5,"heat":1, "shape":{"len":4.1,"wid":1.9,"nose":0.9,"tail":0.9,"wing":0.1},
		"skins":["vw_lp"]},
]

const SECRET_CARS := [
	{"id":"zondaer", "name":"Zephyr Erre",   "cls":"Secret Track",  "top":8.8,"acc":8.8,"hand":9.4,"drift":8.5,"str":5.0,"nitro":8.0,"heat":8,  "unlock":"allDrift",   "hint":"Win every Drift Trial in Velora Coast.",             "shape":{"len":4.4,"wid":2.05,"nose":1.2,"tail":0.5,"wing":1.1}},
	{"id":"lykan",   "name":"Lykan Halo",    "cls":"Secret Luxury", "top":8.6,"acc":8.4,"hand":8.2,"drift":7.0,"str":6.5,"nitro":8.5,"heat":8,  "unlock":"neonSeries", "hint":"Win every event in Neon City.",                     "shape":{"len":4.5,"wid":2.0,"nose":1.1,"tail":0.6,"wing":0.6}},
	{"id":"fenyr",   "name":"Fenyr FS-X",    "cls":"Secret Beast",  "top":9.0,"acc":9.0,"hand":8.6,"drift":7.5,"str":7.0,"nitro":8.5,"heat":9,  "unlock":"heat8escape","hint":"Escape a Heat 8+ pursuit without getting busted.",  "shape":{"len":4.6,"wid":2.05,"nose":1.0,"tail":0.7,"wing":0.7}},
	{"id":"venomf5", "name":"Venin V5",      "cls":"Secret Speed",  "top":10.0,"acc":9.4,"hand":7.6,"drift":5.5,"str":7.0,"nitro":9.5,"heat":10,"unlock":"maxRank",    "hint":"Reach the rank of Full Throttle Legend.",           "shape":{"len":4.7,"wid":2.0,"nose":1.0,"tail":0.7,"wing":0.5}},
	{"id":"solus",   "name":"Solus GT-X",    "cls":"Secret Track",  "top":9.2,"acc":9.6,"hand":10.0,"drift":6.5,"str":4.5,"nitro":9.0,"heat":10,"unlock":"blackTrack", "hint":"Win every event on the Black Track.",               "shape":{"len":4.6,"wid":2.1,"nose":1.4,"tail":0.4,"wing":1.2}},
	{"id":"absolut", "name":"Krait Absolut", "cls":"Secret Legend", "top":10.0,"acc":9.8,"hand":8.8,"drift":6.0,"str":6.5,"nitro":10.0,"heat":10,"unlock":"beatZero",  "hint":"Defeat Zero on the Black Track.",                   "shape":{"len":4.7,"wid":2.0,"nose":1.0,"tail":0.8,"wing":0.3}},
]

const COP_CARS := [
	{"id":"cop1","name":"VCPD Interceptor GT","rank":1,"top":6.5,"acc":6.5,"hand":7.0,"drift":5.0,"str":8.5,"nitro":6.0,"shape":{"len":4.7,"wid":2.0,"nose":0.9,"tail":0.7,"wing":0.3}},
	{"id":"cop2","name":"VCPD Enforcer SVJ",  "rank":3,"top":7.5,"acc":7.5,"hand":8.0,"drift":5.5,"str":9.0,"nitro":7.0,"shape":{"len":4.9,"wid":2.1,"nose":1.3,"tail":0.5,"wing":0.8}},
	{"id":"cop3","name":"VCPD Pursuit RG-1",  "rank":5,"top":8.4,"acc":9.2,"hand":7.5,"drift":5.0,"str":9.0,"nitro":8.0,"shape":{"len":4.6,"wid":2.05,"nose":1.0,"tail":0.7,"wing":0.4}},
	{"id":"cop4","name":"VCPD Guardian One",  "rank":7,"top":9.0,"acc":9.0,"hand":9.0,"drift":5.5,"str":9.5,"nitro":8.5,"shape":{"len":4.8,"wid":2.05,"nose":1.2,"tail":0.5,"wing":0.7}},
	{"id":"cop5","name":"VCPD Lockdown J-90", "rank":9,"top":9.8,"acc":9.5,"hand":8.5,"drift":6.0,"str":10.0,"nitro":9.5,"shape":{"len":4.6,"wid":2.05,"nose":1.1,"tail":0.6,"wing":0.9}},
	{"id":"cop6","name":"VCPD Valkyr Unit",  "rank":10,"top":9.9,"acc":9.6,"hand":8.8,"drift":6.0,"str":10.0,"nitro":9.5,"shape":{"len":4.5,"wid":2.05,"nose":1.0,"tail":0.6,"wing":0.7},
		"skins":["agera_r_cop","one1_cop"]},
]

const PAINTS := ["e8192c","ff6a00","ffd400","3ddc47","00e5d0","1e90ff","7b4dff","ff3dbf","f2f2f2","151515","8a99a8","c47a2c"]
const FINISHES := ["gloss","matte","metallic","carbon","chrome"]

const UPGRADES := [
	{"id":"engine","name":"Engine",           "stat":"top",  "per":0.35,"base":9000, "desc":"+ Top speed  / − launch grip"},
	{"id":"turbo", "name":"Turbo Kit",        "stat":"acc",  "per":0.35,"base":8000, "desc":"+ Acceleration"},
	{"id":"tyres", "name":"Race Tyres",       "stat":"hand", "per":0.35,"base":7000, "desc":"+ Grip  / − drift initiation"},
	{"id":"susp",  "name":"Drift Suspension", "stat":"drift","per":0.40,"base":7000, "desc":"+ Drift control  / − high-speed stability"},
	{"id":"armour","name":"Armour Plating",   "stat":"str",  "per":0.45,"base":8500, "desc":"+ Crash strength  / − acceleration (weight)"},
	{"id":"nitro", "name":"Nitrous System",   "stat":"nitro","per":0.40,"base":9500, "desc":"+ Nitrous power"},
	{"id":"emp",   "name":"EMP Shielding",    "stat":"empres","per":1.0,"base":12000,"desc":"- EMP stun time"},
	{"id":"spike", "name":"Run-Flat Tyres",   "stat":"spkres","per":1.0,"base":11000,"desc":"- Spike damage"},
]
const MAX_UP := 4

# Zone visual definitions — sky colors, sun, fog, ground, scenery type
const ZONES := {
	"neon":     {"name":"Neon City",            "tag":"NIGHT CIRCUITS",     "sky_top":Color(0.02,0.004,0.06),"sky_hor":Color(0.23,0.07,0.38),"sun":Color(1.0,0.4,0.85),"sun_energy":0.7,"ambient":0.5,"fog":Color(0.08,0.02,0.17),"fog_density":0.006,"ground":Color(0.045,0.045,0.075),"scenery":"city","night":true,"wet":true},
	"desert":   {"name":"Crimson Desert",       "tag":"OPEN THROTTLE",      "sky_top":Color(0.17,0.04,0.04),"sky_hor":Color(1.0,0.45,0.16),"sun":Color(1.0,0.75,0.5),"sun_energy":1.3,"ambient":0.5,"fog":Color(0.7,0.32,0.14),"fog_density":0.003,"ground":Color(0.62,0.27,0.14),"scenery":"desert","night":false,"wet":false},
	"mountain": {"name":"Stormridge Mountains", "tag":"DRIFT COUNTRY",      "sky_top":Color(0.05,0.08,0.12),"sky_hor":Color(0.33,0.44,0.54),"sun":Color(0.8,0.87,0.95),"sun_energy":0.7,"ambient":0.45,"fog":Color(0.45,0.56,0.65),"fog_density":0.010,"ground":Color(0.12,0.20,0.15),"scenery":"mountain","night":false,"wet":true},
	"airport":  {"name":"Aeroport Runway",      "tag":"MAX VELOCITY TEST",  "sky_top":Color(0.06,0.08,0.15),"sky_hor":Color(0.37,0.45,0.72),"sun":Color(0.8,0.85,1.0),"sun_energy":0.5,"ambient":0.35,"fog":Color(0.12,0.16,0.31),"fog_density":0.003,"ground":Color(0.16,0.18,0.22),"scenery":"airport","night":true,"wet":false},
	"coastal":  {"name":"Coastal Freeway",      "tag":"TOP SPEED PARADISE", "sky_top":Color(0.07,0.15,0.29),"sky_hor":Color(1.0,0.85,0.63),"sun":Color(1.0,0.85,0.6),"sun_energy":1.2,"ambient":0.5,"fog":Color(0.55,0.6,0.62),"fog_density":0.002,"ground":Color(0.17,0.42,0.56),"scenery":"coastal","night":false,"wet":false},
	"docks":    {"name":"Industrial Docks",     "tag":"PURSUIT ALLEY",      "sky_top":Color(0.04,0.06,0.07),"sky_hor":Color(0.22,0.31,0.36),"sun":Color(1.0,0.68,0.37),"sun_energy":0.5,"ambient":0.35,"fog":Color(0.12,0.18,0.21),"fog_density":0.006,"ground":Color(0.13,0.16,0.17),"scenery":"docks","night":true,"wet":true},
	"blacktrack":{"name":"The Black Track",     "tag":"CLASSIFIED",         "sky_top":Color(0.0,0.0,0.0),"sky_hor":Color(0.15,0.01,0.05),"sun":Color(1.0,0.0,0.2),"sun_energy":0.4,"ambient":0.22,"fog":Color(0.08,0.0,0.03),"fog_density":0.008,"ground":Color(0.03,0.03,0.04),"scenery":"blacktrack","night":true,"wet":false},
}

# v5 — imported 3D model skins (user-supplied GLTF models in assets/models/).
# All are bodywork variants of the Aegir megacar line; "proc" = procedural body.
const MODEL_SKINS := {
	"jesko":        {"name":"Jarl",          "path":"res://assets/models/jesko/scene.gltf",        "yaw":0.0},
	"jesko_attack": {"name":"Jarl Attack",   "path":"res://assets/models/jesko_attack/scene.gltf", "yaw":0.0},
	"agera_rs":     {"name":"Vala RS",       "path":"res://assets/models/agera_rs/scene.gltf",     "yaw":0.0},
	"agera_rs_cf":  {"name":"Vala Carbon",   "path":"res://assets/models/agera_rs_cf/scene.gltf",  "yaw":0.0},
	"agera11":      {"name":"Vala Classic",  "path":"res://assets/models/agera11/scene.gltf",      "yaw":0.0},
	"one1":         {"name":"Aegir One",     "path":"res://assets/models/one1/scene.gltf",         "yaw":0.0},
	"agera_r_cop":  {"name":"Patrol Valkyr", "path":"res://assets/models/agera_r_cop/scene.gltf",  "yaw":0.0},
	"one1_cop":     {"name":"Patrol One",    "path":"res://assets/models/one1_cop/scene.gltf",     "yaw":0.0},
	"divo":         {"name":"Divergent",     "path":"res://assets/models/divo/scene.gltf",         "yaw":0.0},
	"bolide":       {"name":"Boulder Track", "path":"res://assets/models/bolide/scene.gltf",       "yaw":0.0},
	"i8":           {"name":"Ion Coupe",     "path":"res://assets/models/i8/scene.gltf",           "yaw":0.0},
	"m720gt3":      {"name":"GT3 Racer",     "path":"res://assets/models/m720gt3/scene.gltf",      "yaw":0.0},
	"aventador":    {"name":"Tempesta V12",  "path":"res://assets/models/aventador/scene.gltf",    "yaw":180.0},
	"revuelto":     {"name":"Tempesta Volt", "path":"res://assets/models/revuelto/scene.gltf",     "yaw":0.0},
	"countach":     {"name":"Tempesta Retro","path":"res://assets/models/countach/scene.gltf",     "yaw":180.0},
	"camaro_gs":    {"name":"GS Racecar",    "path":"res://assets/models/camaro_gs/scene.gltf",    "yaw":0.0},
	"tourbillon":   {"name":"Tourbillon",    "path":"res://assets/models/tourbillon/scene.gltf",   "yaw":0.0},
	"goblin":       {"name":"Goblin V12",    "path":"res://assets/models/goblin/scene.gltf",       "yaw":180.0},
	"czinger":      {"name":"Cinder 21C",    "path":"res://assets/models/czinger/scene.gltf",      "yaw":0.0},
	"firebird":     {"name":"Formula 78",    "path":"res://assets/models/firebird/scene.gltf",     "yaw":0.0},
	"vw_lp":        {"name":"Wolf Compact",  "path":"res://assets/models/vw_lp/scene.gltf",        "yaw":0.0, "only":"Plane_0"},
}

# A skin is usable only when its model files are actually present.
# The game must boot and stay fully playable without any model packs.
static func skin_ok(sid: String) -> bool:
	if not MODEL_SKINS.has(sid): return false
	return FileAccess.file_exists(str(MODEL_SKINS[sid].path))

# v4 — Velocity County barn-find sites (open-world derelicts you restore)
const BARN_SITES := [
	{"id": "barn_desert",   "frac": 0.62, "car": "vulcan", "zone": "desert"},
	{"id": "barn_docks",    "frac": 0.34, "car": "zephyr", "zone": "docks"},
	{"id": "barn_mountain", "frac": 0.90, "car": "vipera", "zone": "mountain"},
]

const RACER_RANKS := ["Rookie","Street Driver","Pursuit Runner","Drift Specialist","Speed Hunter","Crew Champion","Blacklist Racer","Hypercar Elite","Most Wanted","Full Throttle Legend"]
const COP_RANKS := ["Patrol Recruit","Pursuit Officer","Interceptor Driver","Tactical Unit","Highway Enforcer","Elite Pursuit","Hypercar Response","Lockdown Commander","Most Wanted Task Force","Full Throttle Unit"]
const REP_PER_RANK := 1000
const COP_REP_PER_RANK := 800

const BOSSES := {
	"vex":    {"name":"VEX",    "title":"The Corner King",        "zone":"neon",     "car":"saber",   "car_name":"Saber R-X \"Ghostline\"",    "color":"b8c4ce","skill":1.02,"taunt":"Every corner in this city belongs to me. Try to keep up... briefly.","cash":60000, "car_reward":"",       "part":"tyres"},
	"nova":   {"name":"NOVA",   "title":"The Speed Queen",        "zone":"coastal",  "car":"cyclone", "car_name":"Cyclone Sport \"Aurora\"",   "color":"7b4dff","skill":1.04,"taunt":"Past 400, most drivers blink. I don't.",                            "cash":90000, "car_reward":"",       "part":"engine"},
	"raze":   {"name":"RAZE",   "title":"The Drift Phantom",      "zone":"mountain", "car":"vipera",  "car_name":"Vipera Elemento \"Kagero\"", "color":"3ddc47","skill":1.05,"taunt":"The mountain doesn't forgive. Neither do I.",                       "cash":120000,"car_reward":"vipera", "part":"susp"},
	"specter":{"name":"SPECTER","title":"The Acceleration Ghost", "zone":"airport",  "car":"regalia", "car_name":"Regalia RG-1 \"Blink\"",     "color":"ffd400","skill":1.06,"taunt":"By the time you hear my engine, I'm already gone.",                 "cash":160000,"car_reward":"regalia","part":"turbo"},
	"apex":   {"name":"APEX",   "title":"The Final Champion",     "zone":"docks",    "car":"monarch", "car_name":"Monarch One \"Sovereign\"",  "color":"ff6a00","skill":1.08,"taunt":"Five years unbeaten. You're brave. Brave loses.",                   "cash":250000,"car_reward":"monarch","part":"nitro"},
	"zero":   {"name":"ZERO",   "title":"?????",                  "zone":"blacktrack","car":"absolut","car_name":"Krait Absolut \"Null\"",     "color":"ff0033","skill":1.10,"taunt":"You found the Black Track. A shame you'll never leave it.",         "cash":500000,"car_reward":"absolut","part":""},
}

# Racer events. len = km of road. modes: sprint circuit drag drift topspeed elim escape hotpursuit boss
const RACER_EVENTS := [
	{"id":"r01","tier":1,"zone":"neon",    "mode":"sprint",   "name":"Midnight Initiation",  "len":5.0, "rivals":3,"heat":1,"cash":6000, "rep":220, "desc":"Prove yourself to the Neon City crews."},
	{"id":"r02","tier":1,"zone":"neon",    "mode":"circuit",  "name":"Downtown Loop",        "len":3.2, "laps":2,"rivals":4,"heat":1,"cash":7500,"rep":260,"desc":"Two laps through the glowing heart of the city."},
	{"id":"r03","tier":1,"zone":"desert",  "mode":"drag",     "name":"Dustbowl Drag",        "len":1.6, "rivals":1,"heat":1,"cash":7000, "rep":240, "desc":"Straight-line duel. Perfect shifts win races."},
	{"id":"r04","tier":1,"zone":"neon",    "mode":"drift",    "name":"Wet Streets Slide",    "len":4.0, "target":30000,"heat":1,"cash":8000,"rep":280,"desc":"Chain drifts on rain-slick neon streets."},
	{"id":"r05","tier":2,"zone":"desert",  "mode":"sprint",   "name":"Crimson Run",          "len":6.5, "rivals":4,"heat":2,"cash":10000,"rep":320, "desc":"Flat-out across the burning desert highways."},
	{"id":"r06","tier":2,"zone":"coastal", "mode":"topspeed", "name":"Ocean Road Velocity",  "len":6.0, "target":300,"heat":2,"cash":11000,"rep":340,"desc":"Hit the target speed before the run ends."},
	{"id":"r07","tier":2,"zone":"mountain","mode":"drift",    "name":"Stormridge Touge",     "len":4.5, "target":45000,"heat":2,"cash":12000,"rep":360,"desc":"The mountain's legendary drift road."},
	{"id":"r08","tier":2,"zone":"neon",    "mode":"escape",   "name":"First Blood Pursuit",  "len":8.0, "heat":3,"cash":14000,"rep":420, "desc":"The VCPD knows your name now. Lose them."},
	{"id":"r09","tier":2,"zone":"neon",    "mode":"boss","boss":"vex","name":"BOSS: Vex — The Corner King","len":5.0,"heat":2,"cash":0,"rep":600,"desc":"Beat the master of late braking on his own streets."},
	{"id":"r10","tier":3,"zone":"docks",   "mode":"elim",     "name":"Container Yard Cull",  "len":5.5, "rivals":5,"heat":3,"cash":15000,"rep":420, "desc":"Last place is eliminated every 20 seconds."},
	{"id":"r11","tier":3,"zone":"airport", "mode":"drag",     "name":"Runway Kings",         "len":2.0, "rivals":1,"heat":2,"cash":14000,"rep":400, "desc":"Quarter-mile on live tarmac."},
	{"id":"r12","tier":3,"zone":"coastal", "mode":"sprint",   "name":"Sunset Freeway GP",    "len":7.0, "rivals":5,"heat":3,"cash":17000,"rep":460, "desc":"Traffic, tunnels and top speed."},
	{"id":"r13","tier":3,"zone":"mountain","mode":"circuit",  "name":"Cliffside Circuit",    "len":3.6, "laps":2,"rivals":4,"heat":3,"cash":18000,"rep":480,"desc":"Hairpins, fog and a long way down."},
	{"id":"r14","tier":3,"zone":"coastal", "mode":"boss","boss":"nova","name":"BOSS: Nova — The Speed Queen","len":7.0,"heat":3,"cash":0,"rep":800,"desc":"A pure top-speed war on the Coastal Freeway."},
	{"id":"r15","tier":4,"zone":"desert",  "mode":"escape",   "name":"Dust Storm Getaway",   "len":8.5, "heat":5,"cash":22000,"rep":520, "desc":"Roadblocks in the storm. Thread the needle."},
	{"id":"r16","tier":4,"zone":"mountain","mode":"drift",    "name":"Phantom's Playground", "len":5.0, "target":65000,"heat":3,"cash":22000,"rep":540,"desc":"Raze's home turf. Impress or go home."},
	{"id":"r17","tier":4,"zone":"docks",   "mode":"hotpursuit","name":"Heat Race: Dockside", "len":6.5, "rivals":4,"heat":5,"cash":26000,"rep":580, "desc":"Race rivals while the VCPD hunts everyone."},
	{"id":"r18","tier":4,"zone":"airport", "mode":"topspeed", "name":"Runway Absolut",       "len":6.0, "target":345,"heat":3,"cash":24000,"rep":560,"desc":"The concrete runs out eventually."},
	{"id":"r19","tier":4,"zone":"mountain","mode":"boss","boss":"raze","name":"BOSS: Raze — The Drift Phantom","len":5.0,"heat":3,"cash":0,"rep":1000,"desc":"Beat the phantom through the switchbacks."},
	{"id":"r20","tier":5,"zone":"neon",    "mode":"circuit",  "name":"Neon Grand Prix",      "len":4.0, "laps":3,"rivals":5,"heat":5,"cash":30000,"rep":620,"desc":"Three laps. Full grid. Full police response."},
	{"id":"r21","tier":5,"zone":"coastal", "mode":"topspeed", "name":"Speed Camera Massacre","len":7.5, "target":365,"heat":6,"cash":32000,"rep":640,"desc":"Light up every camera on the freeway."},
	{"id":"r22","tier":5,"zone":"docks",   "mode":"escape",   "name":"Helicopter Alley",     "len":9.0, "heat":7,"cash":36000,"rep":700, "desc":"Air support inbound. Stay out of the spotlight."},
	{"id":"r23","tier":5,"zone":"desert",  "mode":"elim",     "name":"Vulture Circuit",      "len":6.0, "rivals":5,"heat":5,"cash":34000,"rep":660, "desc":"Survive the cull in the open desert."},
	{"id":"r24","tier":5,"zone":"airport", "mode":"boss","boss":"specter","name":"BOSS: Specter — The Acceleration Ghost","len":6.0,"heat":4,"cash":0,"rep":1200,"desc":"A launch war on the runway."},
	{"id":"r25","tier":6,"zone":"coastal", "mode":"hotpursuit","name":"Lockdown GP",         "len":7.5, "rivals":5,"heat":8,"cash":42000,"rep":760, "desc":"Armoured interceptors join the grid."},
	{"id":"r26","tier":6,"zone":"mountain","mode":"sprint",   "name":"Widowmaker Descent",   "len":6.5, "rivals":5,"heat":6,"cash":40000,"rep":740, "desc":"Downhill. In the rain. At night."},
	{"id":"r27","tier":6,"zone":"neon",    "mode":"escape",   "name":"City Lockdown",        "len":10.0,"heat":9,"cash":52000,"rep":860, "desc":"The Elite Pursuit Squad is on you. Survive."},
	{"id":"r28","tier":6,"zone":"docks",   "mode":"boss","boss":"apex","name":"BOSS: Apex — The Final Champion","len":7.5,"heat":5,"cash":0,"rep":1500,"desc":"The champion of Velora Coast. Everything on the line."},
	{"id":"r29","tier":7,"zone":"blacktrack","mode":"circuit","name":"Black Track: Induction","len":4.0,"laps":2,"rivals":3,"heat":0,"cash":60000,"rep":900,"desc":"The hidden track beneath Velora Coast."},
	{"id":"r30","tier":7,"zone":"blacktrack","mode":"drift",  "name":"Black Track: Carbon Slide","len":5.0,"target":90000,"heat":0,"cash":65000,"rep":950,"desc":"Drift between carbon walls. No mistakes."},
	{"id":"r31","tier":7,"zone":"blacktrack","mode":"topspeed","name":"Black Track: Terminal Velocity","len":7.0,"target":400,"heat":0,"cash":70000,"rep":1000,"desc":"The fastest asphalt ever poured."},
	{"id":"r32","tier":7,"zone":"blacktrack","mode":"boss","boss":"zero","name":"FINAL BOSS: Zero","len":7.5,"heat":0,"cash":0,"rep":2000,"desc":"Impossible speed. Perfect driving. Zero mercy."},
	# v3 event variety
	{"id":"r34","tier":2,"zone":"desert",  "mode":"timeattack","name":"Canyon Clock Run",   "len":6.0, "time":42, "gate_bonus":7, "heat":1,"cash":11000,"rep":330,"desc":"Beat the clock — every checkpoint adds seconds."},
	{"id":"r35","tier":3,"zone":"coastal", "mode":"speedtrap", "name":"Radar Row",          "len":6.5, "target":1150,"heat":3,"cash":16000,"rep":450,"desc":"Five cameras. Highest combined speed wins."},
	{"id":"r36","tier":4,"zone":"neon",    "mode":"duel",      "name":"Duel: Ghostline Copy","len":5.5,"rival":"saber","skill":1.02,"heat":3,"cash":24000,"rep":560,"desc":"A Vex admirer wants your reputation. One on one."},
	{"id":"r37","tier":5,"zone":"mountain","mode":"timeattack","name":"Stormridge Stopwatch","len":5.5,"time":40,"gate_bonus":8,"heat":2,"cash":30000,"rep":640,"desc":"Hairpins against the clock. No room for error."},
	{"id":"r38","tier":6,"zone":"blacktrack","mode":"speedtrap","name":"Black Track: Radar Zero","len":6.5,"target":1500,"heat":0,"cash":52000,"rep":820,"desc":"The cameras here were built for prototypes."},
	# Signature marathon event — Hot Pursuit style long-haul survival
	{"id":"r33","tier":5,"zone":"coastal", "mode":"escape",   "name":"The 50-Mile Gauntlet", "len":16.0,"heat":8,"cash":60000,"rep":900, "desc":"The longest pursuit ever attempted. Half the VCPD is waiting on the Coastal Freeway."},
]

const COP_EVENTS := [
	{"id":"c01","tier":1,"zone":"neon",     "name":"Traffic Stop",      "target":"falco",   "skill":0.90,"time":95, "cash":6000, "rep":250,"desc":"A rookie street racer is loose downtown. Bring them in."},
	{"id":"c02","tier":1,"zone":"desert",   "name":"Desert Runner",     "target":"nzo",     "skill":0.94,"time":100,"cash":8000, "rep":280,"desc":"Suspect fleeing across Crimson Desert at extreme speed."},
	{"id":"c03","tier":2,"zone":"coastal",  "name":"Freeway Menace",    "target":"solaris", "skill":0.96,"time":100,"cash":11000,"rep":320,"desc":"Hybrid hypercar terrorising the Coastal Freeway."},
	{"id":"c04","tier":2,"zone":"docks",    "name":"Container Rat",     "target":"zephyr",  "skill":0.97,"time":105,"cash":13000,"rep":360,"desc":"Racer using dock shortcuts to humiliate patrol units."},
	{"id":"c05","tier":3,"zone":"mountain", "name":"Ghost of Stormridge","target":"vipera", "skill":1.00,"time":110,"cash":16000,"rep":400,"desc":"Drift specialist. Do not follow — intercept."},
	{"id":"c06","tier":3,"zone":"neon",     "name":"Neon Serpent",      "target":"tempesta","skill":1.00,"time":110,"cash":19000,"rep":440,"desc":"Repeat offender. Authorised for EMP takedown."},
	{"id":"c07","tier":4,"zone":"airport",  "name":"Runway Breach",     "target":"regalia", "skill":1.03,"time":110,"cash":23000,"rep":500,"desc":"Suspect broke into Aeroport. Acceleration is unreal."},
	{"id":"c08","tier":4,"zone":"desert",   "name":"Storm Chaser",      "target":"vulcan",  "skill":1.03,"time":115,"cash":26000,"rep":540,"desc":"Heavy hypercar. Ramming ineffective — use tech."},
	{"id":"c09","tier":5,"zone":"coastal",  "name":"The 400 Club",      "target":"cyclone", "skill":1.06,"time":115,"cash":32000,"rep":600,"desc":"Fugitive from the speed camera massacre."},
	{"id":"c10","tier":5,"zone":"docks",    "name":"Blacklist: Kestrel","target":"kestrel", "skill":1.07,"time":120,"cash":38000,"rep":660,"desc":"Top-ten blacklist driver. Full task force authorised."},
	{"id":"c11","tier":6,"zone":"mountain", "name":"Blacklist: Valkyra","target":"valkyra", "skill":1.08,"time":120,"cash":45000,"rep":720,"desc":"Track weapon on public roads. Lock down the mountain."},
	{"id":"c12","tier":6,"zone":"blacktrack","name":"OPERATION: FULL THROTTLE","target":"krait","skill":1.10,"time":130,"cash":80000,"rep":1000,"desc":"We found their track. End the league tonight."},
]

const HEAT_INFO := ["","Patrol Alert","Fast Response","Spike Deployment","EMP Units","Roadblock Protocol","Helicopter Tracking","Hypercar Police","Armoured Interceptors","Elite Pursuit Squad","FULL CITY LOCKDOWN"]

const RADIO := [
	{"id":"throttle","name":"Full Throttle FM","file":"music_electro"},
	{"id":"night",   "name":"Night Drive Radio","file":"music_synth"},
	{"id":"redline", "name":"Redline Rock","file":"music_rock"},
	{"id":"bass",    "name":"Velocity Bass","file":"music_dnb"},
	{"id":"chill",   "name":"Coastline Chill","file":"music_chill"},
	{"id":"off",     "name":"Radio Off","file":""},
]

func _ready() -> void:
	_setup_input()

func car_def(id: String) -> Dictionary:
	for c in CARS: if c.id == id: return c
	for c in SECRET_CARS: if c.id == id: return c
	for c in COP_CARS: if c.id == id: return c
	return CARS[0]

func all_car_defs() -> Array:
	return CARS + SECRET_CARS

# top stat (1..10) -> top speed km/h
static func stat_to_kmh(top: float) -> float:
	return 200.0 + top * 24.0

func up_cost(u: Dictionary, lvl: int) -> int:
	return int(round(u.base * pow(1.9, lvl)))

func _setup_input() -> void:
	var keys := {
		"accel":[KEY_W, KEY_UP], "brake":[KEY_S, KEY_DOWN],
		"left":[KEY_A, KEY_LEFT], "right":[KEY_D, KEY_RIGHT],
		"handbrake":[KEY_SPACE], "nitro":[KEY_SHIFT, KEY_N],
		"emp":[KEY_E], "spike":[KEY_Q], "turbo":[KEY_T], "block":[KEY_R],
		"camera":[KEY_C], "reset":[KEY_X], "radio":[KEY_M], "pause":[KEY_ESCAPE, KEY_P],
		"gear_up":[KEY_B], "gear_down":[KEY_V],
		"lookback":[KEY_TAB],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# --- full controller mapping (Xbox-style layout, works on generic pads) ---
	var pad_axes := {
		"accel": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"brake": [JOY_AXIS_TRIGGER_LEFT, 1.0],
		"left":  [JOY_AXIS_LEFT_X, -1.0],
		"right": [JOY_AXIS_LEFT_X, 1.0],
	}
	for action in pad_axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = pad_axes[action][0]
		ev.axis_value = pad_axes[action][1]
		InputMap.action_add_event(action, ev)
	var pad_btns := {
		"handbrake": JOY_BUTTON_X,       # square / X
		"nitro": JOY_BUTTON_A,           # cross / A
		"turbo": JOY_BUTTON_B,
		"emp": JOY_BUTTON_Y,
		"spike": JOY_BUTTON_LEFT_SHOULDER,
		"block": JOY_BUTTON_RIGHT_SHOULDER,
		"camera": JOY_BUTTON_BACK,
		"reset": JOY_BUTTON_DPAD_UP,
		"radio": JOY_BUTTON_DPAD_RIGHT,
		"gear_up": JOY_BUTTON_DPAD_LEFT,
		"gear_down": JOY_BUTTON_DPAD_DOWN,
		"lookback": JOY_BUTTON_RIGHT_STICK,
		"pause": JOY_BUTTON_START,
	}
	for action in pad_btns:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pad_btns[action]
		InputMap.action_add_event(action, ev)
	# menu navigation (ui_* already have pad defaults in Godot; ensure accept on A)
	var ok_ev := InputEventJoypadButton.new()
	ok_ev.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept", ok_ev):
		InputMap.action_add_event("ui_accept", ok_ev)
