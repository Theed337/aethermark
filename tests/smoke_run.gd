extends Node
## Automatischer Spieltest (Autoplay-Bot): spielt einen kompletten Run im Smaragdwald im Zeitraffer
## und prüft Bewegung, Kampf, Gegner, Erfahrung, Level-Ups, Fähigkeiten, Boss, Beute, Ergebnis und Speichern.
## Start:  godot --headless --path . res://tests/smoke_run.tscn -- [weapon] [seed]
## Exit-Code 0 = bestanden.

var arena: Node
var ok := true
var t := 0.0
var start_pos := Vector3.ZERO
var max_levels := 0
var saw_boss := false
var saw_shield := false
var saw_phase3 := false
var max_alive := 0
var max_moved := 0.0
var timeout := 600.0
var _last_log := -1


func check(c: bool, msg: String) -> void:
	if c:
		print("  OK     ", msg)
	else:
		ok = false
		printerr("  FEHLER ", msg)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var weapon: String = args[0] if args.size() > 0 else "sword"
	var seed_v: int = int(args[1]) if args.size() > 1 else 12345
	var area: String = args[2] if args.size() > 2 else "emerald_forest"
	SaveSystem.save_path = "user://smoke_save.json"
	for suf in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists("user://smoke_save.json" + suf):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.json" + suf))
	SaveSystem.data = SaveSystem.default_data()
	var c := SaveSystem.new_character("Testheld", SaveSystem.default_appearance())
	if weapon != "sword":
		var w := SaveSystem.starter_weapon()
		w["weapon_type"] = weapon
		w["slot"] = "weapon"
		w["name"] = weapon
		c["inventory"].append(w)
		SaveSystem.equip(c, w["uid"])
	RunState.area_id = area
	RunState.difficulty = 1
	RunState.quick_mode = true
	RunState.bot_mode = true
	RunState.bot_damage_scale = 0.12
	RunState.seed_value = seed_v
	Engine.time_scale = 3.0
	print("Smoke-Test: Waffe=%s Seed=%d Gebiet=%s" % [weapon, seed_v, area])
	arena = load("res://scenes/arena.tscn").instantiate()
	add_child(arena)
	start_pos = arena.player.global_position


func _process(delta: float) -> void:
	t += delta / Engine.time_scale
	if arena == null:
		return
	if int(t) % 5 == 0 and int(t) != _last_log:
		_last_log = int(t)
		print("  .. HP %.0f/%.0f" % [arena.player.hp, arena.player.stats["max_hp"]]); print("  .. real %ds | Spielzeit %.0f s | FPS %d | Gegner %d | Stufe %d" % [int(t), arena.run_time, Engine.get_frames_per_second(), get_tree().get_nodes_in_group("enemies").size(), arena.player.level])
		if arena.boss != null and is_instance_valid(arena.boss):
			var b = arena.boss
			print("     Boss hp %.0f/%.0f Phase %d Schild %s busy %s Adds %d Abstand %.1f" % [b.hp, b.max_hp, b.phase, str(b.shielded), str(b.busy), b.adds.size(), b.global_position.distance_to(arena.player.global_position)])
	var p: Player = arena.player
	max_levels = maxi(max_levels, p.level)
	max_moved = maxf(max_moved, p.global_position.distance_to(start_pos))
	max_alive = maxi(max_alive, get_tree().get_nodes_in_group("enemies").size())
	if arena.boss != null and is_instance_valid(arena.boss):
		saw_boss = true
		saw_shield = saw_shield or arena.boss.shielded
		saw_phase3 = saw_phase3 or arena.boss.phase == 3
	if arena.finished or t > timeout:
		_report()


func _report() -> void:
	set_process(false)
	print("")
	print("Run beendet nach %.0f s Spielzeit (%.0f s real) | Spieler hp %.0f Zustand %s Schaden erlitten %.0f" % [arena.run_time, t, arena.player.hp, arena.player.state, arena.player.run_stats["damage_taken"]])
	var p: Player = arena.player
	var rs: Dictionary = p.run_stats.duplicate()
	rs["boss_defeated"] = arena.run_stats["boss_defeated"]
	check(max_moved > 5.0, "Spieler hat sich bewegt (max. %.1f m vom Start)" % max_moved)
	check(rs["kills"] > 20, "Gegner besiegt: %d" % rs["kills"])
	check(rs["damage_dealt"] > 500.0, "Schaden verursacht: %d" % int(rs["damage_dealt"]))
	check(max_levels >= 4, "Levelaufstiege: Stufe %d" % max_levels)
	check(p.levels.size() >= 3, "Fähigkeiten gewählt: %s" % str(p.levels))
	check(p.skill_slots.size() >= 1, "Aktive Fähigkeit(en) im Einsatz: %s" % str(p.skill_slots))
	check(max_alive > 3, "Gleichzeitig aktive Gegner (max %d, Obergrenze %d)" % [max_alive, arena.scaling["spawn_cap"]])
	check(max_alive <= arena.scaling["spawn_cap"] + 8, "Spawn-Obergrenze eingehalten")
	check(saw_boss, "Boss ist erschienen")
	check(arena.finished, "Run wurde beendet")
	check(rs["boss_defeated"], "Boss besiegt")
	check(saw_shield, "Boss-Phase 2 (Schutzbarriere) wurde erreicht")
	check(saw_phase3, "Boss-Phase 3 wurde erreicht")
	check(rs["items"].size() > 0, "Beute gesammelt: %d Gegenstände" % rs["items"].size())
	var c := SaveSystem.active_character()
	check(c["stats"]["runs"] == 1, "Run im Spielstand gespeichert")
	check(c["talent_points"] > 3, "Talentpunkte erhalten (%d)" % c["talent_points"])
	check(RunState.area_id in c["cleared_areas"] or not rs["boss_defeated"], "Gebiet als abgeschlossen vermerkt")
	check(RunState.area_id != "emerald_forest" or "sunken_ruins" in c["unlocked_areas"] or not rs["boss_defeated"], "Nächstes Gebiet freigeschaltet")
	var reloaded := SaveSystem.load_game()
	check(reloaded and SaveSystem.active_character()["stats"]["runs"] == 1, "Spielstand lässt sich neu laden")
	print("")
	print("Smoke-Test: ", "BESTANDEN" if ok else "FEHLGESCHLAGEN")
	get_tree().quit(0 if ok else 1)
