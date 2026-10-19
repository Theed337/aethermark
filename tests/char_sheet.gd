extends Node
## Dev: Reihe von Charakteren mit verschiedenen Einstellungen. args: out.png [json-liste]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var variants: Array = JSON.parse_string(a[1]) if a.size() > 1 else [{}]
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
	var i := 0
	for v in variants:
		var ap: Dictionary = SaveSystem.default_appearance()
		for k in v.get("app", {}):
			ap[k] = v["app"][k]
		var gear: Dictionary = v.get("gear", {})
		var m := CharacterModel.build(ap, v.get("weapon", "sword"), gear)
		var r: Node3D = m["root"]
		r.position = Vector3(i * 1.6, 0, 0)
		r.rotation.y = float(v.get("yaw", 0.0))
		add_child(r)
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	var cx := (variants.size() - 1) * 0.8
	cam.fov = 28
	var dist := maxf(3.0, variants.size() * 1.6 * 0.9)
	if OS.get_environment("SHOT_CLOSE") != "":
		dist = 3.2
	cam.look_at_from_position(Vector3(cx, 1.4, dist), Vector3(cx, 0.95, 0))
	cam.current = true
	for k in 16:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("Screenshot: ", out)
	get_tree().quit()
