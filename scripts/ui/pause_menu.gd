class_name PauseMenu
extends Control
## Pausenmenü im Run: Fortsetzen, Lautstärke, Run abbrechen, Hauptmenü.

signal resume
signal abort_run

## Koop-Client: Der Run gehört dem Host, "Abbrechen" verlässt nur die Gruppe (Wiederbeitritt bleibt möglich).
var coop_client := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UI.panel(Vector2(440, 0))
	center.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UI.label("Pause", 34, UI.GOLD, true))
	v.add_child(UI.button("Fortsetzen", func(): resume.emit(), Vector2(0, 48)))
	var s: Dictionary = SaveSystem.data["settings"]
	for pair in [["Gesamtlautstärke", "volume_master"], ["Musik", "volume_music"], ["Effekte", "volume_sfx"]]:
		var row := HBoxContainer.new()
		var l := UI.label(pair[0], 16)
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(s.get(pair[1], 0.8))
		sl.custom_minimum_size = Vector2(220, 24)
		sl.value_changed.connect(func(val: float):
			SaveSystem.data["settings"][pair[1]] = val
			Sfx.apply_volumes())
		sl.drag_ended.connect(func(_c): SaveSystem.save_game())
		row.add_child(sl)
		v.add_child(row)
	v.add_child(UI.label("Steuerung: WASD, Maus, LMB leicht, RMB schwer, Strg Ausweichen,\nF Blocken/Parieren, 1-4 Fähigkeiten, E Interagieren, Tab Zielerfassung", 14, UI.DIM))
	if coop_client:
		v.add_child(UI.button("Run verlassen (Wiederbeitritt über den Lobby-Code möglich)", func(): abort_run.emit(), Vector2(0, 44)))
		return
	v.add_child(UI.button("Run abbrechen (zählt als Niederlage)", func(): abort_run.emit(), Vector2(0, 44)))
	v.add_child(UI.button("Zum Hauptmenü (Run verwerfen)", func():
		SaveSystem.save_game()
		if Net.in_lobby():
			Net.leave("Der Host hat den Run verlassen.")
		RunState.back_to_menu(), Vector2(0, 44)))
