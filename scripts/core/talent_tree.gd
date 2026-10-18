class_name TalentTree
extends RefCounted
## Logik des permanenten Talentbaums (Voraussetzungen, Punkte, Reset).


static func cost_of(id: String) -> int:
	return int(GameData.talents[id].get("cost", 1))


static func spent_points(allocated: Array) -> int:
	var s := 0
	for id in allocated:
		s += cost_of(id)
	return s


static func prerequisites_met(id: String, allocated: Array) -> bool:
	var n: Dictionary = GameData.talents[id]
	var req: Array = n.get("requires", [])
	if req.is_empty():
		return true   # Startknoten am Zentrum
	if n.get("requires_mode", "any") == "all":
		for r in req:
			if not (r in allocated):
				return false
		return true
	for r in req:
		if r in allocated:
			return true
	return false


static func can_allocate(id: String, allocated: Array, points: int) -> String:
	## "" = möglich, sonst Begründung.
	if not GameData.talents.has(id):
		return "Unbekanntes Talent."
	if id in allocated:
		return "Bereits erlernt."
	if not prerequisites_met(id, allocated):
		return "Voraussetzung fehlt."
	if cost_of(id) > points:
		return "Nicht genug Talentpunkte."
	return ""


static func allocate(character: Dictionary, id: String) -> bool:
	var why := can_allocate(id, character["talents"], int(character["talent_points"]))
	if why != "":
		return false
	character["talents"].append(id)
	character["talent_points"] = int(character["talent_points"]) - cost_of(id)
	return true


## Kostenloser Reset: gibt alle Punkte zurück (siehe docs/DESIGN.md: bewusste Entscheidung für kostenlosen Reset).
static func reset(character: Dictionary) -> int:
	var refunded := spent_points(character["talents"])
	character["talent_points"] = int(character["talent_points"]) + refunded
	character["talents"] = []
	return refunded


## Entfernt ein Talent nur, wenn dadurch kein anderes Talent verwaist.
static func can_refund(id: String, allocated: Array) -> bool:
	if not (id in allocated):
		return false
	var rest := allocated.duplicate()
	rest.erase(id)
	# Alle verbleibenden Talente müssen weiterhin vom Zentrum aus erreichbar sein
	var reachable: Array = []
	var changed := true
	while changed:
		changed = false
		for t in rest:
			if t in reachable:
				continue
			if prerequisites_met(t, reachable):
				reachable.append(t)
				changed = true
	return reachable.size() == rest.size()


static func refund(character: Dictionary, id: String) -> bool:
	if not can_refund(id, character["talents"]):
		return false
	character["talents"].erase(id)
	character["talent_points"] = int(character["talent_points"]) + cost_of(id)
	return true


static func describe_effects(effects: Dictionary) -> Array:
	var labels: Dictionary = GameData.items_cfg.get("stat_labels", {})
	var pct: Array = GameData.items_cfg.get("pct_stats", [])
	var lines: Array = []
	for k in effects:
		if k == "flags":
			for f in effects[k]:
				lines.append("Wandlung: " + flag_text(f))
			continue
		var v: float = float(effects[k])
		var sign := "+" if v >= 0.0 else ""
		if k in pct:
			lines.append("%s%s%% %s" % [sign, _fmt(v * 100.0), str(labels.get(k, k)).replace(" %", "")])
		else:
			lines.append("%s%s %s" % [sign, _fmt(v), labels.get(k, k)])
	return lines


static func flag_text(f: String) -> String:
	match f:
		"heavy_light_attacks": return "Leichte Angriffe werden zu schweren Flächenschlägen (langsamer, +60% Schaden, voller Rundumschlag)."
		"fireball_meteor": return "Feuerbälle stürzen als Meteore vom Himmel (größere Explosion, kleine Verzögerung)."
		"dodge_empower": return "Nach dem Ausweichen: nächster Angriff +60% Schaden."
	return f


static func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return str(int(roundf(v)))
	return "%.1f" % v
