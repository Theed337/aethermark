class_name ItemIcons
extends Node
## Rendert Item-Modelle einmalig zu kleinen Symbolen (Cache). Texturen füllen sich nach 1–2 Bildern selbst.

static var _cache := {}
static var _inst: ItemIcons
var _queue: Array = []
var _busy := false


static func icon_for(item: Dictionary) -> Texture2D:
	if item.is_empty():
		return null
	var n := ItemModels.model_name(item)
	if n == "" or not ItemModels.exists(n):
		return null
	return icon_named(n)


static func icon_named(n: String) -> Texture2D:
	if _cache.has(n):
		return _cache[n]
	var tex := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	_cache[n] = tex
	if _inst == null or not is_instance_valid(_inst):
		_inst = ItemIcons.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	_inst._queue.append(n)
	_inst._kick.call_deferred()
	return tex


func _kick() -> void:
	if _busy or not is_inside_tree():
		if not _busy:
			_kick.call_deferred()
		return
	_busy = true
	while not _queue.is_empty():
		var n: String = _queue.pop_front()
		await _render(n)
	_busy = false


func _render(n: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var m := ItemModels.make(n, 1.0)
	m.rotation_degrees = Vector3(8, -30, 35 if n.begins_with("Sword") or n.begins_with("Axe") or n.begins_with("Dagger") or n.contains("Staff") or n.begins_with("Bow") or n.begins_with("Spear") or n.begins_with("Hammer") else 0)
	vp.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 24
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.62, 2.25), Vector3(0, 0.48, 0))
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img != null and _cache.has(n):
		(_cache[n] as ImageTexture).set_image(img)
	vp.queue_free()
