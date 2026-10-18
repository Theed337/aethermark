extends Node
## Dev: contact sheet of all glb in a dir (runtime-loaded). args: dir out.png [cols] [cell]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var cols := int(a[2]) if a.size() > 2 else 8
	var cell := float(a[3]) if a.size() > 3 else 3.0
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
	var files := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb"): files.append(f)
	files.sort()
	var i := 0
	var rows := int(ceil(files.size() / float(cols)))
	for f in files:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(dir + "/" + f, st) != OK:
			print("FAIL ", f); continue
		var n: Node3D = doc.generate_scene(st)
		var box := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (m as MeshInstance3D).get_aabb()
			if first: box = b; first = false
			else: box = box.merge(b)
		var s: float = cell * 0.8 / max(0.01, max(box.size.x, max(box.size.y, box.size.z)))
		n.scale = Vector3.ONE * s
		n.position = Vector3((i % cols) * cell, -box.position.y * s, -(i / cols) * cell)
		n.rotation.y = 0.0
		add_child(n)
		var l := Label3D.new()
		l.text = f.get_basename().trim_prefix("SK_").trim_prefix("S_")
		l.position = Vector3((i % cols) * cell, 0.02, -(i / cols) * cell + cell * 0.45)
		l.rotation_degrees.x = -90
		l.font_size = 40
		l.pixel_size = 0.01
		add_child(l)
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	var cx := (cols - 1) * cell * 0.5
	var cz := -(rows - 1) * cell * 0.5
	cam.fov = 35
	var dist: float = max(cols * cell * 1.45, rows * cell * 2.4)
	var ctr := Vector3(cx, 0.6, cz)
	cam.position = ctr + Vector3(0, 1.0, 0.7).normalized() * dist
	cam.look_at_from_position(cam.position, ctr)
	cam.current = true
	for k in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(a[1])
	get_tree().quit()
