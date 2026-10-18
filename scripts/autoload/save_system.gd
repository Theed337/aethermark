extends Node
## Persistenter Spielstand (JSON) mit Prüfsumme, automatischem Backup und Wiederherstellung.
## Schreiben: temporäre Datei -> altes Save als .bak sichern -> Ersetzen.
## Beim Laden: bei defekter Datei wird automatisch das Backup verwendet.

signal saved
signal loaded

const SAVE_VERSION := 1
const INVENTORY_CAP := 60

var save_path: String = "user://savegame.json"
var data: Dictionary = {}
var last_load_status: String = "neu"   # neu | ok | backup | zurückgesetzt


func _ready() -> void:
	load_game()


func default_settings() -> Dictionary:
	return {
		"volume_master": 0.8, "volume_music": 0.6, "volume_sfx": 0.9, "volume_ambient": 0.7, "mute": false,
		"mouse_sensitivity": 0.0025, "camera_distance": 6.5, "fov": 70.0,
		"graphics_quality": 2, "particle_limit": 1.0, "fullscreen": false, "show_damage_numbers": true,
		"key_bindings": {}, "friends": [], "last_address": "127.0.0.1", "ui_scale": 1.0, "touch_controls": false,
	}


func default_stats() -> Dictionary:
	return {"kills": 0, "elites": 0, "bosses": 0, "runs": 0, "wins": 0, "deaths": 0, "playtime": 0.0,
			"best_run_level": 0, "damage_dealt": 0.0, "legendaries": 0, "flawless_wins": 0, "items_found": 0}


func default_data() -> Dictionary:
	return {"version": SAVE_VERSION, "settings": default_settings(), "characters": [], "active_character": ""}


# ---------------------------------------------------------------- Laden/Speichern

func load_game() -> bool:
	data = default_data()
	var res := _try_read(save_path)
	if res.ok:
		data = _migrate(res.data)
		last_load_status = "ok"
		loaded.emit()
		return true
	var bak := _try_read(save_path + ".bak")
	if bak.ok:
		data = _migrate(bak.data)
		last_load_status = "backup"
		push_warning("Spielstand defekt oder fehlend – Backup wiederhergestellt.")
		loaded.emit()
		return true
	last_load_status = "neu" if not FileAccess.file_exists(save_path) else "zurückgesetzt"
	loaded.emit()
	return false


func _try_read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("checksum") or not parsed.has("payload"):
		return {"ok": false}
	var payload: Dictionary = parsed["payload"]
	if _checksum(payload) != parsed["checksum"]:
		return {"ok": false}
	return {"ok": true, "data": payload}


func _checksum(payload: Dictionary) -> String:
	return JSON.stringify(payload, "", true).sha256_text()


func save_game() -> bool:
	var envelope := {"checksum": _checksum(data), "payload": data}
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Speichern fehlgeschlagen: %s" % tmp)
		return false
	f.store_string(JSON.stringify(envelope, "", true))
	f.close()
	var abs_main := ProjectSettings.globalize_path(save_path)
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(save_path):
		# Backup nur aus einer gültigen Hauptdatei anlegen – ein defekter Stand darf das gute Backup nie überschreiben.
		if _try_read(save_path).ok:
			DirAccess.copy_absolute(abs_main, abs_main + ".bak")
		DirAccess.remove_absolute(abs_main)
	var err := DirAccess.rename_absolute(abs_tmp, abs_main)
	if err != OK:
		push_error("Speichern fehlgeschlagen (rename): %d" % err)
		return false
	saved.emit()
	return true


func _migrate(d: Dictionary) -> Dictionary:
	var out := default_data()
	for k in d:
		out[k] = d[k]
	var s := default_settings()
	for k in out["settings"]:
		s[k] = out["settings"][k]
	out["settings"] = s
	for c in out["characters"]:
		var ds := default_stats()
		for k in c.get("stats", {}):
			ds[k] = c["stats"][k]
		c["stats"] = ds
		if not c.has("title"):
			c["title"] = "Wanderer"
		if not c.has("gold"):
			c["gold"] = 60
		if not c.has("shop"):
			c["shop"] = {}
	return out


# ---------------------------------------------------------------- Charaktere

func default_appearance() -> Dictionary:
	return {"body_height": 1.0, "body_build": 1.0, "skin": "#e0b090", "hair_style": 1, "hair_color": "#4a2f1b",
			"beard": 0, "eye_color": "#3a7bd5", "ears": 0, "horns": 0, "scar": 0, "tattoo": 0,
			"accent": "#4ecdc4", "outfit": 0, "origin": "human", "voice": 0, "female": 0, "body": 0}


func make_item_uid() -> String:
	return "i%d_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi() % 1000000]


func starter_weapon() -> Dictionary:
	return {"uid": make_item_uid(), "base_id": "rusty_sword", "name": "Rostiges Schwert", "slot": "weapon",
			"weapon_type": "sword", "rarity": "common", "stats": {"damage": 2}, "level": 1, "tradable": false, "locked": false, "text": ""}


func new_character(char_name: String, appearance: Dictionary) -> Dictionary:
	var w := starter_weapon()
	var c := {
		"id": "c%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000],
		"name": char_name, "appearance": appearance, "meta_xp": 0, "meta_level": 1, "talent_points": 3,
		"talents": [], "inventory": [w], "equipment": {"weapon": w["uid"]}, "stats": default_stats(),
		"unlocked_areas": ["emerald_forest"], "cleared_areas": [], "bosses_defeated": [],
		"cosmetics": [], "achievements": [], "title": "Wanderer", "gold": 60, "shop": {}, "created": Time.get_unix_time_from_system(),
	}
	data["characters"].append(c)
	data["active_character"] = c["id"]
	save_game()
	return c


func active_character() -> Dictionary:
	for c in data["characters"]:
		if c["id"] == data["active_character"]:
			return c
	return {}


func has_character() -> bool:
	return not active_character().is_empty()


func delete_character(id: String) -> void:
	for i in data["characters"].size():
		if data["characters"][i]["id"] == id:
			data["characters"].remove_at(i)
			break
	if data["active_character"] == id:
		data["active_character"] = data["characters"][0]["id"] if data["characters"].size() > 0 else ""
	save_game()


static func validate_name(n: String) -> String:
	## Gibt "" zurück wenn gültig, sonst eine Fehlermeldung.
	var t := n.strip_edges()
	if t.length() < 3:
		return "Der Name braucht mindestens 3 Zeichen."
	if t.length() > 16:
		return "Der Name darf höchstens 16 Zeichen haben."
	var rx := RegEx.new()
	rx.compile("^[\\p{L}0-9 '\\-]+$")
	if rx.search(t) == null:
		return "Erlaubt sind Buchstaben, Ziffern, Leerzeichen, ' und -."
	return ""


# ---------------------------------------------------------------- Inventar

func add_item(c: Dictionary, item: Dictionary) -> bool:
	if c["inventory"].size() >= INVENTORY_CAP:
		return false
	for it in c["inventory"]:
		if it["uid"] == item["uid"]:
			return false   # Duplikate verhindern
	c["inventory"].append(item)
	return true


func find_item(c: Dictionary, uid: String) -> Dictionary:
	for it in c["inventory"]:
		if it["uid"] == uid:
			return it
	return {}


func equip(c: Dictionary, uid: String) -> bool:
	var it := find_item(c, uid)
	if it.is_empty():
		return false
	var slot: String = it["slot"]
	if slot == "ring1" or slot == "ring2":
		# Ringe dürfen in beide Plätze: bevorzugt freien Platz nehmen
		if not c["equipment"].has("ring1"):
			slot = "ring1"
		elif not c["equipment"].has("ring2"):
			slot = "ring2"
		else:
			slot = "ring1"
	_unequip_uid(c, uid)
	c["equipment"][slot] = uid
	return true


func _unequip_uid(c: Dictionary, uid: String) -> void:
	for s in c["equipment"].keys():
		if c["equipment"][s] == uid:
			c["equipment"].erase(s)


func unequip(c: Dictionary, slot: String) -> void:
	c["equipment"].erase(slot)


func remove_item(c: Dictionary, uid: String) -> void:
	_unequip_uid(c, uid)
	for i in c["inventory"].size():
		if c["inventory"][i]["uid"] == uid:
			c["inventory"].remove_at(i)
			return
