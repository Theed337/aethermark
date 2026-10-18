class_name Toon
extends RefCounted
## Hilfsfunktionen für den stilisierten Look: Materialien, Primitive, Outline.
## Alle Figuren und Umgebungen werden prozedural aus diesen Bausteinen erzeugt (siehe docs/STATUS.md:
## Kunststil-Platzhalter, in Phase 6 durch handgemachte Assets ersetzbar).

static var _shader: Shader
static var _outline_shader: Shader
static var _alpha_shader: Shader
static var _cache: Dictionary = {}


static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/toon.gdshader")
	return _shader


static func alpha_shader() -> Shader:
	if _alpha_shader == null:
		_alpha_shader = load("res://shaders/toon_alpha.gdshader")
	return _alpha_shader


static func outline_shader() -> Shader:
	if _outline_shader == null:
		_outline_shader = load("res://shaders/outline.gdshader")
	return _outline_shader


## Geteiltes Material (gecacht) – für Szenerie, die kein eigenes Blitz-Flackern braucht.
static func mat(color: Color, emission: float = 0.0, rim: float = 0.35) -> ShaderMaterial:
	var key := "%s_%.2f_%.2f" % [color.to_html(true), emission, rim]
	if _cache.has(key):
		return _cache[key]
	var m := make_mat(color, emission, rim)
	_cache[key] = m
	return m


## Laub/Gras: wie mat(), aber mit leichtem Windwiegen (Vertex-Animation im Shader).
static func wind_mat(color: Color, strength: float = 1.0) -> ShaderMaterial:
	var key := "wind_%s_%.2f" % [color.to_html(true), strength]
	if _cache.has(key):
		return _cache[key]
	var m := make_mat(color, 0.0, 0.2)
	m.set_shader_parameter("wind", strength)
	m.set_shader_parameter("detail", 0.22)
	_cache[key] = m
	return m


static var _tex_cache: Dictionary = {}


## Geladene Textur + Höhenkarte + Normierung (1/Durchschnittsfarbe), damit die Grundfarbe erhalten bleibt.
static func _tex(name: String) -> Dictionary:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var d := {"tex": null, "h": null, "norm": Vector3.ONE}
	var path := "res://assets/textures/%s.png" % name
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		d["tex"] = t
		var hp := "res://assets/textures/%s_h.png" % name
		if ResourceLoader.exists(hp):
			d["h"] = load(hp)
		var img := t.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.resize(16, 16)
			var sum := Vector3.ZERO
			for y in 16:
				for x in 16:
					var c := img.get_pixel(x, y)
					sum += Vector3(c.r, c.g, c.b)
			sum /= 256.0
			d["norm"] = Vector3(1.0 / maxf(sum.x, 0.05), 1.0 / maxf(sum.y, 0.05), 1.0 / maxf(sum.z, 0.05))
	_tex_cache[name] = d
	return d


## Texturiertes Material (gecacht): `name` = Datei in assets/textures, `scale` = Wiederholungen je Objekteinheit.
static func tmat(color: Color, name: String, scale: float = 1.0, amount: float = 1.0, bump: float = 0.0,
		emission: float = 0.0, rim: float = 0.3, wind: float = 0.0) -> ShaderMaterial:
	var key := "t_%s_%s_%.2f_%.2f_%.2f_%.2f_%.2f_%.2f" % [color.to_html(true), name, scale, amount, bump, emission, rim, wind]
	if _cache.has(key):
		return _cache[key]
	var m := make_mat(color, emission, rim)
	apply_tex(m, name, scale, amount, bump)
	if wind > 0.0:
		m.set_shader_parameter("wind", wind)
	_cache[key] = m
	return m


static func apply_tex(m: ShaderMaterial, name: String, scale: float = 1.0, amount: float = 1.0, bump: float = 0.0) -> void:
	var d := _tex(name)
	if d["tex"] == null:
		return
	m.set_shader_parameter("tex", d["tex"])
	if d["h"] != null:
		m.set_shader_parameter("tex_h", d["h"])
	m.set_shader_parameter("tex_norm", d["norm"])
	m.set_shader_parameter("tex_mix", amount)
	m.set_shader_parameter("tex_scale", scale)
	m.set_shader_parameter("bump", bump)
	m.set_shader_parameter("detail", 0.05)


## Eigenes Material (nicht geteilt) – z. B. für Gegner, die blitzen.
static func make_mat(color: Color, emission: float = 0.0, rim: float = 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("rim", rim)
	if emission > 0.0:
		m.set_shader_parameter("emission_color", color)
		m.set_shader_parameter("emission_energy", emission)
	return m


static func glow_mat(color: Color, energy: float = 2.0, alpha: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	# Nur wirklich transparente Materialien nutzen die Alpha-Variante: ein ALPHA-Schreibzugriff schaltet in Godot
	# die ganze Oberfläche in die Transparenz-Pipeline (keine Tiefe, Sortierung nach Objektmitte -> Flackern).
	m.shader = alpha_shader() if alpha < 0.999 else shader()
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_color", color)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("rim", 0.0)
	m.set_shader_parameter("detail", 0.0)
	if alpha < 0.999:
		m.set_shader_parameter("alpha", alpha)
	return m


static func mesh_of(kind: String, s: Vector3) -> Mesh:
	## sphere: x=Radius | capsule: x=Radius, y=Höhe | box: Größe | cyl: x=Radius, y=Höhe | cone: x=Radius, y=Höhe
	## disc: x=Radius, y=Dicke | torus: x=Außenradius, y=Innenradius | prism: x=Radius, y=Höhe (3-seitig)
	match kind:
		"sphere":
			var m := SphereMesh.new()
			m.radius = s.x
			m.height = s.x * 2.0 * (s.y if s.y > 0.0 else 1.0)
			m.radial_segments = 16
			m.rings = 8
			return m
		"capsule":
			var m := CapsuleMesh.new()
			m.radius = s.x
			m.height = maxf(s.y, s.x * 2.0 + 0.001)
			m.radial_segments = 12
			m.rings = 4
			return m
		"box":
			var m := BoxMesh.new()
			m.size = s
			return m
		"cyl":
			var m := CylinderMesh.new()
			m.top_radius = s.x
			m.bottom_radius = s.x if s.z <= 0.0 else s.z
			m.height = s.y
			m.radial_segments = 14
			return m
		"cone":
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = s.x
			m.height = s.y
			m.radial_segments = 10
			return m
		"disc":
			var m := CylinderMesh.new()
			m.top_radius = s.x
			m.bottom_radius = s.x
			m.height = s.y
			m.radial_segments = 24
			return m
		"torus":
			var m := TorusMesh.new()
			m.outer_radius = s.x
			m.inner_radius = s.y
			m.rings = 20
			m.ring_segments = 8
			return m
		"limb":
			return MeshKit.limb(s.x, s.y, s.z if s.z > 0.0 else s.x)
		"torso":
			return MeshKit.torso(s.x, s.y)
		"head":
			return MeshKit.head(s.x)
		"rock":
			return MeshKit.blob(s.x, int(s.y), s.z if s.z > 0.0 else 0.35, true, 2)
		"blob":
			return MeshKit.blob(s.x, int(s.y), s.z if s.z > 0.0 else 0.18, false, 3)
		"trunk":
			return MeshKit.trunk(s.x, s.y, s.z if s.z > 0.0 else s.x)
		"prism":
			var m := PrismMesh.new()
			m.size = s
			return m
	return BoxMesh.new()


static func part(parent: Node, kind: String, size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, material: Material = null, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_of(kind, size)
	mi.material_override = material if material != null else mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Fügt einer MeshInstance3D eine Outline-Hülle hinzu.
static func outline(mi: MeshInstance3D, thickness: float = 0.025, color: Color = Color(0.06, 0.04, 0.07)) -> void:
	var o := MeshInstance3D.new()
	o.mesh = mi.mesh
	var m := ShaderMaterial.new()
	m.shader = outline_shader()
	m.set_shader_parameter("outline_color", color)
	m.set_shader_parameter("thickness", thickness)
	o.material_override = m
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(o)


static func set_flash(root: Node, value: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mm: Material = n.material_override
		if mm is ShaderMaterial and mm.shader == shader():
			mm.set_shader_parameter("flash", value)
