extends Node
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
	var areas := ["emerald_forest", "sunken_ruins", "ash_lands", "frost_cliffs", "shadow_wood", "sky_fortress"]
	var types := ["grunt", "archer", "bomber", "shaman", "brute", "crawler", "sentinel", "splitter", "cultist"]
	var r := 0
	for a in areas:
		GameData.activate_area(a)
		var i := 0
		for t in types:
			var e := Enemy.new()
			e.ghost = true
			e.type_id = t
			e.data = GameData.enemy_types[t]
			e.model_scale = float(e.data["scale"])
			e.position = Vector3((i - 4.0) * 1.6, 0, -r * 2.2)
			e.net_pos = e.position
			e.rotation.y = 0.5
			add_child(e)
			i += 1
		r += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 9.0, 4.5)
	cam.look_at(Vector3(0, 0.5, -5.0))
	cam.current = true
	for k in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
