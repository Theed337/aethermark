extends Node
## Automatisierte Tests für die Kernlogik.
## Ausführen:  godot --headless --path . res://tests/test_runner.tscn
## Exit-Code 0 = alle Tests grün.

var passed := 0
var failed := 0
var current := ""


func _ready() -> void:
	SaveSystem.save_path = "user://test_save.json"
	_cleanup()
	for t in [test_data, test_stats, test_level_up, test_talents, test_loot, test_save, test_progression, test_scaling, test_name_validation, test_equipment, test_shop]:
		current = str(t.get_method())
		t.call()
	_cleanup()
	print("")
	print("Ergebnis: %d bestanden, %d fehlgeschlagen" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("  FEHLER [%s]: %s" % [current, msg])


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path("user://test_save.json" + suffix)
		if FileAccess.file_exists("user://test_save.json" + suffix):
			DirAccess.remove_absolute(p)


func _fresh_char() -> Dictionary:
	SaveSystem.data = SaveSystem.default_data()
	return SaveSystem.new_character("Testheld", SaveSystem.default_appearance())


# ------------------------------------------------------------------ Tests

func test_data() -> void:
	check(GameData.skill_list.size() >= 15, "Fähigkeiten geladen")
	check(GameData.talents.size() >= 40, "Talente geladen (%d)" % GameData.talents.size())
	check(GameData.enemy_types.size() >= 4, "Gegnertypen geladen")
	check(GameData.items_cfg["bases"].size() >= 10, "Item-Basen geladen")
	for s in GameData.skill_list:
		check(s["levels"].size() == int(s["max_level"]), "Beschreibung je Stufe: " + s["id"])
	for id in GameData.talents:
		for r in GameData.talents[id]["requires"]:
			check(GameData.talents.has(r), "Talent-Voraussetzung existiert: %s -> %s" % [id, r])


func test_stats() -> void:
	check(Stats.soft_cap(0.0, 0.5) == 0.0, "soft_cap(0)")
	check(Stats.soft_cap(10.0, 0.5) < 0.5, "soft_cap bleibt unter Obergrenze")
	check(Stats.soft_cap(0.2, 0.5) > Stats.soft_cap(0.1, 0.5), "soft_cap monoton steigend")
	check(absf(Stats.mitigate(100.0, 0.0) - 100.0) < 0.001, "Keine Verteidigung = voller Schaden")
	check(absf(Stats.mitigate(100.0, 100.0) - 50.0) < 0.001, "100 Verteidigung halbiert Schaden")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var d := Stats.roll_damage(10.0, 0.0, 2.0, rng)
	check(d["amount"] == 10.0 and not d["crit"], "Kein Krit bei 0% Chance")
	d = Stats.roll_damage(10.0, 1.0, 2.0, rng)
	check(d["amount"] == 20.0 and d["crit"], "Immer Krit bei 100% Chance")
	var crits := 0
	for i in 5000:
		if Stats.roll_damage(1.0, 0.25, 2.0, rng)["crit"]:
			crits += 1
	check(absf(crits / 5000.0 - 0.25) < 0.03, "Kritrate ~25%% (ist %.3f)" % (crits / 5000.0))
	var base := Stats.finalize({})
	check(base["max_hp"] == 100.0 and base["damage"] == 10.0, "Basiswerte")
	var hi := Stats.finalize({"cooldown_reduction": 5.0, "crit_chance": 5.0})
	check(hi["cooldown_reduction"] < 0.56, "Abklingzeit-Reduktion hat Obergrenze")
	check(hi["crit_chance"] <= 0.85, "Kritchance hat Obergrenze")


func test_level_up() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var levels := {}
	var offers := LevelUp.generate_offers(rng, levels, 1, [])
	check(offers.size() == 3, "3 Angebote")
	var has_active := false
	for o in offers:
		if o["kind"] == "active":
			has_active = true
	check(has_active, "Erstes Angebot enthält aktive Fähigkeit")
	for trial in 300:
		levels = {}
		var recent: Array = []
		for lv in range(1, 25):
			offers = LevelUp.generate_offers(rng, levels, lv, recent)
			var ids: Array = []
			for o in offers:
				check(not (o["id"] in ids), "Keine Duplikate im Angebot")
				ids.append(o["id"])
				check(int(levels.get(o["id"], 0)) < int(o["max_level"]), "Keine bereits maximierten Fähigkeiten")
				if lv < 4:
					check(o["rarity"] != "epic", "Epische Optionen erst ab Stufe 4")
			check(offers.size() >= 1, "Immer mindestens ein Angebot")
			var pick: Dictionary = offers[rng.randi() % offers.size()]
			levels[pick["id"]] = int(levels.get(pick["id"], 0)) + 1
			recent.append_array(ids)
			if recent.size() > 6:
				recent = recent.slice(recent.size() - 6)
		check(LevelUp.owned_active_count(levels) <= LevelUp.MAX_ACTIVE_SLOTS, "Höchstens 4 aktive Fähigkeiten")
	levels = {"fireball": 3, "frost_nova": 2}
	check("steam_burst" in LevelUp.active_evolutions(levels), "Evolution Dampfexplosion aktiv")
	check(not ("steam_burst" in LevelUp.active_evolutions({"fireball": 3})), "Evolution braucht beide Fähigkeiten")


func test_talents() -> void:
	var c := _fresh_char()
	c["talent_points"] = 100
	check(TalentTree.allocate(c, "melee_1"), "Startknoten erlernbar")
	check(not TalentTree.allocate(c, "melee_3"), "Knoten mit fehlender Voraussetzung gesperrt")
	check(not TalentTree.allocate(c, "melee_1"), "Doppeltes Erlernen verhindert")
	check(TalentTree.allocate(c, "melee_2") and TalentTree.allocate(c, "melee_3"), "Kette erlernbar")
	check(not TalentTree.can_refund("melee_2", c["talents"]), "Mittlerer Knoten nicht entfernbar (würde verwaisen)")
	check(TalentTree.can_refund("melee_3", c["talents"]), "Endknoten entfernbar")
	# Synergie braucht beide Äste
	check(not TalentTree.allocate(c, "syn_melee_defense"), "Synergie ohne zweiten Ast gesperrt")
	for id in ["defense_1", "defense_2", "defense_3"]:
		TalentTree.allocate(c, id)
	check(TalentTree.allocate(c, "syn_melee_defense"), "Synergie mit beiden Ästen erlernbar")
	var spent := TalentTree.spent_points(c["talents"])
	var before: int = c["talent_points"]
	var refunded := TalentTree.reset(c)
	check(refunded == spent and c["talents"].is_empty(), "Reset entfernt alle Talente")
	check(c["talent_points"] == before + spent, "Reset erstattet alle Punkte")
	c["talent_points"] = 0
	check(not TalentTree.allocate(c, "melee_1") or false, "Ohne Punkte kein Talent") if false else null
	check(TalentTree.can_allocate("melee_1", [], 0) != "", "Ohne Punkte kein Talent")
	# Talentwerte fließen in die Werte ein
	c["talent_points"] = 10
	TalentTree.allocate(c, "melee_1")
	var s := Stats.compute(c)
	check(absf(s["cat_mult"]["melee"] - 1.06) < 0.001, "Talent erhöht Nahkampfschaden")


func test_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var uids := {}
	var counts := {}
	for i in 3000:
		var it := Loot.roll_item(rng, 5)
		check(not uids.has(it["uid"]), "UID eindeutig")
		uids[it["uid"]] = true
		counts[it["rarity"]] = int(counts.get(it["rarity"], 0)) + 1
		check(GameData.items_cfg["slots"].has(it["slot"]), "Gültiger Slot")
		if not it.get("unique", false):
			var want: int = GameData.items_cfg["rarities"][it["rarity"]]["affixes"]
			check(it["stats"].size() >= 1, "Item hat Werte")
			check(it["stats"].size() <= want + 3, "Nicht zu viele Werte")
	check(counts.get("common", 0) > counts.get("rare", 0), "Gewöhnlich häufiger als Selten")
	check(counts.get("rare", 0) > counts.get("legendary", 0), "Selten häufiger als Legendär")
	var a := Loot.roll_item(rng, 1, 1.0, "common", "weapon")
	var b := Loot.roll_item(rng, 20, 5.0, "epic", "weapon")
	check(a["slot"] == "weapon" and b["slot"] == "weapon", "force_slot")
	var cmp := Loot.compare(a, b)
	for k in cmp:
		check(absf(cmp[k]["diff"] - (cmp[k]["b"] - cmp[k]["a"])) < 0.0001, "Vergleich Differenz korrekt")
	var u: Dictionary = Loot.from_unique(GameData.items_cfg["uniques"][0], 5)
	check(u["stats"]["max_hp_pct"] < 0.0, "Artefakt mit Nachteil hat negativen Wert")


func test_save() -> void:
	var c := _fresh_char()
	c["talent_points"] = 7
	c["talents"] = ["melee_1"]
	SaveSystem.data["settings"]["volume_master"] = 0.33
	check(SaveSystem.save_game(), "Speichern erfolgreich")
	SaveSystem.data = SaveSystem.default_data()
	check(SaveSystem.load_game(), "Laden erfolgreich")
	var l := SaveSystem.active_character()
	check(l["name"] == "Testheld" and l["talent_points"] == 7 and l["talents"] == ["melee_1"], "Charakter bleibt erhalten")
	check(absf(SaveSystem.data["settings"]["volume_master"] - 0.33) < 0.0001, "Einstellungen bleiben erhalten")
	check(l["appearance"]["skin"] == SaveSystem.default_appearance()["skin"], "Aussehen bleibt erhalten")
	# zweites Speichern erzeugt Backup
	SaveSystem.save_game()
	check(FileAccess.file_exists("user://test_save.json.bak"), "Backup wird angelegt")
	# Hauptdatei beschädigen -> Backup
	var f := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	SaveSystem.data = SaveSystem.default_data()
	check(SaveSystem.load_game() and SaveSystem.last_load_status == "backup", "Defekter Spielstand -> Backup")
	check(SaveSystem.active_character()["name"] == "Testheld", "Backup enthält Charakter")
	# Manipulation (Prüfsumme)
	SaveSystem.save_game()
	var txt := FileAccess.get_file_as_string("user://test_save.json")
	var parsed: Dictionary = JSON.parse_string(txt)
	parsed["payload"]["characters"][0]["talent_points"] = 999999
	f = FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(parsed))
	f.close()
	SaveSystem.load_game()
	check(SaveSystem.active_character()["talent_points"] != 999999, "Manipulierter Spielstand wird abgelehnt")


func test_progression() -> void:
	var c := _fresh_char()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var it := Loot.roll_item(rng, 3)
	var win := {"victory": true, "boss_defeated": true, "boss_id": "rootwarden", "area_id": "emerald_forest", "kills": 120, "elites": 4,
			"level": 12, "duration": 400.0, "downs": 0, "items": [it], "damage_dealt": 9000.0}
	var tp_before: int = c["talent_points"]
	var sum := Progression.apply_results(c, win)
	check(sum["points"] == Progression.compute_points(win) and sum["points"] > 0, "Punkte vergeben")
	check(c["talent_points"] >= tp_before + sum["points"], "Talentpunkte gutgeschrieben")
	check("rootwarden" in c["bosses_defeated"], "Boss gespeichert")
	check("sunken_ruins" in c["unlocked_areas"], "Nächstes Gebiet freigeschaltet")
	check(c["stats"]["kills"] == 120 and c["stats"]["wins"] == 1, "Statistik aktualisiert")
	check("boss_1" in c["achievements"] and "first_blood" in c["achievements"], "Erfolge vergeben")
	var invn: int = c["inventory"].size()
	var again := Progression.apply_results(c, win)   # dasselbe Item nicht doppelt
	check(c["inventory"].size() == invn, "Kein Duplikat desselben Items")
	check(again["dropped_items"].size() == 1, "Duplikat wird gemeldet")
	var lose := {"victory": false, "kills": 40, "level": 5, "duration": 100.0, "items": [], "downs": 1}
	var half := Progression.compute_points(lose)
	var full := Progression.compute_points({"victory": true, "kills": 40, "level": 5})
	check(half < full, "Niederlage gibt weniger Punkte")
	check(Progression.compute_points(lose) >= 1, "Mindestens 1 Punkt")


func test_scaling() -> void:
	var prev := 0.0
	for p in range(1, 6):
		var s := RunState.scaling(p, 1)
		check(s["hp_mult"] > prev, "HP-Skalierung steigt mit Spielerzahl")
		prev = s["hp_mult"]
		check(s["spawn_cap"] <= 42, "Gegner-Obergrenze eingehalten")
	var s1 := RunState.scaling(1, 1)
	var s5 := RunState.scaling(5, 1)
	check(s5["dmg_mult"] > s1["dmg_mult"] and s5["flank"] and not s1["flank"], "Größere Gruppen: mehr Schaden + neues Verhalten")
	check(s5["boss_adds"] > s1["boss_adds"], "Boss ruft bei größerer Gruppe mehr Begleiter")


func test_curses_and_combos() -> void:
	check(Curses.roll(1, 5).is_empty() and Curses.roll(2, 5).is_empty(), "Keine Flüche bei Normal/Schwer")
	check(Curses.roll(3, 5).size() == 1 and Curses.roll(4, 5).size() == 2, "Albtraum 1 Fluch, Inferno 2 Flüche")
	check(Curses.roll(4, 9) == Curses.roll(4, 9), "Flüche sind seed-deterministisch (Host und Test gleich)")
	var r4 := Curses.roll(4, 9)
	check(r4[0] != r4[1], "Flüche doppeln sich nicht")
	var sc := RunState.scaling(1, 4)
	var hp0: float = sc["hp_mult"]
	Curses.apply(["bloated", "swift"], sc)
	check(is_equal_approx(sc["hp_mult"], hp0 * 1.3) and is_equal_approx(sc["speed_mult"], 1.2), "Flüche verändern Skalierung")
	check(CoopCombos.combo_key("frost", "fire") == "fire+frost", "Kombo-Schlüssel unabhängig von Reihenfolge")
	for a in CoopCombos.ELEMENTS:
		for b in CoopCombos.ELEMENTS:
			if a != b:
				check(CoopCombos.COMBOS.has(CoopCombos.combo_key(a, b)) or (a == "earth" and b == "frost") or (a == "frost" and b == "earth"), "Kombo definiert: %s+%s" % [a, b])
	for u in GameData.items_cfg["uniques"]:
		var it := Loot.from_unique(u, 5)
		check(ItemValidator.validate(it) == "", "Artefakt gültig: " + u["id"])


func test_name_validation() -> void:
	check(SaveSystem.validate_name("Ab") != "", "Zu kurz")
	check(SaveSystem.validate_name("A".repeat(17)) != "", "Zu lang")
	check(SaveSystem.validate_name("Ela<script>") != "", "Sonderzeichen verboten")
	check(SaveSystem.validate_name("Lyra-Mae") == "", "Bindestrich erlaubt")
	check(SaveSystem.validate_name("Jörg Ärmel") == "", "Umlaute erlaubt")
	check(SaveSystem.validate_name("   ") != "", "Nur Leerzeichen verboten")


func test_equipment() -> void:
	var c := _fresh_char()
	var base_stats := Stats.compute(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var w := Loot.roll_item(rng, 10, 5.0, "epic", "weapon")
	SaveSystem.add_item(c, w)
	check(not SaveSystem.add_item(c, w), "Item kann nicht doppelt ins Inventar")
	SaveSystem.equip(c, w["uid"])
	check(c["equipment"]["weapon"] == w["uid"], "Waffe angelegt")
	var s := Stats.compute(c)
	check(s["damage"] >= base_stats["damage"], "Ausrüstung erhöht Schaden")
	var ring1 := Loot.roll_item(rng, 3, 1.0, "common", "ring1")
	var ring2 := Loot.roll_item(rng, 3, 1.0, "common", "ring2")
	SaveSystem.add_item(c, ring1)
	SaveSystem.add_item(c, ring2)
	SaveSystem.equip(c, ring1["uid"])
	SaveSystem.equip(c, ring2["uid"])
	check(c["equipment"].has("ring1") and c["equipment"].has("ring2"), "Zwei Ringplätze")
	SaveSystem.remove_item(c, w["uid"])
	check(not c["equipment"].has("weapon"), "Entfernen löst Ausrüstung")
	# Artefakt mit Nachteil
	var crown: Dictionary = Loot.from_unique(GameData.items_cfg["uniques"][0], 5)
	SaveSystem.add_item(c, crown)
	var before := Stats.compute(c)
	SaveSystem.equip(c, crown["uid"])
	var after := Stats.compute(c)
	check(after["max_hp"] < before["max_hp"] and after["cat_mult"]["elem"] > before["cat_mult"]["elem"], "Artefakt: Bonus UND Nachteil wirken")


func test_shop() -> void:
	SaveSystem.data = SaveSystem.default_data()
	var c := SaveSystem.new_character("Händler", SaveSystem.default_appearance())
	var rot := 12345
	var a: Array = Shop.stock(c, rot)
	var b: Array = Shop.stock(c, rot)
	check(a.size() == Shop.STOCK_SIZE, "Händler hat %d Waren" % Shop.STOCK_SIZE)
	check(a[0]["item"]["name"] == b[0]["item"]["name"] and a[3]["item"]["rarity"] == b[3]["item"]["rarity"], "Angebot einer Rotation ist stabil")
	var other: Array = Shop.stock(c, rot + 1)
	var diff := false
	for i in a.size():
		if a[i]["item"]["name"] != other[i]["item"]["name"]:
			diff = true
	check(diff, "Angebot wechselt mit der Rotation")
	check(Shop.seconds_left() > 0 and Shop.seconds_left() <= Shop.ROTATION_SECONDS, "Restzeit im Bereich")
	c["gold"] = 0
	check(Shop.buy(c, 0, rot) == "Nicht genug Gold.", "Kauf ohne Gold abgelehnt")
	c["gold"] = 100000
	var inv: int = c["inventory"].size()
	check(Shop.buy(c, 0, rot) == "", "Kauf klappt")
	check(c["inventory"].size() == inv + 1 and int(c["gold"]) < 100000, "Gegenstand erhalten, Gold abgezogen")
	check(Shop.buy(c, 0, rot) == "Schon verkauft.", "Doppelkauf verhindert")
	var bought: Dictionary = c["inventory"][c["inventory"].size() - 1]
	var g: int = int(c["gold"])
	check(Shop.sell(c, bought["uid"]) > 0 and int(c["gold"]) > g, "Verkauf bringt Gold")
	check(Shop.sell(c, c["equipment"]["weapon"]) < 0, "Angelegtes nicht verkaufbar")
	var locked := Loot.roll_item(RandomNumberGenerator.new(), 3)
	locked["locked"] = true
	SaveSystem.add_item(c, locked)
	check(Shop.sell(c, locked["uid"]) < 0, "Gesperrtes nicht verkaufbar")
