class_name ClientArena
extends Node3D
## Run-Szene eines Mitspielers (Client). Der Host simuliert alles; hier laufen nur
##  * die eigene Figur (Bewegung lokal vorhergesagt, Kampf auf dem Host),
##  * Darstellung: Gegner-/Geschoss-"Ghosts", Puppets der Mitspieler, Truhen/Schreine, persönliche Beute,
##  * HUD, Level-Up-Overlay (das Spiel pausiert im Koop nie) und Ergebnisbildschirm,
##  * Wiederverbindung: bei Verbindungsverlust versucht der Client, mit demselben Token wieder einzusteigen.
## Schnittstelle zu Net.run: on_snapshot, on_me, on_correct, on_event, on_fx.

const GHOST_TIMEOUT_MS := 2500
const STATE_INTERVAL := 1.0 / 30.0
const READY_RETRY := 1.0

var player: Player
var hud: Hud
var map_info: Dictionary = {}
var run_time := 0.0
var run_stats := {"kills": 0, "elites": 0}
var boss: Boss = null
var finished := false
var enemies: Dictionary = {}     # net_id -> Enemy (Ghost)
var projs: Dictionary = {}       # net_id -> Projectile (Ghost)
var puppets: Dictionary = {}     # slot -> Player (Puppet)
var pickups: Dictionary = {}     # id -> {"node": Node3D, "item": Dictionary, "t": float}
var _chests: Array = []
var _shrines: Array = []
var _objective := ""
var _my_slot := 0
var _ui_layer: CanvasLayer
var _levelup_ui: LevelUpUI
var _pause_menu: PauseMenu
var _result: ResultScreen
var _state_t := 0.0
var _area: Dictionary = {}
var _got_full := false
var _ready_t := 0.0
var _lost := false
var _lost_elapsed := 0.0
var _retry_t := 0.0
var _joined_t := -1.0
var _info_cache: Dictionary = {}


func area_name() -> String:
	return _area.get("name", "")


func objective_text() -> String:
	return _objective


func _ready() -> void:
	GameData.activate_area(RunState.area_id)
	_area = GameData.area_by_id(RunState.area_id)
	_my_slot = Net.my_slot()
	map_info = ForestMap.build(self, RunState.seed_value)
	var c := SaveSystem.active_character()
	player = Player.new()
	player.net_role = "local_client"
	player.net_slot = _my_slot
	player.bot = RunState.bot_mode
	player.bot_damage_scale = RunState.bot_damage_scale
	player.position = _spawn_offset(_my_slot)
	player.setup(self, c)
	player.display_name = c.get("name", "Held")
	add_child(player)
	player.cam_yaw = 0.0
	Net.run.arena = self
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	hud = Hud.new()
	_ui_layer.add_child(hud)
	hud.bind(self, player)
	for p in map_info["chests"]:
		_chests.append(WorldProps.make_chest(self, p))
	for p in map_info["shrines"]:
		_shrines.append(WorldProps.make_shrine(self, p))
	if not RunState.bot_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_banner(_area.get("name", ""), UI.GOLD, 3.5)
	Net.lobby_ended.connect(_on_connection_lost)
	Net.run_rejoined.connect(_on_rejoined)
	Net.joined_lobby.connect(func(): _joined_t = 0.0)


func _exit_tree() -> void:
	if Net.run != null and Net.run.arena == self:
		Net.run.arena = null


func _spawn_offset(slot: int) -> Vector3:
	var a := slot * TAU / 5.0
	return map_info["spawn"] + Vector3(cos(a), 0.0, sin(a)) * 2.5


# ------------------------------------------------------------------ Schnittstelle zu Player/HUD

func on_player_hurt(_p: Node = null) -> void:
	hud.flash_hurt()


func notify_low_mana() -> void:
	hud.show_hint("Nicht genug Mana", 0.6)


func player_interact(_p: Node) -> void:
	Net.run.send_act(Player.ACT_INTERACT, Vector2.ZERO)


func net_act(id: int, v: Vector2) -> void:
	Net.run.send_act(id, v)


func net_send_state(p: Player, inp: Dictionary) -> void:
	_state_t -= get_physics_process_delta_time()
	if _state_t > 0.0 or _lost:
		return
	_state_t = STATE_INTERVAL
	var holds := 0
	if inp.get("light", false):
		holds |= Player.HOLD_LIGHT
	if inp.get("block", false):
		holds |= Player.HOLD_BLOCK
	if inp.get("interact_held", false):
		holds |= Player.HOLD_INTERACT
	Net.run.send_state(p.global_position, p.rotation.y, p.cam_yaw, holds)


func party_members() -> Array:
	var rows: Array = [{"slot": _my_slot, "name": player.display_name, "hp": player.hp, "max": player.stats.get("max_hp", 100.0),
			"down": player.is_down(), "away": false, "level": player.level, "self": true, "lost": player.permadown}]
	for slot in puppets:
		var p: Player = puppets[slot]
		if is_instance_valid(p):
			rows.append({"slot": slot, "name": p.display_name, "hp": p.hp, "max": p.stats.get("max_hp", 100.0), "down": p.is_down(),
					"away": p.net_away, "level": p.level, "self": false, "lost": p.permadown})
	rows.sort_custom(func(a, b): return a["slot"] < b["slot"])
	return rows


# ------------------------------------------------------------------ Schleife

func _process(delta: float) -> void:
	if finished:
		return
	if not _got_full and not _lost:
		_ready_t -= delta
		if _ready_t <= 0.0:
			_ready_t = READY_RETRY
			Net.run.send_req("ready")
	_update_pickups(delta)
	_update_prompt()
	_cleanup_ghosts()
	_update_reconnect(delta)
	if Input.is_action_just_pressed("pause") and not RunState.bot_mode:
		_toggle_pause()


func _cleanup_ghosts() -> void:
	var now := Time.get_ticks_msec()
	for id in enemies.keys():
		var e: Enemy = enemies[id]
		if not is_instance_valid(e) or e.dead:
			enemies.erase(id)
		elif now - int(e.get_meta("seen", now)) > GHOST_TIMEOUT_MS and not _lost:
			e.queue_free()
			enemies.erase(id)
	if boss != null and not is_instance_valid(boss):
		boss = null


func _update_prompt() -> void:
	if player.is_down():
		hud.show_hint(("Du bist kampfunfähig – du siehst %s zu (Linksklick: nächster Spieler)" % player.spec_name) if player.spec_name != "" else "Du bist kampfunfähig – ein Mitspieler kann dich wiederbeleben", 0.2)
		return
	var best := 4.0
	var kind := ""
	for c in _chests:
		if not c["open"]:
			var d: float = c["node"].global_position.distance_to(player.global_position)
			if d < best:
				best = d
				kind = "Truhe öffnen"
	for s in _shrines:
		if s["state"] == "idle":
			var d: float = s["node"].global_position.distance_to(player.global_position)
			if d < best:
				best = d
				kind = "Verfluchten Schrein berühren (Risiko: 2 Eliten)"
	if kind != "":
		hud.show_hint("[%s] %s" % [InputSetup.key_name("interact"), kind], 0.2)
		return
	for slot in puppets:
		var p: Player = puppets[slot]
		if is_instance_valid(p) and p.is_down() and not p.permadown and p.global_position.distance_to(player.global_position) <= 4.0:
			hud.show_hint("[%s halten] %s wiederbeleben" % [InputSetup.key_name("interact"), p.display_name], 0.2)
			return


func _update_pickups(delta: float) -> void:
	for id in pickups:
		var pk: Dictionary = pickups[id]
		pk["t"] += delta
		WorldProps.animate_pickup(pk["node"], pk["t"], delta)


# ------------------------------------------------------------------ Snapshots und privater Zustand

func on_snapshot(t: float, kills: int, elites: int, pl: Array, en: PackedFloat32Array, pr: PackedFloat32Array, hits: PackedInt32Array) -> void:
	if finished:
		return
	run_time = t
	run_stats["kills"] = kills
	run_stats["elites"] = elites
	var seen := {}
	for a in pl:
		var slot := int(a[0])
		seen[slot] = true
		if slot == _my_slot:
			continue
		_puppet(slot).apply_puppet_pack(a)
	for slot in puppets.keys():
		if not seen.has(slot):
			if is_instance_valid(puppets[slot]):
				puppets[slot].queue_free()
			puppets.erase(slot)
	var now := Time.get_ticks_msec()
	for i in range(0, en.size(), 6):
		var e = enemies.get(int(en[i]))
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		e.net_pos = Vector3(en[i + 1], e.position.y, en[i + 2])
		e.net_yaw = en[i + 3]
		e.hp = en[i + 4]
		e.apply_net_flags(int(en[i + 5]))
		e.set_meta("seen", now)
	for id in hits:
		var h = enemies.get(id)
		if h != null and is_instance_valid(h):
			h.ghost_hit()
	for i in range(0, pr.size(), 4):
		var pj = projs.get(int(pr[i]))
		if pj != null and is_instance_valid(pj):
			pj.net_pos = Vector3(pr[i + 1], pr[i + 2], pr[i + 3])


func on_me(d: Dictionary) -> void:
	if finished:
		return
	var prev := player.hp
	player.apply_net_state(d)
	if player.hp < prev - 0.5:
		hud.flash_hurt()
		player.shake = maxf(player.shake, 0.5)


func on_correct(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO


func on_fx(batch: Array) -> void:
	for it in batch:
		var kind: String = it[0]
		var a: Array = it[1]
		if kind == "sfx":
			Sfx.replaying = true
			Sfx.play(a[0], a[1], a[2])
			Sfx.replaying = false
		else:
			FX.apply_event(self, kind, a)


func _info_for_slot(slot: int) -> Dictionary:
	for id in Net.players:
		if int(Net.players[id].get("slot", -1)) == slot:
			_info_cache[slot] = Net.players[id]
			return Net.players[id]
	return _info_cache.get(slot, {"name": "Mitspieler", "appearance": SaveSystem.default_appearance(), "weapon": "sword"})


func _puppet(slot: int) -> Player:
	if puppets.has(slot) and is_instance_valid(puppets[slot]):
		return puppets[slot]
	var info := _info_for_slot(slot)
	var p := Player.new()
	p.net_role = "puppet"
	p.net_slot = slot
	p.display_name = str(info.get("name", "Mitspieler"))
	p.weapon_type = str(info.get("weapon", "sword"))
	p.character = {"appearance": info.get("appearance", SaveSystem.default_appearance()), "name": p.display_name}
	p.stats = {"max_hp": 100.0}
	p.position = _spawn_offset(slot)
	p.puppet_target = p.position
	add_child(p)
	puppets[slot] = p
	return p


# ------------------------------------------------------------------ Ereignisse (zuverlässig)

func on_event(kind: String, d: Array) -> void:
	match kind:
		"full":
			_apply_full(d)
		"spawn":
			_spawn_ghost(d[0])
		"die":
			var e = enemies.get(int(d[0]))
			enemies.erase(int(d[0]))
			if e != null and is_instance_valid(e) and not e.dead:
				e.die(true)
		"pspawn":
			_spawn_proj(d)
		"pend":
			var pj = projs.get(int(d[0]))
			projs.erase(int(d[0]))
			if pj != null and is_instance_valid(pj):
				pj.queue_free()
		"banner":
			hud.show_banner(d[0], d[1], d[2])
		"obj":
			_objective = d[0]
		"chest":
			var i := int(d[0])
			if i >= 0 and i < _chests.size() and not _chests[i]["open"]:
				WorldProps.open_chest_visual(_chests[i], self)
				Sfx.play("loot", 0.8, -3.0)
		"shrine":
			var i := int(d[0])
			if i >= 0 and i < _shrines.size():
				WorldProps.set_shrine_visual(_shrines[i], str(d[1]), self)
		"pickup":
			_add_pickup(int(d[0]), d[1], d[2])
		"pickup_gone":
			_remove_pickup(int(d[0]), true, str(d[1]), str(d[2]))
		"offer":
			_show_offer(d)
		"result":
			_show_result(d[0], bool(d[1]))


func _apply_full(d: Array) -> void:
	_got_full = true
	run_time = float(d[0])
	_clear_world_state()
	for desc in d[1]:
		_spawn_ghost(desc)
	for i in mini(d[2].size(), _chests.size()):
		if d[2][i] and not _chests[i]["open"]:
			WorldProps.open_chest_visual(_chests[i], self)
	for i in mini(d[3].size(), _shrines.size()):
		WorldProps.set_shrine_visual(_shrines[i], str(d[3][i]), self)
	for pk in d[4]:
		_add_pickup(int(pk[0]), pk[1], pk[2])
	_objective = str(d[5])


func _clear_world_state() -> void:
	for id in enemies:
		if is_instance_valid(enemies[id]):
			enemies[id].queue_free()
	enemies.clear()
	boss = null
	for id in projs:
		if is_instance_valid(projs[id]):
			projs[id].queue_free()
	projs.clear()
	for id in pickups.keys():
		_remove_pickup(id, false)


func _spawn_ghost(desc: Array) -> void:
	var id := int(desc[0])
	if enemies.has(id) and is_instance_valid(enemies[id]):
		return
	var e := Enemy.spawn_ghost(self, desc)
	e.set_meta("seen", Time.get_ticks_msec())
	enemies[id] = e
	if bool(desc[9]):
		boss = e as Boss


func _spawn_proj(d: Array) -> void:
	var pr := Projectile.new()
	pr.ghost = true
	pr.net_id = int(d[0])
	pr.life = float(d[5]) + 0.3
	pr.setup(self, d[1], d[2], d[3], float(d[4]))
	projs[pr.net_id] = pr


func _add_pickup(id: int, item: Dictionary, pos: Vector3) -> void:
	if pickups.has(id):
		return
	var n := WorldProps.make_pickup(self, pos, item)
	pickups[id] = {"node": n, "item": item, "t": 0.0}
	if item["rarity"] in ["epic", "legendary", "mythic"]:
		Sfx.play("rare_loot", 1.0, -3.0)
		hud.show_banner("%s gefunden: %s" % [GameData.rarity_name(item["rarity"]), item["name"]], GameData.rarity_color(item["rarity"]), 3.0)


func _remove_pickup(id: int, collected: bool, item_name: String = "", rarity: String = "common") -> void:
	var pk: Dictionary = pickups.get(id, {})
	if pk.is_empty():
		return
	pickups.erase(id)
	var n: Node3D = pk["node"]
	if collected and is_instance_valid(n):
		Sfx.play("loot", 1.0, -6.0)
		FX.float_text(self, n.global_position, item_name, GameData.rarity_color(rarity), 32)
	if is_instance_valid(n):
		n.queue_free()


# ------------------------------------------------------------------ Level-Up-Auswahl (läuft im laufenden Spiel)

func _show_offer(d: Array) -> void:
	var offers: Array = d[1]
	if RunState.bot_mode:
		Net.run.send_req("offer", ["pick", offers[randi() % offers.size()]["id"]])
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _levelup_ui != null and is_instance_valid(_levelup_ui) and _levelup_ui.visible and _levelup_ui.offers.size() == offers.size():
		var same := true
		for i in offers.size():
			same = same and _levelup_ui.offers[i]["id"] == offers[i]["id"]
		if same and _levelup_ui._rerolls == int(d[2]):
			return   # Wiederholtes Angebot vom Host: Karten nicht neu aufbauen
	if _levelup_ui == null or not is_instance_valid(_levelup_ui):
		_levelup_ui = LevelUpUI.new()
		_ui_layer.add_child(_levelup_ui)
		_levelup_ui.picked.connect(func(id): _answer_offer("pick", id))
		_levelup_ui.skipped.connect(func(): _answer_offer("skip", ""))
		_levelup_ui.reroll_requested.connect(func(): _answer_offer("reroll", ""))
	_levelup_ui.show_offers(int(d[0]), offers, int(d[2]), int(d[3]))


func _answer_offer(action: String, id: String) -> void:
	Net.run.send_req("offer", [action, id])
	if action != "reroll":
		# Das nächste Angebot (falls vorhanden) kommt vom Host; die Karten werden dann ersetzt.
		if _levelup_ui != null and is_instance_valid(_levelup_ui):
			_levelup_ui.queue_free()
		_levelup_ui = null
		if not RunState.bot_mode and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ Ergebnis

func _show_result(result: Dictionary, victory: bool) -> void:
	if finished:
		return
	finished = true
	var clean: Array = []
	for it in result.get("items", []):
		if typeof(it) == TYPE_DICTIONARY and ItemValidator.validate(it) == "":
			clean.append(it)
	result["items"] = clean
	RunState.finish_run(result)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _levelup_ui != null and is_instance_valid(_levelup_ui):
		_levelup_ui.queue_free()
	_result = ResultScreen.new()
	_ui_layer.add_child(_result)
	_result.show_result(result, RunState.last_summary)
	_result.continue_pressed.connect(func():
		Net.run_finished()
		RunState.back_to_menu())
	if RunState.auto_quit:
		get_tree().create_timer(0.5).timeout.connect(func(): get_tree().quit(0))


# ------------------------------------------------------------------ Pause, Verbindungsverlust

func _toggle_pause() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_resume()
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_menu = PauseMenu.new()
	_pause_menu.coop_client = true
	_ui_layer.add_child(_pause_menu)
	_pause_menu.resume.connect(_resume)
	_pause_menu.abort_run.connect(func():
		Net.leave("Run verlassen")
		RunState.back_to_menu())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _pause_menu != null and is_instance_valid(_pause_menu):
		_resume()


func _resume() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null
	if not RunState.bot_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_connection_lost(reason: String) -> void:
	if finished:
		return
	_lost = true
	_lost_elapsed = 0.0
	_retry_t = 1.0
	hud.show_banner("Verbindung verloren – versuche, wieder beizutreten …", UI.RED, 60.0)
	hud.show_hint(reason, 6.0)


func _update_reconnect(delta: float) -> void:
	if _joined_t >= 0.0:
		_joined_t += delta
		if _joined_t > 2.5 and _lost:
			# Verbunden, aber der Run läuft nicht mehr (z. B. schon beendet): zurück ins Menü
			RunState.back_to_menu()
			return
	if not _lost:
		return
	_lost_elapsed += delta
	if _lost_elapsed > Net.RECONNECT_GRACE:
		Net.leave()
		RunState.back_to_menu()
		return
	_retry_t -= delta
	if _retry_t <= 0.0 and Net.peer == null:
		_retry_t = 3.0
		Net.join_lobby("%s:%d" % [Net.host_ip, Net.host_port])


func _on_rejoined() -> void:
	_lost = false
	_joined_t = -1.0
	_got_full = false
	_ready_t = 0.0
	Net.run.arena = self
	hud.show_banner("Wieder verbunden!", UI.TEAL, 2.5)
