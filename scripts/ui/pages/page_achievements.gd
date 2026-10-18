class_name PageAchievements
extends MenuPage
## Erfolge (mit Fortschrittsbalken und Belohnungen) und persönliche Statistiken.


func build() -> void:
	var c := character()
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(title("Erfolge & Statistiken", "Erfolge geben Gold. Talentpunkte gibt es nur durch Charakterstufen im Hauptmenü."))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	var done := 0
	for a in GameData.achievements:
		if a["id"] in c["achievements"]:
			done += 1
	box.add_child(UI.label("Erfolge: %d / %d" % [done, GameData.achievements.size()], 20, UI.TEAL, true))
	for a in GameData.achievements:
		var got: bool = a["id"] in c["achievements"]
		var cur := mini(int(c["stats"].get(a["stat"], 0)), int(a["target"]))
		var p := UI.panel()
		p.add_theme_stylebox_override("panel", UI.box(Color("#18382f") if got else UI.PANEL, 10, UI.GOLD if got else Color("#2c4a68"), 2))
		box.add_child(p)
		var row := VBoxContainer.new()
		p.add_child(row)
		row.add_child(UI.label(("✓ " if got else "") + a["name"] + "   (+%d Gold)" % (int(a["reward_points"]) * 60), 17, UI.GOLD if got else UI.TEXT, true))
		row.add_child(UI.label(a["desc"], 14, UI.DIM))
		var bar := UI.bar(UI.GOLD if got else UI.TEAL, Vector2(0, 12))
		bar.max_value = a["target"]
		bar.value = cur
		row.add_child(bar)
		row.add_child(UI.label("%d / %d" % [cur, a["target"]], 13, UI.DIM))
	box.add_child(HSeparator.new())
	box.add_child(UI.label("Statistiken", 20, UI.TEAL, true))
	var st: Dictionary = c["stats"]
	var pt := int(st["playtime"])
	for row in [["Runs", st["runs"]], ["Siege", st["wins"]], ["Niederlagen", st["deaths"]], ["Besiegte Gegner", st["kills"]],
			["Besiegte Elitegegner", st["elites"]], ["Besiegte Bosse", st["bosses"]], ["Verursachter Schaden", int(st["damage_dealt"])],
			["Höchste Run-Stufe", st["best_run_level"]], ["Gefundene Gegenstände", st["items_found"]], ["Legendäre Funde", st["legendaries"]],
			["Makellose Siege", st["flawless_wins"]], ["Spielzeit", "%dh %02dm" % [pt / 3600, (pt % 3600) / 60]]]:
		var r := HBoxContainer.new()
		var l := UI.label(str(row[0]), 16, UI.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(UI.label(str(row[1]), 16))
		box.add_child(r)
