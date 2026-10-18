class_name RunEvents
extends Node
## Zufallsereignisse während des Runs (nur Host/Solo): Blutmond, Hinterhalt, Zeitjagd.
## Anzeige läuft über Banner und Zielanzeige der Arena (beides wird im Koop automatisch an alle Spieler gesendet).

var arena: Node = null
var active := ""
var _timer := 0.0
var _left := 0.0
var _target := 0
var _kills_start := 0
var _group: Array = []
var history: Array = []     # Für Tests: gestartete/gewonnene Ereignisse


func setup(a: Node) -> void:
	arena = a
	_timer = 40.0 * a._time_k


func _process(delta: float) -> void:
	if arena == null or arena.finished:
		return
	if arena.boss_spawned:
		if active != "":
			_end(false, true)
		return
	if active == "":
		_timer -= delta
		if _timer <= 0.0 and arena.run_time < arena._boss_time() - 25.0 * arena._time_k:
			_start()
		return
	_left -= delta
	match active:
		"blood_moon":
			if _left <= 0.0:
				_end(true)
		"ambush":
			_group = _group.filter(func(e): return is_instance_valid(e) and not e.dead)
			arena.event_text = "Hinterhalt! Besiege die Angreifer (%d)" % _group.size()
			if _group.is_empty():
				_end(true)
			elif _left <= 0.0:
				_end(false)
		"hunt":
			var got: int = arena.run_stats["kills"] - _kills_start
			arena.event_text = "Zeitjagd: %d/%d Gegner – noch %d s" % [mini(got, _target), _target, int(maxf(_left, 0.0))]
			if got >= _target:
				_end(true)
			elif _left <= 0.0:
				_end(false)


func _start() -> void:
	var pool := ["blood_moon", "ambush", "hunt"]
	active = pool[arena.rng.randi() % pool.size()]
	history.append("start:" + active)
	match active:
		"blood_moon":
			_left = 30.0 * arena._time_k
			arena.xp_mult = 1.5
			arena.event_spawn_mult = 0.6
			arena.event_text = "Blutmond: mehr Gegner, +50 % Erfahrung"
			arena.banner_all("Blutmond! Mehr Gegner, aber +50 % Erfahrung", UI.RED, 3.0)
		"ambush":
			_left = 60.0
			_group.clear()
			var c: Vector3 = arena._random_active_player().global_position
			var elites: Array = GameData.elite_mods.keys()
			var types := ["grunt", "grunt", "archer", "brute", "grunt", "archer"]
			for i in types.size():
				var a := i * TAU / types.size()
				var pos: Vector3 = arena._clamp_to_map(c + Vector3(cos(a), 0, sin(a)) * 9.0)
				var mod: String = elites[i % elites.size()] if i < 3 else ""
				var e := Enemy.spawn(arena, types[i], pos, arena.scaling, mod)
				arena.register_enemy(e)
				_group.append(e)
			arena.banner_all("Hinterhalt! Elitegegner umzingeln euch", UI.RED, 3.0)
		"hunt":
			_left = 40.0 * arena._time_k
			_target = 14 + 4 * (arena.players.size() - 1)
			_kills_start = arena.run_stats["kills"]
			arena.banner_all("Zeitjagd! Besiege %d Gegner in %d s" % [_target, int(_left)], UI.GOLD, 3.0)


func _end(success: bool, silent: bool = false) -> void:
	var what := active
	active = ""
	arena.event_text = ""
	arena.xp_mult = 1.0
	arena.event_spawn_mult = 1.0
	_timer = randf_range(55.0, 80.0) * arena._time_k
	for e in _group:
		if is_instance_valid(e) and not e.dead and what == "ambush" and success == false and not silent:
			pass
	_group.clear()
	if silent:
		return
	if success:
		history.append("won:" + what)
		if what == "blood_moon":
			arena.banner_all("Der Blutmond vergeht", UI.GOLD, 2.0)
		else:
			arena.banner_all("Geschafft! Belohnung für alle", UI.GOLD, 2.5)
			for p in arena.players:
				if is_instance_valid(p):
					arena._drop_item(p.global_position + Vector3(1.5, 0, 0), "rare", 2.0, p)
	else:
		history.append("lost:" + what)
		arena.banner_all("Ereignis verstrichen", UI.DIM, 2.0)
