extends Node
## Registriert alle Eingabe-Aktionen (Tastatur, Maus, Gamepad). Tastaturbelegungen sind
## im Einstellungsmenü änderbar und werden im Spielstand gespeichert.
## Alle Spielsysteme fragen nur Aktionen ab (nie direkt Tasten) -> später Touch-Steuerung möglich.

const KEY_DEFAULTS := {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"jump": KEY_SPACE, "sprint": KEY_SHIFT, "dodge": KEY_CTRL, "interact": KEY_E,
	"block": KEY_F, "skill_1": KEY_1, "skill_2": KEY_2, "skill_3": KEY_3, "skill_4": KEY_4,
	"pause": KEY_ESCAPE, "lock_on": KEY_TAB, "skills_overview": KEY_K,
}

const LABELS := {
	"move_forward": "Vorwärts", "move_back": "Rückwärts", "move_left": "Links", "move_right": "Rechts",
	"jump": "Springen", "sprint": "Sprinten", "dodge": "Ausweichen/Rollen", "interact": "Interagieren",
	"block": "Blocken/Parieren", "skill_1": "Fähigkeit 1", "skill_2": "Fähigkeit 2", "skill_3": "Fähigkeit 3",
	"skill_4": "Fähigkeit 4", "pause": "Pause", "lock_on": "Zielerfassung", "skills_overview": "Fähigkeiten-Übersicht (halten)",
}

const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A, "dodge": JOY_BUTTON_B, "attack_light": JOY_BUTTON_X, "attack_heavy": JOY_BUTTON_Y,
	"interact": JOY_BUTTON_DPAD_UP, "sprint": JOY_BUTTON_LEFT_STICK, "skill_1": JOY_BUTTON_RIGHT_SHOULDER,
	"skill_3": JOY_BUTTON_DPAD_LEFT, "skill_4": JOY_BUTTON_DPAD_RIGHT, "pause": JOY_BUTTON_START,
	"lock_on": JOY_BUTTON_RIGHT_STICK,
}


func _ready() -> void:
	setup()


func setup() -> void:
	var overrides: Dictionary = {}
	if has_node("/root/SaveSystem"):
		overrides = SaveSystem.data.get("settings", {}).get("key_bindings", {})
	for action in KEY_DEFAULTS:
		_reset_action(action)
		var code: int = int(overrides.get(action, KEY_DEFAULTS[action]))
		var ev := InputEventKey.new()
		ev.physical_keycode = code as Key
		InputMap.action_add_event(action, ev)
	# Maus
	for pair in [["attack_light", MOUSE_BUTTON_LEFT], ["attack_heavy", MOUSE_BUTTON_RIGHT]]:
		_reset_action(pair[0])
		var m := InputEventMouseButton.new()
		m.button_index = pair[1]
		InputMap.action_add_event(pair[0], m)
	# Gamepad
	for action in PAD_BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var b := InputEventJoypadButton.new()
		b.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, b)
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("skill_2", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis("block", JOY_AXIS_TRIGGER_LEFT, 1.0)
	for pair in [["look_left", -1.0, JOY_AXIS_RIGHT_X], ["look_right", 1.0, JOY_AXIS_RIGHT_X],
			["look_up", -1.0, JOY_AXIS_RIGHT_Y], ["look_down", 1.0, JOY_AXIS_RIGHT_Y]]:
		_reset_action(pair[0])
		_pad_axis(pair[0], pair[2], pair[1])


func _reset_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.2)


func _pad_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


## Ändert die Tastaturbelegung einer Aktion und speichert sie.
func rebind(action: String, keycode: int) -> void:
	if not KEY_DEFAULTS.has(action):
		return
	var settings: Dictionary = SaveSystem.data["settings"]
	var b: Dictionary = settings.get("key_bindings", {})
	b[action] = keycode
	settings["key_bindings"] = b
	SaveSystem.save_game()
	setup()


func reset_bindings() -> void:
	SaveSystem.data["settings"]["key_bindings"] = {}
	SaveSystem.save_game()
	setup()


func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
	return "-"


## Tastencode der aktuellen Belegung (Standard oder gespeicherte Änderung).
func key_code_of(action: String) -> int:
	var overrides: Dictionary = SaveSystem.data.get("settings", {}).get("key_bindings", {})
	return int(overrides.get(action, KEY_DEFAULTS.get(action, 0)))


func key_name_of(action: String) -> String:
	return OS.get_keycode_string(key_code_of(action) as Key)
