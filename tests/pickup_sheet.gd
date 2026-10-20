extends Node
const PropsS = preload("res://scripts/world/props.gd")
func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.4, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var holder := Node3D.new()
	add_child(holder)
	var i := 0
	for r in ["common", "uncommon", "rare", "epic", "legendary"]:
		for slot in ["weapon", "chest", "head", "amulet"]:
			var it := Loot.roll_item(rng, 8, 2.0, r, slot)
			PropsS.make_pickup(holder, Vector3((i % 5 - 2) * 1.6, 0, (i / 5) * -1.6), it)
			i += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 5.5, 4.5), Vector3(0, 0, -2.0))
	cam.current = true
	for k in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
