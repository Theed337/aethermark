class_name ForestMap
extends RefCounted
## Der Smaragdwald: handgesetzte Zonen (Startlichtung, Teich, Ruinen, Bossarena) mit zufällig
## variierter Dekoration. Zonen sind fest, Bäume/Pilze/Truhen/Schrein-Orte variieren je Seed.

const RADIUS := 60.0
const SPAWN_POS := Vector3(0, 0.1, 18)
const BOSS_POS := Vector3(0, 0.1, -36)
const BOSS_ARENA_R := 15.0
const POND_POS := Vector3(24, 0, 8)
const POND_R := 8.0

const FOREST := [Color("#3f8f4a"), Color("#4fa356"), Color("#2f7a45"), Color("#5cb35a")]

## Gebiets-Thema (Farben, Baumstil, Gefahrenzone). Standard = Smaragdwald; areas.json überschreibt einzelne Werte ("biome").
const DEFAULT_THEME := {
	"sky_top": "#5aa8e8", "sky_horizon": "#d8f0e8", "sky_ground": "#2f5a3a", "fog": "#bfe6d0", "fog_density": 0.006,
	"sun": "#fff1d0", "sun_energy": 1.25, "ambient": 0.9, "saturation": 1.18,
	"ground": "#4b9a4d", "patches": ["#3f8f4a", "#4fa356", "#2f7a45", "#5cb35a"], "path": "#c9ab72", "clearing": "#d8c288",
	"foliage": ["#3f8f4a", "#4fa356", "#2f7a45", "#5cb35a"], "bark": ["#7a5232", "#5a3a22"], "tree_style": "round", "trees": 95,
	"grass_hue": [0.25, 0.36], "flowers": ["#ff9ad0", "#ffe066", "#9ad8ff", "#ffffff", "#ff8a6a"],
	"glow_things": ["#ff6a9a", "#6ae0ff", "#c0ff6a", "#d99bff"], "rocks": ["#8d968f", "#6b7d6a"],
	"stone": "#b9b3a0", "moss": "#6fa86a", "rune": "#7dffe0", "arena_floor": "#9a9a82", "arena_inner": "#7a9a62", "glyph": "#d8ff6a",
	"particles": "#f4ff8a", "hills": ["#3d8a6a", "#5a8fb0"],
	"liquid": "water", "liquid_color": "#3a9ad0",
	"hazard": "none", "hazard_dps": 0.0
}
static var T: Dictionary = DEFAULT_THEME.duplicate(true)


static func set_theme(area_id: String) -> void:
	T = DEFAULT_THEME.duplicate(true)
	var a: Dictionary = GameData.area_by_id(area_id)
	var b: Dictionary = a.get("biome", {})
	for k in b:
		T[k] = b[k]


static func col(key: String) -> Color:
	return Color(str(T[key]))


static func pal(key: String) -> Array:
	var out: Array = []
	for c in T[key]:
		out.append(Color(str(c)))
	return out


## Gefahrenzone (Teich/Lava/Gift/Leere): liegt der Punkt darin?
static func in_hazard(p: Vector3) -> bool:
	return str(T["hazard"]) != "none" and Vector2(p.x - POND_POS.x, p.z - POND_POS.z).length() < POND_R


static func build(root: Node3D, seed_value: int, area_id: String = "") -> Dictionary:
	set_theme(area_id if area_id != "" else RunState.area_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var info := {"chests": [], "shrines": [], "boss_pos": BOSS_POS, "spawn": SPAWN_POS, "radius": RADIUS}
	_environment(root)
	_ground(root, rng)
	_pond(root)
	_trees(root, rng)
	_undergrowth(root, rng)
	_ruins(root, rng)
	_boss_arena(root)
	_boundary(root, rng)
	_fireflies(root)
	# Truhen und Schreine: Orte variieren je Seed, aber immer abseits der Zonen
	for i in 6:
		info["chests"].append(_free_spot(rng, 14.0, 50.0))
	for i in 2:
		info["shrines"].append(_free_spot(rng, 18.0, 46.0))
	return info


static func _free_spot(rng: RandomNumberGenerator, rmin: float, rmax: float) -> Vector3:
	for i in 60:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if _blocked(p, 3.0):
			continue
		return p
	return Vector3(8, 0, 8)


static func _blocked(p: Vector3, margin: float) -> bool:
	if Vector2(p.x - SPAWN_POS.x, p.z - SPAWN_POS.z).length() < 7.0 + margin:
		return true
	if Vector2(p.x - BOSS_POS.x, p.z - BOSS_POS.z).length() < BOSS_ARENA_R + margin:
		return true
	if Vector2(p.x - POND_POS.x, p.z - POND_POS.z).length() < POND_R + margin:
		return true
	return false


static func _environment(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = col("sun")
	sun.light_energy = float(T["sun_energy"])
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	root.add_child(sun)
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = col("sky_top")
	sky_mat.sky_horizon_color = col("sky_horizon")
	sky_mat.ground_bottom_color = col("sky_ground")
	sky_mat.ground_horizon_color = col("sky_horizon")
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(T["ambient"])
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = col("fog")
	env.fog_density = float(T["fog_density"])
	env.fog_sky_affect = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = float(T["saturation"])
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


static func _ground(root: Node3D, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS + 12.0
	shape.height = 2.0
	cs.shape = shape
	cs.position.y = -1.0
	body.add_child(cs)
	root.add_child(body)
	Toon.part(body, "disc", Vector3(RADIUS + 12.0, 0.2, 0), col("ground"), Vector3(0, -0.1, 0), Vector3.ZERO, Toon.mat(col("ground"), 0.0, 0.0), false)
	# Farbflecken für Variation
	for i in 36:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RADIUS - 4.0)
		var pc := pal("patches")
		var c: Color = pc[rng.randi() % pc.size()]
		var m := Toon.part(body, "disc", Vector3(rng.randf_range(3.0, 9.0), 0.02, 0), c, Vector3(cos(ang) * r, 0.01 + i * 0.0004, sin(ang) * r), Vector3.ZERO, Toon.mat(c, 0.0, 0.0), false)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Weg von der Startlichtung zur Bossarena
	var path_c := col("path")
	for i in 14:
		var t := float(i) / 13.0
		var pos := SPAWN_POS.lerp(BOSS_POS, t)
		pos.x += sin(t * 7.0) * 4.0
		var m := Toon.part(body, "disc", Vector3(2.4 + sin(i) * 0.3, 0.03, 0), path_c, Vector3(pos.x, 0.03, pos.z), Vector3.ZERO, Toon.mat(path_c, 0.0, 0.0), false)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Startlichtung
	var m2 := Toon.part(body, "disc", Vector3(7.0, 0.03, 0), col("clearing"), Vector3(SPAWN_POS.x, 0.035, SPAWN_POS.z), Vector3.ZERO, Toon.mat(col("clearing"), 0.0, 0.0), false)
	m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _pond(root: Node3D) -> void:
	var water := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = POND_R
	cm.bottom_radius = POND_R
	cm.height = 0.05
	cm.radial_segments = 40
	water.mesh = cm
	if str(T["liquid"]) == "water":
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/water.gdshader")
		water.material_override = sm
	else:
		var lc := col("liquid_color")
		water.material_override = Toon.glow_mat(lc, 1.6 if str(T["hazard"]) in ["lava", "poison", "void"] else 0.3, 0.95)
	water.position = Vector3(POND_POS.x, 0.08, POND_POS.z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	# Uferrand und Seerosen
	var rim := Toon.part(root, "torus", Vector3(POND_R + 0.4, POND_R - 0.4, 0), Color("#8a8a7a"), Vector3(POND_POS.x, 0.12, POND_POS.z), Vector3.ZERO, Toon.mat(Color("#8a8a7a")), false)
	rim.scale.y = 0.4
	if str(T["liquid"]) != "water":
		return
	for i in 7:
		var a := i * 0.9 + 0.3
		Toon.part(root, "disc", Vector3(0.5, 0.03, 0), Color("#5fd16a"), Vector3(POND_POS.x + cos(a) * (2.0 + i * 0.5), 0.12, POND_POS.z + sin(a) * (2.5 + i * 0.4)), Vector3.ZERO, Toon.mat(Color("#5fd16a")), false)
		Toon.part(root, "sphere", Vector3(0.14, 0, 0), Color("#ff9ad0"), Vector3(POND_POS.x + cos(a) * (2.0 + i * 0.5), 0.2, POND_POS.z + sin(a) * (2.5 + i * 0.4)), Vector3.ZERO, Toon.glow_mat(Color("#ff9ad0"), 0.6), false)


static func _tree(parent: Node3D, pos: Vector3, scale_f: float, rng: RandomNumberGenerator, collide: bool = true) -> void:
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = rng.randf() * TAU
	parent.add_child(t)
	var kind := rng.randi() % 3
	var fol := pal("foliage")
	var leaf: Color = fol[rng.randi() % fol.size()].lightened(rng.randf_range(-0.05, 0.12))
	var bk := pal("bark")
	var bark: Color = bk[0].lerp(bk[1], rng.randf())
	var h := 2.4 * scale_f
	var style := str(T["tree_style"])
	if style == "crystal":
		for i in 3:
			var ch := h * (0.7 + i * 0.35)
			Toon.part(t, "prism", Vector3(0.3 * scale_f, ch, 0.3 * scale_f), leaf.lightened(0.1 * i), Vector3((i - 1) * 0.45 * scale_f, ch * 0.5, (i % 2) * 0.3), Vector3(0, 0, (i - 1) * 12), Toon.glow_mat(leaf, 1.2, 0.9))
		kind = -1
	elif style == "dead":
		Toon.part(t, "cyl", Vector3(0.2 * scale_f, h * 1.3, 0.3 * scale_f), bark, Vector3(0, h * 0.65, 0))
		for i in 3:
			Toon.part(t, "cyl", Vector3(0.08 * scale_f, h * 0.7, 0.1 * scale_f), bark.darkened(0.1), Vector3(sin(i * 2.1) * 0.5 * scale_f, h * (0.9 + i * 0.2), cos(i * 2.1) * 0.5 * scale_f), Vector3(0, 0, 40 * (1 if i % 2 == 0 else -1)))
		kind = -1
	else:
		Toon.part(t, "cyl", Vector3(0.28 * scale_f, h, 0.42 * scale_f), bark, Vector3(0, h * 0.5, 0))
		if style == "pine":
			kind = 0
	if kind == -1:
		pass
	elif kind == 0:
		for i in 3:
			Toon.part(t, "cone", Vector3((1.5 - i * 0.35) * scale_f, 1.5 * scale_f, 0), leaf.darkened(0.04 * i), Vector3(0, h + i * 0.9 * scale_f, 0))
	elif kind == 1:
		Toon.part(t, "sphere", Vector3(1.5 * scale_f, 0.85, 0), leaf, Vector3(0, h + 0.8 * scale_f, 0))
		Toon.part(t, "sphere", Vector3(1.0 * scale_f, 0.9, 0), leaf.lightened(0.08), Vector3(0.7 * scale_f, h + 0.3 * scale_f, 0.3))
		Toon.part(t, "sphere", Vector3(0.9 * scale_f, 0.9, 0), leaf.darkened(0.05), Vector3(-0.6 * scale_f, h + 0.4 * scale_f, -0.4))
	else:
		Toon.part(t, "sphere", Vector3(1.3 * scale_f, 1.1, 0), leaf, Vector3(0, h + 1.1 * scale_f, 0))
		Toon.part(t, "sphere", Vector3(0.7 * scale_f, 1.0, 0), col("rune").lerp(leaf, 0.6) if style != "round" else Color("#ff9ad0").lerp(leaf, 0.3), Vector3(0.7 * scale_f, h + 1.6 * scale_f, 0.5))
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.5 * scale_f
		sh.height = 3.0
		cs.shape = sh
		cs.position.y = 1.5
		sb.add_child(cs)
		t.add_child(sb)


static func _trees(root: Node3D, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Trees"
	root.add_child(holder)
	var placed := 0
	var tries := 0
	while placed < int(T["trees"]) and tries < 700:
		tries += 1
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RADIUS - 6.0)
		var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if _blocked(p, 2.0):
			continue
		_tree(holder, p, rng.randf_range(0.9, 1.7), rng)
		placed += 1


static func _undergrowth(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Gras und Blumen als MultiMesh (performant)
	var grass := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.1
	cm.height = 0.5
	cm.radial_segments = 4
	mm.mesh = cm
	mm.instance_count = 900
	for i in 900:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RADIUS - 3.0)
		var p := Vector3(cos(ang) * r, 0.2, sin(ang) * r)
		var s := rng.randf_range(0.7, 1.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, p))
		mm.set_instance_color(i, Color.from_hsv(rng.randf_range(float(T["grass_hue"][0]), float(T["grass_hue"][1])), rng.randf_range(0.5, 0.75), rng.randf_range(0.65, 0.95)))
	grass.multimesh = mm
	grass.material_override = Toon.mat(Color.WHITE, 0.0, 0.1)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grass)
	var flowers := MultiMeshInstance3D.new()
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	var sp := SphereMesh.new()
	sp.radius = 0.09
	sp.height = 0.18
	sp.radial_segments = 6
	sp.rings = 3
	fm.mesh = sp
	fm.instance_count = 260
	var fpal := pal("flowers")
	for i in 260:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RADIUS - 3.0)
		fm.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(ang) * r, 0.4, sin(ang) * r)))
		fm.set_instance_color(i, fpal[rng.randi() % fpal.size()])
	flowers.multimesh = fm
	flowers.material_override = Toon.glow_mat(Color.WHITE, 0.5)
	flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flowers)
	# Leuchtpilze und Felsen
	for i in 38:
		var p := _free_spot(rng, 4.0, 56.0)
		var gt := pal("glow_things")
		var c: Color = gt[rng.randi() % gt.size()]
		var s := rng.randf_range(0.6, 1.4)
		var m := Node3D.new()
		m.position = p
		root.add_child(m)
		Toon.part(m, "cyl", Vector3(0.09 * s, 0.4 * s, 0.12 * s), Color("#f0e8d8"), Vector3(0, 0.2 * s, 0))
		var cap := Toon.part(m, "sphere", Vector3(0.32 * s, 0.6, 0), c, Vector3(0, 0.42 * s, 0), Vector3.ZERO, Toon.make_mat(c, 0.6, 0.5))
		cap.scale.y = 0.6
	for i in 30:
		var p := _free_spot(rng, 5.0, 57.0)
		var s := rng.randf_range(0.5, 1.6)
		var rk := pal("rocks")
		var c: Color = rk[0].lerp(rk[1], rng.randf())
		var rock := Toon.part(root, "sphere", Vector3(0.6 * s, 0.7, 0), c, p + Vector3(0, 0.25 * s, 0), Vector3(rng.randf() * 30, rng.randf() * 360, 0))
		rock.scale = Vector3(1.0, 0.7, 0.9)
		if s > 1.0:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			var cs := CollisionShape3D.new()
			var sh := SphereShape3D.new()
			sh.radius = 0.55 * s
			cs.shape = sh
			cs.position = p + Vector3(0, 0.3, 0)
			sb.add_child(cs)
			root.add_child(sb)


static func _ruins(root: Node3D, rng: RandomNumberGenerator) -> void:
	var stone := col("stone")
	var moss := col("moss")
	for k in 4:
		var c := _free_spot(rng, 16.0, 44.0)
		var n := rng.randi_range(3, 5)
		for i in n:
			var a := i * TAU / n
			var p := c + Vector3(cos(a), 0, sin(a)) * 3.0
			var h := rng.randf_range(1.2, 3.2)
			var col := Toon.part(root, "cyl", Vector3(0.45, h, 0.5), stone.lerp(moss, rng.randf() * 0.4), p + Vector3(0, h * 0.5, 0))
			Toon.outline(col, 0.02)
			Toon.part(root, "box", Vector3(1.0, 0.25, 1.0), stone.darkened(0.08), p + Vector3(0, h + 0.12, 0), Vector3(0, rng.randf() * 40, rng.randf_range(-6, 6)))
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.45
			sh.height = h
			cs.shape = sh
			cs.position = p + Vector3(0, h * 0.5, 0)
			sb.add_child(cs)
			root.add_child(sb)
		Toon.part(root, "disc", Vector3(2.2, 0.15, 0), stone.darkened(0.1), c + Vector3(0, 0.08, 0), Vector3.ZERO, Toon.mat(stone.darkened(0.1)), false)
		Toon.part(root, "sphere", Vector3(0.22, 0, 0), col("rune"), c + Vector3(0, 0.6, 0), Vector3.ZERO, Toon.glow_mat(col("rune"), 2.0), false)


static func _boss_arena(root: Node3D) -> void:
	var c := BOSS_POS
	var stone := col("stone").darkened(0.05)
	Toon.part(root, "disc", Vector3(BOSS_ARENA_R, 0.12, 0), col("arena_floor"), c + Vector3(0, 0.06, 0), Vector3.ZERO, Toon.mat(col("arena_floor"), 0.0, 0.0), false)
	Toon.part(root, "disc", Vector3(BOSS_ARENA_R - 2.5, 0.14, 0), col("arena_inner"), c + Vector3(0, 0.07, 0), Vector3.ZERO, Toon.mat(col("arena_inner"), 0.0, 0.0), false)
	var glyph := Toon.part(root, "torus", Vector3(9.0, 8.8, 0), col("glyph"), c + Vector3(0, 0.16, 0), Vector3.ZERO, Toon.glow_mat(col("glyph"), 1.2, 0.8), false)
	glyph.scale.y = 0.2
	# Wächtersäulen mit Wurzeln
	var n := 12
	for i in n:
		var a := i * TAU / n
		var p := c + Vector3(cos(a), 0, sin(a)) * (BOSS_ARENA_R + 1.0)
		var h := 3.5 + (i % 3) * 0.8
		var col := Toon.part(root, "cyl", Vector3(0.7, h, 0.85), stone, p + Vector3(0, h * 0.5, 0))
		Toon.outline(col, 0.025)
		Toon.part(root, "sphere", Vector3(0.25, 0, 0), col("glyph"), p + Vector3(0, h + 0.3, 0), Vector3.ZERO, Toon.glow_mat(col("glyph"), 2.2), false)
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.8
		sh.height = h
		cs.shape = sh
		cs.position = p + Vector3(0, h * 0.5, 0)
		sb.add_child(cs)
		root.add_child(sb)


static func _boundary(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Unsichtbare Wand + dichter Baumring
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var segs := 36
	for i in segs:
		var a := i * TAU / segs
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(10.0, 12.0, 1.0)
		cs.shape = b
		cs.position = Vector3(cos(a), 0, sin(a)) * (RADIUS + 1.0) + Vector3(0, 6, 0)
		cs.rotation.y = -a + PI * 0.5
		wall.add_child(cs)
	root.add_child(wall)
	var holder := Node3D.new()
	root.add_child(holder)
	for i in 70:
		var a := i * TAU / 70.0 + rng.randf() * 0.05
		var r := RADIUS + rng.randf_range(0.0, 8.0)
		_tree(holder, Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(1.8, 2.8), rng, false)
	# Ferne Hügel als Kulisse
	for i in 14:
		var a := i * TAU / 14.0 + rng.randf() * 0.3
		var r := RADIUS + 38.0 + rng.randf() * 14.0
		var hc := pal("hills")
		var c: Color = hc[0].lerp(hc[1], rng.randf() * 0.7)
		var h := Toon.part(root, "sphere", Vector3(rng.randf_range(16.0, 26.0), 0.8, 0), c, Vector3(cos(a) * r, -3.0, sin(a) * r), Vector3.ZERO, Toon.mat(c, 0.0, 0.2), false)
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _fireflies(root: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(60 * clampf(float(SaveSystem.data.get("settings", {}).get("particle_limit", 1.0)), 0.2, 1.0))
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(RADIUS, 2.5, RADIUS)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 4
	sm.rings = 2
	p.mesh = sm
	p.material_override = Toon.glow_mat(col("particles"), 3.0)
	p.position = Vector3(0, 2.5, 0)
	root.add_child(p)
