class_name LevelUpUI
extends Control
## Auswahl der zufälligen Fähigkeiten beim Levelaufstieg (3 Karten, Neuwurf, Überspringen).
## Läuft im pausierten Spiel (process_mode = always). Tasten 1-3 wählen, R würfelt neu, S überspringt.

signal picked(id: String)
signal reroll_requested
signal skipped

var offers: Array = []
var cards: Array = []
var _rerolls := 0
var _row: HBoxContainer
var _title: Label
var _reroll_btn: Button
var _skip_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	_title = UI.label("", 34, UI.GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	col.add_child(_row)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	_reroll_btn = UI.button("Neu würfeln [R]", func(): reroll_requested.emit(), Vector2(220, 44))
	btns.add_child(_reroll_btn)
	_skip_btn = UI.button("Überspringen [S]  (+25 % LP, +50 % Mana)", func(): skipped.emit(), Vector2(380, 44))
	btns.add_child(_skip_btn)


func show_offers(level: int, offers_: Array, rerolls_left: int, pending: int) -> void:
	offers = offers_
	_rerolls = rerolls_left
	_title.text = "Stufe %d erreicht!   Wähle eine Verbesserung" % level + ("   (+%d weitere)" % pending if pending > 0 else "")
	UI.clear(_row)
	cards.clear()
	for i in offers.size():
		_row.add_child(_card(i, offers[i]))
	_reroll_btn.text = "Neu würfeln [R]  (%d übrig)" % rerolls_left
	_reroll_btn.disabled = rerolls_left <= 0


func _card(i: int, o: Dictionary) -> Control:
	var col := Color(GameData.skill_cfg["rarity_colors"][o["rarity"]])
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(290, 330)
	p.add_theme_stylebox_override("panel", UI.box(Color("#14263a"), 14, col, 3, 14))
	var v := VBoxContainer.new()
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(UI.label("[%d]" % (i + 1), 18, UI.DIM))
	var rar := UI.label(GameData.rarity_name("common") if false else _rarity_label(o["rarity"]), 15, col, true)
	rar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(rar)
	var nm := UI.label(o["name"], 26, Color.WHITE, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var kind := "Aktive Fähigkeit" if o["kind"] == "active" else "Passiv"
	var lv_txt := "NEU" if o["is_new"] else "Stufe %d / %d" % [o["new_level"], o["max_level"]]
	v.add_child(UI.label("%s  ·  %s" % [kind, lv_txt], 15, UI.TEAL))
	var desc := UI.label(o["desc"], 17, UI.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(250, 120)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var syn := _synergy_hint(o)
	if syn != "":
		var sl := UI.label(syn, 14, UI.GOLD)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
	v.add_child(UI.button("Wählen", func(): picked.emit(o["id"]), Vector2(0, 42)))
	return p


static func _rarity_label(r: String) -> String:
	return {"common": "Gewöhnlich", "uncommon": "Ungewöhnlich", "rare": "Selten", "epic": "Episch"}.get(r, r)


func _synergy_hint(o: Dictionary) -> String:
	for e in GameData.evolutions:
		if e["requires"].has(o["id"]):
			return "★ Evolution: %s" % e["name"]
	return ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: _pick_idx(0)
		KEY_2: _pick_idx(1)
		KEY_3: _pick_idx(2)
		KEY_R:
			if _rerolls > 0:
				reroll_requested.emit()
		KEY_S: skipped.emit()


func _pick_idx(i: int) -> void:
	if i < offers.size():
		picked.emit(offers[i]["id"])
