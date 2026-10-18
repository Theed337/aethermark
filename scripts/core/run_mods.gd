class_name RunMods
extends RefCounted
## Übersetzt die in einer Runde gewählten Fähigkeiten-Stufen in Stat-Modifikatoren.
## Rein datenbasiert und testbar. Verhaltensänderungen (Evolutionen, Wisps, Frostwelle ...)
## liest der Spieler direkt aus den Stufen.


static func _lv(levels: Dictionary, id: String) -> int:
	return int(levels.get(id, 0))


static func build(levels: Dictionary) -> Dictionary:
	var m: Dictionary = {}
	var l: int
	l = _lv(levels, "crit_mastery")
	if l > 0:
		m["crit_mult"] = [0.25, 0.5, 0.75, 1.05][mini(l, 4) - 1]
		if l >= 3:
			m["crit_chance"] = 0.05
	l = _lv(levels, "vampiric")
	if l > 0:
		m["lifesteal"] = 0.03 * minf(l, 3.0)
	l = _lv(levels, "swift")
	if l > 0:
		m["move_speed_pct"] = [0.08, 0.16, 0.16, 0.26][mini(l, 4) - 1]
	l = _lv(levels, "vitality")
	if l > 0:
		m["max_hp"] = [25.0, 50.0, 75.0, 105.0, 145.0][mini(l, 5) - 1]
	l = _lv(levels, "arcane_focus")
	if l > 0:
		m["cooldown_reduction"] = [0.08, 0.16, 0.16, 0.24][mini(l, 4) - 1]
		if l >= 3:
			m["mana_regen_pct"] = 0.3
	l = _lv(levels, "wide_strikes")
	if l > 0:
		m["area_pct"] = 0.15 * minf(l, 3.0)
	l = _lv(levels, "iron_will")
	if l > 0:
		m["defense"] = [6.0, 12.0, 12.0][mini(l, 3) - 1]
	l = _lv(levels, "heal_aura")
	if l > 0:
		m["hp_regen"] = [1.5, 2.5, 3.5, 3.5][mini(l, 4) - 1]
	if _lv(levels, "heal_aura") >= 4:
		m["damage_pct"] = float(m.get("damage_pct", 0.0)) + 0.10
	if _lv(levels, "glass_cannon") > 0:
		m["damage_pct"] = float(m.get("damage_pct", 0.0)) + 0.45
		m["max_hp_pct"] = -0.25
	return m


## Kritischer Zusatz durch "Henker": Schaden gegen Gegner unter 30 % Leben.
static func executioner_mult(levels: Dictionary, target_hp_pct: float) -> float:
	var l := _lv(levels, "executioner")
	if l <= 0 or target_hp_pct >= 0.3:
		return 1.0
	return 1.0 + 0.25 * minf(l, 2.0)


static func executioner_forces_crit(levels: Dictionary, target_hp_pct: float) -> bool:
	return _lv(levels, "executioner") >= 3 and target_hp_pct < 0.3
