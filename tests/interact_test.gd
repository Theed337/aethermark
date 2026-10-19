extends Node
var arena: Node
var f := 0
func _ready() -> void:
	SaveSystem.save_path = "user://i_save.json"
	SaveSystem.data = SaveSystem.default_data()
	SaveSystem.new_character("T", SaveSystem.default_appearance())
	RunState.area_id = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "emerald_forest"
	RunState.difficulty = 1
	RunState.seed_value = 7
	arena = load("res://scenes/arena.tscn").instantiate()
	add_child(arena)
func _process(_d: float) -> void:
	f += 1
	if f == 20:
		print("chests ", arena._chests.size(), " shrines ", arena._shrines.size())
		var c: Dictionary = arena._chests[0]
		print("chest pos ", c["node"].global_position, " player ", arena.player.global_position)
		arena.player.global_position = c["node"].global_position + Vector3(1, 0, 0)
	if f == 25:
		Input.action_press("interact")
	if f == 27:
		Input.action_release("interact")
	if f == 40:
		print("pickups ", arena._pickups.size())
		var sh: Dictionary = arena._shrines[0]
		arena.player.global_position = sh["node"].global_position + Vector3(1, 0, 0)
	if f == 45:
		Input.action_press("interact")
	if f == 47:
		Input.action_release("interact")
	if f == 60:
		print("shrine ", arena._shrines[0]["state"])
		print("chest open? ", arena._chests[0]["open"], " keys: ", InputMap.has_action("interact"), " ", InputMap.action_get_events("interact"))
		get_tree().quit()
