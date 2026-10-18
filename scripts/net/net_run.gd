extends Node
## Run-Synchronisierung für den Koop-Betrieb (Kindknoten von "Net", Pfad /root/Net/Run auf allen Peers gleich).
##
## Host-autoritativ (siehe docs/ARCHITEKTUR.md):
##  * Der Host simuliert Gegner, Schaden, Beute, Level-Up-Angebote, Wiederbelebung und Wipe.
##  * Clients senden nur Eingaben (Position, Blickrichtung, gehaltene Tasten, Aktionen, Angebots-Wahl).
##  * Der Host sendet Snapshots (unzuverlässig, ~15 Hz: Spieler, Gegner, Geschosse), einen privaten Zustand pro Client
##    (~20 Hz), zuverlässige Ereignisse (Spawn/Tod, Banner, Truhen, Beute, Angebote, Ergebnis) und gebündelte Effekte.
##
## Diese Klasse enthält nur Transport und Prüfungen. Die Spiellogik liegt in Arena (Host) bzw. ClientArena (Client).

const SNAP_HZ := 15.0
const ME_HZ := 20.0
const STATE_HZ := 30.0
const FX_HZ := 30.0
const FX_CAP := 48           # maximale Effekte pro Paket (Rest wird verworfen, rein kosmetisch)
const MAX_ACTS := 8          # maximal gepufferte Aktionen pro Spieler und Frame

var arena: Node = null       # Host: Arena, Client: ClientArena (setzen die Arenen selbst)
var sims: Dictionary = {}    # Host: slot -> Player (remote_sim)
var stats := {"snap_bytes": 0, "snaps": 0, "events": 0, "rejected": 0}

var _fx_u: Array = []
var _fx_r: Array = []
var _fx_t := 0.0
var _snap_t := 0.0
var _me_t := 0.0


# ------------------------------------------------------------------ Schnittstelle zu Net (Lobby/Verbindung)

func reset() -> void:
	sims.clear()
	arena = null
	_fx_u.clear()
	_fx_r.clear()
	FX.net_hook = Callable()
	Sfx.net_hook = Callable()


func host_prepare(_seed: int) -> void:
	sims.clear()


func has_slot(slot: int) -> bool:
	return sims.has(slot) and is_instance_valid(sims[slot])


func on_peer_lost(slot: int) -> void:
	if has_slot(slot):
		var p: Player = sims[slot]
		p.net_away = true
		p.remote_holds = 0
		p.remote_acts.clear()


func on_rejoin(slot: int, peer_id: int) -> void:
	if has_slot(slot):
		var p: Player = sims[slot]
		p.net_peer = peer_id
		p.net_away = false


## Verbundene Remote-Spieler (Host).
func peers() -> Array:
	var out: Array = []
	for slot in sims:
		var p: Player = sims[slot]
		if is_instance_valid(p) and not p.net_away and p.net_peer > 1:
			out.append(p.net_peer)
	return out


func _has_remote() -> bool:
	return Net.is_host() and not multiplayer.get_peers().is_empty()


# ------------------------------------------------------------------ Host -> Clients

func send_snapshot(t: float, kills: int, elites: int, pl: Array, en: PackedFloat32Array, pr: PackedFloat32Array, hits: PackedInt32Array) -> void:
	if not _has_remote():
		return
	stats["snaps"] += 1
	stats["snap_bytes"] += en.size() * 4 + pr.size() * 4 + hits.size() * 4 + pl.size() * 100
	rpc("_snap", t, kills, elites, pl, en, pr, hits)


func send_me(peer_id: int, d: Dictionary) -> void:
	if _has_remote():
		rpc_id(peer_id, "_me", d)


func send_correct(peer_id: int, pos: Vector3) -> void:
	rpc_id(peer_id, "_correct", pos)


## Zuverlässiges Ereignis an alle (peer_id = 0) oder an einen Spieler.
func ev(kind: String, data: Array = [], peer_id: int = 0) -> void:
	if not _has_remote():
		return
	stats["events"] += 1
	if peer_id > 0:
		rpc_id(peer_id, "_ev", kind, data)
	else:
		rpc("_ev", kind, data)


func queue_fx(kind: String, args: Array) -> void:
	if not _has_remote():
		return
	if kind == "tele" or kind == "zone":
		_fx_r.append([kind, args])       # Warnzonen dürfen nicht verloren gehen
	elif _fx_u.size() < FX_CAP:
		_fx_u.append([kind, args])


func queue_sfx(id: String, pitch: float, vol: float) -> void:
	if _has_remote() and _fx_u.size() < FX_CAP:
		_fx_u.append(["sfx", [id, pitch, vol]])


## Host: jeden Frame aufrufen. Bündelt Effekte und sendet sie ca. 30x pro Sekunde.
func host_tick(delta: float) -> void:
	_fx_t += delta
	if _fx_t < 1.0 / FX_HZ:
		return
	_fx_t = 0.0
	if not _fx_r.is_empty():
		rpc("_fx_reliable", _fx_r)
		_fx_r = []
	if not _fx_u.is_empty():
		rpc("_fx_fast", _fx_u)
		_fx_u = []


@rpc("authority", "unreliable_ordered")
func _snap(t: float, kills: int, elites: int, pl: Array, en: PackedFloat32Array, pr: PackedFloat32Array, hits: PackedInt32Array) -> void:
	if arena != null and not Net.is_host():
		arena.call("on_snapshot", t, kills, elites, pl, en, pr, hits)


@rpc("authority", "unreliable_ordered")
func _me(d: Dictionary) -> void:
	if arena != null and not Net.is_host():
		arena.call("on_me", d)


@rpc("authority", "unreliable")
func _correct(pos: Vector3) -> void:
	if arena != null and not Net.is_host():
		arena.call("on_correct", pos)


@rpc("authority", "reliable")
func _ev(kind: String, data: Array) -> void:
	if arena != null and not Net.is_host():
		arena.call("on_event", kind, data)


@rpc("authority", "unreliable")
func _fx_fast(batch: Array) -> void:
	if arena != null and not Net.is_host():
		arena.call("on_fx", batch)


@rpc("authority", "reliable")
func _fx_reliable(batch: Array) -> void:
	if arena != null and not Net.is_host():
		arena.call("on_fx", batch)


# ------------------------------------------------------------------ Clients -> Host

## Client: eigene Position, Blickrichtung und gehaltene Tasten (~30 Hz).
func send_state(pos: Vector3, yaw: float, cam_yaw: float, holds: int) -> void:
	if Net.peer != null and not Net.is_host():
		rpc_id(1, "_state", pos, yaw, cam_yaw, holds)


func send_act(id: int, v: Vector2) -> void:
	if Net.peer != null and not Net.is_host():
		rpc_id(1, "_act", id, v)


func send_req(kind: String, data: Array = []) -> void:
	if Net.peer != null and not Net.is_host():
		rpc_id(1, "_req", kind, data)


func _sim_of_sender() -> Player:
	var id := multiplayer.get_remote_sender_id()
	var slot := Net.slot_of(id)
	if slot < 0 or not has_slot(slot):
		return null
	var p: Player = sims[slot]
	return p if p.net_peer == id else null


@rpc("any_peer", "unreliable_ordered")
func _state(pos: Vector3, yaw: float, cam_yaw: float, holds: int) -> void:
	if not Net.is_host():
		return
	var p := _sim_of_sender()
	if p == null:
		return
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z) and is_finite(yaw) and is_finite(cam_yaw)):
		stats["rejected"] += 1
		return
	if not p.accept_remote_position(pos, yaw, cam_yaw, holds & 7):
		stats["rejected"] += 1
		send_correct(p.net_peer, p.global_position)


@rpc("any_peer", "reliable")
func _act(id: int, v: Vector2) -> void:
	if not Net.is_host():
		return
	var p := _sim_of_sender()
	if p == null or id < 0 or id > Player.ACT_BLOCK:
		return
	if p.remote_acts.size() < MAX_ACTS:
		p.remote_acts.append([id, v.limit_length(1.0)])


@rpc("any_peer", "reliable")
func _req(kind: String, data: Array) -> void:
	if not Net.is_host() or arena == null:
		return
	var p := _sim_of_sender()
	if p == null:
		return
	arena.call("on_client_request", p, kind, data)
