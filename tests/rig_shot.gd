extends Node
## Dev-Tool: Held in Pose rendern. Args: weapon clip time out [yaw_deg]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	SaveSystem.data = SaveSystem.default_data()
	var wt := a[0]
	var clip := a[1]
	var t := float(a[2])
	var out := a[3]
	var yaw := float(a[4]) if a.size() > 4 else 35.0
	var ap0 := SaveSystem.default_appearance()
	if OS.get_environment("FEMALE") == "1":
		ap0["female"] = 1
	if OS.get_environment("HAIR") != "":
		ap0["hair_style"] = int(OS.get_environment("HAIR"))
	var m := CharacterModel.build(ap0, wt)
	add_child(m["root"])
	if a.size() > 5:
		var r := a[5].split(",")
		m["weapon"].rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))
	var ap: AnimationPlayer = m["anim"]
	ap.play(clip)
	ap.seek(t, true)
	ap.pause()
	m["root"].rotation_degrees.y = yaw
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.4, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 40, 0)
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.2, 3.4)
	cam.look_at(Vector3(0, 1.0, 0))
	if OS.get_environment("ZOOM") == "1":
		cam.position = Vector3(0, 1.65, 1.1)
		cam.look_at(Vector3(0, 1.6, 0))
	cam.current = true
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
