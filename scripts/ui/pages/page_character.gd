class_name PageCharacter
extends MenuPage
## Charaktereditor und Charakterverwaltung. Änderungen erscheinen sofort im 3D-Vorschaubereich
## (drehen: Maus ziehen; Kamera-Schaltflächen). Dasselbe Modell wird im Spiel verwendet.

const MAX_CHARACTERS := 6

var _draft: Dictionary = {}
var _name_edit: LineEdit
var _name_msg: Label
var _creating := false
var _body: VBoxContainer
var _origin_desc: Label
var _delete_armed := false
var _action_btn: Button
var _unlock_char: Dictionary = {}


func build() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	_creating = not SaveSystem.has_character() or menu.creating_new
	_load_draft()
	v.add_child(title("Charakter", "Gestalte deinen Helden. Es gibt keine festen Klassen – der Spielstil entsteht durch Talente, Ausrüstung und Fähigkeiten."))
	v.add_child(_manage_row())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	_build_editor()
	_action_btn = UI.button("", Callable(), Vector2(0, 52))
	_action_btn.add_theme_font_size_override("font_size", 22)
	_action_btn.pressed.connect(apply_draft)
	v.add_child(_action_btn)
	_update_action()
	_preview()


func _load_draft() -> void:
	if _creating:
		_draft = SaveSystem.default_appearance()
		_unlock_char = {"stats": SaveSystem.default_stats()}
	else:
		var c := character()
		_draft = SaveSystem.default_appearance()
		for k in c["appearance"]:
			_draft[k] = c["appearance"][k]
		_unlock_char = c


func _manage_row() -> Control:
	var row := HBoxContainer.new()
	var ob := UI.option()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := 0
	for i in SaveSystem.data["characters"].size():
		var c: Dictionary = SaveSystem.data["characters"][i]
		ob.add_item("%s (Stufe %d)" % [c["name"], c["meta_level"]], i)
		if c["id"] == SaveSystem.data["active_character"] and not _creating:
			idx = i
	if SaveSystem.data["characters"].size() > 0:
		if _creating:
			ob.add_item("— neuer Charakter —", 999)
			ob.select(ob.item_count - 1)
		else:
			ob.select(idx)
	ob.item_selected.connect(func(i: int):
		var id := ob.get_item_id(i)
		if id < SaveSystem.data["characters"].size():
			select_character(SaveSystem.data["characters"][id]["id"]))
	if SaveSystem.data["characters"].size() > 0:
		row.add_child(ob)
	var nb := UI.button("Neu", func(): start_new(), Vector2(70, 36))
	nb.disabled = SaveSystem.data["characters"].size() >= MAX_CHARACTERS
	row.add_child(nb)
	var db := UI.button("Löschen", Callable(), Vector2(90, 36))
	db.disabled = _creating or not SaveSystem.has_character()
	db.pressed.connect(func():
		if not _delete_armed:
			_delete_armed = true
			db.text = "Sicher?"
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(db):
					_delete_armed = false
					db.text = "Löschen")
		else:
			delete_active())
	row.add_child(db)
	return row


func select_character(id: String) -> void:
	SaveSystem.data["active_character"] = id
	SaveSystem.save_game()
	menu.go("character")


func start_new() -> void:
	if SaveSystem.data["characters"].size() >= MAX_CHARACTERS:
		return
	# Neuer Entwurf ohne zu speichern: Seite im Erstell-Modus neu aufbauen
	menu.creating_new = true
	menu.go("character", true)


func delete_active() -> void:
	SaveSystem.delete_character(SaveSystem.data["active_character"])
	menu.go("character")


# -------------------------------------------------------------- Editor

func _row(label: String, ctrl: Control) -> void:
	var r := HBoxContainer.new()
	var l := UI.label(label, 16, UI.DIM)
	l.custom_minimum_size = Vector2(150, 0)
	r.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctrl)
	_body.add_child(r)


func _opt_list(label: String, key: String, names: Array, auto_value: int) -> void:
	# Auswahl mit fester Liste; Eintrag 0 kann „Automatisch“ (auto_value) bedeuten
	var ob := UI.option()
	for n in names:
		ob.add_item(n)
	var cur := int(_draft.get(key, auto_value))
	var idx := cur + 1 if auto_value == -1 and key == "head_style" else (cur + 1 if auto_value == -1 else cur)
	ob.select(clampi(idx, 0, names.size() - 1))
	ob.item_selected.connect(func(i: int):
		_draft[key] = (i - 1) if auto_value == -1 else i
		_preview())
	_row(label, ob)


func _section(t: String) -> void:
	_body.add_child(UI.label(t, 19, UI.TEAL, true))


func _build_editor() -> void:
	_section("Name")
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "Name deines Helden (3–16 Zeichen)"
	_name_edit.text = "" if _creating else character()["name"]
	_name_edit.text_changed.connect(func(_t: String): _check_name())
	_body.add_child(_name_edit)
	_name_msg = UI.label("", 14, UI.RED)
	_body.add_child(_name_msg)
	_section("Herkunft & Körper")
	var origin_ids: Array = GameData.origins.keys()
	var ob := UI.option()
	for id in origin_ids:
		ob.add_item(GameData.origins[id]["name"])
	ob.select(maxi(origin_ids.find(_draft["origin"]), 0))
	ob.item_selected.connect(func(i: int):
		_draft["origin"] = origin_ids[i]
		_draft["skin"] = GameData.origins[origin_ids[i]]["skin"][0]
		_origin_desc.text = GameData.origins[origin_ids[i]]["desc"]
		_preview())
	_row("Herkunft", ob)
	var sx := UI.option()
	sx.add_item("Männlich", 0)
	sx.add_item("Weiblich", 1)
	sx.select(clampi(int(_draft.get("female", 0)), 0, 1))
	sx.item_selected.connect(func(i: int):
		_draft["female"] = i
		_preview())
	_row("Geschlecht", sx)
	var gb := UI.option()
	for i in CharacterModel.KK_BODY_NAMES.size():
		gb.add_item(CharacterModel.KK_BODY_NAMES[i], i)
	gb.select(clampi(int(_draft.get("body", 0)), 0, CharacterModel.KK_BODY_NAMES.size() - 1))
	gb.item_selected.connect(func(i: int):
		_draft["body"] = i
		_preview())
	_row("Figur", gb)
	_origin_desc = UI.label(GameData.origins[_draft["origin"]]["desc"], 14, UI.GOLD)
	_origin_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_origin_desc)
	_slider("Körpergröße", "body_height", 0.9, 1.1)
	_slider("Statur", "body_build", 0.85, 1.15)
	var kk := ResourceLoader.exists(CharacterModel.KK_DIR + "Knight.glb")
	_section("Gesicht & Haut")
	_swatches("Hautfarbe", "skin", func(): return GameData.origins[_draft["origin"]]["skin"], true)
	if kk:
		_opt_list("Kopfform", "head_style", ["Automatisch", "Ritter", "Barbar", "Magier", "Waldläuferin", "Kapuze"], -1)
	_opt("Frisur", "hair_style", GameData.origin_cfg["hair_styles"], "hair_style")
	_swatches("Haarfarbe", "hair_color", func(): return GameData.origin_cfg["palettes"]["hair"], true)
	_opt("Bart", "beard", GameData.origin_cfg["beards"], "beard")
	_opt("Ohren", "ears", GameData.origin_cfg["ears"], "ears")
	_opt("Hörner", "horns", GameData.origin_cfg["horns"], "horns")
	if not kk:
		_swatches("Augenfarbe", "eye_color", func(): return GameData.origin_cfg["palettes"]["eyes"], true)
		_opt("Narben", "scar", GameData.origin_cfg["scars"], "scar")
		_opt("Tätowierung", "tattoo", GameData.origin_cfg["tattoos"], "tattoo")
	_section("Kleidung & Farbe")
	if not kk:
		_opt("Startkleidung", "outfit", GameData.origin_cfg["outfits"], "outfit")
	else:
		_opt_list("Umhang", "cape", ["Keiner", "Ritterumhang", "Barbarenfell", "Magiermantel", "Schattenumhang", "Kapuzenumhang"], 0)
		_opt_list("Rock", "skirt", ["Standard", "Kurzer Rock", "Langer Rock"], -1)
		_swatches("Kleidungsfarbe", "cloth", func(): return GameData.origin_cfg["palettes"]["cloth"], true)
	_swatches("Akzentfarbe", "accent", func(): return GameData.origin_cfg["palettes"]["accent"], true)
	_section("Stimme")
	var vb := HBoxContainer.new()
	var vo := UI.option()
	for n in GameData.origin_cfg["voices"]:
		vo.add_item(n)
	vo.select(int(_draft["voice"]))
	vo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vo.item_selected.connect(func(i: int):
		_draft["voice"] = i
		play_voice())
	vb.add_child(vo)
	vb.add_child(UI.button("Probe", func(): play_voice(), Vector2(80, 34)))
	_row("Stimme", vb)
	if not _creating:
		_section("Titel")
		var tb := UI.option()
		var titles := Cosmetics.unlocked_titles(character())
		for t in titles:
			tb.add_item(t)
		tb.select(maxi(titles.find(character().get("title", "Wanderer")), 0))
		tb.item_selected.connect(func(i: int):
			character()["title"] = titles[i]
			SaveSystem.save_game()
			menu.refresh_header())
		_row("Titel", tb)
	_section("Kamera")
	var cr := HBoxContainer.new()
	for pair in [["Vorne", "front"], ["Kopf", "head"], ["Hinten", "back"], ["Weit", "far"]]:
		cr.add_child(UI.button(pair[0], func(): menu.camera_view(pair[1]), Vector2(0, 34)))
	_body.add_child(cr)
	_check_name(true)


func play_voice() -> void:
	var pitches: Array = GameData.origin_cfg["voice_pitch"]
	Sfx.play("cast", float(pitches[clampi(int(_draft["voice"]), 0, pitches.size() - 1)]), -4.0)


func _opt(label: String, key: String, names: Array, kind: String) -> void:
	var ob := UI.option()
	for i in names.size():
		var locked := not Cosmetics.is_unlocked(_unlock_char, kind, i)
		ob.add_item(names[i] + ("   (gesperrt: %s)" % Cosmetics.unlock_text(kind, i) if locked else ""), i)
		ob.set_item_disabled(i, locked)
	ob.select(clampi(int(_draft[key]), 0, names.size() - 1))
	ob.item_selected.connect(func(i: int):
		_draft[key] = i
		_preview())
	_row(label, ob)


func _slider(label: String, key: String, lo: float, hi: float) -> void:
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.01
	sl.value = float(_draft[key])
	sl.custom_minimum_size = Vector2(200, 24)
	sl.value_changed.connect(func(val: float):
		_draft[key] = val
		_preview())
	_row(label, sl)


func _swatches(label: String, key: String, colors_fn: Callable, free_picker: bool) -> void:
	var fl := HFlowContainer.new()
	var colors: Array = colors_fn.call()
	for col in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.add_theme_stylebox_override("normal", UI.box(Color(col), 6, Color("#2c4a68"), 2, 0))
		b.add_theme_stylebox_override("hover", UI.box(Color(col), 6, Color.WHITE, 2, 0))
		b.add_theme_stylebox_override("pressed", UI.box(Color(col), 6, UI.GOLD, 3, 0))
		b.pressed.connect(func():
			_draft[key] = col
			_preview())
		fl.add_child(b)
	if free_picker:
		var cp := ColorPickerButton.new()
		cp.custom_minimum_size = Vector2(60, 30)
		cp.color = Color(_draft[key])
		cp.edit_alpha = false
		cp.color_changed.connect(func(c: Color):
			_draft[key] = "#" + c.to_html(false)
			_preview())
		fl.add_child(cp)
	_row(label, fl)


func _preview() -> void:
	var w := "sword"
	var gear := {}
	if not _creating and SaveSystem.has_character():
		var c := character()
		var eq: Dictionary = c.get("equipment", {})
		if eq.has("weapon"):
			w = SaveSystem.find_item(c, eq["weapon"]).get("weapon_type", "sword")
		gear = CharacterModel.gear_looks(c)
	menu.set_preview(_draft, w, gear)


func _check_name(silent: bool = false) -> bool:
	var err := SaveSystem.validate_name(_name_edit.text)
	_name_msg.text = "" if (silent and _name_edit.text == "") else err
	_update_action()
	return err == ""


func _update_action() -> void:
	if _action_btn == null:
		return
	_action_btn.text = "CHARAKTER ERSTELLEN" if _creating else "ÄNDERUNGEN SPEICHERN"
	_action_btn.disabled = SaveSystem.validate_name(_name_edit.text) != ""


## Legt den Charakter an bzw. speichert das Aussehen. Gibt true zurück, wenn gespeichert wurde.
func apply_draft() -> bool:
	if not _check_name():
		return false
	var nm := _name_edit.text.strip_edges()
	if _creating:
		SaveSystem.new_character(nm, _draft.duplicate(true))
		Sfx.play("levelup", 1.0, -6.0)
		menu.go("play")
	else:
		var c := character()
		c["name"] = nm
		c["appearance"] = _draft.duplicate(true)
		Cosmetics.sanitize(c)
		SaveSystem.save_game()
		menu.refresh_header()
		Sfx.play("loot", 1.0, -6.0)
		_name_msg.text = "Gespeichert."
	return true
