class_name ResultScreen
extends Control
## Ergebnisbildschirm nach einem Run: Statistiken, Beute, Fortschritt, Freischaltungen.

signal continue_pressed


func show_result(result: Dictionary, summary: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UI.panel(Vector2(900, 0))
	center.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var win: bool = result.get("victory", false)
	var t := UI.label("SIEG!" if win else "Niederlage", 44, UI.GOLD if win else UI.RED, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("%s ist besiegt." % GameData.boss.get("name", "Der Boss") if win else "Dein Fortschritt bleibt erhalten – Ausrüstung und Erfahrung gehören dir.", 17, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	cols.add_child(left)
	left.add_child(UI.label("Run-Statistik", 20, UI.TEAL, true))
	var dur := int(result.get("duration", 0.0))
	for row in [["Dauer", "%02d:%02d" % [dur / 60, dur % 60]], ["Besiegte Gegner", str(result.get("kills", 0))],
			["Elitegegner / Zwischenbosse", "%d / %d" % [result.get("elites", 0), result.get("minibosses", 0)]],
			["Boss besiegt", "Ja" if result.get("boss_defeated", false) else "Nein"],
			["Erreichte Rundenstufe", str(result.get("level", 1))],
			["Verursachter Schaden", str(int(result.get("damage_dealt", 0.0)))],
			["Erlittener Schaden", str(int(result.get("damage_taken", 0.0)))],
			["Kampfunfähig", str(result.get("downs", 0))],
			["Geöffnete Truhen / Schreine", "%d / %d" % [result.get("chests", 0), result.get("shrines", 0)]]]:
		left.add_child(_row(row[0], row[1]))
	var skills_txt: Array = []
	for id in result.get("skills", {}):
		skills_txt.append("%s %d" % [GameData.skills[id]["name"], result["skills"][id]])
	var sk := UI.label("Build: " + (", ".join(skills_txt) if not skills_txt.is_empty() else "–"), 14, UI.DIM)
	sk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sk.custom_minimum_size = Vector2(370, 0)
	left.add_child(sk)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	cols.add_child(right)
	right.add_child(UI.label("Dauerhafter Fortschritt", 20, UI.TEAL, true))
	right.add_child(_row("Erfahrung", "+%d" % summary.get("xp", 0), UI.GOLD))
	right.add_child(_row("Gold", "+%d" % summary.get("gold", 0), UI.GOLD))
	if summary.get("meta_levels", 0) > 0:
		right.add_child(_row("Charakterstufe", "+%d  →  +%d Talentpunkt(e)" % [summary["meta_levels"], summary["meta_levels"]], UI.GOLD))
	if summary.get("achievement_points", 0) > 0:
		right.add_child(_row("Erfolgs-Gold", "+%d" % summary["achievement_points"], UI.GOLD))
	for a in summary.get("new_areas", []):
		right.add_child(UI.label("★ Neues Gebiet freigeschaltet: %s" % a, 17, UI.GOLD, true))
	for a in summary.get("new_achievements", []):
		right.add_child(UI.label("🏆 Erfolg: %s" % a, 16, UI.GOLD))
	right.add_child(UI.label("Gefundene Gegenstände (%d)" % result.get("items", []).size(), 18, UI.TEAL, true))
	var shown := 0
	var items: Array = result.get("items", [])
	items.sort_custom(func(a, b): return _rank(a) > _rank(b))
	for it in items:
		if shown >= 7:
			right.add_child(UI.label("… und %d weitere" % (items.size() - shown), 14, UI.DIM))
			break
		var l := UI.label("• %s  (%s)" % [it["name"], GameData.rarity_name(it["rarity"])], 15, GameData.rarity_color(it["rarity"]))
		right.add_child(l)
		shown += 1
	if summary.get("dropped_items", []).size() > 0:
		right.add_child(UI.label("Inventar voll: %d Gegenstände konnten nicht behalten werden." % summary["dropped_items"].size(), 14, UI.RED))
	var b := UI.button("Weiter zum Hauptmenü", func(): continue_pressed.emit(), Vector2(0, 50))
	v.add_child(b)
	b.grab_focus()


static func _rank(it: Dictionary) -> int:
	return ["common", "uncommon", "rare", "epic", "legendary", "mythic"].find(it["rarity"])


func _row(a: String, b: String, color: Color = UI.TEXT) -> Control:
	var h := HBoxContainer.new()
	var l := UI.label(a, 16, UI.DIM)
	l.custom_minimum_size = Vector2(210, 0)
	h.add_child(l)
	h.add_child(UI.label(b, 16, color))
	return h
