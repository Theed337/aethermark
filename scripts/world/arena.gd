class_name Arena
extends Node3D
## Eine Spielrunde (Host-/Solo-Seite): Karte, Spieler, Spawner mit Eskalation, Zwischenboss, Hauptboss,
## Truhen, Schrein-Ereignis, Beute, Level-Up-Auswahl, Ergebnis.
##
## Solo und Koop laufen mit demselben Code:
##  * Solo: players = [player], keine Netzwerkschicht (net_on = false), Level-Up pausiert das Spiel.
##  * Koop (Host): zusätzlich je ein "remote_sim"-Spieler pro Mitspieler. Der Host simuliert alles und sendet
##    Snapshots/Ereignisse über Net.run. Beute und Level-Up-Angebote sind pro Spieler, das Spiel pausiert nie.
## Die Clients nutzen ClientArena (scripts/world/client_arena.gd).

const TIME_SCALE_QUICK := 0.33
const OFFER_TIMEOUT := 25.0          # Koop: nach dieser Zeit wird eine Option automatisch gewählt
const SNAP_INTERVAL := 1.0 / 15.0
const ME_INTERVAL := 1.0 / 20.0
const REVIVE_RANGE := 2.4
const WIPE_DELAY := 2.0

var player: Player                   # lokaler Spieler (Solo oder Host)
var players: Array = []              # alle Spieler dieses Runs
var boss: Boss = null
var _hazard_t := 0.0
var victory_pending := false      # Boss besiegt: Zeit zum Einsammeln der Beute, dann Ergebnis
var victory_t := 0.0
var _hint_t := 0.0
const VICTORY_LOOT_TIME := 25.0
var xp_mult := 1.0               # Ereignisse (Blutmond)
var event_spawn_mult := 1.0
var event_text := ""
var curses: Array = []
var events: RunEvents = null
var hud: Hud
var map_info: Dictionary = {}
var scaling: Dictionary = {}
var rng := RandomNumberGenerator.new()
var run_time := 0.0
## Team-Werte für HUD und Spielablauf. Persönliche Werte stehen in player.run_stats.
var run_stats := {"kills": 0, "elites": 0, "minibosses": 0, "boss_defeated": false}
var finished := false
var boss_spawned := false
var miniboss_spawned := false
var net_on := false
var _spawn_timer := 1.0
var _levelup_ui: LevelUpUI
var _pause_menu: PauseMenu
var _result: ResultScreen
var _ui_layer: CanvasLayer
var _chests: Array = []
var _shrines: Array = []
var _pickups: Array = []
var _next_pid := 1
var _prompt_target: Node3D = null
var _time_k := 1.0
var _banner_shown_tier := -1
var _area: Dictionary = {}
var _wipe_t := 0.0
var _last_objective := ""
# Netzwerk (nur Host im Koop)
var _next_net_id := 1
var _enemy_ids: Dictionary = {}      # net_id -> Enemy
var _projs: Dictionary = {}          # net_id -> Projectile
var _hit_ids := PackedInt32Array()
var _snap_t := 0.0
var _me_t := 0.0


func area_name() -> String:
	return _area.get("name", "")


func _ready() -> void:
	GameData.activate_area(RunState.area_id)
	rng.seed = RunState.seed_value
	_area = GameData.area_by_id(RunState.area_id)
	_time_k = TIME_SCALE_QUICK if RunState.quick_mode else 1.0
	net_on = Net.is_host() and Net.state == "running" and Net.players.size() > 1
	var party := 1
	var avg_power := 1.0
	if net_on:
		party = Net.players.size()
		var sum := 0.0
		for id in Net.players:
			sum += float(Net.players[id].get("power", 1.0))
		avg_power = sum / float(party)
	scaling = RunState.scaling(party, RunState.difficulty, avg_power, RunState.area_id)
	curses = Curses.roll(RunState.difficulty, RunState.seed_value)
	Curses.apply(curses, scaling)
	map_info = ForestMap.build(self, RunState.seed_value)
	var c := SaveSystem.active_character()
	player = Player.new()
	player.bot = RunState.bot_mode
	player.bot_damage_scale = RunState.bot_damage_scale
	player.position = map_info["spawn"] if not net_on else _spawn_offset(0)
	player.setup(self, c)
	player.display_name = c.get("name", "Held")
	player.net_slot = 0
	add_child(player)
	player.cam_yaw = 0.0
	players.append(player)
	_connect_player(player)
	if net_on:
		_setup_coop()
	# UI
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	hud = Hud.new()
	_ui_layer.add_child(hud)
	hud.bind(self, player)
	_build_world_objects()
	if not RunState.bot_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_banner(_area.get("name", "Smaragdwald"), UI.GOLD, 3.5)
	hud.show_hint("Besiege Gegner, steige auf – am Ende wartet %s" % GameData.boss.get("name", "der Boss"), 5.0)
	events = RunEvents.new()
	add_child(events)
	events.setup(self)
	if not curses.is_empty():
		hud.show_hint(Curses.text(curses), 7.0)
	_spawn_wave(["grunt", "grunt", "grunt"])


func _exit_tree() -> void:
	if net_on and Net.run.arena == self:
		Net.run.arena = null
		Net.run.sims.clear()
		FX.net_hook = Callable()
		Sfx.net_hook = Callable()


func _spawn_offset(slot: int) -> Vector3:
	var a := slot * TAU / 5.0
	return map_info["spawn"] + Vector3(cos(a), 0.0, sin(a)) * 2.5


func _connect_player(p: Player) -> void:
	p.leveled_up.connect(_on_level_up.bind(p))
	p.died_signal.connect(_on_player_died.bind(p))
	p.skill_unlocked.connect(func(id): player_banner(p, "Neue Fähigkeit: %s" % GameData.skills[id]["name"], UI.TEAL))
	p.evolution_unlocked.connect(_on_evolution.bind(p))


## Koop: Remote-Spieler anlegen und Netzwerk-Hooks setzen.
func _setup_coop() -> void:
	RunState.world_freeze = 0.0
	Net.run.arena = self
	FX.net_hook = Net.run.queue_fx
	Sfx.net_hook = Net.run.queue_sfx
	Net.player_left_run.connect(_on_player_left_run)
	for id in Net.players:
		if id == 1:
			continue
		var info: Dictionary = Net.players[id]
		var slot := int(info["slot"])
		var ch := Net.character_from_build(Net.builds[id])
		var rp := Player.new()
		rp.net_role = "remote_sim"
		rp.bot_damage_scale = RunState.bot_damage_scale   # nur für Tests relevant (Standard 1.0)
		rp.net_peer = id
		rp.net_slot = slot
		rp.display_name = str(info["name"])
		rp.setup(self, ch)
		rp.position = _spawn_offset(slot)
		rp.remote_target = rp.position
		add_child(rp)
		_connect_player(rp)
		players.append(rp)
		Net.run.sims[slot] = rp


func _build_world_objects() -> void:
	for p in map_info["chests"]:
		_chests.append(WorldProps.make_chest(self, p))
	for p in map_info["shrines"]:
		_shrines.append(WorldProps.make_shrine(self, p))


func objective_text() -> String:
	if boss != null and is_instance_valid(boss) and not boss.dead:
		return "Besiege %s!" % GameData.boss.get("name", "den Boss")
	if event_text != "":
		return event_text
	if boss_spawned:
		return ""
	var t_boss := _boss_time()
	var left := maxf(t_boss - run_time, 0.0)
	return "Der Wächter erwacht in %d:%02d – sammle Stärke!" % [int(left) / 60, int(left) % 60]


func _boss_time() -> float:
	return 150.0 * _time_k


## Gruppenliste für das HUD (Name, Leben, Zustand).
func party_members() -> Array:
	var out: Array = []
	for p in players:
		if is_instance_valid(p):
			out.append({"name": p.display_name, "hp": p.hp, "max": p.stats.get("max_hp", 100.0), "down": p.is_down(),
					"away": p.net_away, "level": p.level, "self": p == player, "lost": p.permadown})
	return out


func valid_players() -> Array:
	return players.filter(func(p): return is_instance_valid(p))


## Banner für alle Spieler (lokal + Netzwerk).
func banner_all(text: String, color: Color = UI.GOLD, duration: float = 2.8) -> void:
	hud.show_banner(text, color, duration)
	if net_on:
		Net.run.ev("banner", [text, color, duration])


## Banner nur für einen Spieler.
func player_banner(p: Player, text: String, color: Color = UI.GOLD, duration: float = 2.0) -> void:
	if p == player:
		hud.show_banner(text, color, duration)
	elif net_on and p.net_role == "remote_sim" and not p.net_away:
		Net.run.ev("banner", [text, color, duration], p.net_peer)


# ------------------------------------------------------------------ Hauptschleife

func _process(delta: float) -> void:
	if finished:
		return
	if RunState.world_freeze > 0.0:
		RunState.world_freeze = maxf(RunState.world_freeze - delta, 0.0)
		_update_pickups(delta)
		_update_prompt()
		_update_offers()
		if net_on:
			_update_revive(delta)
			_net_tick(delta)
		return
	run_time += delta
	if victory_pending:
		victory_t -= delta
		_hint_t -= delta
		if _hint_t <= 0.0 and hud != null:
			_hint_t = 1.0
			hud.show_hint("Beute einsammeln – Rückkehr in %d s  (Enter: jetzt beenden)" % int(ceil(victory_t)), 1.2)
		if victory_t <= 0.0 or (Input.is_action_just_pressed("ui_accept") and not RunState.bot_mode and not net_on):
			_finish(true)
			return
	_update_spawner(delta)
	_update_pickups(delta)
	_update_hazards(delta)
	_update_prompt()
	_update_offers()
	if net_on:
		_update_revive(delta)
		_update_wipe(delta)
		_net_tick(delta)
		var obj := objective_text()
		if obj != _last_objective and int(run_time * 2.0) % 2 == 0:
			_last_objective = obj
			Net.run.ev("obj", [obj])
	if Input.is_action_just_pressed("pause") and not RunState.bot_mode and not (_levelup_ui != null and is_instance_valid(_levelup_ui)):
		_toggle_pause()
	if not boss_spawned and run_time >= _boss_time():
		_spawn_boss()
	if not miniboss_spawned and run_time >= 70.0 * _time_k and not boss_spawned:
		_spawn_miniboss()


## Gefahrenzone des Gebiets (Lava, Gift, Eisloch, Leere): periodischer Schaden für Spieler darin.
func _update_hazards(delta: float) -> void:
	if str(ForestMap.T["hazard"]) == "none":
		return
	_hazard_t += delta
	if _hazard_t < 0.5:
		return
	_hazard_t = 0.0
	var dmg := float(ForestMap.T["hazard_dps"]) * 0.5 * float(scaling.get("dmg_mult", 1.0))
	for p in players:
		if is_instance_valid(p) and not p.is_down() and not p.net_away and ForestMap.in_hazard(p.global_position):
			p.take_damage(dmg, p.global_position)
			FX.burst(self, p.global_position + Vector3(0, 0.3, 0), ForestMap.col("liquid_color"), 6, 3.0)


func _current_tier() -> Dictionary:
	var tier: Dictionary = GameData.threat_tiers[0]
	var idx := 0
	for i in GameData.threat_tiers.size():
		if run_time >= float(GameData.threat_tiers[i]["time"]) * _time_k:
			tier = GameData.threat_tiers[i]
			idx = i
	if idx != _banner_shown_tier:
		_banner_shown_tier = idx
		if idx > 0 and hud != null:
			banner_all("Die Bedrohung steigt …", UI.RED, 2.2)
	return tier


func _update_spawner(delta: float) -> void:
	if victory_pending:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var tier := _current_tier()
	_spawn_timer = float(tier["interval"]) * (0.6 if RunState.quick_mode else 1.0) * event_spawn_mult
	var cap: int = scaling["spawn_cap"]
	if boss_spawned:
		cap = 8
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= cap:
		return
	var list: Array = []
	for g in tier["groups"]:
		for i in int(g[1]) + int(scaling["group_bonus"]):
			list.append(g[0])
	list.shuffle()
	var room := cap - alive
	if list.size() > room:
		list.resize(room)
	_spawn_wave(list, float(tier.get("elite_chance", 0.0)) + float(scaling["elite_bonus"]))


## Ein zufälliger kampffähiger Spieler (Gegnergruppen erscheinen bei wechselnden Spielern).
func _random_active_player() -> Player:
	var alive: Array = players.filter(func(p): return is_instance_valid(p) and not p.is_down() and not p.net_away)
	if alive.is_empty():
		return player
	return alive[rng.randi() % alive.size()]


func _spawn_wave(types: Array, elite_chance: float = 0.0) -> void:
	var center := _random_active_player().global_position
	var ang0 := rng.randf() * TAU
	for i in types.size():
		var ang := ang0 + rng.randf_range(-0.7, 0.7)
		var r := rng.randf_range(20.0, 28.0)
		var p := _clamp_to_map(center + Vector3(cos(ang), 0, sin(ang)) * r)
		var elite := ""
		var tdata: Dictionary = GameData.enemy_types[types[i]]
		if elite_chance > 0.0 and rng.randf() < elite_chance and int(tdata["tier"]) < 3:
			var keys: Array = GameData.elite_mods.keys()
			elite = keys[rng.randi() % keys.size()]
		var e := Enemy.spawn(self, types[i], p, scaling, elite)
		register_enemy(e)


func _clamp_to_map(p: Vector3) -> Vector3:
	var flat := Vector2(p.x, p.z)
	var maxr := ForestMap.RADIUS - 4.0
	if flat.length() > maxr:
		flat = flat.normalized() * maxr
	var out := Vector3(flat.x, 0.5, flat.y)
	# Bossarena freihalten, solange der Boss noch nicht aktiv ist
	var d := Vector2(out.x - ForestMap.BOSS_POS.x, out.z - ForestMap.BOSS_POS.z)
	if d.length() < ForestMap.BOSS_ARENA_R and not boss_spawned:
		var push := d.normalized() * (ForestMap.BOSS_ARENA_R + 1.5)
		out.x = ForestMap.BOSS_POS.x + push.x
		out.z = ForestMap.BOSS_POS.z + push.y
	return out


func register_enemy(e: Enemy) -> void:
	if not e.died.is_connected(_on_enemy_died):
		e.died.connect(_on_enemy_died)
	if net_on and e.net_id == 0:
		e.net_id = _next_net_id
		_next_net_id += 1
		_enemy_ids[e.net_id] = e
		Net.run.ev("spawn", [_spawn_desc(e)])


func _spawn_desc(e: Enemy) -> Array:
	return [e.net_id, e.type_id, e.position.x, e.position.y, e.position.z, e.elite_mod, e.is_mini, e.model_scale, e.max_hp, e is Boss]


func _spawn_miniboss() -> void:
	miniboss_spawned = true
	var ang := rng.randf() * TAU
	var p := _clamp_to_map(_random_active_player().global_position + Vector3(cos(ang), 0, sin(ang)) * 22.0)
	var e := Enemy.spawn(self, "brute", p, scaling, "", true)
	register_enemy(e)
	banner_all("Zwischenboss: %s" % e.display_name(), UI.RED, 3.0)
	Sfx.play("boss", 1.3, -4.0)


func _spawn_boss() -> void:
	boss_spawned = true
	boss = Boss.spawn_boss(self, ForestMap.BOSS_POS + Vector3(0, 0.2, -3), scaling)
	boss.announce = func(t: String): banner_all(t, UI.GOLD, 2.6)
	register_enemy(boss)
	banner_all("%s erwacht!" % GameData.boss.get("name", "Der Boss"), UI.RED, 4.0)
	Sfx.play("boss", 0.8, 0.0)
	# Die Gegner der Umgebung ziehen sich nicht zurück, aber es kommen weniger nach (Obergrenze 8)


# ------------------------------------------------------------------ Gegner-Tod, XP, Beute

## Teiler-Gegner zerfallen beim Tod in kleinere Gegner.
func _split_enemy(e: Enemy) -> void:
	var sp: Dictionary = e.data["split"]
	for i in int(sp["count"]):
		var a := rng.randf() * TAU
		var pos := e.global_position + Vector3(cos(a), 0.3, sin(a)) * 1.2
		register_enemy(Enemy.spawn(self, str(sp["type"]), pos, scaling))


func _on_enemy_died(e: Enemy) -> void:
	if finished:
		return
	if net_on and e.net_id > 0:
		_enemy_ids.erase(e.net_id)
		Net.run.ev("die", [e.net_id])
	var killer: Player = player
	if e.last_hit_by != null and is_instance_valid(e.last_hit_by) and e.last_hit_by is Player:
		killer = e.last_hit_by
	var xp: int = int(e.data.get("xp", 5))
	var is_boss := e is Boss
	if e.data.has("split") and not e.ghost:
		_split_enemy(e)
	run_stats["kills"] += 1
	killer.run_stats["kills"] += 1
	if e.is_mini:
		xp *= 8
		run_stats["minibosses"] += 1
		run_stats["elites"] += 1
		killer.run_stats["minibosses"] += 1
		killer.run_stats["elites"] += 1
	elif e.elite_mod != "":
		xp *= 3
		run_stats["elites"] += 1
		killer.run_stats["elites"] += 1
	_share_xp(xp, e.global_position)
	killer.on_enemy_killed(e)
	if e.is_mini or e.elite_mod != "":
		# Loot bewusst knapp: Mini-Bosse immer, Elite nur etwa jeder zweite
		if e.is_mini or rng.randf() < 0.30 * RunState.drop_mult:
			_drop_item(e.global_position, "rare" if e.is_mini else "uncommon", 1.0)
	elif is_boss:
		for i in 3:
			_drop_item(e.global_position + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), "rare", 3.0)
		_drop_unique_for_boss(e.global_position)
	elif rng.randf() < 0.012 * RunState.drop_mult:
		_drop_item(e.global_position, "common", 1.0, killer)
	if is_boss:
		run_stats["boss_defeated"] = true
		victory_pending = true
		victory_t = 2.0 if RunState.bot_mode else VICTORY_LOOT_TIME
		banner_all("%s besiegt! Sammle deine Beute …" % GameData.boss.get("name", "Der Wächter"), UI.GOLD, 4.0)


## Erfahrung wird auf alle kampffähigen Spieler verteilt (mit mehr Spielern bekommt jeder etwas weniger, gesamt mehr).
func _share_xp(xp: int, at: Vector3) -> void:
	var able: Array = players.filter(func(p): return is_instance_valid(p) and not p.is_down() and not p.net_away)
	if able.is_empty():
		return
	var share := 1.0 if able.size() == 1 else 0.45 + 0.55 / float(able.size())
	var each := maxi(int(round(xp * share * xp_mult)), 1)
	for p in able:
		p.add_xp(each)
	FX.float_text(self, at + Vector3(0, 0.8, 0), "+%d EP" % each, Color("#f0c65a"), 30)


func _item_level() -> int:
	return 1 + int(run_time / 60.0) + RunState.difficulty


## Persönliche Beute: owner = null -> jeder Spieler würfelt für sich, sonst nur der genannte Spieler.
func _drop_item(pos: Vector3, min_rarity: String, bonus: float, owner: Player = null) -> void:
	if owner != null:
		_drop_item_for(owner, pos, min_rarity, bonus)
		return
	for p in players:
		if is_instance_valid(p):
			_drop_item_for(p, pos, min_rarity, bonus)


func _drop_item_for(p: Player, pos: Vector3, min_rarity: String, bonus: float) -> void:
	bonus *= 1.0 + Curses.LOOT_BONUS_PER_CURSE * curses.size()
	_spawn_pickup(pos, Loot.roll_item(rng, _item_level(), bonus, min_rarity), p)


func _drop_unique_for_boss(pos: Vector3) -> void:
	# Bossdrop: Klinge des Wächters (einzigartige Waffe mit Wandlung), je Spieler 50 % Chance
	for p in players:
		if not is_instance_valid(p):
			continue
		for u in GameData.items_cfg["uniques"]:
			if u.get("boss", "") == GameData.boss.get("id", "") and rng.randf() < 0.5:
				_spawn_pickup(pos + Vector3(1.5, 0, 0), Loot.from_unique(u, _item_level()), p)
				break


func _spawn_pickup(pos: Vector3, item: Dictionary, owner: Player) -> void:
	var pk := {"id": _next_pid, "item": item, "owner": owner, "pos": Vector3(pos.x, 0.0, pos.z), "t": 0.0, "node": null}
	_next_pid += 1
	var rare: bool = item["rarity"] in ["epic", "legendary", "mythic"]
	var col := GameData.rarity_color(item["rarity"])
	if owner == player:
		pk["node"] = WorldProps.make_pickup(self, pos, item)
		if rare:
			Sfx.play("rare_loot", 1.0, -3.0)
			hud.show_banner("%s gefunden: %s" % [GameData.rarity_name(item["rarity"]), item["name"]], col, 3.0)
	elif net_on and owner.net_role == "remote_sim" and not owner.net_away:
		Net.run.ev("pickup", [pk["id"], item, pk["pos"]], owner.net_peer)
	_pickups.append(pk)


func _update_pickups(delta: float) -> void:
	for i in range(_pickups.size() - 1, -1, -1):
		var pk: Dictionary = _pickups[i]
		var o: Player = pk["owner"]
		if not is_instance_valid(o):
			if pk["node"] != null:
				pk["node"].queue_free()
			_pickups.remove_at(i)
			continue
		pk["t"] += delta
		var n: Node3D = pk["node"]
		if n != null:
			WorldProps.animate_pickup(n, pk["t"], delta)
		if o.is_down() or o.net_away:
			continue
		var flat := Vector3(o.global_position.x, 0.0, o.global_position.z)
		if pk["t"] > 0.6 and pk["pos"].distance_to(flat) <= o.stats["pickup_radius"]:
			o.run_stats["items"].append(pk["item"])
			if n != null:
				Sfx.play("loot", 1.0, -6.0)
				FX.float_text(self, n.global_position, pk["item"]["name"], GameData.rarity_color(pk["item"]["rarity"]), 32)
				n.queue_free()
			elif net_on and o.net_role == "remote_sim":
				Net.run.ev("pickup_gone", [pk["id"], pk["item"]["name"], pk["item"]["rarity"]], o.net_peer)
			_pickups.remove_at(i)


# ------------------------------------------------------------------ Truhen & Schrein

func _update_prompt() -> void:
	_prompt_target = null
	if player.is_down():
		hud.show_hint("Du bist kampfunfähig – ein Mitspieler kann dich wiederbeleben" if net_on else "", 0.2)
		return
	var best := 3.0
	var chest_nodes: Array = []
	for c in _chests:
		chest_nodes.append(c["node"])
		if not c["open"]:
			var d: float = c["node"].global_position.distance_to(player.global_position)
			if d < best:
				best = d
				_prompt_target = c["node"]
	for s in _shrines:
		if s["state"] == "idle":
			var d: float = s["node"].global_position.distance_to(player.global_position)
			if d < best:
				best = d
				_prompt_target = s["node"]
		elif s["state"] == "active":
			s["enemies"] = s["enemies"].filter(func(e): return is_instance_valid(e) and not e.dead)
			if s["enemies"].is_empty():
				_complete_shrine(s)
	if _prompt_target != null:
		var kind := "Truhe öffnen" if _prompt_target in chest_nodes else "Verfluchten Schrein berühren (Risiko: 2 Eliten)"
		hud.show_hint("[%s] %s" % [InputSetup.key_name("interact"), kind], 0.2)
	elif net_on:
		for p in players:
			if is_instance_valid(p) and p != player and p.is_down() and not p.permadown and p.global_position.distance_to(player.global_position) <= 3.5:
				hud.show_hint("[%s halten] %s wiederbeleben" % [InputSetup.key_name("interact"), p.display_name], 0.2)
				break


func _complete_shrine(s: Dictionary) -> void:
	WorldProps.set_shrine_visual(s, "done", self)
	if net_on:
		Net.run.ev("shrine", [_shrines.find(s), "done"])
	for p in players:
		if is_instance_valid(p):
			p.run_stats["shrines"] += 1
			p.add_xp(60)
	_drop_item(s["node"].global_position + Vector3(0, 0, 1.5), "rare", 2.5)
	banner_all("Fluch gebrochen – die Belohnung gehört euch!" if net_on else "Fluch gebrochen – die Belohnung gehört dir!", Color("#d89bff"), 3.0)


## Interaktion eines Spielers (Host-Spieler per Taste, Remote-Spieler per Aktion).
func player_interact(p: Node) -> void:
	if p.is_down():
		return
	for i in _chests.size():
		var c: Dictionary = _chests[i]
		if not c["open"] and c["node"].global_position.distance_to(p.global_position) <= 3.0:
			_open_chest(i, p)
			return
	for i in _shrines.size():
		var s: Dictionary = _shrines[i]
		if s["state"] == "idle" and s["node"].global_position.distance_to(p.global_position) <= 3.0:
			_activate_shrine(i, p)
			return


func _open_chest(i: int, p: Player) -> void:
	var c: Dictionary = _chests[i]
	WorldProps.open_chest_visual(c, self)
	p.run_stats["chests"] += 1
	Sfx.play("loot", 0.8, -3.0)
	if net_on:
		Net.run.ev("chest", [i])
	for q in players:
		if not is_instance_valid(q):
			continue
		var n := 1 + (1 if rng.randf() < 0.2 else 0)
		for k in n:
			_drop_item_for(q, c["node"].global_position + Vector3(rng.randf_range(-1, 1), 0, 1.2), "uncommon", 1.5)
		q.add_xp(20)


func _activate_shrine(i: int, p: Player) -> void:
	var s: Dictionary = _shrines[i]
	WorldProps.set_shrine_visual(s, "active", self)
	if net_on:
		Net.run.ev("shrine", [i, "active"])
	banner_all("Der Schrein erwacht – besiegt die Wächter!", Color("#d89bff"), 3.0)
	Sfx.play("boss", 1.5, -4.0)
	for k in 2:
		var ang := k * PI + rng.randf()
		var e := Enemy.spawn(self, "brute" if k == 0 else "archer", s["node"].global_position + Vector3(cos(ang), 0, sin(ang)) * 4.0, scaling, "armored" if k == 0 else "swift")
		register_enemy(e)
		s["enemies"].append(e)


# ------------------------------------------------------------------ Level-Up (pro Spieler)

func _on_level_up(_new_level: int, p: Player) -> void:
	if finished:
		return
	p.level_pending += 1
	if p == player:
		Sfx.play("levelup", 1.0, -3.0)
	FX.ring(self, p.global_position, 5.0, Color("#f0c65a"), 0.6)
	FX.burst(self, p.global_position + Vector3(0, 1, 0), Color("#f0c65a"), 20, 6.0)
	p.hp = minf(p.hp + p.stats["max_hp"] * 0.15, p.stats["max_hp"])


## Jeden Frame: bietet wartenden Spielern Verbesserungen an bzw. wählt nach Ablauf der Zeit automatisch.
func _update_offers() -> void:
	if finished:
		return
	for p in players:
		if not is_instance_valid(p):
			continue
		if p.level_pending > 0 and p.net_offers.is_empty() and not p.is_down() and not p.net_away:
			_start_offer(p)
		elif not p.net_offers.is_empty() and net_on and run_time > p.offer_deadline and p != player:
			var o: Dictionary = p.net_offers[p.rng.randi() % p.net_offers.size()]
			_resolve_offer(p, "pick", o["id"])


func _start_offer(p: Player) -> void:
	var offers := LevelUp.generate_offers(p.rng, p.levels, p.level, p.recent_offers)
	if offers.is_empty():
		p.level_pending = 0
		return
	p.net_offers = offers
	p.offer_deadline = run_time + OFFER_TIMEOUT
	if net_on and RunState.world_freeze < RunState.OFFER_FREEZE:
		RunState.world_freeze = RunState.OFFER_FREEZE
		banner_all("Fähigkeitenwahl – kurze Pause!", UI.TEAL, 3.0)
	if p == player:
		if RunState.bot_mode:
			_resolve_offer(p, "pick", offers[p.rng.randi() % offers.size()]["id"])
			return
		_show_local_offers()
	else:
		_send_offer(p)


func _offer_level(p: Player) -> int:
	return p.level - p.level_pending + 1


func _send_offer(p: Player) -> void:
	Net.run.ev("offer", [_offer_level(p), p.net_offers, p.rerolls_left, p.level_pending - 1, OFFER_TIMEOUT], p.net_peer)


func _show_local_offers() -> void:
	if not net_on:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _levelup_ui == null or not is_instance_valid(_levelup_ui):
		_levelup_ui = LevelUpUI.new()
		_ui_layer.add_child(_levelup_ui)
		_levelup_ui.picked.connect(func(id): _resolve_offer(player, "pick", id))
		_levelup_ui.skipped.connect(func(): _resolve_offer(player, "skip", ""))
		_levelup_ui.reroll_requested.connect(func(): _resolve_offer(player, "reroll", ""))
	_levelup_ui.show_offers(_offer_level(player), player.net_offers, player.rerolls_left, player.level_pending - 1)


## Verarbeitet Auswahl, Neuwurf oder Überspringen. Wird vom Host für sich selbst und für Remote-Spieler aufgerufen;
## Remote-Eingaben werden hier geprüft (nur Optionen aus dem aktuellen Angebot, nur wenn ein Angebot offen ist).
func _resolve_offer(p: Player, action: String, id: String) -> void:
	if p.net_offers.is_empty() or p.level_pending <= 0:
		return
	match action:
		"pick":
			var ok := false
			for o in p.net_offers:
				if o["id"] == id:
					ok = true
			if not ok:
				return
			p.add_skill_level(id)
			p.recent_offers.append(id)
			if p.recent_offers.size() > 4:
				p.recent_offers = p.recent_offers.slice(p.recent_offers.size() - 4)
			var d: Dictionary = GameData.skills[id]
			player_banner(p, "%s – Stufe %d" % [d["name"], p.skill_lv(id)], Color(GameData.skill_cfg["rarity_colors"][d["rarity"]]), 2.0)
		"reroll":
			if p.rerolls_left <= 0:
				return
			p.rerolls_left -= 1
			for o in p.net_offers:
				p.recent_offers.append(o["id"])
			var fresh := LevelUp.generate_offers(p.rng, p.levels, p.level, p.recent_offers)
			if not fresh.is_empty():
				p.net_offers = fresh
				p.offer_deadline = run_time + OFFER_TIMEOUT
			if p == player:
				_show_local_offers()
			else:
				_send_offer(p)
			return
		"skip":
			var rew: Dictionary = GameData.skill_cfg["skip_reward"]
			p.hp = minf(p.hp + p.stats["max_hp"] * float(rew["heal_pct"]), p.stats["max_hp"])
			p.mana = minf(p.mana + p.stats["mana_max"] * float(rew["mana_pct"]), p.stats["mana_max"])
			player_banner(p, "Übersprungen: Leben und Mana aufgefüllt", UI.TEAL, 2.0)
		_:
			return
	p.net_offers = []
	p.level_pending -= 1
	if p == player:
		if _levelup_ui != null and is_instance_valid(_levelup_ui):
			_levelup_ui.queue_free()
		_levelup_ui = null
		if not net_on:
			get_tree().paused = false
		if p.level_pending <= 0 and not RunState.bot_mode and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_evolution(evo_id: String, p: Player) -> void:
	for e in GameData.evolutions:
		if e["id"] == evo_id:
			player_banner(p, "★ Evolution: %s" % e["name"], UI.GOLD, 4.0)
			if p == player:
				Sfx.play("rare_loot", 1.2, -2.0)


# ------------------------------------------------------------------ Spielerzustand, Wiederbelebung, Wipe

func on_player_hurt(_p: Node = null) -> void:
	if _p == null or _p == player:
		hud.flash_hurt()


func notify_low_mana() -> void:
	hud.show_hint("Nicht genug Mana", 0.6)


func _on_player_died(p: Player) -> void:
	if not net_on:
		hud.show_banner("Du wurdest besiegt …", UI.RED, 3.0)
		get_tree().create_timer(1.8, false).timeout.connect(func(): _finish(false))
		return
	banner_all("%s ist kampfunfähig!" % p.display_name, UI.RED, 2.5)


## Wiederbelebung: Ein Mitspieler hält die Interaktionstaste in Reichweite. Sonst verblutet der Spieler nach BLEED_TIME.
func _update_revive(delta: float) -> void:
	for p in players:
		if not is_instance_valid(p) or not p.is_down() or p.permadown:
			continue
		p.bleed_t -= delta
		if p.bleed_t <= 0.0:
			p.bleed_t = 0.0
			p.permadown = true
			banner_all("%s ist verloren." % p.display_name, UI.RED, 2.5)
			continue
		var helper: Player = null
		for h in players:
			if h == p or not is_instance_valid(h) or h.is_down() or h.net_away:
				continue
			if h.interact_held and h.global_position.distance_to(p.global_position) <= REVIVE_RANGE:
				helper = h
				break
		if helper != null:
			p.revive_progress += delta / Player.REVIVE_TIME
			if p.revive_progress >= 1.0:
				p.revive(0.4)
				helper.run_stats["revives"] += 1
				banner_all("%s wurde wiederbelebt!" % p.display_name, UI.TEAL, 2.0)
		else:
			p.revive_progress = maxf(p.revive_progress - delta * 0.5, 0.0)
	for p in players:
		if is_instance_valid(p) and p.net_role == "remote_sim":
			p.update_plate()


## Niederlage, wenn kein Spieler mehr kämpfen kann. Getrennte Spieler zählen bis zum Ablauf der Frist als kampffähig.
func _update_wipe(delta: float) -> void:
	var any_able := false
	for p in players:
		if is_instance_valid(p) and not p.is_down():
			any_able = true
	if any_able:
		_wipe_t = 0.0
		return
	_wipe_t += delta
	if _wipe_t >= WIPE_DELAY:
		_finish(false)


func _on_player_left_run(slot: int) -> void:
	if not Net.run.has_slot(slot):
		return
	var p: Player = Net.run.sims[slot]
	Net.run.sims.erase(slot)
	players.erase(p)
	banner_all("%s hat die Gruppe verlassen." % p.display_name, UI.DIM, 2.5)
	p.queue_free()


# ------------------------------------------------------------------ Netzwerk (Host)

func net_proj_spawn(pr: Projectile) -> void:
	if not net_on:
		return
	pr.net_id = _next_net_id
	_next_net_id += 1
	_projs[pr.net_id] = pr
	Net.run.ev("pspawn", [pr.net_id, pr.position, pr.velocity, pr.color, pr.visual_size, pr.life])


func net_proj_end(id: int) -> void:
	if net_on and _projs.erase(id):
		Net.run.ev("pend", [id])


func net_enemy_hit(e: Enemy) -> void:
	if net_on and e.net_id > 0:
		_hit_ids.append(e.net_id)


func _net_tick(delta: float) -> void:
	Net.run.host_tick(delta)
	_snap_t += delta
	if _snap_t >= SNAP_INTERVAL:
		_snap_t = 0.0
		_send_snapshot()
	_me_t += delta
	if _me_t >= ME_INTERVAL:
		_me_t = 0.0
		for p in players:
			if is_instance_valid(p) and p.net_role == "remote_sim" and not p.net_away:
				Net.run.send_me(p.net_peer, p.net_me_pack())


func _send_snapshot() -> void:
	var pl: Array = []
	for p in players:
		if is_instance_valid(p):
			pl.append(p.net_pack())
	var en := PackedFloat32Array()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.net_id <= 0:
			continue
		en.push_back(float(e.net_id))
		en.push_back(snappedf(e.global_position.x, 0.05))
		en.push_back(snappedf(e.global_position.z, 0.05))
		en.push_back(snappedf(e.rotation.y, 0.05))
		en.push_back(snappedf(e.hp, 0.5))
		en.push_back(float(e.net_flags()))
	var pr := PackedFloat32Array()
	for id in _projs:
		var pj: Projectile = _projs[id]
		if is_instance_valid(pj):
			pr.push_back(float(id))
			pr.push_back(snappedf(pj.global_position.x, 0.05))
			pr.push_back(snappedf(pj.global_position.y, 0.05))
			pr.push_back(snappedf(pj.global_position.z, 0.05))
	Net.run.send_snapshot(run_time, run_stats["kills"], run_stats["elites"], pl, en, pr, _hit_ids)
	_hit_ids = PackedInt32Array()


## Anfragen von Clients (Angebots-Wahl, "bereit" nach dem Laden).
func on_client_request(p: Player, kind: String, data: Array) -> void:
	match kind:
		"ready":
			net_send_full(p)
		"offer":
			if data.size() >= 2 and typeof(data[0]) == TYPE_STRING and typeof(data[1]) == TYPE_STRING:
				_resolve_offer(p, data[0], data[1])


## Vollständiger Zustand für einen Client (nach dem Laden oder Wiederbeitritt).
func net_send_full(p: Player) -> void:
	var spawns: Array = []
	for id in _enemy_ids:
		var e: Enemy = _enemy_ids[id]
		if is_instance_valid(e) and not e.dead:
			spawns.append(_spawn_desc(e))
	var chests: Array = _chests.map(func(c): return c["open"])
	var shrines: Array = _shrines.map(func(s): return s["state"])
	var pk: Array = []
	for k in _pickups:
		if k["owner"] == p:
			pk.append([k["id"], k["item"], k["pos"]])
	Net.run.ev("full", [run_time, spawns, chests, shrines, pk, objective_text()], p.net_peer)
	if not p.net_offers.is_empty():
		_send_offer(p)


# ------------------------------------------------------------------ Pause, Ende

func _toggle_pause() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_resume()
		return
	if not net_on:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_menu = PauseMenu.new()
	_ui_layer.add_child(_pause_menu)
	_pause_menu.resume.connect(_resume)
	_pause_menu.abort_run.connect(func():
		_resume()
		_finish(false))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _pause_menu != null and is_instance_valid(_pause_menu):
		_resume()


func _resume() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null
	SaveSystem.save_game()
	get_tree().paused = false
	if not RunState.bot_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Ergebnis für einen Spieler (persönliche Werte aus p.run_stats, Boss-Ergebnis gilt für das Team).
func build_result(victory: bool, p: Player = null) -> Dictionary:
	if p == null:
		p = player
	var rs: Dictionary = p.run_stats
	var names: Array = []
	for q in players:
		if is_instance_valid(q):
			names.append(q.display_name)
	return {
		"victory": victory and not p.is_down() and not p.permadown, "area_id": RunState.area_id, "boss_id": GameData.boss.get("id", "") if run_stats["boss_defeated"] else "",
		"boss_defeated": run_stats["boss_defeated"], "kills": rs["kills"], "elites": rs["elites"],
		"minibosses": rs["minibosses"], "level": p.level, "duration": run_time, "damage_dealt": rs["damage_dealt"],
		"damage_taken": rs["damage_taken"], "downs": rs["downs"], "chests": rs["chests"],
		"shrines": rs["shrines"], "items": rs["items"].duplicate(true), "skills": p.levels.duplicate(),
		"healing": rs["healing"], "revives": rs["revives"], "party": names,
		"team_kills": run_stats["kills"],
	}


func _finish(victory: bool) -> void:
	RunState.world_freeze = 0.0
	if finished:
		return
	finished = true
	var result := build_result(victory)
	RunState.finish_run(result)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			e.set_physics_process(false)
	if net_on:
		for p in players:
			if is_instance_valid(p) and p.net_role == "remote_sim" and not p.net_away:
				Net.run.ev("result", [build_result(victory, p), victory], p.net_peer)
	if _levelup_ui != null and is_instance_valid(_levelup_ui):
		_levelup_ui.queue_free()
	_result = ResultScreen.new()
	_ui_layer.add_child(_result)
	_result.show_result(result, RunState.last_summary)
	_result.continue_pressed.connect(func():
		if net_on:
			Net.run_finished()
		RunState.back_to_menu())
	if RunState.auto_quit:
		get_tree().create_timer(1.5 if net_on else 0.2).timeout.connect(func(): get_tree().quit(0))
