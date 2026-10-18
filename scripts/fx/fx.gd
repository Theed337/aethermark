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
		"beam": beam(parent, a[0], a[1], a[2], a[3], a[4], a[5] if a.size() > 5 else true)
		"zone": zone(parent, a[0], a[1], a[2], a[3])
		"shards": shards(parent, a[0], a[1], a[2], a[3], a[4])
		"dust": dust(parent, a[0], a[1], a[2])
		"tele":
			var t := telegraph(parent, a[0], a[1], a[2], a[3])
			parent.get_tree().create_timer(float(a[2]) + 0.05).timeout.connect(func(): if is_instance_valid(t): t.queue_free())
	replaying = false

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


static func fx_tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var path := "res://assets/fx/%s.png" % name
		_tex_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[name]


## Additives, ungeschattetes Billboard-Material mit Textur (für Partikel und Blitze).
static func glow_tex_mat(tex_name: String, billboard_particles: bool = true) -> StandardMaterial3D:
	var key := "%s_%s" % [tex_name, billboard_particles]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = fx_tex(tex_name)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if billboard_particles:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	_mat_cache[key] = m
	return m


static func _scale_curve(from_s: float, to_s: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, from_s))
	c.add_point(Vector2(1, to_s))
	return c


static func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([color.lightened(0.5), color, Color(color.r, color.g, color.b, 0.0)])
	return g


## Kurzer heller Blitz-Sprite (Billboard), z. B. bei Treffern.
static func flash(parent: Node, pos: Vector3, color: Color, size: float = 1.2, duration: float = 0.18) -> void:
	if fx_tex("flash") == null:
		return
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = fx_tex("flash")
	m.albedo_color = Color(color.r, color.g, color.b, 1.0).lightened(0.3)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = false
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.top_level = true
	q.position = pos
	q.scale = Vector3(size * 0.4, size * 0.4, size * 0.4)
	parent.add_child(q)
	var tw := q.create_tween()
	tw.set_parallel(true)
	tw.tween_property(q, "scale", Vector3(size, size, size), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_delay(duration * 0.3)
	tw.chain().tween_callback(q.queue_free)


static func _limit() -> float:
	return clampf(float(SaveSystem.data.get("settings", {}).get("particle_limit", 1.0)), 0.1, 1.0)


static func burst(parent: Node, pos: Vector3, color: Color, count: int = 10, speed: float = 4.0, size: float = 0.12, life: float = 0.5) -> void:
	_emit("burst", [pos, color, count, speed, size, life])
	var n := maxi(int(count * _limit()), 2)
	if fx_tex("spark") == null:
		return
	# Funken (Sternchen) + weicher Glow-Nebel + Blitz
	for layer in 2:
		var p := CPUParticles3D.new()
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = n if layer == 0 else maxi(n / 2, 2)
		p.lifetime = life if layer == 0 else life * 1.2
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = speed * (0.4 if layer == 0 else 0.1)
		p.initial_velocity_max = speed * (1.0 if layer == 0 else 0.4)
		p.gravity = Vector3(0, -5, 0) if layer == 0 else Vector3(0, 0.4, 0)
		p.damping_min = 1.0
		p.damping_max = 3.0
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE
		p.mesh = qm
		p.material_override = glow_tex_mat("spark" if layer == 0 else "glow")
		p.scale_amount_min = size * (8.0 if layer == 0 else 9.0)
		p.scale_amount_max = size * (14.0 if layer == 0 else 16.0)
		p.scale_amount_curve = _scale_curve(1.0, 0.1 if layer == 0 else 1.6)
		p.color_ramp = _fade_ramp(color if layer == 0 else color.darkened(0.25))
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.position = pos
		p.top_level = true
		parent.add_child(p)
		_free_later(p, life * 1.2 + 0.4)
	flash(parent, pos, color, size * 9.0, 0.16)


static func ring(parent: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.4, thickness: float = 0.12, start_scale: float = 0.1) -> void:
	_emit("ring", [pos, radius, color, duration, thickness, start_scale])
	if fx_tex("ring") == null:
		return
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	qm.orientation = PlaneMesh.FACE_Y
	mi.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = fx_tex("ring")
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95).lightened(0.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.1, 0)
	mi.scale = Vector3(radius * start_scale, 1.0, radius * start_scale)
	mi.top_level = true
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(duration * 0.25)
	tw.chain().tween_callback(mi.queue_free)
	# aufsteigender Glanz in der Mitte
	flash(parent, pos + Vector3(0, 0.4, 0), color, minf(radius * 0.8, 2.5), duration * 0.7)


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


static func beam(parent: Node, a: Vector3, b: Vector3, color: Color, duration: float = 0.18, width: float = 0.07, flashes: bool = true) -> void:
	_emit("beam", [a, b, color, duration, width, flashes])
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
	if flashes:
		flash(parent, a, color, width * 14.0, duration)
		flash(parent, b, color, width * 20.0, duration * 1.4)
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
	if fx_tex("glow") != null:
		var gq := MeshInstance3D.new()
		var gm := QuadMesh.new()
		gm.size = Vector2(radius * 2.4, radius * 2.4)
		gm.orientation = PlaneMesh.FACE_Y
		gq.mesh = gm
		var gmat := StandardMaterial3D.new()
		gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gmat.albedo_texture = fx_tex("glow")
		gmat.albedo_color = Color(color.r, color.g, color.b, 0.9)
		gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		gq.material_override = gmat
		gq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gq)
		var rq := MeshInstance3D.new()
		var rm := QuadMesh.new()
		rm.size = Vector2(radius * 2.0, radius * 2.0)
		rm.orientation = PlaneMesh.FACE_Y
		rq.mesh = rm
		var rmat := gmat.duplicate()
		rmat.albedo_texture = fx_tex("ring")
		rmat.albedo_color = Color(color.r, color.g, color.b, 0.8).lightened(0.2)
		rq.material_override = rmat
		rq.position.y = 0.01
		rq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rq)
	else:
		var ring_mesh := Toon.part(root, "disc", Vector3(radius, 0.05, 0), color, Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(color, 1.6, 0.5), false)
		ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if fx_tex("flame") != null:
		var em := CPUParticles3D.new()
		em.amount = maxi(int(18 * radius * _limit()), 6)
		em.lifetime = 1.1
		em.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		em.emission_sphere_radius = radius * 0.85
		em.direction = Vector3.UP
		em.spread = 12.0
		em.initial_velocity_min = 0.6
		em.initial_velocity_max = 1.8
		em.gravity = Vector3(0, 0.6, 0)
		var fm := QuadMesh.new()
		fm.size = Vector2.ONE
		em.mesh = fm
		em.material_override = glow_tex_mat("flame")
		em.scale_amount_min = 0.5
		em.scale_amount_max = 1.1
		em.scale_amount_curve = _scale_curve(1.0, 0.2)
		em.color_ramp = _fade_ramp(color)
		em.position.y = 0.1
		root.add_child(em)
	var light := OmniLight3D.new()
	light.light_color = color.lightened(0.2)
	light.omni_range = 6.0
	light.position.y = 0.8
	root.add_child(light)
	root.get_tree().create_timer(duration).timeout.connect(func(): if is_instance_valid(root): root.queue_free())
	return root


## Dauerhafter Glow-Sprite (Billboard) zum Anhängen an Geschosse, Wisps usw. (kein Netzwerkereignis).
static func glow_sprite(parent: Node3D, color: Color, size: float, tex_name: String = "glow") -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = fx_tex(tex_name)
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.scale = Vector3(size, size, size)
	parent.add_child(q)
	return q


## Partikelschweif, der hinter einem bewegten Knoten zurückbleibt.
static func trail(parent: Node3D, color: Color, size: float, amount: int = 22, life: float = 0.45) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(int(amount * _limit()), 4)
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.4
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, 0.6, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	p.mesh = qm
	p.material_override = glow_tex_mat("glow")
	p.scale_amount_min = size * 3.0
	p.scale_amount_max = size * 5.0
	p.scale_amount_curve = _scale_curve(1.0, 0.05)
	p.color_ramp = _fade_ramp(color)
	parent.add_child(p)
	return p


## Zackige Blitzlinie aus mehreren Strahl-Segmenten.
static func bolt(parent: Node, a: Vector3, b: Vector3, color: Color, duration: float = 0.25, width: float = 0.05) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.1:
		return
	var dirn := d / len
	var side := dirn.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dirn).normalized()
	var segs := clampi(int(len / 0.9), 3, 9)
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var pt := a + d * t
		if i < segs:
			var jit := minf(0.45, len * 0.06)
			pt += side * randf_range(-jit, jit) + up * randf_range(-jit, jit)
		beam(parent, prev, pt, color, duration, width, false)
		prev = pt
	beam(parent, a, b, Color(1, 1, 1), duration * 0.7, width * 0.35, false)
	flash(parent, a, color, width * 16.0, duration)
	flash(parent, b, color, width * 28.0, duration * 1.4)


## Aufragende Splitter (Eis/Stein) im Kreis um pos.
static func shards(parent: Node, pos: Vector3, radius: float, color: Color, count: int = 14, rise: float = 1.4) -> void:
	_emit("shards", [pos, radius, color, count, rise])
	var n := maxi(int(count * _limit()), 4)
	for i in n:
		var ang := randf() * TAU
		var rr := radius * sqrt(randf()) * 0.95
		var h := randf_range(0.5, 1.0) * rise
		var sh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.12, 0.26) * (0.6 + rise * 0.3)
		cm.height = h
		cm.radial_segments = 5
		sh.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
		mat.roughness = 0.2
		mat.metallic_specular = 0.8
		sh.material_override = mat
		sh.top_level = true
		sh.position = pos + Vector3(cos(ang) * rr, -h * 0.5, sin(ang) * rr)
		sh.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(sh)
		var tw := sh.create_tween()
		tw.tween_property(sh, "position:y", pos.y + h * 0.45, 0.22).set_ease(Tween.EASE_OUT).set_delay(randf() * 0.15)
		tw.tween_interval(0.5)
		tw.tween_property(sh, "position:y", pos.y - h * 0.6, 0.45).set_ease(Tween.EASE_IN)
		tw.tween_callback(sh.queue_free)


## Aufgewirbelter Staub / Nebel (Alpha-Rauch) in einer wachsenden Ringwolke.
static func dust(parent: Node, pos: Vector3, radius: float, color: Color) -> void:
	_emit("dust", [pos, radius, color])
	if fx_tex("smoke") == null:
		return
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = maxi(int(26 * _limit()), 6)
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius * 0.5
	p.emission_ring_inner_radius = radius * 0.3
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = radius * 0.6
	p.initial_velocity_max = radius * 1.2
	p.radial_accel_min = radius * 0.6
	p.radial_accel_max = radius * 1.2
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	p.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = fx_tex("smoke")
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.2
	p.scale_amount_curve = _scale_curve(0.5, 1.4)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.55), Color(color.r, color.g, color.b, 0.0)])
	p.color_ramp = g
	p.position = pos + Vector3(0, 0.25, 0)
	p.top_level = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	_free_later(p, 1.8)


static func _free_later(n: Node, t: float) -> void:
	n.get_tree().create_timer(t).timeout.connect(func(): if is_instance_valid(n): n.queue_free())
