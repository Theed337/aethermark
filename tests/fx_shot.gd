extends Node
func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.16, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.environment.glow_enabled = true
	add_child(env)
	Toon.part(self, "disc", Vector3(10, 0.2, 0), Color("#2f6b45"), Vector3(0, -0.1, 0))
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 3.2, 6.5)
	cam.look_at(Vector3(0, 0.8, 0))
	cam.current = true
	await get_tree().process_frame
	FX.burst(self, Vector3(-3, 1, 0), Color("#ff8a3d"), 16, 4.5, 0.12, 0.7)
	FX.burst(self, Vector3(-1.2, 1, 0), Color("#4ecdc4"), 16, 4.5, 0.12, 0.7)
	FX.ring(self, Vector3(1.2, 0, 0), 1.6, Color("#9a6bff"), 0.9)
	FX.zone(self, Vector3(3.2, 0, 0), 1.2, Color("#ff5a2a"), 5.0)
	FX.beam(self, Vector3(-3, 2.5, -2), Vector3(3, 2.2, -2), Color("#7ad7ff"), 1.0, 0.07)
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
