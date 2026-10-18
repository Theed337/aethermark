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
