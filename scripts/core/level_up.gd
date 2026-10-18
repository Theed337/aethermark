class_name LevelUp
extends RefCounted
## Erzeugt die zufälligen Optionen beim Levelaufstieg (testbar, ohne Szenenbezug).
## Regeln: gewichtete Seltenheit, Synergien, kein Wiederholen kürzlich angebotener Optionen,
## garantierte aktive Fähigkeit zu Beginn, abgeschlossene Fähigkeiten werden nicht angeboten.

const MAX_ACTIVE_SLOTS := 4


static func owned_active_count(levels: Dictionary) -> int:
	var n := 0
	for id in levels:
		if levels[id] > 0 and GameData.skills.get(id, {}).get("kind", "") == "active":
			n += 1
	return n


static func eligible(levels: Dictionary) -> Array:
	var out: Array = []
	var actives := owned_active_count(levels)
	for s in GameData.skill_list:
		var lv: int = int(levels.get(s["id"], 0))
		if lv >= int(s["max_level"]):
			continue
		if s["kind"] == "active" and lv == 0 and actives >= MAX_ACTIVE_SLOTS:
			continue   # keine freien Slots mehr
		out.append(s)
	return out


static func weight_for(s: Dictionary, levels: Dictionary, player_level: int) -> float:
	var w: float = float(GameData.skill_cfg["rarity_weights"].get(s["rarity"], 10))
	# Seltene Optionen werden mit steigender Stufe etwas wahrscheinlicher
	if s["rarity"] in ["rare", "epic"]:
		w *= 1.0 + 0.04 * player_level
	# Synergie: Fähigkeiten, die Tags mit bereits gewählten teilen, sind bevorzugt
	var syn := 0
	for id in levels:
		if levels[id] > 0 and id != s["id"]:
			for t in GameData.skills.get(id, {}).get("tags", []):
				if t in s.get("tags", []):
					syn += 1
	w *= 1.0 + 0.25 * minf(syn, 4)
	# Vorhandene Fähigkeiten weiter ausbauen ist leicht bevorzugt
	if levels.get(s["id"], 0) > 0:
		w *= 1.2
	# Epische Optionen erst ab Stufe 4
	if s["rarity"] == "epic" and player_level < 4:
		w = 0.0
	return w


static func generate_offers(rng: RandomNumberGenerator, levels: Dictionary, player_level: int, recent: Array, count: int = 3) -> Array:
	var pool := eligible(levels)
	var offers: Array = []
	# Zu Beginn mindestens eine aktive Fähigkeit anbieten
	if owned_active_count(levels) == 0:
		var actives := pool.filter(func(s): return s["kind"] == "active" and s["rarity"] != "epic")
		if not actives.is_empty():
			offers.append(_pick(rng, actives, levels, player_level, []))
	var candidates := pool.filter(func(s): return not _contains(offers, s) and not (s["id"] in recent))
	if candidates.size() < count - offers.size():
		candidates = pool.filter(func(s): return not _contains(offers, s))   # Schutz vor leerem Pool
	while offers.size() < count and not candidates.is_empty():
		var pick := _pick(rng, candidates, levels, player_level, [])
		offers.append(pick)
		candidates = candidates.filter(func(s): return s["id"] != pick["id"])
	var result: Array = []
	for s in offers:
		var lv: int = int(levels.get(s["id"], 0)) + 1
		result.append({
			"id": s["id"], "name": s["name"], "kind": s["kind"], "rarity": s["rarity"],
			"new_level": lv, "max_level": s["max_level"],
			"desc": s["levels"][lv - 1], "is_new": lv == 1,
		})
	return result


static func _contains(arr: Array, s: Dictionary) -> bool:
	for a in arr:
		if a["id"] == s["id"]:
			return true
	return false


static func _pick(rng: RandomNumberGenerator, pool: Array, levels: Dictionary, player_level: int, _x: Array) -> Dictionary:
	var total := 0.0
	var ws: Array = []
	for s in pool:
		var w := weight_for(s, levels, player_level)
		ws.append(w)
		total += w
	if total <= 0.0:
		return pool[rng.randi() % pool.size()]
	var r := rng.randf() * total
	for i in pool.size():
		r -= ws[i]
		if r <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


## Prüft, welche Evolutionen mit den aktuellen Stufen aktiv sind.
static func active_evolutions(levels: Dictionary) -> Array:
	var out: Array = []
	for e in GameData.evolutions:
		var ok := true
		for id in e["requires"]:
			if int(levels.get(id, 0)) < int(e["requires"][id]):
				ok = false
				break
		if ok:
			out.append(e["id"])
	return out
