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
	var sets := [
		[0, 0, {}],
		[1, 0, {"head": 0, "chest": 0, "legs": 0, "shield": "Round_Shield"}],
		[3, 1, {}],
		[0, 1, {"head": 2, "chest": 3, "legs": 1, "shield": "Spike_Shield"}],
		[2, 0, {"head": 1, "chest": 4, "legs": 0, "shield": "Rectangle_Shield"}],
		[4, 1, {"head": 4, "chest": 1, "legs": 2, "shield": "Barbarian_Round_Shield"}],
	]
	var i := 0
	for s in sets:
		var ap := SaveSystem.default_appearance()
		ap["body"] = s[0]
		ap["female"] = s[1]
		var m := CharacterModel.build(ap, "sword", s[2])
		add_child(m["root"])
		m["root"].position.x = (i - 2.5) * 1.3
		m["anim"].play("Idle")
		m["anim"].seek(0.2, true)
		m["anim"].pause()
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.0, 5.5)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	for k in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
