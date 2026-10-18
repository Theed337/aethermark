class_name ItemText
extends RefCounted
## Gemeinsame Textdarstellung von Gegenständen (Handelsfenster, Gruppenansicht).


static func stat_line(k: String, v: float) -> String:
	var labels: Dictionary = GameData.items_cfg["stat_labels"]
	var pct: Array = GameData.items_cfg["pct_stats"]
	var sign := "+" if v >= 0.0 else ""
	if k in pct:
		return "%s%.1f%% %s" % [sign, v * 100.0, str(labels.get(k, k)).replace(" %", "")]
	return "%s%s %s" % [sign, TalentTree._fmt(v), labels.get(k, k)]


## Alle Werte eines Gegenstands als Zeilen (Name zuerst, dann Werte und Artefakt-Wandlungen).
static func lines(it: Dictionary) -> Array:
	var out: Array = []
	out.append("%s · %s · Stufe %d" % [GameData.rarity_name(it["rarity"]), GameData.items_cfg["slots"].get(it["slot"], it["slot"]), int(it["level"])])
	for k in it["stats"]:
		if k == "flags":
			for f in it["stats"][k]:
				out.append("★ " + TalentTree.flag_text(f))
		else:
			out.append(stat_line(k, float(it["stats"][k])))
	if str(it.get("text", "")) != "":
		out.append(str(it["text"]))
	return out


## Darf dieser Gegenstand in ein Handelsfenster? (nicht gesperrt, nicht angelegt, als handelbar markiert)
static func tradable_now(c: Dictionary, it: Dictionary) -> bool:
	if not it.get("tradable", false) or it.get("locked", false):
		return false
	for s in c.get("equipment", {}):
		if c["equipment"][s] == it["uid"]:
			return false
	return true
