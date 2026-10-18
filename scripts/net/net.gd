extends Node
## Netzwerk-Schicht (Autoload "Net"): Lobby, Gruppe, Verbindungsverwaltung.
##
## Architektur (siehe docs/ARCHITEKTUR.md): Listen-Server über ENet. Der Host ist autoritativ für den Run
## (Gegner, Schaden, Beute, Level-Up-Angebote). Clients senden nur Eingaben und erhalten Snapshots.
## Der Host validiert beim Beitritt Name, Aussehen, Talente und Ausrüstung (ItemValidator).
## Lobby-Code = Adresse des Hosts (IPv4+Port, Base32). Kein Relay-Server: Internet-Spiel braucht Portfreigabe
## oder ein VPN (siehe README).

signal roster_changed
signal lobby_ended(reason: String)
signal join_failed(reason: String)
signal chat_received(sender: String, text: String)
signal joined_lobby
signal run_begin(area: String, diff: int, seed_value: int)
signal player_left_run(slot: int)
signal run_rejoined

const PROTOCOL := 4
const MAX_PLAYERS := 5
const DEFAULT_PORT := 24680
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const RECONNECT_GRACE := 90.0

var peer: ENetMultiplayerPeer = null
var players: Dictionary = {}         # peer_id -> öffentliche Spielerinfo
var builds: Dictionary = {}          # peer_id -> geprüfter Charakter-Build (nur Host)
var leader_id := 1
var area_id := "emerald_forest"
var difficulty := 1
var state := "offline"               # offline | joining | lobby | running
var my_token := ""
var host_ip := ""
var host_port := DEFAULT_PORT
var last_error := ""
var run_id := ""
var _slots_by_token: Dictionary = {} # token -> slot (Host, für Wiederbeitritt)
var _next_slot := 0
var _grace: Dictionary = {}          # slot -> verbleibende Sekunden bis Freigabe (Host, im Run)
var run: Node = null                 # NetRun (Kindknoten)
var trade: Node = null               # NetTrade (Kindknoten)
var run_seed := 0
var use_upnp := true                 # Tests schalten das ab
var upnp_status := ""                # Text für die Oberfläche
var external_ip := ""                # öffentliche Adresse, falls UPnP erfolgreich war
var _upnp: UPNP = null
var _upnp_thread: Thread = null
var _upnp_port := 0


func _ready() -> void:
	run = load("res://scripts/net/net_run.gd").new()
	run.name = "Run"
	add_child(run)
	trade = load("res://scripts/net/net_trade.gd").new()
	trade.name = "Trade"
	add_child(trade)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	for s in _grace.keys():
		_grace[s] -= delta
		if _grace[s] <= 0.0:
			_grace.erase(s)
			player_left_run.emit(s)


# ------------------------------------------------------------------ Abfragen

func in_lobby() -> bool:
	return state == "lobby" or state == "running"


func is_host() -> bool:
	return peer != null and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if peer != null else 1


func my_slot() -> int:
	return slot_of(my_id())


func is_leader() -> bool:
	return in_lobby() and my_id() == leader_id


func player_list() -> Array:
	var out: Array = players.values()
	out.sort_custom(func(a, b): return int(a["slot"]) < int(b["slot"]))
	return out


func slot_of(peer_id: int) -> int:
	return int(players[peer_id]["slot"]) if players.has(peer_id) else -1


func peer_of_slot(slot: int) -> int:
	for id in players:
		if int(players[id]["slot"]) == slot:
			return id
	return -1


# ------------------------------------------------------------------ Lobby-Code

static func encode_address(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var n := 0
	for p in parts:
		n = (n << 8) | clampi(int(p), 0, 255)
	n = (n << 16) | clampi(port, 0, 65535)
	var s := ""
	for i in 10:
		s = ALPHABET[(n >> (5 * i)) & 31] + s
	return s.substr(0, 5) + "-" + s.substr(5, 5)


## Gibt {"ip": String, "port": int} oder {} zurück. Akzeptiert Lobby-Code oder "ip[:port]".
static func parse_target(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {}
	if t.count(".") == 3 or t.begins_with("localhost"):
		var ip := t
		var port := DEFAULT_PORT
		if ":" in t:
			ip = t.get_slice(":", 0)
			port = int(t.get_slice(":", 1))
		if ip == "localhost":
			ip = "127.0.0.1"
		if ip.split(".").size() != 4 or port < 1 or port > 65535:
			return {}
		return {"ip": ip, "port": port}
	var code := t.replace("-", "").replace(" ", "").to_upper()
	if code.length() != 10:
		return {}
	var n := 0
	for ch in code:
		var idx := ALPHABET.find(ch)
		if idx < 0:
			return {}
		n = (n << 5) | idx
	var port := n & 0xFFFF
	var ipn := n >> 16
	if ipn > 0xFFFFFFFF or port == 0:
		return {}
	return {"ip": "%d.%d.%d.%d" % [(ipn >> 24) & 255, (ipn >> 16) & 255, (ipn >> 8) & 255, ipn & 255], "port": port}


static func local_ip() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
		if best == "":
			best = a
	return best if best != "" else "127.0.0.1"


## Code für Mitspieler im Internet (öffentliche Adresse, wenn die Portfreigabe geklappt hat).
func lobby_code() -> String:
	return encode_address(host_ip if host_ip != "" else local_ip(), host_port)


## Code für Mitspieler im selben Netzwerk (WLAN/LAN).
func lan_code() -> String:
	return encode_address(local_ip(), host_port)


# ------------------------------------------------------------------ Automatische Portfreigabe (UPnP)

func _start_upnp(port: int) -> void:
	if not use_upnp or _upnp_thread != null:
		return
	upnp_status = "Suche Router (UPnP) …"
	_upnp_port = port
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker.bind(port))


func _upnp_worker(port: int) -> void:
	var u := UPNP.new()
	var msg := ""
	var ext := ""
	var ok := false
	if u.discover(2000, 2, "InternetGatewayDevice") != OK or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		msg = "Kein UPnP-Router gefunden. Mitspieler außerhalb deines Netzwerks brauchen eine Portfreigabe (UDP %d) oder ein VPN." % port
	elif u.add_port_mapping(port, port, "Aethermark", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		msg = "Der Router hat die automatische Portfreigabe abgelehnt (UDP %d manuell freigeben oder VPN nutzen)." % port
	else:
		ext = u.query_external_address()
		ok = ext != ""
		msg = "Portfreigabe aktiv – dein Code funktioniert im Internet." if ok else "Portfreigabe aktiv, aber die öffentliche Adresse ist unbekannt."
	call_deferred("_upnp_done", ok, ext, msg, u)


func _upnp_done(ok: bool, ext: String, msg: String, u: UPNP) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	upnp_status = msg
	if peer == null or not is_host():
		if ok and u != null:
			u.delete_port_mapping(_upnp_port, "UDP")
		return
	_upnp = u if ok else null
	if ok:
		external_ip = ext
		host_ip = ext
	roster_changed.emit()


func _stop_upnp() -> void:
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null
	external_ip = ""
	upnp_status = ""


func _exit_tree() -> void:
	_stop_upnp()
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()


# ------------------------------------------------------------------ Aufbau / Abbau

func local_info() -> Dictionary:
	var c := SaveSystem.active_character()
	var w := "sword"
	var eq: Dictionary = c.get("equipment", {})
	if eq.has("weapon"):
		w = SaveSystem.find_item(c, eq["weapon"]).get("weapon_type", "sword")
	var st := Stats.compute(c)
	return {"name": c.get("name", "Spieler"), "title": c.get("title", "Wanderer"), "level": int(c.get("meta_level", 1)),
			"appearance": c.get("appearance", SaveSystem.default_appearance()), "weapon": w, "ready": false,
			"power": snappedf(sqrt((st["damage"] / 10.0) * (st["max_hp"] / 100.0)), 0.01)}


## Vollständiger Build für den Host (Talente + angelegte Ausrüstung), wird dort geprüft.
func local_build() -> Dictionary:
	var c := SaveSystem.active_character()
	var items: Array = []
	for slot in c.get("equipment", {}):
		var it := SaveSystem.find_item(c, c["equipment"][slot])
		if not it.is_empty():
			items.append(it.duplicate(true))
	return {"talents": c.get("talents", []).duplicate(), "items": items, "equipment": c.get("equipment", {}).duplicate(),
			"meta_level": int(c.get("meta_level", 1)), "name": c.get("name", "Spieler"), "appearance": c.get("appearance", {}),
			"title": c.get("title", "Wanderer")}


func host_lobby(port: int = DEFAULT_PORT) -> int:
	if peer != null:
		return ERR_ALREADY_IN_USE
	if not SaveSystem.has_character():
		last_error = "Erstelle zuerst einen Charakter."
		return ERR_UNCONFIGURED
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "Der Port %d ist nicht verfügbar (läuft schon eine Gruppe?)." % port
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	host_port = port
	host_ip = local_ip()
	players.clear()
	builds.clear()
	_slots_by_token.clear()
	_next_slot = 0
	var info := local_info()
	info["id"] = 1
	info["slot"] = _alloc_slot("host")
	info["ready"] = true
	info["connected"] = true
	players[1] = info
	builds[1] = _checked_build(local_build())
	leader_id = 1
	area_id = "emerald_forest"
	difficulty = 1
	state = "lobby"
	run_id = ""
	roster_changed.emit()
	joined_lobby.emit()
	_start_upnp(port)
	return OK


func join_lobby(target_text: String) -> int:
	if peer != null:
		return ERR_ALREADY_IN_USE
	var t := parse_target(target_text)
	if t.is_empty():
		last_error = "Ungültiger Code oder ungültige Adresse."
		join_failed.emit(last_error)
		return ERR_INVALID_PARAMETER
	if not SaveSystem.has_character():
		last_error = "Erstelle zuerst einen Charakter."
		join_failed.emit(last_error)
		return ERR_UNCONFIGURED
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(t["ip"], t["port"])
	if err != OK:
		peer = null
		last_error = "Verbindung konnte nicht gestartet werden."
		join_failed.emit(last_error)
		return err
	multiplayer.multiplayer_peer = peer
	host_ip = t["ip"]
	host_port = t["port"]
	state = "joining"
	if my_token == "":
		my_token = "%d%d%d" % [Time.get_ticks_usec(), randi(), randi()]
	SaveSystem.data["settings"]["last_address"] = target_text.strip_edges()
	return OK


func leave(reason: String = "") -> void:
	var was := state
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	run.call("reset")
	_stop_upnp()
	players.clear()
	builds.clear()
	_slots_by_token.clear()
	_grace.clear()
	state = "offline"
	leader_id = 1
	if was != "offline":
		lobby_ended.emit(reason)
		roster_changed.emit()


func _alloc_slot(token: String) -> int:
	if _slots_by_token.has(token):
		return _slots_by_token[token]
	var used: Array = _slots_by_token.values()
	for s in MAX_PLAYERS:
		if not (s in used):
			_slots_by_token[token] = s
			return s
	return -1


# ------------------------------------------------------------------ Verbindungsereignisse

func _on_peer_connected(id: int) -> void:
	pass   # Der Client meldet sich mit _hello; erst danach gehört er zur Gruppe.


func _on_connected() -> void:
	var build := local_build()
	rpc_id(1, "_hello", PROTOCOL, my_token, local_info(), build)


func _on_connection_failed() -> void:
	var was_joining := state == "joining"
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	state = "offline"
	last_error = "Keine Verbindung zum Host (Adresse, Portfreigabe oder Firewall prüfen)."
	if was_joining:
		join_failed.emit(last_error)


func _on_server_disconnected() -> void:
	leave("Der Host hat die Verbindung beendet.")


func _on_peer_disconnected(id: int) -> void:
	if not is_host() or not players.has(id):
		return
	var info: Dictionary = players[id]
	if state == "running" and run.call("has_slot", int(info["slot"])):
		# Im Run: Platz und Spielfigur bleiben für den Wiederbeitritt reserviert
		info["connected"] = false
		_grace[int(info["slot"])] = RECONNECT_GRACE
		run.call("on_peer_lost", int(info["slot"]))
		_broadcast_roster()
	else:
		var slot := int(info["slot"])
		players.erase(id)
		builds.erase(id)
		for t in _slots_by_token.keys():
			if _slots_by_token[t] == slot:
				_slots_by_token.erase(t)
		if leader_id == id:
			leader_id = 1
		_broadcast_roster()


# ------------------------------------------------------------------ Beitritt (Host)

@rpc("any_peer", "reliable")
func _hello(protocol: int, token: String, info: Dictionary, build: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_reject(id, "Falsche Spielversion (Host: %d, du: %d)." % [PROTOCOL, protocol])
		return
	var clean := _sanitize_info(info)
	var chk := _checked_build(build)
	if chk.is_empty():
		_reject(id, "Dein Charakter wurde vom Host nicht akzeptiert (ungültige Talente oder Ausrüstung).")
		return
	# Wiederbeitritt: gleicher Token, Platz im laufenden Run reserviert
	if token != "" and _slots_by_token.has(token):
		var slot: int = _slots_by_token[token]
		var old_id := peer_of_slot(slot)
		if old_id != -1 and players[old_id].get("connected", true):
			_reject(id, "Dieser Platz ist bereits belegt.")
			return
		if old_id != -1:
			players.erase(old_id)
			builds.erase(old_id)
		clean["slot"] = slot
		clean["id"] = id
		clean["connected"] = true
		clean["ready"] = true
		players[id] = clean
		builds[id] = chk
		_grace.erase(slot)
		if leader_id == old_id:
			leader_id = id
		_broadcast_roster()
		rpc_id(id, "_accepted", id, int(clean["slot"]))
		if state == "running":
			rpc_id(id, "_begin_run", area_id, difficulty, run_seed, run_id)
			run.call("on_rejoin", slot, id)
		return
	if state == "running":
		_reject(id, "Der Run läuft bereits.")
		return
	if players.size() >= MAX_PLAYERS:
		_reject(id, "Die Gruppe ist voll (5/5).")
		return
	var slot := _alloc_slot(token if token != "" else "anon%d" % id)
	if slot < 0:
		_reject(id, "Die Gruppe ist voll (5/5).")
		return
	clean["slot"] = slot
	clean["id"] = id
	clean["connected"] = true
	clean["ready"] = false
	players[id] = clean
	builds[id] = chk
	_broadcast_roster()
	rpc_id(id, "_accepted", id, slot)


func _reject(id: int, reason: String) -> void:
	rpc_id(id, "_rejected", reason)
	get_tree().create_timer(0.4).timeout.connect(func():
		if peer != null and is_host():
			peer.disconnect_peer(id))


func _sanitize_info(info: Dictionary) -> Dictionary:
	var nm := str(info.get("name", "Spieler")).strip_edges()
	if SaveSystem.validate_name(nm) != "":
		nm = "Spieler"
	var app: Dictionary = SaveSystem.default_appearance()
	var given: Dictionary = info.get("appearance", {})
	for k in app:
		if given.has(k) and typeof(given[k]) == typeof(app[k]):
			app[k] = given[k]
		elif given.has(k) and typeof(app[k]) == TYPE_FLOAT and typeof(given[k]) == TYPE_INT:
			app[k] = float(given[k])
	for k in ["skin", "hair_color", "eye_color", "accent"]:
		if not str(app[k]).is_valid_html_color():
			app[k] = SaveSystem.default_appearance()[k]
	if not GameData.origins.has(app["origin"]):
		app["origin"] = "human"
	app["body_height"] = clampf(float(app["body_height"]), 0.85, 1.15)
	app["body_build"] = clampf(float(app["body_build"]), 0.8, 1.2)
	var w := str(info.get("weapon", "sword"))
	if not GameData.items_cfg["weapon_types"].has(w):
		w = "sword"
	return {"name": nm, "title": str(info.get("title", "Wanderer")).left(24), "level": clampi(int(info.get("level", 1)), 1, 999),
			"appearance": app, "weapon": w, "power": clampf(float(info.get("power", 1.0)), 0.3, 5.0)}


## Prüft den Build eines Spielers; gibt {} bei Manipulation zurück, sonst den bereinigten Build.
func _checked_build(b: Dictionary) -> Dictionary:
	if typeof(b.get("talents", null)) != TYPE_ARRAY or typeof(b.get("items", null)) != TYPE_ARRAY:
		return {}
	if b["items"].size() > 12 or b["talents"].size() > 120:
		return {}
	var err := ItemValidator.validate_talents(b["talents"])
	if err != "":
		push_warning("Build abgelehnt: " + err)
		return {}
	var meta := clampi(int(b.get("meta_level", 1)), 1, 999)
	if TalentTree.spent_points(b["talents"]) > ItemValidator.max_talent_points(meta):
		push_warning("Build abgelehnt: zu viele Talentpunkte")
		return {}
	var seen := {}
	for it in b["items"]:
		if typeof(it) != TYPE_DICTIONARY:
			return {}
		var e := ItemValidator.validate(it)
		if e != "":
			push_warning("Build abgelehnt: %s (%s)" % [e, str(it.get("name", "?"))])
			return {}
		if seen.has(it["uid"]):
			return {}
		seen[it["uid"]] = true
	var eq: Dictionary = {}
	for s in b.get("equipment", {}):
		if GameData.items_cfg["slots"].has(s) and seen.has(b["equipment"][s]):
			eq[s] = b["equipment"][s]
	return {"talents": b["talents"].duplicate(), "items": b["items"].duplicate(true), "equipment": eq, "meta_level": meta,
			"name": str(b.get("name", "Spieler")).left(16), "appearance": b.get("appearance", {}), "title": str(b.get("title", "Wanderer")).left(24)}


## Baut aus einem geprüften Build ein Charakter-Dictionary (nur im Speicher, wird nie gespeichert).
func character_from_build(b: Dictionary) -> Dictionary:
	return {"name": b["name"], "appearance": b["appearance"], "meta_level": b["meta_level"], "talents": b["talents"],
			"inventory": b["items"], "equipment": b["equipment"], "title": b.get("title", "Wanderer"), "stats": SaveSystem.default_stats()}


@rpc("authority", "reliable")
func _accepted(my_peer_id: int, slot: int) -> void:
	state = "lobby"
	joined_lobby.emit()


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	last_error = reason
	var was_joining := state == "joining"
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	state = "offline"
	players.clear()
	if was_joining:
		join_failed.emit(reason)
	else:
		lobby_ended.emit(reason)


# ------------------------------------------------------------------ Roster

func _broadcast_roster() -> void:
	var pub := {}
	for id in players:
		pub[id] = players[id]
	_apply_roster(pub, leader_id, area_id, difficulty, state)
	for id in players:
		if id != 1 and players[id].get("connected", true):
			rpc_id(id, "_roster", pub, leader_id, area_id, difficulty, state)


@rpc("authority", "reliable")
func _roster(pub: Dictionary, leader: int, area: String, diff: int, st: String) -> void:
	_apply_roster(pub, leader, area, diff, st)


func _apply_roster(pub: Dictionary, leader: int, area: String, diff: int, st: String) -> void:
	players = pub
	leader_id = leader
	area_id = area
	difficulty = diff
	if not is_host() and state != "joining" and state != "offline":
		state = st
	roster_changed.emit()


func set_ready(on: bool) -> void:
	if not in_lobby():
		return
	if is_host():
		players[1]["ready"] = true
		_broadcast_roster()
	else:
		rpc_id(1, "_set_ready", on)


@rpc("any_peer", "reliable")
func _set_ready(on: bool) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and state == "lobby":
		players[id]["ready"] = on
		_broadcast_roster()


## Nur der Gruppenleiter darf Ziel und Schwierigkeit ändern.
func set_lobby_settings(area: String, diff: int) -> void:
	if is_host():
		_apply_settings(1, area, diff)
	else:
		rpc_id(1, "_leader_settings", area, diff)


@rpc("any_peer", "reliable")
func _leader_settings(area: String, diff: int) -> void:
	if is_host():
		_apply_settings(multiplayer.get_remote_sender_id(), area, diff)


func _apply_settings(sender: int, area: String, diff: int) -> void:
	if sender != leader_id or state != "lobby":
		return
	if GameData.area_by_id(area).is_empty():
		return
	area_id = area
	difficulty = clampi(diff, 1, 4)
	for id in players:
		if id != 1:
			players[id]["ready"] = false   # Einstellungen geändert -> alle müssen neu bestätigen
	_broadcast_roster()


func promote_leader(id: int) -> void:
	if is_host() and players.has(id) and state == "lobby":
		leader_id = id
		_broadcast_roster()


func kick(id: int) -> void:
	if is_host():
		if id != 1 and players.has(id):
			rpc_id(id, "_rejected", "Du wurdest aus der Gruppe entfernt.")
			get_tree().create_timer(0.3).timeout.connect(func(): if peer != null: peer.disconnect_peer(id))
	elif my_id() == leader_id:
		rpc_id(1, "_kick_request", id)


@rpc("any_peer", "reliable")
func _kick_request(id: int) -> void:
	if is_host() and multiplayer.get_remote_sender_id() == leader_id and id != 1:
		kick(id)


func send_chat(text: String) -> void:
	var t := text.strip_edges().left(200)
	if t == "" or not in_lobby():
		return
	if is_host():
		_broadcast_chat(1, t)
	else:
		rpc_id(1, "_chat_in", t)


@rpc("any_peer", "reliable")
func _chat_in(t: String) -> void:
	if is_host():
		_broadcast_chat(multiplayer.get_remote_sender_id(), t.left(200))


func _broadcast_chat(sender: int, t: String) -> void:
	var nm: String = players.get(sender, {}).get("name", "?")
	chat_received.emit(nm, t)
	for id in players:
		if id != 1 and players[id].get("connected", true):
			rpc_id(id, "_chat_out", nm, t)


@rpc("authority", "reliable")
func _chat_out(nm: String, t: String) -> void:
	chat_received.emit(nm, t)


# ------------------------------------------------------------------ Run starten

func all_ready() -> bool:
	for id in players:
		if id != leader_id and not players[id].get("ready", false):
			return false
	return true


func host_start_run(area: String, diff: int) -> void:
	## Wird vom Gruppenleiter-Knopf aufgerufen (Leiter = Host oder Client).
	if is_host():
		_do_start(1, area, diff)
	elif is_leader():
		rpc_id(1, "_start_request", area, diff)


@rpc("any_peer", "reliable")
func _start_request(area: String, diff: int) -> void:
	if is_host():
		_do_start(multiplayer.get_remote_sender_id(), area, diff)


func _do_start(sender: int, area: String, diff: int) -> void:
	if sender != leader_id or state != "lobby" or not all_ready():
		return
	if GameData.area_by_id(area).is_empty() or not GameData.area_by_id(area).get("playable", false):
		return
	area_id = area
	difficulty = clampi(diff, 1, 4)
	var seed_value := randi()
	run_seed = seed_value
	run_id = "run%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	state = "running"
	_broadcast_roster()
	run.call("host_prepare", seed_value)
	for id in players:
		if id != 1:
			rpc_id(id, "_begin_run", area_id, difficulty, seed_value, run_id)
	_enter_run(seed_value)


@rpc("authority", "reliable")
func _begin_run(area: String, diff: int, seed_value: int, rid: String) -> void:
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("client_arena.tscn"):
		# Wiederbeitritt, während die Run-Szene noch geladen ist: Szene bleibt, ClientArena holt sich den Stand neu.
		area_id = area
		difficulty = diff
		run_id = rid
		state = "running"
		run_rejoined.emit()
		return
	area_id = area
	difficulty = diff
	run_id = rid
	state = "running"
	_enter_run(seed_value)


func _enter_run(seed_value: int) -> void:
	RunState.area_id = area_id
	RunState.difficulty = difficulty
	RunState.seed_value = seed_value
	RunState.party_size = players.size()
	RunState.quick_mode = RunState.test_quick
	run_begin.emit(area_id, difficulty, seed_value)
	get_tree().paused = false
	if is_host():
		get_tree().change_scene_to_file("res://scenes/arena.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/client_arena.tscn")


## Nach dem Run zurück in die Lobby (Gruppe bleibt bestehen).
func run_finished() -> void:
	if state == "running":
		state = "lobby"
		for id in players:
			players[id]["ready"] = (id == 1)
		if is_host():
			_grace.clear()
			_broadcast_roster()
