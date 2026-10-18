extends Node
## Soundeffekte aus echten CC0-Aufnahmen (assets/audio/sfx, Quellen in assets/CREDITS.txt); fehlt eine Datei,
## springt der prozedurale Platzhalter ein. Lautstärke-Busse. Es gibt noch KEINE Musik – siehe docs/STATUS.md.

const MIX_RATE := 22050

var _cache: Dictionary = {}
var _files: Dictionary = {}   # id -> Array[AudioStream]
## Feinabstimmung der Lautstärke je Klang (dB), weil die Quelldateien unterschiedlich laut sind
const GAIN_DB := {"hit": -2.0, "swing": -3.0, "crit": -1.0, "cast": -2.0, "boom": -1.0, "levelup": -3.0, "loot": -4.0,
		"rare_loot": -3.0, "hurt": -2.0, "ui": -8.0, "roll": -5.0, "boss": 0.0}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for n in ["Music", "SFX", "Ambient"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, n)
			AudioServer.set_bus_send(idx, "Master")
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	apply_volumes()


func apply_volumes() -> void:
	var s: Dictionary = SaveSystem.data.get("settings", {})
	var mute: bool = s.get("mute", false)
	_set_bus("Master", float(s.get("volume_master", 0.8)), mute)
	_set_bus("Music", float(s.get("volume_music", 0.6)), false)
	_set_bus("SFX", float(s.get("volume_sfx", 0.9)), false)
	_set_bus("Ambient", float(s.get("volume_ambient", 0.7)), false)


func _set_bus(name: String, linear: float, mute: bool) -> void:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, mute)


var net_hook: Callable = Callable()   # Host: (id, pitch, vol_db) -> sendet den Klang an die Clients
var replaying := false


func play(id: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if net_hook.is_valid() and not replaying:
		net_hook.call(id, pitch, vol_db)
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = _pick_file(id)
	if stream == null:
		stream = _cache.get(id)
		if stream == null:
			stream = _make(id)
			_cache[id] = stream
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = vol_db + float(GAIN_DB.get(id, 0.0)) if _files.get(id, []).size() > 0 else vol_db
	p.play()


func _pick_file(id: String) -> AudioStream:
	if not _files.has(id):
		var arr: Array = []
		for i in range(1, 9):
			var path := "res://assets/audio/sfx/%s_%d.ogg" % [id, i]
			if ResourceLoader.exists(path):
				arr.append(load(path))
		_files[id] = arr
	var list: Array = _files[id]
	if list.is_empty():
		return null
	return list[randi() % list.size()]


func _make(id: String) -> AudioStreamWAV:
	var dur := 0.18
	var f0 := 440.0
	var f1 := 440.0
	var noise := 0.0
	match id:
		"hit": dur = 0.12; f0 = 220.0; f1 = 90.0; noise = 0.5
		"swing": dur = 0.14; f0 = 300.0; f1 = 600.0; noise = 0.7
		"crit": dur = 0.2; f0 = 700.0; f1 = 300.0; noise = 0.3
		"cast": dur = 0.3; f0 = 300.0; f1 = 900.0; noise = 0.1
		"boom": dur = 0.35; f0 = 120.0; f1 = 40.0; noise = 0.6
		"levelup": dur = 0.5; f0 = 520.0; f1 = 1040.0; noise = 0.0
		"loot": dur = 0.25; f0 = 800.0; f1 = 1200.0; noise = 0.0
		"rare_loot": dur = 0.6; f0 = 600.0; f1 = 1500.0; noise = 0.0
		"hurt": dur = 0.2; f0 = 160.0; f1 = 80.0; noise = 0.4
		"ui": dur = 0.06; f0 = 900.0; f1 = 900.0
		"roll": dur = 0.2; f0 = 200.0; f1 = 120.0; noise = 0.9
		"boss": dur = 0.8; f0 = 80.0; f1 = 50.0; noise = 0.3
	var n := int(dur * MIX_RATE)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / MIX_RATE
		var env := (1.0 - t) * minf(1.0, t * 40.0)
		var v := sin(phase) * (1.0 - noise) + (rng.randf() * 2.0 - 1.0) * noise
		var s := int(clampf(v * env * 0.45, -1.0, 1.0) * 32767.0)
		buf.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = buf
	return w
