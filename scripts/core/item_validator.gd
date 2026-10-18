class_name ItemValidator
extends RefCounted
## Prüft Gegenstände auf Manipulation (Handel, Beitritt zu einer Gruppe, Beute).
## Ein Gegenstand ist gültig, wenn Platz, Seltenheit und Werte innerhalb dessen liegen, was Loot.build_item
## bzw. ein definiertes Artefakt überhaupt erzeugen kann.

const REQUIRED := ["uid", "base_id", "name", "slot", "rarity", "stats", "level"]


static func validate(item: Dictionary) -> String:
	## "" = gültig, sonst Grund.
	for k in REQUIRED:
		if not item.has(k):
			return "Feld fehlt: " + k
	if typeof(item["stats"]) != TYPE_DICTIONARY:
		return "Werte ungültig"
	if typeof(item["uid"]) != TYPE_STRING or str(item["uid"]).length() > 64 or str(item["uid"]) == "":
		return "ID ungültig"
	if str(item["name"]).length() > 80:
		return "Name zu lang"
	var cfg: Dictionary = GameData.items_cfg
	if not cfg["rarities"].has(item["rarity"]):
		return "Seltenheit unbekannt"
	if not cfg["slots"].has(item["slot"]):
		return "Platz unbekannt"
	var lvl := int(item["level"])
	if lvl < 1 or lvl > 99:
		return "Stufe ungültig"
	# Artefakte: Werte müssen exakt der Definition entsprechen
	for u in cfg["uniques"]:
		if u["id"] == item["base_id"]:
			if u["slot"] != item["slot"] or u["rarity"] != item["rarity"]:
				return "Artefakt verändert"
			for k in item["stats"]:
				if not u["stats"].has(k):
					return "Artefaktwert fremd: " + str(k)
				if k == "flags":
					if item["stats"][k] != u["stats"][k]:
						return "Artefakt-Wandlung verändert"
				elif absf(float(item["stats"][k]) - float(u["stats"][k])) > 0.0001:
					return "Artefaktwert verändert: " + str(k)
			return ""
	var base := _base(item["base_id"])
	if base.is_empty():
		return "Basisgegenstand unbekannt"
	if base["slot"] != item["slot"]:
		return "Platz passt nicht zur Basis"
	var rc: Dictionary = cfg["rarities"][item["rarity"]]
	var mult: float = float(rc["mult"]) * (1.0 + 0.06 * float(lvl - 1))
	var pool: Dictionary = cfg["affix_pool"][base.get("pool", "armor")]
	var extra := 0
	for k in item["stats"]:
		if k == "flags":
			return "Wandlungen nur bei Artefakten"
		var v := float(item["stats"][k])
		var base_v := float(base["base"].get(k, 0.0))
		var max_v := base_v * mult
		if pool.has(k):
			max_v += float(pool[k][1]) * mult
			if not base["base"].has(k):
				extra += 1
		elif not base["base"].has(k):
			return "Wert nicht erlaubt: " + str(k)
		# Rundung in Loot._scaled kann leicht über das Maximum führen
		var tol := maxf(1.0, absf(max_v) * 0.02) if not (k in cfg["pct_stats"] or k == "hp_regen" or k == "dodge_iframes") else 0.002
		if v > max_v + tol or v < -0.0001:
			return "Wert zu hoch: " + str(k)
	if extra > int(rc["affixes"]):
		return "Zu viele Zusatzwerte"
	if item.has("weapon_type") and item["weapon_type"] != base.get("weapon_type", ""):
		return "Waffentyp passt nicht"
	return ""


static func _base(id: String) -> Dictionary:
	for b in GameData.items_cfg["bases"]:
		if b["id"] == id:
			return b
	if id == "rusty_sword":
		return {"id": "rusty_sword", "slot": "weapon", "weapon_type": "sword", "base": {"damage": 2}, "pool": "weapon"}
	return {}


## Prüft einen Talent-Entwurf: bekannte IDs, keine Duplikate, alle vom Startpunkt aus erreichbar.
static func validate_talents(allocated: Array) -> String:
	var seen := {}
	for id in allocated:
		if not GameData.talents.has(id):
			return "Unbekanntes Talent: " + str(id)
		if seen.has(id):
			return "Doppeltes Talent"
		seen[id] = true
	var reachable: Array = []
	var changed := true
	while changed:
		changed = false
		for t in allocated:
			if t in reachable:
				continue
			if TalentTree.prerequisites_met(t, reachable):
				reachable.append(t)
				changed = true
	if reachable.size() != allocated.size():
		return "Talente nicht verbunden"
	return ""


## Mehr Talentpunkte, als ein Charakter dieser Stufe haben kann (1 Startpunkt + 1 je Stufe), sind unmöglich.
static func max_talent_points(meta_level: int) -> int:
	return Progression.total_points_for_level(meta_level)
