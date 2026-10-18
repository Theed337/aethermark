class_name PagePlay
extends MenuPage
## Spielen: Charakterübersicht, Gebiet und Schwierigkeit wählen, Run starten (solo oder als Gruppenleiter).

var _area_box: VBoxContainer
var _start_btn: Button
var _diff_buttons: Array = []
var _hint: Label


func build() -> void:
	var c := character()
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(title("Spielen", "Wähle Gebiet und Schwierigkeit. Ein Run funktioniert allein genauso wie mit bis zu fünf Spielern."))
	# Charakterkarte
	var card := UI.panel()
	v.add_child(card)
	var cv := VBoxContainer.new()
	card.add_child(cv)
	cv.add_child(UI.label("%s – %s" % [c["name"], c.get("title", "Wanderer")], 22, UI.TEAL, true))
	var need := Progression.meta_xp_for_level(int(c["meta_level"]))
	var xpbar := UI.bar(UI.GOLD, Vector2(0, 16))
	xpbar.max_value = need
	xpbar.value = c["meta_xp"]
	cv.add_child(UI.label("Charakterstufe %d  (%d / %d Erfahrung)" % [c["meta_level"], c["meta_xp"], need], 15, UI.DIM))
	cv.add_child(xpbar)
	var st := Stats.compute(c)
	cv.add_child(UI.label("Leben %d · Schaden %.0f · Krit %.0f%% · Tempo %.1f · Angriffstempo ×%.2f" % [st["max_hp"], st["damage"], st["crit_chance"] * 100.0, st["move_speed"], st["attack_speed"]], 15))
	var w := _equipped_weapon(c)
	cv.add_child(UI.label("Waffe: " + (w["name"] if not w.is_empty() else "keine"), 15, DataColors.rarity(w.get("rarity", "common"))))
	# Gebiet
	v.add_child(UI.label("Gebiet", 20, UI.GOLD, true))
	var opt := UI.option()
	var ids: Array = []
	for a in GameData.areas:
		if a["id"] in c["unlocked_areas"]:
			var label: String = a["name"] + ("" if a["playable"] else "  (in Entwicklung)")
			opt.add_item(label)
			ids.append(a["id"])
	var sel := maxi(ids.find(menu.selected_area), 0)
	opt.select(sel)
	menu.selected_area = ids[sel]
	opt.item_selected.connect(func(i: int):
		menu.selected_area = ids[i]
		_refresh_area())
	v.add_child(opt)
	_area_box = VBoxContainer.new()
	v.add_child(_area_box)
	# Schwierigkeit
	v.add_child(UI.label("Schwierigkeit", 20, UI.GOLD, true))
	var row := HBoxContainer.new()
	v.add_child(row)
	for d in range(1, 5):
		var b := UI.button(Progression.DIFFICULTY_NAMES[d], Callable(), Vector2(120, 38))
		b.toggle_mode = true
		var dd: int = d
		b.disabled = not Progression.difficulty_unlocked(c, dd)
		b.tooltip_text = Progression.difficulty_text(dd)
		b.pressed.connect(func():
			menu.selected_difficulty = dd
			_refresh_diff())
		row.add_child(b)
		_diff_buttons.append(b)
	if not Progression.difficulty_unlocked(c, menu.selected_difficulty):
		menu.selected_difficulty = 1
	_hint = UI.label("", 14, UI.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hint)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	_start_btn = UI.button("RUN STARTEN", Callable(), Vector2(0, 58))
	_start_btn.add_theme_font_size_override("font_size", 24)
	_start_btn.pressed.connect(start)
	v.add_child(_start_btn)
	v.add_child(UI.label("Regel: Gefundene Ausrüstung bleibt immer erhalten. Talentpunkte gibt es nur durch Charakterstufen (Erfahrung aus Runs). Bei einer Niederlage gibt es keine Gebietsfreischaltung.", 13, UI.DIM))
	_refresh_area()
	_refresh_diff()


func _equipped_weapon(c: Dictionary) -> Dictionary:
	var eq: Dictionary = c.get("equipment", {})
	return SaveSystem.find_item(c, eq["weapon"]) if eq.has("weapon") else {}


func _refresh_area() -> void:
	UI.clear(_area_box)
	var a := GameData.area_by_id(menu.selected_area)
	var d := UI.label(a.get("desc", ""), 15, UI.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_area_box.add_child(d)
	var info := "Gebietsschwierigkeit: %d" % a.get("difficulty", 1)
	if not a.get("playable", false):
		info += " – dieses Gebiet ist noch nicht spielbar (siehe Weltkarte)."
	_area_box.add_child(UI.label(info, 14, UI.DIM))
	_update_start()


func _refresh_diff() -> void:
	for i in _diff_buttons.size():
		_diff_buttons[i].set_pressed_no_signal(menu.selected_difficulty == i + 1)
	_update_start()


func _update_start() -> void:
	if _start_btn == null:
		return
	var a := GameData.area_by_id(menu.selected_area)
	var playable: bool = a.get("playable", false)
	var in_lobby: bool = Net.in_lobby()
	_start_btn.disabled = not playable or (in_lobby and not (Net.is_leader() and Net.all_ready() and Net.state == "lobby"))
	if in_lobby and not Net.is_leader():
		_hint.text = "Der Gruppenleiter startet den Run. Ziel und Schwierigkeit legt er im Gruppenmenü fest."
		_start_btn.text = "WARTE AUF GRUPPENLEITER"
	elif in_lobby:
		_hint.text = "Du startest den Run für %d Spieler (Ziel und Schwierigkeit der Gruppe)." % Net.players.size() if Net.all_ready() else "Warte, bis alle Mitglieder bereit sind (Gruppenmenü)."
		_start_btn.text = "GRUPPEN-RUN STARTEN (%d Spieler)" % Net.players.size()
	else:
		_hint.text = "Solo-Run." if playable else "Dieses Gebiet kann noch nicht gespielt werden."
		_start_btn.text = "RUN STARTEN"


func start() -> void:
	SaveSystem.save_game()
	if Net.in_lobby():
		Net.host_start_run(Net.area_id, Net.difficulty)
	else:
		RunState.party_size = 1
		RunState.start_run(menu.selected_area, menu.selected_difficulty)
