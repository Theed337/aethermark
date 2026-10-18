class_name Stats
extends RefCounted
## Zentrale, testbare Kampf- und Wertelogik (keine Szenenabhängigkeit).

const BASE := {
	"max_hp": 100.0, "damage": 10.0, "crit_chance": 0.05, "crit_mult": 1.5, "move_speed": 6.0,
	"mana_max": 100.0, "mana_regen": 7.0, "hp_regen": 0.0, "defense": 0.0, "lifesteal": 0.0,
	"dodge_iframes": 0.32,
}


static func soft_cap(x: float, cap: float) -> float:
	## Abnehmende Skalierung: nähert sich 'cap' asymptotisch.
	if x <= 0.0:
		return x
	return cap * (1.0 - exp(-x / cap))


static func merge(acc: Dictionary, src: Dictionary) -> void:
	for k in src:
		var v: Variant = src[k]
		if v is Array:
			if not acc.has(k):
				acc[k] = []
			acc[k].append_array(v)
		else:
			acc[k] = float(acc.get(k, 0.0)) + float(v)


static func compute(character: Dictionary, run_mods: Dictionary = {}) -> Dictionary:
	## Berechnet die endgültigen Werte aus Talenten, Ausrüstung und Run-Modifikatoren.
	var acc: Dictionary = {}
	for id in character.get("talents", []):
		var node: Dictionary = GameData.talents.get(id, {})
		if not node.is_empty():
			merge(acc, node.get("effects", {}))
	# Herkunft: kleine, feste Boni (keine Klasse – nur eine Würze für den Build)
	var origin: Dictionary = GameData.origins.get(character.get("appearance", {}).get("origin", "human"), {})
	merge(acc, origin.get("effects", {}))
	var inv: Array = character.get("inventory", [])
	var eq: Dictionary = character.get("equipment", {})
	for slot in eq:
		for it in inv:
			if it["uid"] == eq[slot]:
				merge(acc, it.get("stats", {}))
				break
	merge(acc, run_mods)
	return finalize(acc, int(character.get("meta_level", 1)))


static func finalize(acc: Dictionary, meta_level: int = 1) -> Dictionary:
	var s: Dictionary = {}
	var lvl_bonus := 1.0 + 0.01 * float(maxi(meta_level - 1, 0))
	s["max_hp"] = maxf(20.0, (BASE["max_hp"] + acc.get("max_hp", 0.0)) * (1.0 + acc.get("max_hp_pct", 0.0)) * lvl_bonus)
	s["damage"] = (BASE["damage"] + acc.get("damage", 0.0)) * (1.0 + acc.get("damage_pct", 0.0)) * lvl_bonus
	s["crit_chance"] = clampf(BASE["crit_chance"] + soft_cap(acc.get("crit_chance", 0.0), 0.6), 0.0, 0.85)
	s["crit_mult"] = BASE["crit_mult"] + acc.get("crit_mult", 0.0)
	s["move_speed"] = BASE["move_speed"] * (1.0 + clampf(acc.get("move_speed_pct", 0.0), -0.5, 0.6))
	s["attack_speed"] = 1.0 + soft_cap(acc.get("attack_speed_pct", 0.0), 0.8)
	s["defense"] = BASE["defense"] + acc.get("defense", 0.0)
	s["cooldown_reduction"] = soft_cap(acc.get("cooldown_reduction", 0.0), 0.55)
	s["area"] = 1.0 + acc.get("area_pct", 0.0)
	s["lifesteal"] = clampf(BASE["lifesteal"] + acc.get("lifesteal", 0.0), 0.0, 0.5)
	s["mana_max"] = BASE["mana_max"] + acc.get("mana_max", 0.0)
	s["mana_regen"] = BASE["mana_regen"] * (1.0 + acc.get("mana_regen_pct", 0.0))
	s["hp_regen"] = acc.get("hp_regen", 0.0)
	s["heal_power"] = 1.0 + acc.get("heal_power_pct", 0.0)
	s["dodge_iframes"] = BASE["dodge_iframes"] + acc.get("dodge_iframes", 0.0)
	s["pickup_radius"] = 3.0 * (1.0 + acc.get("pickup_radius_pct", 0.0))
	s["summon_count"] = int(acc.get("summon_count", 0.0))
	s["cat_mult"] = {
		"melee": 1.0 + acc.get("melee_dmg_pct", 0.0),
		"ranged": 1.0 + acc.get("ranged_dmg_pct", 0.0),
		"elem": 1.0 + acc.get("elem_dmg_pct", 0.0),
		"summon": 1.0 + acc.get("summon_dmg_pct", 0.0),
		"dot": 1.0 + acc.get("dot_dmg_pct", 0.0),
	}
	s["flags"] = acc.get("flags", [])
	return s


static func mitigate(amount: float, defense: float) -> float:
	## Verteidigung reduziert Schaden mit abnehmendem Ertrag (100 / (100 + Def)).
	return amount * 100.0 / (100.0 + maxf(defense, 0.0))


static func roll_damage(base: float, crit_chance: float, crit_mult: float, rng: RandomNumberGenerator, force_crit: bool = false) -> Dictionary:
	var crit := force_crit or rng.randf() < crit_chance
	var amount := base * (crit_mult if crit else 1.0)
	return {"amount": amount, "crit": crit}


static func level_cooldown(base_cd: float, cdr: float) -> float:
	return base_cd * (1.0 - cdr)
