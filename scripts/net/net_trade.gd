extends Node
## Handel zwischen Gruppenmitgliedern (Netzwerk-Glue um TradeLedger). Der Host vermittelt und prüft,
## die Clients halten ihr Inventar lokal und wenden Transaktionen idempotent an.

signal state_changed(snapshot: Dictionary)   # aktueller Handel (leer = keiner)
signal request_received(from_name: String, trade_id: int)
signal message(text: String)

var ledger := TradeLedger.new()       # nur Host
var current: Dictionary = {}          # Handelsansicht dieses Spielers


func _net() -> Node:
	return get_parent()


func reset() -> void:
	ledger = TradeLedger.new()
	current = {}
	state_changed.emit(current)


# ------------------------------------------------------------------ Client-Aktionen

func request_trade(partner_peer: int) -> void:
	if _net().is_host():
		_on_request(1, partner_peer)
	else:
		rpc_id(1, "_request", partner_peer)


func answer(trade_id: int, accept_it: bool) -> void:
	if _net().is_host():
		_on_answer(1, trade_id, accept_it)
	else:
		rpc_id(1, "_answer", trade_id, accept_it)


func set_offer(items: Array) -> void:
	if current.is_empty():
		return
	if _net().is_host():
		_on_offer(1, items)
	else:
		rpc_id(1, "_offer", items)


func confirm(on: bool) -> void:
	if current.is_empty():
		return
	if _net().is_host():
		_on_confirm(1, on)
	else:
		rpc_id(1, "_confirm", on)


func cancel() -> void:
	if current.is_empty():
		return
	if _net().is_host():
		_on_cancel(1)
	else:
		rpc_id(1, "_cancel")


@rpc("any_peer", "reliable")
func _request(partner: int) -> void:
	if _net().is_host():
		_on_request(multiplayer.get_remote_sender_id(), partner)


@rpc("any_peer", "reliable")
func _answer(trade_id: int, accept_it: bool) -> void:
	if _net().is_host():
		_on_answer(multiplayer.get_remote_sender_id(), trade_id, accept_it)


@rpc("any_peer", "reliable")
func _offer(items: Array) -> void:
	if _net().is_host():
		_on_offer(multiplayer.get_remote_sender_id(), items)


@rpc("any_peer", "reliable")
func _confirm(on: bool) -> void:
	if _net().is_host():
		_on_confirm(multiplayer.get_remote_sender_id(), on)


@rpc("any_peer", "reliable")
func _cancel() -> void:
	if _net().is_host():
		_on_cancel(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func _ack(tx: String) -> void:
	if _net().is_host():
		ledger.ack(tx, multiplayer.get_remote_sender_id())


# ------------------------------------------------------------------ Host-Logik

func _on_request(from: int, to: int) -> void:
	var n := _net()
	if n.state != "lobby" or not n.players.has(to) or not n.players.has(from):
		_tell(from, "Handel nur mit Gruppenmitgliedern in der Lobby möglich.")
		return
	var id := ledger.request(from, to)
	if id == -1:
		_tell(from, "Einer von euch handelt bereits.")
		return
	_push(id)
	_notify_request(to, n.players[from]["name"], id)


func _on_answer(from: int, trade_id: int, accept_it: bool) -> void:
	if accept_it and ledger.accept(trade_id, from):
		_push(trade_id)
	else:
		var t := ledger.snapshot(trade_id)
		ledger.cancel(trade_id)
		if not t.is_empty():
			_clear_for(t["a"]["peer"], "Handel abgelehnt.")
			_clear_for(t["b"]["peer"], "")


func _on_offer(from: int, items: Array) -> void:
	var id := ledger.trade_of(from)
	if id == -1:
		return
	var err := ledger.set_offer(id, from, items)
	if err != "":
		_tell(from, err)
	_push(id)


func _on_confirm(from: int, on: bool) -> void:
	var id := ledger.trade_of(from)
	if id == -1:
		return
	var both := ledger.confirm(id, from, on)
	if both:
		var tx := ledger.commit(id)
		if tx.is_empty():
			return
		var peers: Array = []
		for k in tx:
			if typeof(k) == TYPE_INT:
				peers.append(k)
		for p in peers:
			_send_commit(p, tx[p])
			_clear_for(p, "Handel abgeschlossen.")
	else:
		_push(id)


func _on_cancel(from: int) -> void:
	var id := ledger.trade_of(from)
	if id == -1:
		return
	var t := ledger.snapshot(id)
	ledger.cancel(id)
	for s in ["a", "b"]:
		_clear_for(t[s]["peer"], "Handel abgebrochen.")


func _push(id: int) -> void:
	var t := ledger.snapshot(id)
	if t.is_empty():
		return
	var n := _net()
	for s in ["a", "b"]:
		var peer: int = t[s]["peer"]
		var view := {"id": id, "status": t["status"], "me": s, "a": _pub(t["a"], n), "b": _pub(t["b"], n)}
		_send_state(peer, view)


func _pub(side: Dictionary, n: Node) -> Dictionary:
	return {"peer": side["peer"], "name": n.players.get(side["peer"], {}).get("name", "?"), "offer": side["offer"], "confirmed": side["confirmed"]}


func _send_state(peer: int, view: Dictionary) -> void:
	if peer == 1:
		_on_state(view)
	elif multiplayer.get_peers().has(peer):
		rpc_id(peer, "_state", view)


func _clear_for(peer: int, text: String) -> void:
	_send_state(peer, {})
	if text != "":
		_tell(peer, text)


func _tell(peer: int, text: String) -> void:
	if peer == 1:
		message.emit(text)
	elif multiplayer.get_peers().has(peer):
		rpc_id(peer, "_msg", text)


func _notify_request(peer: int, from_name: String, id: int) -> void:
	if peer == 1:
		request_received.emit(from_name, id)
	else:
		rpc_id(peer, "_req_in", from_name, id)


func _send_commit(peer: int, msg: Dictionary) -> void:
	if peer == 1:
		_on_commit(msg)
	elif multiplayer.get_peers().has(peer):
		rpc_id(peer, "_commit", msg)


## Wird bei Wiederbeitritt aufgerufen: offene, nicht bestätigte Transaktionen erneut senden.
func resend_pending(old_peer: int, new_peer: int) -> void:
	ledger.rename_peer(old_peer, new_peer)
	for msg in ledger.unacked_for(new_peer):
		_send_commit(new_peer, msg)


func peer_gone(peer: int) -> void:
	var id := ledger.trade_of(peer)
	if id != -1:
		_on_cancel(peer)


# ------------------------------------------------------------------ Client-Empfang

@rpc("authority", "reliable")
func _state(view: Dictionary) -> void:
	_on_state(view)


func _on_state(view: Dictionary) -> void:
	current = view
	state_changed.emit(current)


@rpc("authority", "reliable")
func _msg(text: String) -> void:
	message.emit(text)


@rpc("authority", "reliable")
func _req_in(from_name: String, id: int) -> void:
	request_received.emit(from_name, id)


@rpc("authority", "reliable")
func _commit(msg: Dictionary) -> void:
	_on_commit(msg)


func _on_commit(msg: Dictionary) -> void:
	var c := SaveSystem.active_character()
	if c.is_empty():
		return
	if TradeLedger.apply_to_character(c, msg):
		SaveSystem.save_game()
		message.emit("Handel abgeschlossen: %d Gegenstand/Gegenstände erhalten." % msg["receive"].size())
	if _net().is_host():
		ledger.ack(msg["tx"], 1)
	else:
		rpc_id(1, "_ack", msg["tx"])
