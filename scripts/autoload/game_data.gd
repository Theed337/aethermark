extends Node
## Lädt alle datengetriebenen Inhalte (Fähigkeiten, Gegner, Items, Talente, Gebiete).
## Neue Inhalte werden in den JSON-Dateien unter res://data ergänzt.

var skills: Dictionary = {}          # id -> Skill-Eintrag
var skill_list: Array = []
var skill_cfg: Dictionary = {}       # level_curve, rarity_weights, ...
var evolutions: Array = []
var enemy_types: Dictionary = {}
var elite_mods: Dictionary = {}
var boss: Dictionary = {}
var threat_tiers: Array = []
var items_cfg: Dictionary = {}
var talents: Dictionary = {}         # id -> Knoten
var talent_branches: Array = []
var talent_center: Array = [600, 420]
var areas: Array = []
var achievements: Array = []
var origins: Dictionary = {}
var origin_cfg: Dictionary = {}
var cosmetics: Array = []


func _ready() -> void:
	reload()


func reload() -> void:
	var s: Dictionary = _load_json("res://data/skills.json")
	skill_cfg = s
	skill_list = s.get("skills", [])
	evolutions = s.get("evolutions", [])
	skills.clear()
	for e in skill_list:
		skills[e["id"]] = e
	var en: Dictionary = _load_json("res://data/enemies.json")
	enemy_types = en.get("types", {})
	elite_mods = en.get("elite_mods", {})
	boss = en.get("boss", {})
	threat_tiers = en.get("threat_tiers", [])
	items_cfg = _load_json("res://data/items.json")
	var t: Dictionary = _load_json("res://data/talents.json")
	talents = t.get("nodes", {})
	talent_branches = t.get("branches", [])
	talent_center = t.get("center", [600, 420])
	var a: Dictionary = _load_json("res://data/areas.json")
	areas = a.get("areas", [])
	achievements = a.get("achievements", [])
	origin_cfg = _load_json("res://data/origins.json")
	origins = origin_cfg.get("origins", {})
	cosmetics = _load_json("res://data/cosmetics.json").get("items", [])


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Datei fehlt: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ungültiges JSON: %s" % path)
		return {}
	return parsed


func rarity_color(rarity: String) -> Color:
	var r: Dictionary = items_cfg.get("rarities", {}).get(rarity, {})
	return Color.html(r.get("color", "#ffffff"))


func rarity_name(rarity: String) -> String:
	return items_cfg.get("rarities", {}).get(rarity, {}).get("name", rarity)


var _base_types: Dictionary = {}
var _base_tiers: Array = []
var _bosses: Dictionary = {}
var active_area := ""


## Stellt Gegnerwerte, Bedrohungsstufen und Boss auf das Gebiet ein (Host und Client rufen das beim Laufstart auf).
func activate_area(area_id: String) -> void:
	if _base_types.is_empty():
		_base_types = enemy_types.duplicate(true)
		_base_tiers = threat_tiers.duplicate(true)
		_bosses = _load_json("res://data/enemies.json").get("bosses", {})
	var a := area_by_id(area_id)
	var types: Dictionary = _base_types.duplicate(true)
	for k in a.get("skins", {}):
		if types.has(k):
			for f in a["skins"][k]:
				types[k][f] = a["skins"][k][f]
	enemy_types = types
	threat_tiers = a["tiers"].duplicate(true) if a.has("tiers") else _base_tiers.duplicate(true)
	var bid: String = a.get("boss", "rootwarden")
	if _bosses.has(bid):
		boss = _bosses[bid].duplicate(true)
	active_area = area_id


func area_by_id(id: String) -> Dictionary:
	for a in areas:
		if a["id"] == id:
			return a
	return {}


func xp_needed(level: int) -> int:
	var c: Dictionary = skill_cfg.get("level_curve", {"base": 22, "per_level": 12, "quad": 1.6})
	return int(c["base"] + c["per_level"] * level + c["quad"] * level * level)
