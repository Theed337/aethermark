class_name FX
extends RefCounted
## Visuelle Effekte (Partikel, Ringe, Blitze, Schadenszahlen). Alles prozedural.
## Multiplayer: Der Host setzt net_hook; jeder Effekt wird dann zusätzlich als Ereignis an alle Clients gesendet,
## die ihn mit apply_event() lokal abspielen. So sehen alle dieselben Effekte, ohne dass jede Fähigkeit einzeln
## synchronisiert werden muss.

static var net_hook: Callable = Callable()   # (kind: String, args: Array) -> void, nur auf dem Host gesetzt
static var replaying := false                # true, solange ein empfangenes Ereignis abgespielt wird


static func _emit(kind: String, args: Array) -> void:
	if net_hook.is_valid() and not replaying:
		net_hook.call(kind, args)


## Spielt ein vom Host empfangenes Effekt-Ereignis lokal ab.
static func apply_event(parent: Node, kind: String, a: Array) -> void:
	replaying = true
	match kind:
		"burst": burst(parent, a[0], a[1], a[2], a[3], a[4], a[5])
		"ring": ring(parent, a[0], a[1], a[2], a[3], a[4], a[5])
		"float": float_text(parent, a[0], a[1], a[2], a[3], a[4])
		"beam": beam(parent, a[0], a[1], a[2], a[3], a[4])
		"zone": zone(parent, a[0], a[1], a[2], a[3])
		"tele":
			var t := telegraph(parent, a[0], a[1], a[2], a[3])
			parent.get_tree().create_timer(float(a[2]) + 0.05).timeout.connect(func(): if is_instance_valid(t): t.queue_free())
	replaying = false

static func _limit() -> float:
	return clampf(float(SaveSystem.data.get("settings", {}).get("particle_limit", 1.0)), 0.1, 1.0)


static func burst(parent: Node, pos: Vector3, color: Color, count: int = 10, speed: float = 4.0, size: float = 0.12, life: float = 0.5) -> void:
	_emit("burst", [pos, color, count, speed, size, life])
	var n := maxi(int(count * _limit()), 2)
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	p.mesh = m
	p.material_override = Toon.glow_mat(color, 2.0)
	p.position = pos
	p.top_level = true
	parent.add_child(p)
	_free_later(p, life + 0.4)


static func ring(parent: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.4, thickness: float = 0.12, start_scale: float = 0.1) -> void:
	_emit("ring", [pos, radius, color, duration, thickness, start_scale])
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.outer_radius = 1.0
	t.inner_radius = 1.0 - thickness
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	var mat := Toon.glow_mat(color, 2.2, 0.85)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.12, 0)
	mi.scale = Vector3(radius * start_scale, radius * start_scale, radius * start_scale)
	mi.top_level = true
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.25, radius), duration).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float): mat.set_shader_parameter("alpha", a), 0.85, 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


## Warnzone am Boden (Telegraph). Gibt den Knoten zurück, damit der Aufrufer ihn entfernen kann.
static func telegraph(parent: Node, pos: Vector3, radius: float, duration: float, color: Color = Color(1.0, 0.25, 0.2)) -> Node3D:
	_emit("tele", [pos, radius, duration, color])
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.06, pos.z)
	root.top_level = true
	var disc := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.04
	m.radial_segments = 32
	disc.mesh = m
	var mat := Toon.glow_mat(color, 1.2, 0.25)
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var fill := MeshInstance3D.new()
	var m2 := CylinderMesh.new()
	m2.top_radius = radius
	m2.bottom_radius = radius
	m2.height = 0.05
	m2.radial_segments = 32
	fill.mesh = m2
	var mat2 := Toon.glow_mat(color, 2.0, 0.5)
	fill.material_override = mat2
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.scale = Vector3(0.02, 1, 0.02)
	root.add_child(fill)
	parent.add_child(root)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3(1, 1, 1), duration)
	return root


static func float_text(parent: Node, pos: Vector3, text: String, color: Color = Color.WHITE, size: int = 48, crit: bool = false) -> void:
	_emit("float", [pos, text, color, size, crit])
	if not SaveSystem.data.get("settings", {}).get("show_damage_numbers", true):
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = size + (24 if crit else 0)
	l.pixel_size = 0.008
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.02, 0.08)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.top_level = true
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 1.8, randf_range(-0.3, 0.3))
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.4, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


static func beam(parent: Node, a: Vector3, b: Vector3, color: Color, duration: float = 0.18, width: float = 0.07) -> void:
	_emit("beam", [a, b, color, duration, width])
	var d := b - a
	var len := d.length()
	if len < 0.05:
		return
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = width
	m.bottom_radius = width
	m.height = len
	m.radial_segments = 5
	mi.mesh = m
	var mat := Toon.glow_mat(color, 3.0, 0.95)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	parent.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := d.normalized()
	var axis := Vector3.UP.cross(up)
	if axis.length() < 0.001:
		axis = Vector3.RIGHT
	mi.global_transform.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("alpha", v), 0.95, 0.0, duration)
	tw.tween_callback(mi.queue_free)


## Flächeneffekt am Boden (z. B. Feuerfläche): leuchtende Scheibe mit Licht, die nach `duration` verschwindet.
static func zone(parent: Node, pos: Vector3, radius: float, color: Color, duration: float) -> Node3D:
	_emit("zone", [pos, radius, color, duration])
	var root := Node3D.new()
	root.top_level = true
	root.position = Vector3(pos.x, 0.05, pos.z)
	parent.add_child(root)
	var ring_mesh := Toon.part(root, "disc", Vector3(radius, 0.05, 0), color, Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(color, 1.6, 0.5), false)
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = color.lightened(0.2)
	light.omni_range = 6.0
	light.position.y = 0.8
	root.add_child(light)
	root.get_tree().create_timer(duration).timeout.connect(func(): if is_instance_valid(root): root.queue_free())
	return root


static func _free_later(n: Node, t: float) -> void:
	n.get_tree().create_timer(t).timeout.connect(func(): if is_instance_valid(n): n.queue_free())
