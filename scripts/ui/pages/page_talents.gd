class_name PageTalents
extends MenuPage
## Permanenter Talentbaum (keine Klassen): 11 Spezialisierungen, Synergien, Umwandlungen. Reset ist kostenlos.

var view: TalentView
var _points_label: Label
var _stats_box: VBoxContainer
var _reset_btn: Button
var _reset_armed := false


func _init() -> void:
	wide = true


func build() -> void:
	var c := character()
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(UI.label("Talentbaum", 30, UI.GOLD, true))
	_points_label = UI.label("", 20, UI.TEAL, true)
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_points_label)
	_reset_btn = UI.button("Alle zurücksetzen (kostenlos)", Callable(), Vector2(260, 38))
	_reset_btn.pressed.connect(func():
		if not _reset_armed:
			_reset_armed = true
			_reset_btn.text = "Wirklich zurücksetzen?"
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(_reset_btn):
					_reset_armed = false
					_reset_btn.text = "Alle zurücksetzen (kostenlos)")
		else:
			reset_all())
	top.add_child(_reset_btn)
	var help := UI.label("Linksklick: erlernen · Rechtsklick: zurücknehmen · Ziehen: verschieben · Mausrad: zoomen. Sechs Hauptpfade = Klassen – spezialisiere dich auf einen; die Nebenpfade zweigen davon ab. Punkte gibt es für Charakterstufen, Runs und Erfolge.", 14, UI.DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	view = TalentView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(500, 400)
	h.add_child(view)
	view.bind(c)
	view.changed.connect(refresh)
	var side := UI.panel(Vector2(330, 0))
	h.add_child(side)
	var sc := ScrollContainer.new()
	side.add_child(sc)
	_stats_box = VBoxContainer.new()
	_stats_box.custom_minimum_size = Vector2(300, 0)
	sc.add_child(_stats_box)
	refresh()


func reset_all() -> int:
	var n := TalentTree.reset(character())
	SaveSystem.save_game()
	_reset_armed = false
	_reset_btn.text = "Alle zurücksetzen (kostenlos)"
	refresh()
	return n


func refresh() -> void:
	var c := character()
	_points_label.text = "Freie Punkte: %d   ·   Ausgegeben: %d" % [c["talent_points"], TalentTree.spent_points(c["talents"])]
	_reset_btn.disabled = c["talents"].is_empty()
	UI.clear(_stats_box)
	_stats_box.add_child(UI.label("Aktuelle Werte", 19, UI.GOLD, true))
	var st := Stats.compute(c)
	for row in [["Leben", "%d" % st["max_hp"]], ["Schaden", "%.1f" % st["damage"]], ["Krit-Chance", "%.1f%%" % (st["crit_chance"] * 100.0)],
			["Krit-Schaden", "×%.2f" % st["crit_mult"]], ["Tempo", "%.2f" % st["move_speed"]], ["Angriffstempo", "×%.2f" % st["attack_speed"]],
			["Verteidigung", "%.0f" % st["defense"]], ["Abklingzeit -", "%.0f%%" % (st["cooldown_reduction"] * 100.0)],
			["Mana", "%d" % st["mana_max"]], ["Lebensraub", "%.1f%%" % (st["lifesteal"] * 100.0)],
			["Nahkampf", "×%.2f" % st["cat_mult"]["melee"]], ["Fernkampf", "×%.2f" % st["cat_mult"]["ranged"]],
			["Elementar", "×%.2f" % st["cat_mult"]["elem"]], ["Beschwörung", "×%.2f" % st["cat_mult"]["summon"]]]:
		var r := HBoxContainer.new()
		var a := UI.label(row[0], 15, UI.DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(a)
		r.add_child(UI.label(row[1], 15))
		_stats_box.add_child(r)
	_stats_box.add_child(HSeparator.new())
	_stats_box.add_child(UI.label("Punkte pro Zweig", 17, UI.TEAL, true))
	var per: Dictionary = {}
	for id in c["talents"]:
		var b: String = GameData.talents[id]["branch"]
		per[b] = int(per.get(b, 0)) + TalentTree.cost_of(id)
	for b in GameData.talent_branches:
		var n := int(per.get(b["id"], 0))
		if n > 0:
			_stats_box.add_child(UI.label("%s: %d" % [b["name"], n], 14, Color.html(b["color"]).lightened(0.25)))
	if per.is_empty():
		_stats_box.add_child(UI.label("Noch nichts gewählt.", 14, UI.DIM))
	# Übersicht aller erlernten Talente mit Wirkung (damit man jederzeit sieht, was man geskillt hat)
	_stats_box.add_child(HSeparator.new())
	_stats_box.add_child(UI.label("Erlernte Talente (%d)" % c["talents"].size(), 17, UI.TEAL, true))
	for b in GameData.talent_branches:
		var mine: Array = c["talents"].filter(func(id): return GameData.talents[id]["branch"] == b["id"])
		if mine.is_empty():
			continue
		var bc := Color.html(b["color"]).lightened(0.25)
		_stats_box.add_child(UI.label(b["name"], 15, bc, true))
		for id in mine:
			var n: Dictionary = GameData.talents[id]
			var fx: Array = TalentTree.describe_effects(n.get("effects", {}))
			var l := UI.label("• %s%s" % [n["name"], ("  –  " + ", ".join(fx)) if not fx.is_empty() else ""], 13, UI.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(1, 0)
			_stats_box.add_child(l)
	if view != null:
		view.queue_redraw()
	menu.refresh_header()
