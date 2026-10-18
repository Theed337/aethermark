class_name Progression
extends RefCounted
## Dauerhafter Fortschritt nach einem Run (rein datenbasiert, testbar).
##
## Regel (im Spiel erklärt): Gefundene Ausrüstung bleibt IMMER erhalten ("sichere Extraktion").
## Bei einer Niederlage gibt es nur die Hälfte der Talentpunkte und keine Gebietsfreischaltung.
## Rundenfähigkeiten und Rundenstufe gehen nach jedem Run verloren.


static func meta_xp_for_level(level: int) -> int:
	return 170 * level


static func compute_points(result: Dictionary) -> int:
	var pts := int(result.get("kills", 0)) / 45 + int(result.get("level", 1)) / 4
	pts += int(result.get("elites", 0))
	if result.get("boss_defeated", false):
		pts += 4
	if result.get("victory", false):
		pts += 2
	if not result.get("victory", false):
		pts = pts / 2
	return maxi(pts, 1)


static func apply_results(character: Dictionary, result: Dictionary) -> Dictionary:
	var summary := {"points": 0, "meta_levels": 0, "new_items": [], "dropped_items": [], "new_areas": [],
			"new_achievements": [], "achievement_points": 0}
	var st: Dictionary = character["stats"]
	var victory: bool = result.get("victory", false)
	st["runs"] += 1
	st["kills"] += int(result.get("kills", 0))
	st["elites"] += int(result.get("elites", 0))
	st["playtime"] += float(result.get("duration", 0.0))
	st["damage_dealt"] += float(result.get("damage_dealt", 0.0))
	st["best_run_level"] = maxi(int(st["best_run_level"]), int(result.get("level", 1)))
	if victory:
		st["wins"] += 1
		if result.get("boss_defeated", false):
			st["bosses"] += 1
		if int(result.get("downs", 0)) == 0:
			st["flawless_wins"] += 1
	else:
		st["deaths"] += 1

	var gold := int(result.get("kills", 0)) * 2 + int(result.get("elites", 0)) * 12 + int(result.get("level", 1)) * 8
	if result.get("boss_defeated", false):
		gold += 200
	if not victory:
		gold = gold / 2
	character["gold"] = int(character.get("gold", 0)) + gold
	summary["gold"] = gold
	var pts := compute_points(result)
	summary["points"] = pts
	character["talent_points"] = int(character["talent_points"]) + pts

	# Meta-Erfahrung -> Charakterstufe (jede Stufe = +1 Talentpunkt)
	var mx := int(result.get("kills", 0)) * 2 + int(result.get("level", 1)) * 15 + (120 if result.get("boss_defeated", false) else 0)
	character["meta_xp"] = int(character["meta_xp"]) + mx
	while int(character["meta_xp"]) >= meta_xp_for_level(int(character["meta_level"])):
		character["meta_xp"] = int(character["meta_xp"]) - meta_xp_for_level(int(character["meta_level"]))
		character["meta_level"] = int(character["meta_level"]) + 1
		character["talent_points"] = int(character["talent_points"]) + 1
		summary["meta_levels"] += 1

	# Items
	for it in result.get("items", []):
		if it["rarity"] in ["legendary", "mythic"]:
			st["legendaries"] += 1
		st["items_found"] += 1
		if SaveSystem.add_item(character, it):
			summary["new_items"].append(it)
		else:
			summary["dropped_items"].append(it)

	# Bosse/Gebiete
	if victory and result.get("boss_defeated", false):
		var area_id: String = result.get("area_id", "emerald_forest")
		if not (area_id in character["cleared_areas"]):
			character["cleared_areas"].append(area_id)
		var boss_id: String = result.get("boss_id", "")
		if boss_id != "" and not (boss_id in character["bosses_defeated"]):
			character["bosses_defeated"].append(boss_id)
		for a in GameData.areas:
			var u: Dictionary = a["unlock"]
			var ok := false
			if u["type"] == "boss" and u["id"] in character["bosses_defeated"]:
				ok = true
			elif u["type"] == "area_clear" and u["id"] in character["cleared_areas"]:
				ok = true
			if ok and not (a["id"] in character["unlocked_areas"]):
				character["unlocked_areas"].append(a["id"])
				summary["new_areas"].append(a["name"])

	# Erfolge
	for ach in GameData.achievements:
		if ach["id"] in character["achievements"]:
			continue
		if int(st.get(ach["stat"], 0)) >= int(ach["target"]):
			character["achievements"].append(ach["id"])
			character["talent_points"] = int(character["talent_points"]) + int(ach["reward_points"])
			summary["achievement_points"] += int(ach["reward_points"])
			summary["new_achievements"].append(ach["name"])
	return summary


const DIFFICULTY_NAMES := ["", "Normal", "Schwer", "Albtraum", "Inferno"]
const DIFFICULTY_WINS := [0, 0, 1, 3, 6]   # benötigte Siege je Schwierigkeitsgrad


static func difficulty_unlocked(character: Dictionary, diff: int) -> bool:
	return int(character.get("stats", {}).get("wins", 0)) >= DIFFICULTY_WINS[clampi(diff, 1, 4)]


static func difficulty_text(diff: int) -> String:
	if diff <= 1:
		return "Standard."
	return "Gegner mit mehr Leben und Schaden, mehr Elitegegner. Benötigt %d Siege." % DIFFICULTY_WINS[clampi(diff, 1, 4)]
