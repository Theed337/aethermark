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
	_nature_scatter(root, rng)
	var aid := area_id if area_id != "" else RunState.area_id
	if aid == "emerald_forest":
		_ruins(root, rng)
	AreaDecor.build(root, rng, aid)
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
	var q: int = clampi(int(SaveSystem.data.get("settings", {}).get("graphics_quality", 2)), 0, 2)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = col("sun")
	sun.light_energy = float(T["sun_energy"])
	sun.shadow_enabled = true
	# Kaskadenschatten: scharf nahe der Kamera, kein Flimmern beim Laufen
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q >= 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_split_1 = 0.15
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.6
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 0.6
	sun.light_volumetric_fog_energy = 1.0
	root.add_child(sun)
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = col("sky_top")
	sky_mat.sky_horizon_color = col("sky_horizon")
	sky_mat.ground_bottom_color = col("sky_ground")
	sky_mat.ground_horizon_color = col("sky_horizon")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Umgebungslicht als feste Farbe (in allen Renderern zuverlässig); die Himmelsfärbung steckt in der Farbe
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = col("sky_horizon").lerp(col("sky_top"), 0.4).lerp(col("ground"), 0.25)
	env.ambient_light_energy = float(T["ambient"]) * 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = col("fog")
	env.fog_density = float(T["fog_density"])
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = float(T["saturation"])
	env.adjustment_contrast = 1.08
	if q >= 1:
		env.ssao_enabled = true
		env.ssao_radius = 1.4
		env.ssao_intensity = 2.2
		env.ssao_power = 1.6
		env.ssao_detail = 0.6
	if q >= 2:
		# Lichtstrahlen durch die Bäume (nur Forward+; im Kompatibilitätsmodus automatisch ohne Wirkung)
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = col("fog").lerp(Color.WHITE, 0.4)
		env.volumetric_fog_anisotropy = 0.65
		env.volumetric_fog_length = 90.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_ambient_inject = 0.25
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
	# Ein einziges Geländenetz; Weg, Lichtung, Arena und Bodenfarben werden im Shader berechnet (kein Z-Fighting)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300.0, 300.0)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	plane.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/ground.gdshader")
	gm.set_shader_parameter("c_ground", col("ground"))
	var pc := pal("patches")
	gm.set_shader_parameter("c_p1", pc[0])
	gm.set_shader_parameter("c_p2", pc[1 % pc.size()])
	gm.set_shader_parameter("c_path", col("path"))
	gm.set_shader_parameter("c_clear", col("clearing"))
	gm.set_shader_parameter("c_arena", col("arena_floor"))
	gm.set_shader_parameter("c_inner", col("arena_inner"))
	gm.set_shader_parameter("spawn", Vector2(SPAWN_POS.x, SPAWN_POS.z))
	gm.set_shader_parameter("boss", Vector2(BOSS_POS.x, BOSS_POS.z))
	gm.set_shader_parameter("pond", Vector2(POND_POS.x, POND_POS.z))
	gm.set_shader_parameter("pond_r", POND_R)
	gm.set_shader_parameter("arena_r", BOSS_ARENA_R)
	gm.set_shader_parameter("path_pts", path_points())
	for k in ["grass", "dirt", "rock"]:
		var td: Dictionary = Toon._tex(k)
		if td["tex"] != null:
			gm.set_shader_parameter("t_" + k, td["tex"])
			if td["h"] != null:
				gm.set_shader_parameter("t_%s_h" % k, td["h"])
			gm.set_shader_parameter("n_" + k, td["norm"])
	plane.material_override = gm
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(plane)


## Stützpunkte des Weges von der Startlichtung zur Bossarena (auch vom Shader benutzt).
static func path_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var t := float(i) / 13.0
		var pos := SPAWN_POS.lerp(BOSS_POS, t)
		pts.append(Vector2(pos.x + sin(t * 7.0) * 4.0, pos.z))
	return pts


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


static func _tree_model(style: String, rng: RandomNumberGenerator, scale_f: float) -> Node3D:
	var pick := ""
	var h := 0.0
	match style:
		"pine":
			if rng.randf() < 0.25:
				pick = NatureKit.pick("GiantPine", 5, rng)
				h = rng.randf_range(11.0, 15.0)
			else:
				pick = NatureKit.pick("Pine", 5, rng)
				h = rng.randf_range(6.0, 9.5)
		"dead":
			pick = NatureKit.pick("DeadTree", 5, rng) if rng.randf() < 0.7 else NatureKit.pick("TwistedTree", 5, rng)
			h = rng.randf_range(6.0, 10.0)
		_:
			var r := rng.randf()
			if RunState.area_id == "emerald_forest":
				if r < 0.62:
					pick = NatureKit.pick("CommonTree", 5, rng)
					h = rng.randf_range(5.5, 8.5)
				elif r < 0.84:
					pick = NatureKit.pick("Pine", 5, rng)
					h = rng.randf_range(6.0, 9.0)
				elif r < 0.95:
					pick = NatureKit.pick("GiantPine", 5, rng)
					h = rng.randf_range(10.0, 14.0)
				else:
					pick = NatureKit.pick("CherryBlossom", 5, rng)
					h = rng.randf_range(7.0, 9.5)
			elif r < 0.4:
				pick = NatureKit.pick("CommonTree", 5, rng)
				h = rng.randf_range(5.5, 8.5)
			elif r < 0.7:
				pick = NatureKit.pick("Birch", 5, rng)
				h = rng.randf_range(6.5, 9.5)
			elif r < 0.88:
				pick = NatureKit.pick("TallThick", 5, rng)
				h = rng.randf_range(8.0, 11.0)
			else:
				pick = NatureKit.pick("CherryBlossom", 5, rng)
				h = rng.randf_range(7.0, 9.5)
	return NatureKit.make(pick, h * (0.7 + 0.3 * scale_f))


static func _tree(parent: Node3D, pos: Vector3, scale_f: float, rng: RandomNumberGenerator, collide: bool = true) -> void:
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = rng.randf() * TAU
	parent.add_child(t)
	if NatureKit.available() and str(T["tree_style"]) != "crystal":
		t.add_child(_tree_model(str(T["tree_style"]), rng, scale_f))
		if collide:
			var sb2 := StaticBody3D.new()
			sb2.collision_layer = 1
			var cs2 := CollisionShape3D.new()
			var sh2 := CylinderShape3D.new()
			sh2.radius = 0.55
			sh2.height = 3.0
			cs2.shape = sh2
			cs2.position.y = 1.5
			sb2.add_child(cs2)
			t.add_child(sb2)
		return
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
		Toon.part(t, "trunk", Vector3(0.2 * scale_f, h * 1.3, 0.3 * scale_f), bark, Vector3(0, h * 0.65, 0), Vector3.ZERO, Toon.tmat(bark, "bark", 1.6, 1.0, 1.2))
		for i in 3:
			Toon.part(t, "cyl", Vector3(0.08 * scale_f, h * 0.7, 0.1 * scale_f), bark.darkened(0.1), Vector3(sin(i * 2.1) * 0.5 * scale_f, h * (0.9 + i * 0.2), cos(i * 2.1) * 0.5 * scale_f), Vector3(0, 0, 40 * (1 if i % 2 == 0 else -1)), Toon.tmat(bark.darkened(0.1), "bark", 2.0, 1.0, 1.2))
		kind = -1
	else:
		Toon.part(t, "trunk", Vector3(0.28 * scale_f, h, 0.42 * scale_f), bark, Vector3(0, h * 0.5, 0), Vector3.ZERO, Toon.tmat(bark, "bark", 1.6, 1.0, 1.2))
		if style == "pine":
			kind = 0
	if kind == -1:
		pass
	elif kind == 0:
		for i in 3:
			Toon.part(t, "cone", Vector3((1.5 - i * 0.35) * scale_f, 1.5 * scale_f, 0), leaf.darkened(0.04 * i), Vector3(0, h + i * 0.9 * scale_f, 0), Vector3.ZERO, Toon.tmat(leaf.darkened(0.04 * i), "leaves", 0.9, 0.9, 0.5, 0.0, 0.2, 1.0))
	elif kind == 1:
		Toon.part(t, "blob", Vector3(1.5 * scale_f, 18, 0.2), leaf, Vector3(0, h + 0.8 * scale_f, 0), Vector3.ZERO, Toon.tmat(leaf, "leaves", 0.9, 0.9, 0.5, 0.0, 0.2, 1.0))
		Toon.part(t, "blob", Vector3(1.0 * scale_f, 25, 0.2), leaf.lightened(0.08), Vector3(0.7 * scale_f, h + 0.3 * scale_f, 0.3), Vector3.ZERO, Toon.tmat(leaf.lightened(0.08), "leaves", 0.9, 0.9, 0.5, 0.0, 0.2, 1.0))
		Toon.part(t, "blob", Vector3(0.9 * scale_f, 32, 0.2), leaf.darkened(0.05), Vector3(-0.6 * scale_f, h + 0.4 * scale_f, -0.4), Vector3.ZERO, Toon.tmat(leaf.darkened(0.05), "leaves", 0.9, 0.9, 0.5, 0.0, 0.2, 1.0))
	else:
		Toon.part(t, "blob", Vector3(1.3 * scale_f, 39, 0.2), leaf, Vector3(0, h + 1.1 * scale_f, 0), Vector3.ZERO, Toon.tmat(leaf, "leaves", 0.9, 0.9, 0.5, 0.0, 0.2, 1.0))
		Toon.part(t, "blob", Vector3(0.38 * scale_f, 46, 0.25), col("rune").lerp(leaf, 0.6) if style != "round" else Color("#ff9ad0").lerp(leaf, 0.3), Vector3(0.95 * scale_f, h + 1.75 * scale_f, 0.7))
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


## Ein Grasbüschel aus 7 gebogenen, spitz zulaufenden Halmen (UV.y = Höhe 0..1 für Farbverlauf und Wind).
static func grass_clump_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for k in 7:
		var ang := r.randf() * TAU
		var off := Vector3(cos(ang), 0, sin(ang)) * r.randf_range(0.0, 0.22)
		var yaw := r.randf() * PI
		var side := Vector3(cos(yaw), 0, sin(yaw))
		var lean := Vector3(-sin(yaw), 0, cos(yaw)) * r.randf_range(0.05, 0.22)
		var hgt := r.randf_range(0.28, 0.5)
		var w := r.randf_range(0.035, 0.055)
		var base := verts.size()
		for lv in 3:
			var t := float(lv) / 3.0
			var c := off + lean * t * t + Vector3(0, hgt * t, 0)
			var half := w * (1.0 - t * 0.85)
			verts.append(c - side * half)
			verts.append(c + side * half)
			uvs.append(Vector2(0, t))
			uvs.append(Vector2(1, t))
			norms.append(Vector3.UP)
			norms.append(Vector3.UP)
		verts.append(off + lean + Vector3(0, hgt, 0))
		uvs.append(Vector2(0.5, 1.0))
		norms.append(Vector3.UP)
		for lv in 2:
			var i0 := base + lv * 2
			idx.append_array([i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2])
		idx.append_array([base + 4, base + 5, base + 6])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Echte Büsche, Farne, Pflanzen, Blumen, Pilze und Felsen (Quaternius) verstreuen; Felsen bekommen Kollision.
static func _nature_scatter(root: Node3D, rng: RandomNumberGenerator) -> void:
	if not NatureKit.available():
		return
	var holder := Node3D.new()
	holder.name = "NatureScatter"
	root.add_child(holder)
	var plan := [
		["Bush_Large", 1, 14, 1.2, 2.0], ["Bush_Common_Flowers", 1, 14, 1.0, 1.6], ["Bush_Large", 1, 8, 1.4, 2.2], ["Bush_Large_Flowers", 1, 6, 1.4, 2.0],
		["Bush_Long", 2, 12, 1.2, 2.0], ["Fern", 2, 40, 0.5, 0.9], ["Plant_1", 1, 18, 0.7, 1.1], ["Plant_5", 1, 12, 0.7, 1.1],
		["Flower_1_Group", 1, 16, 0.4, 0.8], ["Flower_2_Group", 1, 16, 0.4, 0.8], ["Flower_3_Group", 1, 12, 0.4, 0.8], ["Flower_4_Group", 1, 12, 0.4, 0.8],
		["Clover", 2, 24, 0.3, 0.5], ["Mushroom_Common", 1, 10, 0.3, 0.5], ["Mushroom_RedCap", 1, 8, 0.4, 0.7], ["Mushroom_Laetiporus", 1, 4, 0.5, 0.8]]
	for e in plan:
		for i in int(e[2]):
			var name: String = e[0]
			if int(e[1]) > 1:
				name = "%s_%d" % [name, 1 + rng.randi() % int(e[1])]
			if not NatureKit.has(name):
				continue
			var p := _free_spot(rng, 4.0, 57.0)
			var n := NatureKit.make(name, rng.randf_range(float(e[3]), float(e[4])))
			n.position = p
			n.rotation.y = rng.randf() * TAU
			holder.add_child(n)
	# Felsen
	for i in 26:
		var big := rng.randf() < 0.25
		var name := "Rock_Big_%d" % (1 + rng.randi() % 2) if big else "Rock_Medium_%d" % (1 + rng.randi() % 4)
		var p := _free_spot(rng, 5.0, 57.0)
		var h := rng.randf_range(2.0, 3.4) if big else rng.randf_range(0.7, 1.7)
		var n := NatureKit.make(name, h)
		n.position = p - Vector3(0, 0.05, 0)
		n.rotation.y = rng.randf() * TAU
		holder.add_child(n)
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = h * 0.45
		cs.shape = sh
		cs.position = p + Vector3(0, h * 0.4, 0)
		sb.add_child(cs)
		holder.add_child(sb)


static func _undergrowth(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Gras und Blumen als MultiMesh (performant)
	var grass := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = grass_clump_mesh()
	var clumps := 1700
	mm.instance_count = clumps
	for i in clumps:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RADIUS - 3.0)
		var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var s := rng.randf_range(0.75, 1.45)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		mm.set_instance_transform(i, Transform3D(b, p))
		mm.set_instance_color(i, Color.from_hsv(rng.randf_range(float(T["grass_hue"][0]), float(T["grass_hue"][1])), rng.randf_range(0.45, 0.7), rng.randf_range(0.6, 0.9)))
	grass.multimesh = mm
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/grass.gdshader")
	grass.material_override = gmat
	grass.visibility_range_end = 70.0
	grass.visibility_range_end_margin = 12.0
	grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
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
	for i in (0 if NatureKit.available() else 30):
		var p := _free_spot(rng, 5.0, 57.0)
		var s := rng.randf_range(0.5, 1.6)
		var rk := pal("rocks")
		var c: Color = rk[0].lerp(rk[1], rng.randf())
		var rock := Toon.part(root, "rock", Vector3(0.6 * s, float(rng.randi() % 1000), 0.32), c, p + Vector3(0, 0.25 * s, 0), Vector3(rng.randf() * 30, rng.randf() * 360, 0), Toon.tmat(c, "rock", 1.1, 1.0, 1.6))
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
			var col := Toon.part(root, "cyl", Vector3(0.45, h, 0.5), stone.lerp(moss, rng.randf() * 0.4), p + Vector3(0, h * 0.5, 0), Vector3.ZERO, Toon.tmat(stone.lerp(moss, rng.randf() * 0.4), "bricks", 1.4, 1.0, 1.4))
			Toon.outline(col, 0.02)
			Toon.part(root, "box", Vector3(1.0, 0.25, 1.0), stone.darkened(0.08), p + Vector3(0, h + 0.12, 0), Vector3(0, rng.randf() * 40, rng.randf_range(-6, 6)), Toon.tmat(stone.darkened(0.08), "rock", 1.2, 1.0, 1.6))
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
	var glyph := Toon.part(root, "torus", Vector3(9.0, 8.8, 0), col("glyph"), c + Vector3(0, 0.07, 0), Vector3.ZERO, Toon.glow_mat(col("glyph"), 1.2, 0.8), false)
	glyph.scale.y = 0.2
	# Wächtersäulen mit Wurzeln
	var n := 12
	for i in n:
		var a := i * TAU / n
		var p := c + Vector3(cos(a), 0, sin(a)) * (BOSS_ARENA_R + 1.0)
		var h := 3.5 + (i % 3) * 0.8
		var col := Toon.part(root, "cyl", Vector3(0.7, h, 0.85), stone, p + Vector3(0, h * 0.5, 0), Vector3.ZERO, Toon.tmat(stone, "bricks", 1.1, 1.0, 1.5))
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
