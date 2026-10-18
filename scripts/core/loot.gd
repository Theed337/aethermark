class_name Loot
extends RefCounted
## Beute-Erzeugung (deterministisch mit übergebenem RNG -> testbar).


static func roll_rarity(rng: RandomNumberGenerator, bonus: float = 1.0, min_rarity: String = "common") -> String:
	var rar: Dictionary = GameData.items_cfg["rarities"]
	var order := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
	var total := 0.0
	var ws: Dictionary = {}
	for r in order:
		if order.find(r) < order.find(min_rarity):
			continue
		var w: float = float(rar[r]["weight"])
		if r != "common":
			w *= bonus
		ws[r] = w
		total += w
	var x := rng.randf() * total
	for r in ws:
		x -= ws[r]
		if x <= 0.0:
			return r
	return "common"


static func roll_item(rng: RandomNumberGenerator, item_level: int, bonus: float = 1.0, min_rarity: String = "common", force_slot: String = "") -> Dictionary:
	var rarity := roll_rarity(rng, bonus, min_rarity)
	# Legendäre/mythische Treffer: Chance auf ein einzigartiges Artefakt
	if rarity in ["legendary", "mythic"]:
		var uniques: Array = GameData.items_cfg["uniques"].filter(func(u): return u["rarity"] == rarity and u["id"] != "wardens_blade" and (force_slot == "" or u["slot"] == force_slot))
		if not uniques.is_empty():
			return from_unique(uniques[rng.randi() % uniques.size()], item_level)
	var bases: Array = GameData.items_cfg["bases"]
	if force_slot != "":
		bases = bases.filter(func(b): return b["slot"] == force_slot)
	var base: Dictionary = bases[rng.randi() % bases.size()]
	return build_item(rng, base, rarity, item_level)


static func build_item(rng: RandomNumberGenerator, base: Dictionary, rarity: String, item_level: int) -> Dictionary:
	var cfg: Dictionary = GameData.items_cfg
	var rcfg: Dictionary = cfg["rarities"][rarity]
	var mult: float = float(rcfg["mult"]) * (1.0 + 0.06 * float(item_level - 1))
	var stats: Dictionary = {}
	for k in base["base"]:
		stats[k] = _scaled(float(base["base"][k]), mult, k)
	var pool: Dictionary = cfg["affix_pool"][base.get("pool", "armor")]
	var keys: Array = pool.keys()
	# Waffentyp beeinflusst sinnvolle Affixe
	var wt: String = base.get("weapon_type", "")
	if wt != "":
		if wt in ["sword", "axe", "hammer", "dagger"]:
			keys.erase("ranged_dmg_pct")
		elif wt == "bow":
			keys.erase("melee_dmg_pct")
		elif wt == "staff":
			keys.erase("melee_dmg_pct")
			keys.erase("ranged_dmg_pct")
	var affixes: Array = []
	var n: int = int(rcfg["affixes"])
	var tries := 0
	while affixes.size() < n and tries < 50 and not keys.is_empty():
		tries += 1
		var k: String = keys[rng.randi() % keys.size()]
		if k in affixes:
			continue
		affixes.append(k)
		var rng_r: Array = pool[k]
		var v: float = rng.randf_range(float(rng_r[0]), float(rng_r[1])) * mult
		stats[k] = float(stats.get(k, 0.0)) + _scaled(v, 1.0, k)
	var item := {
		"uid": _uid(rng), "base_id": base["id"], "name": _make_name(rng, base, rarity, affixes),
		"slot": base["slot"], "rarity": rarity, "stats": stats, "level": item_level,
		"tradable": true, "locked": false, "text": "",
	}
	if wt != "":
		item["weapon_type"] = wt
	return item


static func from_unique(u: Dictionary, item_level: int) -> Dictionary:
	var stats: Dictionary = u["stats"].duplicate(true)
	var it := {
		"uid": "u%d_%d" % [Time.get_ticks_usec(), randi() % 1000000], "base_id": u["id"], "name": u["name"], "slot": u["slot"],
		"rarity": u["rarity"], "stats": stats, "level": item_level, "tradable": true, "locked": false, "text": u.get("text", ""),
		"unique": true,
	}
	if u.has("weapon_type"):
		it["weapon_type"] = u["weapon_type"]
	return it


static func _scaled(v: float, mult: float, key: String) -> float:
	var x := v * mult
	var pct: Array = GameData.items_cfg.get("pct_stats", [])
	if key in pct or key == "hp_regen" or key == "dodge_iframes":
		return snappedf(x, 0.001)
	return roundf(x)


static func _uid(rng: RandomNumberGenerator) -> String:
	return "i%d_%d" % [Time.get_ticks_usec(), rng.randi()]


const PREFIX := {
	"damage": "Scharfer", "crit_chance": "Präziser", "crit_mult": "Tödlicher", "attack_speed_pct": "Flinker",
	"melee_dmg_pct": "Wuchtiger", "elem_dmg_pct": "Glühender", "ranged_dmg_pct": "Treffsicherer", "lifesteal": "Durstiger",
	"max_hp": "Robuster", "defense": "Gepanzerter", "max_hp_pct": "Zäher", "move_speed_pct": "Leichter", "hp_regen": "Belebender",
	"dodge_iframes": "Gewandter", "cooldown_reduction": "Zeitloser", "mana_regen_pct": "Fließender", "mana_max": "Tiefer",
	"summon_dmg_pct": "Rufender", "heal_power_pct": "Heilender", "area_pct": "Weiter", "damage_pct": "Mächtiger",
}


static func _make_name(rng: RandomNumberGenerator, base: Dictionary, rarity: String, affixes: Array) -> String:
	var nm: String = base["name"]
	if affixes.is_empty() or rarity == "common":
		return nm
	var pre: String = PREFIX.get(affixes[0], "Alter")
	var out := "%s %s" % [pre, nm]
	if rarity in ["rare", "epic", "legendary", "mythic"]:
		var suffixes := ["des Smaragdwaldes", "der Wurzeln", "der alten Eiche", "des Morgentaus", "der Glühwürmer", "des Moosherrn"]
		out += " " + suffixes[rng.randi() % suffixes.size()]
	return out


static func item_tooltip(item: Dictionary) -> String:
	var labels: Dictionary = GameData.items_cfg.get("stat_labels", {})
	var pct: Array = GameData.items_cfg.get("pct_stats", [])
	var lines: Array = []
	for k in item.get("stats", {}):
		if k == "flags":
			for f in item["stats"][k]:
				lines.append(TalentTree.flag_text(f))
			continue
		var v: float = float(item["stats"][k])
		var sign := "+" if v >= 0.0 else ""
		if k in pct:
			lines.append("%s%.1f%% %s" % [sign, v * 100.0, str(labels.get(k, k)).replace(" %", "")])
		else:
			lines.append("%s%s %s" % [sign, TalentTree._fmt(v), labels.get(k, k)])
	var t: String = "\n".join(lines)
	if item.get("text", "") != "":
		t += "\n" + item["text"]
	return t


## Vergleich zweier Items: gibt pro Stat {a, b, diff} zurück.
static func compare(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = []
	for k in a.get("stats", {}):
		if k != "flags" and not (k in keys):
			keys.append(k)
	for k in b.get("stats", {}):
		if k != "flags" and not (k in keys):
			keys.append(k)
	for k in keys:
		var va: float = float(a.get("stats", {}).get(k, 0.0))
		var vb: float = float(b.get("stats", {}).get(k, 0.0))
		out[k] = {"a": va, "b": vb, "diff": vb - va}
	return out
