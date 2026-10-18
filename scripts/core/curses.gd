class_name Curses
extends RefCounted
## Endgame-Flüche: Ab Schwierigkeit "Albtraum" (3) erhält jeder Run zufällige Flüche (Albtraum 1, Inferno 2).
## Sie machen den Run härter, dafür steigt die Beutequalität. Der Host würfelt sie aus dem Seed, Clients sehen sie als Banner.

const ALL := {
	"swift": {"name": "Hetzjagd", "desc": "Gegner sind 20 % schneller", "speed_mult": 1.2},
	"bloated": {"name": "Zähe Brut", "desc": "Gegner haben 30 % mehr Leben", "hp_mult": 1.3},
	"elite_tide": {"name": "Elitenflut", "desc": "Deutlich mehr Elitegegner", "elite_bonus": 0.12},
	"titan_blood": {"name": "Titanenblut", "desc": "Der Boss hat 25 % mehr Leben", "boss_hp_mult": 1.25},
	"bitter": {"name": "Bitterer Schlag", "desc": "Gegner verursachen 20 % mehr Schaden", "dmg_mult": 1.2},
}
const LOOT_BONUS_PER_CURSE := 0.25


static func count_for(difficulty: int) -> int:
	return clampi(difficulty - 2, 0, 2)


static func roll(difficulty: int, seed_value: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + 777
	var ids: Array = ALL.keys()
	var out: Array = []
	for i in count_for(difficulty):
		var id: String = ids[r.randi() % ids.size()]
		ids.erase(id)
		out.append(id)
	return out


## Wendet Flüche auf das Skalierungs-Dictionary an (ändert es direkt).
static func apply(ids: Array, scaling: Dictionary) -> void:
	scaling["speed_mult"] = 1.0
	for id in ids:
		var c: Dictionary = ALL[id]
		scaling["speed_mult"] *= float(c.get("speed_mult", 1.0))
		scaling["hp_mult"] *= float(c.get("hp_mult", 1.0))
		scaling["dmg_mult"] *= float(c.get("dmg_mult", 1.0))
		scaling["boss_hp_mult"] *= float(c.get("boss_hp_mult", 1.0))
		scaling["elite_bonus"] += float(c.get("elite_bonus", 0.0))


static func text(ids: Array) -> String:
	var parts: Array = []
	for id in ids:
		parts.append("%s (%s)" % [ALL[id]["name"], ALL[id]["desc"]])
	return "Flüche: " + ", ".join(parts)
