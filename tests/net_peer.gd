extends Node
## Mehrprozess-Test für den Koop-Lauf (Host oder Client in einem eigenen Prozess, Bots spielen).
## Start über tests/run_net_test.py (startet Host + Clients, wertet Logs aus). Einzeln:
##   godot --headless --path . res://tests/net_peer.tscn -- role=host total=3 port=24777
##   godot --headless --path . res://tests/net_peer.tscn -- role=client name=Bea weapon=bow port=24777
## Weitere Optionen: token=<text> (Wiederbeitritt), drop_at=<Run-Sekunden> (Client verlässt die Gruppe und beendet sich),
## down_at=<Run-Sekunden> (Host schickt den ersten Mitspieler zu Boden), scale=<Zeitraffer>.

var cfg := {"role": "host", "total": "2", "port": "24777", "name": "Host", "weapon": "sword", "token": "", "drop_at": "-1",
		"down_at": "-1", "scale": "2.0", "seed": "4242"}
var mon: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			cfg[a.get_slice("=", 0)] = a.get_slice("=", 1)
	Net.use_upnp = false
	SaveSystem.save_path = "user://nettest_%s.json" % cfg["name"]
	if not (cfg["role"] == "client" and cfg["token"] != "" and SaveSystem.load_game() and SaveSystem.has_character()):
		for suf in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(SaveSystem.save_path + suf):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.save_path + suf))
		SaveSystem.data = SaveSystem.default_data()
		var c := SaveSystem.new_character(cfg["name"], SaveSystem.default_appearance())
		_give_weapon(c, cfg["weapon"])
	RunState.bot_mode = true
	RunState.bot_damage_scale = 0.12
	RunState.test_quick = true
	RunState.auto_quit = true
	Engine.time_scale = float(cfg["scale"])
	if cfg["token"] != "":
		Net.my_token = cfg["token"]
	# Der Monitor überlebt den Szenenwechsel (Kind von root)
	mon = NetMonitor.new()
	mon.cfg = cfg
	get_tree().root.add_child.call_deferred(mon)
	print("NETPEER start: ", cfg)
	if cfg["role"] == "host":
		var err := Net.host_lobby(int(cfg["port"]))
		print("NETPEER host_lobby=", err)
	else:
		Net.joined_lobby.connect(func(): Net.set_ready(true))
		Net.join_failed.connect(func(r): printerr("NETPEER join_failed: ", r))
		print("NETPEER join=", Net.join_lobby("127.0.0.1:%s" % cfg["port"]))


func _give_weapon(c: Dictionary, weapon: String) -> void:
	if weapon == "sword":
		return
	for b in GameData.items_cfg["bases"]:
		if b["slot"] == "weapon" and b.get("weapon_type", "") == weapon:
			var r := RandomNumberGenerator.new()
			r.seed = hash(cfg["name"])
			var it := Loot.build_item(r, b, "uncommon", 1)
			c["inventory"].append(it)
			SaveSystem.equip(c, it["uid"])
			return


class NetMonitor extends Node:
	var cfg: Dictionary
	var _t := 0.0
	var _log_t := 0.0
	var _started := false
	var _max_ghosts := 0
	var _max_puppets := 0
	var _max_pickups := 0
	var _forced_down := false
	var _dropped := false
	var _victim: Player = null
	var _victim_downs := 0
	var _revives := 0
	var _start_wait := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var scene := get_tree().current_scene
		if cfg["role"] == "host":
			_host(scene, delta)
		else:
			_client(scene, delta)

	func _host(scene: Node, delta: float) -> void:
		if scene is Arena:
			var a: Arena = scene
			if not _started:
				_started = true
				print("NETPEER host run started, net_on=", a.net_on, " players=", a.players.size())
			_log_t += delta
			if _log_t >= 1.0 and not a.finished:
				_log_t = 0.0
				print("NETSAMPLE %d %d" % [int(a.run_time), get_tree().get_nodes_in_group("enemies").size()])
			if a.net_on and int(cfg["down_at"]) >= 0 and not _forced_down and a.run_time >= float(cfg["down_at"]) and a.players.size() > 1:
				_forced_down = true
				_victim = a.players[1]
				_victim.take_damage(99999.0, _victim.global_position)
				print("NETPEER forced down: ", _victim.display_name, " state=", _victim.state)
			if _victim != null and is_instance_valid(_victim):
				_revives = 0
				for p in a.players:
					if is_instance_valid(p):
						_revives += int(p.run_stats["revives"])
			if a.finished:
				_report_host(a)
		else:
			_start_wait += delta
			if not _started and Net.state == "lobby" and Net.players.size() >= int(cfg["total"]) and Net.all_ready():
				print("NETPEER host starting run with ", Net.players.size(), " players")
				_started = true
				Net.host_start_run("emerald_forest", 1)
			if _start_wait > 60.0 and not _started:
				printerr("NETPEER FEHLER: Lobby wurde nicht voll (", Net.players.size(), ")")
				get_tree().quit(2)

	func _report_host(a: Arena) -> void:
		set_process(false)
		var ok := true
		var lines: Array = []
		var s: Dictionary = Net.run.stats
		lines.append("snaps=%d events=%d rejected=%d bytes=%d" % [s["snaps"], s["events"], s["rejected"], s["snap_bytes"]])
		for p in a.players:
			if is_instance_valid(p):
				var rs: Dictionary = p.run_stats
				lines.append("player %s role=%s lvl=%d kills=%d dmg=%d downs=%d revives=%d items=%d" % [p.display_name, p.net_role, p.level,
						rs["kills"], int(rs["damage_dealt"]), rs["downs"], rs["revives"], rs["items"].size()])
				if p.net_role == "remote_sim" and (p.level < 2 or rs["damage_dealt"] <= 0.0):
					ok = false
					lines.append("  FEHLER: Remote-Spieler %s hat nichts bewirkt" % p.display_name)
		if a.run_stats["kills"] < 20:
			ok = false
			lines.append("FEHLER: zu wenige Kills")
		if not a.run_stats["boss_defeated"]:
			ok = false
			lines.append("FEHLER: Boss nicht besiegt")
		if s["snaps"] < 100:
			ok = false
			lines.append("FEHLER: zu wenige Snapshots")
		if int(cfg["down_at"]) >= 0:
			if _victim == null or _victim.run_stats["downs"] < 1:
				ok = false
				lines.append("FEHLER: erzwungene Kampfunfähigkeit nicht eingetreten")
			elif _revives < 1 and not _victim.permadown:
				ok = false
				lines.append("FEHLER: kein Wiederbelebungsversuch erfolgreich")
		for l in lines:
			print("NETREPORT ", l)
		print("NETRESULT host ", "OK" if ok else "FEHLER")
		# kurz warten, damit die Ergebnisse die Clients erreichen (Arena beendet den Prozess selbst)
		if not ok:
			get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(1))

	func _client(scene: Node, delta: float) -> void:
		if scene is ClientArena:
			var c: ClientArena = scene
			if not _started:
				_started = true
				print("NETPEER client in run, slot=", c._my_slot)
			_max_ghosts = maxi(_max_ghosts, c.enemies.size())
			_max_puppets = maxi(_max_puppets, c.puppets.size())
			_max_pickups = maxi(_max_pickups, c.pickups.size())
			_log_t += delta
			if _log_t >= 1.0 and not c.finished:
				_log_t = 0.0
				print("NETSAMPLE %d %d" % [int(c.run_time), c.enemies.size()])
			if int(cfg["drop_at"]) >= 0 and not _dropped and c.run_time >= float(cfg["drop_at"]):
				_dropped = true
				print("NETPEER client dropping at run_time ", int(c.run_time))
				Net.leave("Test: Verbindung getrennt")
				get_tree().quit(77)
				return
			if c.finished:
				set_process(false)
				var ok := true
				var res := RunState.last_result
				print("NETREPORT client ghosts=%d puppets=%d pickups=%d level=%d kills=%d items=%d victory=%s" % [_max_ghosts,
						_max_puppets, _max_pickups, c.player.level, res.get("kills", -1), res.get("items", []).size(), str(res.get("victory"))])
				if _max_puppets < int(cfg["total"]) - 1:
					ok = false
					printerr("NETREPORT FEHLER: zu wenige Mitspieler sichtbar")
				if _max_ghosts < 3:
					ok = false
					printerr("NETREPORT FEHLER: kaum Gegner synchronisiert")
				if res.get("damage_dealt", 0.0) <= 0.0:
					ok = false
					printerr("NETREPORT FEHLER: kein Schaden im Ergebnis")
				print("NETRESULT client ", cfg["name"], " ", "OK" if ok else "FEHLER")
				get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit(0 if ok else 1))
		elif _t > 120.0 and not _started:
			printerr("NETPEER FEHLER: Run hat nicht begonnen")
			get_tree().quit(2)
