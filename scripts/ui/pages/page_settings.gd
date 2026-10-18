class_name PageSettings
extends MenuPage
## Einstellungen: Audio, Grafik (Qualitätsstufen), Kamera, Steuerung mit Tastenbelegung, Oberfläche.

var _rebind_action := ""
var _rebind_btn: Button
var _bind_buttons: Dictionary = {}
var _msg: Label


func build() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(title("Einstellungen", "Änderungen werden sofort angewendet und gespeichert."))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	var s: Dictionary = SaveSystem.data["settings"]
	box.add_child(UI.label("Audio", 20, UI.TEAL, true))
	for pair in [["Gesamtlautstärke", "volume_master"], ["Musik", "volume_music"], ["Effekte", "volume_sfx"], ["Umgebung", "volume_ambient"]]:
		box.add_child(slider_row(pair[0], pair[1], 0.0, 1.0, 0.05, func(): Sfx.apply_volumes()))
	box.add_child(check_row("Alles stummschalten", "mute", func(): Sfx.apply_volumes()))
	box.add_child(UI.label("Grafik", 20, UI.TEAL, true))
	var q := UI.option()
	for n in SettingsApply.QUALITY_NAMES:
		q.add_item(n)
	q.select(clampi(int(s["graphics_quality"]), 0, 2))
	q.item_selected.connect(func(i: int):
		s["graphics_quality"] = i
		SaveSystem.save_game()
		SettingsApply.apply_graphics(get_viewport()))
	box.add_child(_row("Qualität", q))
	box.add_child(slider_row("Partikel-Menge", "particle_limit", 0.2, 1.0, 0.1, Callable()))
	box.add_child(check_row("Vollbild", "fullscreen", func(): SettingsApply.apply_graphics(get_viewport())))
	box.add_child(check_row("Schadenszahlen anzeigen", "show_damage_numbers", Callable()))
	box.add_child(slider_row("Oberflächen-Größe", "ui_scale", 0.6, 1.5, 0.05, func(): SettingsApply.apply_graphics(get_viewport())))
	box.add_child(UI.label("Kamera & Maus", 20, UI.TEAL, true))
	box.add_child(slider_row("Mausempfindlichkeit", "mouse_sensitivity", 0.001, 0.006, 0.0002, Callable()))
	box.add_child(slider_row("Kameradistanz", "camera_distance", 4.0, 10.0, 0.5, Callable()))
	box.add_child(slider_row("Sichtfeld (FOV)", "fov", 50.0, 100.0, 1.0, Callable()))
	box.add_child(UI.label("Tastenbelegung (Tastatur)", 20, UI.TEAL, true))
	_msg = UI.label("Klicke eine Belegung und drücke die neue Taste (Esc bricht ab).", 14, UI.DIM)
	box.add_child(_msg)
	for action in InputSetup.KEY_DEFAULTS:
		var r := HBoxContainer.new()
		var l := UI.label(InputSetup.LABELS[action], 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var b := UI.button(InputSetup.key_name_of(action), Callable(), Vector2(150, 32))
		var a: String = action
		b.pressed.connect(func(): begin_rebind(a))
		r.add_child(b)
		_bind_buttons[action] = b
		box.add_child(r)
	box.add_child(UI.button("Belegung zurücksetzen", func():
		InputSetup.reset_bindings()
		menu.go("settings"), Vector2(0, 36)))
	box.add_child(UI.label("Maus: LMB leichter Angriff, RMB schwerer Angriff. Gamepad: A Sprung, B Ausweichen, X/Y Angriff, Schultertasten/Trigger Fähigkeiten, Start Pause (fest belegt).", 14, UI.DIM))


func _row(label: String, ctrl: Control) -> Control:
	var r := HBoxContainer.new()
	var l := UI.label(label, 16)
	l.custom_minimum_size = Vector2(220, 0)
	r.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctrl)
	return r


func slider_row(label: String, key: String, lo: float, hi: float, step: float, on_change: Callable) -> Control:
	var s: Dictionary = SaveSystem.data["settings"]
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(s.get(key, lo))
	sl.custom_minimum_size = Vector2(240, 24)
	var vl := UI.label("%.2f" % sl.value if hi <= 1.5 else "%.1f" % sl.value, 14, UI.DIM)
	vl.custom_minimum_size = Vector2(54, 0)
	sl.value_changed.connect(func(val: float):
		s[key] = val
		vl.text = "%.2f" % val if hi <= 1.5 else "%.1f" % val
		if key == "mouse_sensitivity":
			vl.text = "%.4f" % val
		if on_change.is_valid():
			on_change.call()
		SaveSystem.save_game())
	var h := HBoxContainer.new()
	h.add_child(sl)
	h.add_child(vl)
	if key == "mouse_sensitivity":
		vl.text = "%.4f" % sl.value
	return _row(label, h)


func check_row(label: String, key: String, on_change: Callable) -> Control:
	var s: Dictionary = SaveSystem.data["settings"]
	var cb := CheckBox.new()
	cb.button_pressed = bool(s.get(key, false))
	cb.text = "an"
	cb.toggled.connect(func(on: bool):
		s[key] = on
		if on_change.is_valid():
			on_change.call()
		SaveSystem.save_game())
	return _row(label, cb)


func begin_rebind(action: String) -> void:
	_rebind_action = action
	_msg.text = "Drücke eine Taste für „%s“ …" % InputSetup.LABELS[action]
	_bind_buttons[action].text = "…"


func _unhandled_key_input(event: InputEvent) -> void:
	if _rebind_action == "" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var action := _rebind_action
	_rebind_action = ""
	if event.physical_keycode == KEY_ESCAPE:
		_msg.text = "Abgebrochen."
		_bind_buttons[action].text = InputSetup.key_name_of(action)
		return
	apply_binding(action, int(event.physical_keycode))


## Setzt die Belegung. Wird die Taste schon verwendet, werden beide Aktionen getauscht (keine doppelten Belegungen).
func apply_binding(action: String, code: int) -> void:
	var other := ""
	for a in InputSetup.KEY_DEFAULTS:
		if a != action and InputSetup.key_code_of(a) == code:
			other = a
	var old := InputSetup.key_code_of(action)
	if other != "":
		InputSetup.rebind(other, old)
	InputSetup.rebind(action, code)
	_msg.text = "„%s“ ist jetzt %s." % [InputSetup.LABELS[action], OS.get_keycode_string(code as Key)]
	for a in _bind_buttons:
		_bind_buttons[a].text = InputSetup.key_name_of(a)
