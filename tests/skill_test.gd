extends Node
## Wirft alle Fähigkeiten auf Stufe 1..5 in einer Arena und prüft, dass nichts abstürzt und Schaden entsteht.
var arena: Node
var frames := 0
var stage := 0

func _ready() -> void:
	SaveSystem.save_path = "user://skill_save.json"
	SaveSystem.data = SaveSystem.default_data()
	SaveSystem.new_character("T", SaveSystem.default_appearance())
	RunState.area_id = "emerald_forest"
	RunState.difficulty = 1
	RunState.quick_mode = true
	RunState.seed_value = 7
	arena = load("res://scenes/arena.tscn").instantiate()
	add_child(arena)

func _process(_d: float) -> void:
	frames += 1
	var p: Player = arena.player
	if frames == 30:
		for s in GameData.skills.values():
			p.levels[s["id"]] = 5
		p.stats = Stats.compute(p.character, RunMods.build(p.levels))
		p.mana = 9999.0
		p.stats["mana_max"] = 9999.0
	if frames > 60 and frames % 20 == 0 and stage < 40:
		var ids: Array = []
		for s in GameData.skills.values():
			if s["kind"] == "active":
				ids.append(s["id"])
		var id: String = ids[stage % ids.size()]
		p.mana = 9999.0
		var before: float = p.run_stats["damage_dealt"]
		p.cast_skill(id, true)
		stage += 1
		print("cast ", id)
	if stage >= 40 and frames % 20 == 0:
		print("damage_dealt ", p.run_stats["damage_dealt"], " kills ", p.run_stats["kills"])
		get_tree().quit(0)
