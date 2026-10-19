extends Node
var arena: Node
var f := 0
var victim: Player
func _ready() -> void:
	SaveSystem.save_path = "user://r_save.json"
	SaveSystem.data = SaveSystem.default_data()
	SaveSystem.new_character("T", SaveSystem.default_appearance())
	RunState.area_id = "emerald_forest"
	RunState.seed_value = 7
	arena = load("res://scenes/arena.tscn").instantiate()
	add_child(arena)
func _process(delta: float) -> void:
	f += 1
	if f == 10:
		victim = Player.new()
		victim.character = SaveSystem.active_character()
		victim.arena = arena
		victim.net_role = "remote_sim"
		arena.add_child(victim)
		arena.players.append(victim)
		victim.global_position = arena.player.global_position + Vector3(3.2, 0, 0)
		victim.take_damage(99999.0, victim.global_position)
		print("victim state ", victim.state)
	if f == 20:
		Input.action_press("interact")
	if f > 20 and f < 400:
		arena._update_revive(delta)
		if f % 60 == 0:
			print("progress ", victim.revive_progress, " state ", victim.state, " helper held ", arena.player.interact_held, " dist ", victim.global_position.distance_to(arena.player.global_position))
	if f == 400:
		print("RESULT state=", victim.state)
		get_tree().quit()
