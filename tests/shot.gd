extends Node
## Screenshot-Werkzeug (nur Entwicklung): xvfb-run godot --rendering-method gl_compatibility res://tests/shot.tscn -- menu:character out.png
## Argumente: menu:<seite> | arena:<gebiet>  <Ausgabedatei> [Frames] [Breite x Höhe]
var out := "shot.png"
var a_ref: Node

func _walk(n: Node, d: int) -> void:
	if n is Control and n.get_combined_minimum_size().x > 500:
		print("  ".repeat(d), n.get_class(), " ", n.name, " min=", n.get_combined_minimum_size())
	for c in n.get_children():
		_walk(c, d + 1)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "menu:play"
	out = args[1] if args.size() > 1 else "shot.png"
	var frames := int(args[2]) if args.size() > 2 else 40
	Net.use_upnp = false
	SaveSystem.save_path = "user://shot_save.json"
	SaveSystem.data = SaveSystem.default_data()
	SaveSystem.new_character("Testheld", SaveSystem.default_appearance())
	if OS.get_environment("SHOT_ITEMS") != "":
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var ch: Dictionary = SaveSystem.active_character()
		for i in 14:
			ch["inventory"].append(Loot.roll_item(rng, 3 + i, 3.0))
		for slot in ["chest", "head", "feet"]:
			var it := Loot.roll_item(rng, 5, 2.0, "uncommon", slot)
			ch["inventory"].append(it)
			SaveSystem.equip(ch, it["uid"])
	var kind := mode.split(":")[0]
	var arg := mode.split(":")[1]
	var m: Node = null
	if kind == "menu":
		m = load("res://scenes/main_menu.tscn").instantiate()
		add_child(m)
		await get_tree().process_frame
		m.go(arg)
		m.spin_speed = 0.0
		if OS.get_environment("SHOT_TAB") != "" and m.page.has_method("_set_tab"):
			m.page._set_tab(OS.get_environment("SHOT_TAB"))
		if args.size() > 4:
			m.camera_view(args[4])
		await get_tree().process_frame
		if not m.model.is_empty():
			m.model["root"].rotation.y = float(args[3]) if args.size() > 3 else 0.0
	else:
		RunState.area_id = arg
		RunState.seed_value = 12345
		RunState.bot_mode = true
		var a: Node = load("res://scenes/arena.tscn").instantiate()
		a_ref = a
		add_child(a)
	if kind == "menu" and OS.get_environment("SHOT_DEBUG") != "":
		await get_tree().process_frame
		_walk(m.page, 0)
	if kind == "arena" and OS.get_environment("SHOT_SKILLS") != "":
		for id in ["fireball", "fireball", "fireball", "frost_nova", "chain_lightning", "crit_mastery", "crit_mastery", "vitality", "swift", "iron_will", "heal_aura", "arcane_focus"]:
			a_ref.player.add_skill_level(id)
	if OS.get_environment("SHOT_K") != "":
		Input.action_press("skills_overview")
	if kind == "arena" and OS.get_environment("SHOT_TOP") != "":
		var tc := Camera3D.new()
		a_ref.add_child(tc)
		var pv := OS.get_environment("SHOT_TOP").split(",")
		tc.far = 600.0
		tc.fov = 60
		tc.position = Vector3(float(pv[0]), float(pv[1]), float(pv[2]))
		tc.look_at_from_position(tc.position, Vector3(float(pv[3]), 0, float(pv[4])))
		tc.current = true
		a_ref.hud.visible = false
	for i in frames:
		await get_tree().process_frame
	if kind == "arena":
		var h = a_ref.hud
		print("HUD size=", h.size, " pos=", h.position, " viewport=", get_viewport().get_visible_rect().size, " win=", get_window().size, " anchors=", h.anchor_right, h.anchor_bottom)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("Screenshot: ", out, " ", get_viewport().get_visible_rect().size)
	get_tree().quit()
