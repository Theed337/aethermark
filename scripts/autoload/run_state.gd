extends Node
## Konfiguration und Ergebnis des aktuellen Runs. Enthält die Gruppenskalierung.

var area_id: String = "emerald_forest"
var difficulty: int = 1            # 1 = normal, 2..4 = schwerer
var party_size: int = 1            # Phase 1: lokal 1; Phase 2 verbindet echte Spieler
var quick_mode: bool = false       # verkürzte Eskalation (Tests/Demo)
var test_quick: bool = false       # Tests: auch Gruppen-Runs verkürzen
var bot_mode: bool = false         # Autoplay für automatisierte Tests
var bot_damage_scale: float = 1.0
var auto_quit: bool = false        # Test: Spiel nach dem Ergebnis beenden
var seed_value: int = 0
var last_result: Dictionary = {}
var last_summary: Dictionary = {}


func start_run(area: String, diff: int = 1) -> void:
	area_id = area
	difficulty = diff
	seed_value = randi()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func finish_run(result: Dictionary) -> void:
	last_result = result
	var c := SaveSystem.active_character()
	last_summary = Progression.apply_results(c, result)
	SaveSystem.save_game()


## Gruppenskalierung: nicht nur Lebenspunkte, auch Schaden, Gruppengrößen, Spawn-Obergrenze,
## Elite-Chance und zusätzliche Verhaltensweisen (Flankieren ab 3 Spielern).
static func scaling(players: int, diff: int, avg_power: float = 1.0, area: String = "emerald_forest") -> Dictionary:
	var extra := maxi(players - 1, 0)
	var ad := float(GameData.area_by_id(area).get("difficulty", 1)) - 1.0   # Gebietsstufe: spätere Gebiete sind härter
	return {
		"hp_mult": (1.0 + 0.55 * extra + 0.25 * (diff - 1) + 0.22 * ad) * clampf(avg_power, 0.8, 1.6),
		"dmg_mult": 1.0 + 0.10 * extra + 0.18 * (diff - 1) + 0.08 * ad,
		"spawn_cap": mini(22 + 5 * extra, 42),         # harte Obergrenze für Performance/Übersicht
		"group_bonus": extra / 2,                       # zusätzliche Gegner pro Gruppe
		"elite_bonus": 0.03 * extra,
		"flank": players >= 3,                          # Gegner umkreisen/flankieren
		"boss_hp_mult": 1.0 + 0.8 * extra + 0.3 * (diff - 1),
		"boss_adds": 1 + extra / 2,                     # Anzahl Begleiter bei Boss-Phase 2
	}
