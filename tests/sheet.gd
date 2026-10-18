extends Node
## Dev-Tool: Kontaktbogen von Modellen. Argumente: Prefixliste (kommagetrennt) Ausgabe
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var prefixes := args[0].split(",")
	var out := args[1]
	var vp := get_viewport()
	var cam := Camera3D.new()
	add_child(cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.85, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var row := 0
	var maxx := 0.0
	for pf in prefixes:
		var col := 0
		for i in range(0, 8):
			var name := ("%s_%d" % [pf, i]) if i > 0 else pf
			if not NatureKit.has(name):
				continue
			var n := NatureKit.make(name, 4.0)
			n.position = Vector3(col * 4.4, -row * 5.0, 0)
			add_child(n)
			col += 1
			maxx = maxf(maxx, col * 4.2)
		row += 1
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(row * 5.0, maxx / 1.7)
	cam.position = Vector3(maxx * 0.5 - 2.2, -row * 2.5 + 2.2, 30)
	cam.current = true
	for i in 12:
		await get_tree().process_frame
	vp.get_texture().get_image().save_png(out)
	get_tree().quit()
