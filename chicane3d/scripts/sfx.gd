# ============================================================
# CHICANE 3D — sfx.gd (autoload "SFX")
# Layered dynamic audio: 4-band engine crossfade, turbo, wind,
# tyre squeal, sirens, music with ducking, volume buses.
# ============================================================
extends Node

var master_vol := 1.0
var music_vol := 0.8
var engine_vol := 1.0
var fx_vol := 1.0
var muted := false

var _streams: Dictionary = {}
var _eng: Array[AudioStreamPlayer] = []   # idle, mid, high, red
var siren_p: AudioStreamPlayer
var squeal_p: AudioStreamPlayer
var wind_p: AudioStreamPlayer
var turbo_p: AudioStreamPlayer
var music_p: AudioStreamPlayer
var _duck := 0.0
var _duck_t := 0.0

const LOOPS := ["engine_loop","engine_idle","engine_high","engine_red","siren_loop","skid_loop",
	"squeal_loop","wind_loop","turbo_loop"]
const ONESHOTS := ["crash_big","crash_small","glass","nitro","emp","ui_click","ui_win","ui_lose",
	"checkpoint","shift","blowoff"]
const MUSIC := ["music_electro","music_synth","music_rock","music_dnb","music_chill"]

func _ready() -> void:
	for n in LOOPS + ONESHOTS + MUSIC:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			if s is AudioStreamWAV and (n in LOOPS or n in MUSIC):
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_end = s.data.size() / 2 / (2 if s.stereo else 1)
			_streams[n] = s
	for n in ["engine_idle", "engine_loop", "engine_high", "engine_red"]:
		var p := AudioStreamPlayer.new()
		if _streams.has(n): p.stream = _streams[n]
		p.volume_db = -80.0
		add_child(p)
		_eng.append(p)
	siren_p = _mk("siren_loop"); squeal_p = _mk("squeal_loop")
	wind_p = _mk("wind_loop"); turbo_p = _mk("turbo_loop")
	music_p = AudioStreamPlayer.new()
	add_child(music_p)
	refresh_volumes()

func _mk(stream_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if _streams.has(stream_name): p.stream = _streams[stream_name]
	p.volume_db = -80.0
	add_child(p)
	return p

func refresh_volumes() -> void:
	music_p.volume_db = _db(music_vol * master_vol * 0.6)

func _db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))

func _process(delta: float) -> void:
	if _duck_t > 0.0:
		_duck_t -= delta
		_duck = maxf(_duck - delta * 0.5, 0.35) if _duck_t > 0.0 else 0.0
	else:
		_duck = minf(_duck + delta * 1.5, 1.0) if _duck < 1.0 else 1.0
	music_p.volume_db = _db(music_vol * master_vol * 0.6 * (_duck if _duck > 0.0 else 1.0))

# ---- layered engine: rpm 0..1, load 0..1 (throttle), on/off ----
func engine(rpm: float, on: bool, load := 1.0) -> void:
	var base := engine_vol * master_vol * (0.0 if muted or not on else 1.0)
	rpm = clampf(rpm, 0.0, 1.15)
	# band weights: idle→mid→high→red crossfades
	var w := [
		clampf(1.0 - rpm * 4.0, 0.0, 1.0),
		clampf(1.0 - absf(rpm - 0.38) * 3.2, 0.0, 1.0),
		clampf(1.0 - absf(rpm - 0.75) * 3.2, 0.0, 1.0),
		clampf((rpm - 0.85) * 5.0, 0.0, 1.0),
	]
	var pitches := [0.9 + rpm * 1.2, 0.62 + rpm * 1.5, 0.7 + rpm * 1.05, 0.85 + rpm * 0.55]
	for i in 4:
		var p := _eng[i]
		if p.stream == null: continue
		if base > 0.0 and not p.playing: p.play()
		if base <= 0.0 and p.playing: p.stop(); continue
		p.pitch_scale = clampf(pitches[i], 0.5, 2.8)
		var loud: float = w[i] * base * (0.55 + 0.45 * load)
		p.volume_db = _db(loud * 0.4)

func siren(on: bool, closeness := 1.0) -> void:
	if siren_p.stream == null: return
	if on and not siren_p.playing: siren_p.play()
	siren_p.volume_db = _db(fx_vol * master_vol * (0.18 * closeness if on and not muted else 0.0))

func squeal(amount: float) -> void:   # 0..1 slip
	if squeal_p.stream == null: return
	if amount > 0.02 and not squeal_p.playing: squeal_p.play()
	if amount <= 0.02 and squeal_p.playing: squeal_p.stop(); return
	squeal_p.pitch_scale = 0.85 + amount * 0.4
	squeal_p.volume_db = _db(fx_vol * master_vol * amount * 0.35 * (0.0 if muted else 1.0))

func skid(on: bool) -> void:          # legacy API — routes to squeal
	squeal(0.6 if on else 0.0)

func wind(speed_kmh: float) -> void:
	if wind_p.stream == null: return
	var a := clampf((speed_kmh - 90.0) / 260.0, 0.0, 1.0)
	if a > 0.02 and not wind_p.playing: wind_p.play()
	if a <= 0.02 and wind_p.playing: wind_p.stop(); return
	wind_p.pitch_scale = 0.8 + a * 0.7
	wind_p.volume_db = _db(fx_vol * master_vol * a * 0.4 * (0.0 if muted else 1.0))

func turbo(boost: float) -> void:     # 0..1
	if turbo_p.stream == null: return
	if boost > 0.05 and not turbo_p.playing: turbo_p.play()
	if boost <= 0.05 and turbo_p.playing: turbo_p.stop(); return
	turbo_p.pitch_scale = 0.7 + boost * 0.9
	turbo_p.volume_db = _db(fx_vol * master_vol * boost * 0.22 * (0.0 if muted else 1.0))

func gear_shift() -> void:
	play("shift", -6.0)

func blowoff() -> void:
	play("blowoff", -10.0)

func play(sound: String, db := 0.0) -> void:
	if muted or not _streams.has(sound): return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	p.volume_db = db + _db(fx_vol * master_vol)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func crash(big: bool) -> void:
	play("crash_big" if big else "crash_small", -2.0)
	if big:
		play("glass", -6.0)
		duck(1.2)

func duck(dur: float) -> void:
	_duck_t = maxf(_duck_t, dur)

func set_station(id: String) -> void:
	var st = null
	for r in D.RADIO:
		if r.id == id: st = r
	if st == null or st.file == "" or not _streams.has(st.file):
		music_p.stop()
		return
	music_p.stream = _streams[st.file]
	if not muted: music_p.play()

func cycle_radio() -> String:
	var ids := D.RADIO.map(func(r): return r.id)
	var i := ids.find(P.data.station)
	P.data.station = ids[(i + 1) % ids.size()]
	set_station(P.data.station)
	P.save_game()
	for r in D.RADIO:
		if r.id == P.data.station: return r.name
	return ""

func stop_race_audio() -> void:
	engine(0.0, false)
	siren(false)
	squeal(0.0)
	wind(0.0)
	turbo(0.0)
