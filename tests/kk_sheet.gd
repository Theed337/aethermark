extends Node
const NAMES := ["Knight", "Barbarian", "Mage", "Rogue", "Rogue_Hooded"]
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
	var i := 0
	for n in NAMES:
		var m: Node3D = load("res://assets/kaykit/%s.glb" % n).instantiate()
		add_child(m)
		m.position.x = (i - 2) * 1.3
		var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
		for c in sk.get_children():
			if c is BoneAttachment3D and not (c.name.contains("Hat") or c.name.contains("Cape") or c.name.contains("Helmet") or c.name.contains("Hood")):
				c.visible = false
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		ap.play("Idle")
		ap.seek(0.2, true)
		ap.pause()
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.0, 6.5)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	for k in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
