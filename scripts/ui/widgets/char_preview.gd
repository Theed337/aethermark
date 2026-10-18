class_name CharPreview
extends SubViewportContainer
## Eigene kleine 3D-Welt mit dem Charakter (Paper-Doll im Inventar). Ziehen mit der Maus dreht die Figur.

var _vp: SubViewport
var _holder: Node3D
var _model: Dictionary = {}
var _yaw := 0.35
var _drag := false


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(300, 420)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.74)
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_energy = 1.1
	_vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.5
	rim.light_color = Color("#9ad0ff")
	_vp.add_child(rim)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	var cam := Camera3D.new()
	cam.fov = 28.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.15, 5.3), Vector3(0, 1.05, 0))
	cam.current = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_character(c: Dictionary) -> void:
	if not _model.is_empty():
		_model["root"].queue_free()
		_model = {}
	var w := "sword"
	var eq: Dictionary = c.get("equipment", {})
	if eq.has("weapon"):
		w = SaveSystem.find_item(c, eq["weapon"]).get("weapon_type", "sword")
	_model = CharacterModel.build(c.get("appearance", {}), w, CharacterModel.gear_looks(c))
	_holder.add_child(_model["root"])
	_model["root"].rotation.y = _yaw
	var ap: AnimationPlayer = _model.get("anim")
	if ap != null and ap.has_animation("Idle"):
		ap.play("Idle")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag and not _model.is_empty():
		_yaw += event.relative.x * 0.012
		_model["root"].rotation.y = _yaw
