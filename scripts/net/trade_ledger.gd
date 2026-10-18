class_name TradeLedger
extends RefCounted
## Host-seitige Handelslogik (rein datenbasiert, ohne Netzwerk -> testbar).
##
## Regeln: Nur Gegenstände, die handelbar und nicht gesperrt sind. Jeder Gegenstand darf zur selben Zeit nur in
## EINEM Handel liegen. Ändert sich ein Angebot, verfallen beide Bestätigungen. Der Abschluss ist atomar:
## Beide Seiten bekommen dieselbe Transaktion (tx_id); Clients wenden sie idempotent an (doppeltes Anwenden ist wirkungslos).

const MAX_ITEMS := 8

var trades: Dictionary = {}       # id -> Handel
var uid_locks: Dictionary = {}    # uid -> Handels-ID
var owner_of: Dictionary = {}     # uid -> Peer, dem der Gegenstand nach einem Handel gehört
var pending: Dictionary = {}      # tx_id -> {peers: {peer: bool(acked)}, msgs: {peer: Dictionary}}
var _next := 1


func trade_of(peer: int) -> int:
	for id in trades:
		var t: Dictionary = trades[id]
		if t["a"]["peer"] == peer or t["b"]["peer"] == peer:
			return id
	return -1


func request(a: int, b: int) -> int:
	if a == b or trade_of(a) != -1 or trade_of(b) != -1:
		return -1
	var id := _next
	_next += 1
	trades[id] = {"id": id, "status": "requested", "a": _side(a), "b": _side(b)}
	return id


func _side(peer: int) -> Dictionary:
	return {"peer": peer, "offer": [], "confirmed": false}


func _side_of(t: Dictionary, peer: int) -> String:
	if t["a"]["peer"] == peer:
		return "a"
	if t["b"]["peer"] == peer:
		return "b"
	return ""


func accept(id: int, peer: int) -> bool:
	var t: Dictionary = trades.get(id, {})
	if t.is_empty() or t["status"] != "requested" or t["b"]["peer"] != peer:
		return false
	t["status"] = "open"
	return true


func set_offer(id: int, peer: int, items: Array) -> String:
	var t: Dictionary = trades.get(id, {})
	if t.is_empty() or t["status"] != "open":
		return "Kein offener Handel."
	var side := _side_of(t, peer)
	if side == "":
		return "Nicht beteiligt."
	if items.size() > MAX_ITEMS:
		return "Höchstens %d Gegenstände." % MAX_ITEMS
	var seen := {}
	for it in items:
		if typeof(it) != TYPE_DICTIONARY:
			return "Ungültiger Gegenstand."
		var err := ItemValidator.validate(it)
		if err != "":
			return "Gegenstand abgelehnt: " + err
		if not it.get("tradable", false) or it.get("locked", false):
			return "%s ist nicht handelbar." % it["name"]
		var uid: String = it["uid"]
		if seen.has(uid):
			return "Doppelter Gegenstand."
		seen[uid] = true
		if uid_locks.has(uid) and uid_locks[uid] != id:
			return "%s liegt schon in einem anderen Handel." % it["name"]
		if owner_of.has(uid) and owner_of[uid] != peer:
			return "%s gehört dir nicht." % it["name"]
	# alte Sperren dieses Angebots lösen, neue setzen
	for old in t[side]["offer"]:
		uid_locks.erase(old["uid"])
	t[side]["offer"] = items.duplicate(true)
	for it in items:
		uid_locks[it["uid"]] = id
	t["a"]["confirmed"] = false
	t["b"]["confirmed"] = false
	return ""


func confirm(id: int, peer: int, on: bool) -> bool:
	## Gibt true zurück, wenn jetzt beide bestätigt haben.
	var t: Dictionary = trades.get(id, {})
	if t.is_empty() or t["status"] != "open":
		return false
	var side := _side_of(t, peer)
	if side == "":
		return false
	t[side]["confirmed"] = on
	return t["a"]["confirmed"] and t["b"]["confirmed"]


func cancel(id: int) -> void:
	var t: Dictionary = trades.get(id, {})
	if t.is_empty():
		return
	for s in ["a", "b"]:
		for it in t[s]["offer"]:
			uid_locks.erase(it["uid"])
	trades.erase(id)


## Schließt den Handel ab und liefert die Transaktion für beide Seiten.
func commit(id: int) -> Dictionary:
	var t: Dictionary = trades.get(id, {})
	if t.is_empty() or t["status"] != "open" or not (t["a"]["confirmed"] and t["b"]["confirmed"]):
		return {}
	var tx := "tx%d_%d" % [id, Time.get_ticks_usec()]
	var a: Dictionary = t["a"]
	var b: Dictionary = t["b"]
	var msg_a := {"tx": tx, "give": _uids(a["offer"]), "receive": b["offer"].duplicate(true)}
	var msg_b := {"tx": tx, "give": _uids(b["offer"]), "receive": a["offer"].duplicate(true)}
	for it in a["offer"]:
		owner_of[it["uid"]] = b["peer"]
		uid_locks.erase(it["uid"])
	for it in b["offer"]:
		owner_of[it["uid"]] = a["peer"]
		uid_locks.erase(it["uid"])
	pending[tx] = {"acked": {a["peer"]: false, b["peer"]: false}, "msgs": {a["peer"]: msg_a, b["peer"]: msg_b}}
	trades.erase(id)
	return {"tx": tx, a["peer"]: msg_a, b["peer"]: msg_b}


func ack(tx: String, peer: int) -> void:
	if pending.has(tx) and pending[tx]["acked"].has(peer):
		pending[tx]["acked"][peer] = true
		var all := true
		for p in pending[tx]["acked"]:
			all = all and pending[tx]["acked"][p]
		if all:
			pending.erase(tx)


func unacked_for(peer: int) -> Array:
	var out: Array = []
	for tx in pending:
		if pending[tx]["acked"].has(peer) and not pending[tx]["acked"][peer]:
			out.append(pending[tx]["msgs"][peer])
	return out


## Wechselt die Peer-ID (Wiederbeitritt) in allen laufenden Vorgängen.
func rename_peer(old_id: int, new_id: int) -> void:
	for tx in pending:
		var p: Dictionary = pending[tx]
		if p["acked"].has(old_id):
			p["acked"][new_id] = p["acked"][old_id]
			p["acked"].erase(old_id)
			p["msgs"][new_id] = p["msgs"][old_id]
			p["msgs"].erase(old_id)
	for uid in owner_of:
		if owner_of[uid] == old_id:
			owner_of[uid] = new_id


func _uids(items: Array) -> Array:
	var out: Array = []
	for it in items:
		out.append(it["uid"])
	return out


func snapshot(id: int) -> Dictionary:
	return trades.get(id, {}).duplicate(true)


## Wendet eine Transaktion auf einen Charakter an (Client-Seite, idempotent). Gibt true zurück, wenn angewendet.
static func apply_to_character(c: Dictionary, msg: Dictionary) -> bool:
	var applied: Array = c.get("applied_tx", [])
	if msg["tx"] in applied:
		return false   # schon angewendet (z. B. Wiederholung nach Wiederbeitritt)
	for uid in msg["give"]:
		SaveSystem.remove_item(c, uid)
	for it in msg["receive"]:
		var exists := false
		for have in c["inventory"]:
			if have["uid"] == it["uid"]:
				exists = true
		if not exists:
			var copy: Dictionary = it.duplicate(true)
			copy["locked"] = false
			c["inventory"].append(copy)   # bewusst ohne Kapazitätsgrenze: Gegenstände dürfen nie verloren gehen
	applied.append(msg["tx"])
	if applied.size() > 60:
		applied = applied.slice(applied.size() - 60)
	c["applied_tx"] = applied
	return true
