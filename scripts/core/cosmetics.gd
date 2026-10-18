class_name Cosmetics
extends RefCounted
## Kosmetische Freischaltungen (Frisuren, Hörner, Titel, Akzentfarben ...). Regeln stehen in data/cosmetics.json.
## Freischaltung ergibt sich aus den dauerhaften Charakterstatistiken – kein Echtgeld, kein Zufall.


static func entry(kind: String, value: Variant) -> Dictionary:
	for e in GameData.cosmetics:
		if e["kind"] == kind and str(e["value"]) == str(value):
			return e
	return {}


## Ein Wert ist frei, wenn es keine Regel gibt (Standardinhalt) oder die Regel erfüllt ist.
static func is_unlocked(character: Dictionary, kind: String, value: Variant) -> bool:
	var e := entry(kind, value)
	if e.is_empty():
		return true
	var u: Dictionary = e["unlock"]
	return int(character.get("stats", {}).get(u["stat"], 0)) >= int(u["target"])


static func unlock_text(kind: String, value: Variant) -> String:
	var e := entry(kind, value)
	return "" if e.is_empty() else str(e["unlock"]["text"])


static func unlocked_titles(character: Dictionary) -> Array:
	var out: Array = []
	for e in GameData.cosmetics:
		if e["kind"] == "title" and is_unlocked(character, "title", e["value"]):
			out.append(e["value"])
	return out


static func count_unlocked(character: Dictionary) -> Vector2i:
	var done := 0
	for e in GameData.cosmetics:
		if is_unlocked(character, e["kind"], e["value"]):
			done += 1
	return Vector2i(done, GameData.cosmetics.size())


## Setzt gesperrte Werte auf Standard zurück (Schutz gegen manipulierte Speicherstände / Reset).
static func sanitize(character: Dictionary) -> void:
	var a: Dictionary = character["appearance"]
	var d := SaveSystem.default_appearance()
	for kind in ["outfit", "horns", "tattoo", "hair_style", "beard"]:
		if not is_unlocked(character, kind, a.get(kind, d[kind])):
			a[kind] = d[kind]
	if not is_unlocked(character, "title", character.get("title", "Wanderer")):
		character["title"] = "Wanderer"
