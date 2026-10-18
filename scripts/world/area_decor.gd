class_name AreaDecor
extends RefCounted
## Gebietsspezifische Wahrzeichen und Landschaftsformen (Quaternius CC0 Modelle, assets/env).
## Jedes Gebiet bekommt eigene Bauwerke, Felsformen, Partikel und Lichtstimmung, damit sie sich klar unterscheiden.

const DIR := "res://assets/env/"
static var _cache := {}


static func _scene(nm: String) -> PackedScene:
	if not _cache.has(nm):
		var path := DIR + nm + ".glb"
		_cache[nm] = load(path) if ResourceLoader.exists(path) else null
	return _cache[nm]


## Stellt ein Modell auf. opts: tint (Color), emit (Color), emit_e, collide (Radius), tall (Kollisionshöhe), tilt (Vector3 Grad), sink.
static func prop(parent: Node3D, nm: String, pos: Vector3, scale: float, yaw_deg: float = 0.0, opts: Dictionary = {}) -> Node3D:
	var ps := _scene(nm)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	n.position = pos + Vector3(0, -float(opts.get("sink", 0.0)), 0)
	n.scale = Vector3.ONE * scale
	n.rotation_degrees = Vector3(0, yaw_deg, 0) + (opts.get("tilt", Vector3.ZERO) as Vector3)
	parent.add_child(n)
	var tint: Color = opts.get("tint", Color.WHITE)
	var has_emit := opts.has("emit")
	if tint != Color.WHITE or has_emit:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var m0: Material = (mi as MeshInstance3D).get_active_material(i)
				if m0 is StandardMaterial3D:
					var m: StandardMaterial3D = m0.duplicate()
					m.albedo_color = m.albedo_color * tint
					if has_emit:
						m.emission_enabled = true
						m.emission = opts["emit"]
						m.emission_energy_multiplier = float(opts.get("emit_e", 1.2))
					(mi as MeshInstance3D).set_surface_override_material(i, m)
	var cr := float(opts.get("collide", 0.0))
	if cr > 0.0:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = cr
		sh.height = float(opts.get("tall", 3.0))
		cs.shape = sh
		cs.position = Vector3(pos.x, pos.y + sh.height * 0.5, pos.z)
		sb.add_child(cs)
		parent.add_child(sb)
	return n


static func _on_path(p: Vector3, margin: float) -> bool:
	var pts := ForestMap.path_points()
	for i in pts.size():
		if Vector2(p.x - pts[i].x, p.z - pts[i].y).length() < margin:
			return true
	return false


static func _spot(rng: RandomNumberGenerator, rmin: float, rmax: float, margin: float = 3.0) -> Vector3:
	for i in 80:
		var a := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if ForestMap._blocked(p, margin) or _on_path(p, 4.5):
			continue
		return p
	return Vector3(-30, 0, 20)


static func build(root: Node3D, rng: RandomNumberGenerator, area_id: String) -> void:
	var holder := Node3D.new()
	holder.name = "AreaDecor"
	root.add_child(holder)
	match area_id:
		"emerald_forest": _forest(holder, rng)
		"sunken_ruins": _ruins(holder, rng)
		"ash_lands": _ash(holder, rng)
		"frost_cliffs": _frost(holder, rng)
		"shadow_wood": _shadow(holder, rng)
		"sky_fortress": _sky(holder, rng)


static func _ring(parent: Node3D, c: Vector3, n: int, r: float, nm: String, sc: float, opts: Dictionary = {}, face_in: bool = true) -> void:
	for i in n:
		var a := i * TAU / n
		var p := c + Vector3(cos(a), 0, sin(a)) * r
		prop(parent, nm, p, sc, rad_to_deg(-a) + (90.0 if face_in else -90.0), opts)


static func _particles(root: Node3D, color: Color, amount: int, extents: Vector3, vel: Vector3, size: float, life: float, e: float = 2.0) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(amount * clampf(float(SaveSystem.data.get("settings", {}).get("particle_limit", 1.0)), 0.2, 1.0))
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = vel.normalized() if vel.length() > 0.01 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length() * 1.2
	p.gravity = Vector3.ZERO
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 4
	sm.rings = 2
	p.mesh = sm
	p.material_override = Toon.glow_mat(color, e)
	p.position = Vector3(0, extents.y, 0)
	root.add_child(p)


# ---------------------------------------------------------------- Smaragdwald
static func _forest(h: Node3D, rng: RandomNumberGenerator) -> void:
	# Uralter Hain: Ruine mit Bogen, Pilzringe, Steinbrücke zum Teich
	var c := Vector3(-30, 0, -4)
	prop(h, "R_WallArchGothic", c, 2.0, 90, {"tint": Color("#a8c49a"), "collide": 0.0})
	prop(h, "R_ColumnRound", c + Vector3(0, 0, -5.0), 1.6, 0, {"tint": Color("#a8c49a"), "collide": 0.8, "tall": 6.0})
	prop(h, "R_ColumnRoundShort", c + Vector3(0, 0, 5.0), 1.6, 0, {"tint": Color("#a8c49a"), "collide": 0.8, "tall": 3.0})
	prop(h, "R_StatueStag", c + Vector3(-4, 0, 0), 1.5, 90, {"tint": Color("#b4c8a8"), "collide": 1.4, "tall": 6.0})
	for i in 5:
		var a := rng.randf() * TAU
		prop(h, "R_Bricks", c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.0, 6.0), rng.randf_range(0.8, 1.4), rng.randf() * 360.0, {"tint": Color("#9ab88c")})
	# Pilzringe
	for k in 4:
		var mc := _spot(rng, 14.0, 48.0)
		for i in 7:
			var a := i * TAU / 7.0
			prop(h, "C_Mushroom", mc + Vector3(cos(a), 0, sin(a)) * 2.2, rng.randf_range(1.4, 2.2), rng.randf() * 360.0, {"tint": Color("#ffd0c0")})
		prop(h, "N_Bush_1", mc, 1.8, 0)
	# Birken-Hain
	var gc := Vector3(30, 0, -26)
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.0, 12.0)
		var p := gc + Vector3(cos(a), 0, sin(a)) * r
		if ForestMap._blocked(p, 2.0) or _on_path(p, 4.0):
			continue
		prop(h, "N_BirchTree_%d" % (1 + i % 2), p, rng.randf_range(2.4, 3.4), rng.randf() * 360.0, {"collide": 0.5})
	for i in 10:
		var p := _spot(rng, 10.0, 52.0, 2.0)
		prop(h, "N_Rock_%d" % (1 + i % 4), p, rng.randf_range(3.0, 6.0), rng.randf() * 360.0, {"collide": 1.2, "tall": 2.0, "tint": Color("#a8b8a0")})


# ---------------------------------------------------------------- Versunkene Ruinen
static func _ruins(h: Node3D, rng: RandomNumberGenerator) -> void:
	var stone := Color("#b8c8bc")
	# Flache Wasserbecken zwischen den Ruinen
	for i in 7:
		var p := _spot(rng, 10.0, 50.0, 5.0)
		var water := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := rng.randf_range(3.5, 7.5)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.04
		cm.radial_segments = 28
		water.mesh = cm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/water.gdshader")
		water.material_override = sm
		water.position = Vector3(p.x, 0.1, p.z)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(water)
		if i % 2 == 0:
			prop(h, "N_Lilypad", p + Vector3(1.0, 0.1, 0.6), 2.0, rng.randf() * 360.0)
	# Tempelfassaden: Reihe aus Bögen und Säulen
	for t in 3:
		var c := _spot(rng, 22.0, 46.0, 8.0)
		var yaw := rng.randf() * 360.0
		var dir := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
		for i in 3:
			var p := c + dir * (i - 1) * 8.2
			prop(h, "R_WallArchGothic" if i != 1 else "R_ArchGothic", p, 2.0, yaw, {"tint": stone})
			prop(h, "R_ColumnRound", p + dir * 4.1, 2.0, 0, {"tint": stone, "collide": 1.0, "tall": 8.0})
		prop(h, "R_ColumnRound", c + dir * 12.3, 2.0, 0, {"tint": stone, "collide": 1.0, "tall": 8.0})
		prop(h, "R_Stairs", c + Vector3(0, 0, 0) - dir.cross(Vector3.UP) * 3.0, 2.0, yaw, {"tint": stone})
		prop(h, "R_StatueStag" if t % 2 == 0 else "R_StatueFox", c + dir.cross(Vector3.UP) * 6.0, 1.7, yaw + 90.0, {"tint": stone, "collide": 1.4, "tall": 7.0})
	# Umgestürzte Säulen und Trümmer
	for i in 16:
		var p := _spot(rng, 8.0, 54.0, 2.0)
		if i % 3 == 0:
			prop(h, "R_ColumnRound", p + Vector3(0, 0.6, 0), 1.8, rng.randf() * 360.0, {"tint": stone, "tilt": Vector3(88, 0, 0), "collide": 0.8, "tall": 1.4})
		elif i % 3 == 1:
			prop(h, "R_WallBroken", p, 2.0, rng.randf() * 360.0, {"tint": stone, "collide": 1.8, "tall": 3.5})
		else:
			prop(h, "R_Bricks", p, 1.5, rng.randf() * 360.0, {"tint": stone})
	# Bossarena: hohe Säulenring
	_ring(h, ForestMap.BOSS_POS, 8, ForestMap.BOSS_ARENA_R + 4.5, "R_ColumnSquare", 2.4, {"tint": Color("#9fb8b0"), "collide": 1.0, "tall": 10.0})
	_particles(h, Color("#aaf4ff"), 40, Vector3(60, 3, 60), Vector3(0, 0.3, 0), 0.04, 6.0, 2.5)


# ---------------------------------------------------------------- Aschelande
static func _ash(h: Node3D, rng: RandomNumberGenerator) -> void:
	var basalt := Color("#4a3e3c")
	var lava := Color("#ff5a10")
	# Lavarisse im Boden (nur optisch)
	for i in 26:
		var p := _spot(rng, 6.0, 56.0, 3.0)
		var len := rng.randf_range(3.0, 9.0)
		var crack := Toon.part(h, "box", Vector3(len, 0.04, 0.22), lava, p + Vector3(0, 0.07, 0), Vector3(0, rng.randf() * 180.0, 0), Toon.glow_mat(lava, 2.4, 0.95), false)
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Basaltsäulen-Gruppen (Obsidiankristalle)
	for k in 7:
		var c := _spot(rng, 14.0, 54.0, 4.0)
		for i in rng.randi_range(3, 6):
			var p := c + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			var s := rng.randf_range(3.0, 6.5)
			prop(h, "C_CrystalBig", p, s, rng.randf() * 360.0, {"tint": Color("#3a2a2c"), "emit": Color("#ff4a10"), "emit_e": 0.25, "collide": 0.7 * s / 3.0, "tall": 2.0 * s})
	# Felsbrocken
	for i in 18:
		var p := _spot(rng, 8.0, 56.0, 2.0)
		prop(h, "N_Rock_%d" % (1 + i % 4), p, rng.randf_range(3.5, 8.0), rng.randf() * 360.0, {"tint": basalt, "collide": 1.4, "tall": 2.5})
	# Zerstörtes Festungstor
	var g := Vector3(-34, 0, -18)
	prop(h, "R_WallArchGothic", g, 2.4, 70, {"tint": Color("#5a4640")})
	prop(h, "R_ColumnSquare", g + Vector3(-1.6, 0, -5.0), 2.2, 0, {"tint": Color("#5a4640"), "collide": 1.0, "tall": 8.0})
	prop(h, "R_WallBroken", g + Vector3(-3.0, 0, 6.0), 2.4, 70, {"tint": Color("#4a3a36"), "collide": 2.0, "tall": 4.0})
	for i in 9:
		var a := rng.randf() * TAU
		prop(h, "R_Skull" if i % 2 == 0 else "D_Bones", g + Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.0, 7.0), rng.randf_range(2.0, 3.0), rng.randf() * 360.0)
	# Bossarena: Glutsäulen
	for i in 10:
		var a := i * TAU / 10.0
		var p := ForestMap.BOSS_POS + Vector3(cos(a), 0, sin(a)) * (ForestMap.BOSS_ARENA_R + 3.0)
		prop(h, "C_CrystalBig", p, 5.0 + (i % 3), rng.randf() * 360.0, {"tint": Color("#2a1a1a"), "emit": Color("#ff5a10"), "emit_e": 0.6, "collide": 1.2, "tall": 9.0})
	_particles(h, Color("#ff9a40"), 90, Vector3(60, 1.0, 60), Vector3(0.2, 1.4, 0.1), 0.05, 6.0, 3.0)


# ---------------------------------------------------------------- Frostklippen
static func _frost(h: Node3D, rng: RandomNumberGenerator) -> void:
	var ice := Color("#a8d8ff")
	# Eisspitzen / Kristalle
	for k in 8:
		var c := _spot(rng, 14.0, 54.0, 4.0)
		for i in rng.randi_range(2, 5):
			var p := c + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
			var s := rng.randf_range(2.5, 6.0)
			prop(h, "C_CrystalBig", p, s, rng.randf() * 360.0, {"tint": ice, "emit": Color("#7ad8ff"), "emit_e": 0.5, "tilt": Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)), "collide": 0.6 * s / 3.0, "tall": 1.8 * s})
	# Verschneite Felsen und Schneewehen
	for i in 20:
		var p := _spot(rng, 8.0, 56.0, 2.0)
		prop(h, "N_RockSnow_%d" % (1 + i % 3), p, rng.randf_range(4.0, 9.0), rng.randf() * 360.0, {"collide": 1.5, "tall": 2.5})
	for i in 14:
		var p := _spot(rng, 6.0, 54.0, 2.0)
		prop(h, "C_Snow", p, rng.randf_range(1.6, 3.2), rng.randf() * 360.0, {"sink": 0.9 * 2.0})
	# Verschneite Kiefern-Wäldchen
	for k in 3:
		var c := _spot(rng, 20.0, 50.0, 6.0)
		for i in 9:
			var a := rng.randf() * TAU
			var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 9.0)
			if ForestMap._blocked(p, 2.0) or _on_path(p, 4.0):
				continue
			prop(h, "N_PineTreeSnow_%d" % (1 + i % 3), p, rng.randf_range(2.6, 4.0), rng.randf() * 360.0, {"collide": 0.6})
	# Gefrorene Ruine
	var g := Vector3(32, 0, -22)
	for i in 4:
		prop(h, "R_WallBroken", g + Vector3(i * 4.0 - 6.0, 0, sin(i) * 2.0), 2.0, rng.randf_range(-20, 20), {"tint": Color("#d8ecff"), "collide": 1.8, "tall": 3.5})
	prop(h, "R_ArchRound", g + Vector3(0, 0, 5.0), 2.4, 0, {"tint": Color("#d8ecff")})
	prop(h, "R_StatueFox", g + Vector3(-2, 0, 8.0), 1.6, 180, {"tint": Color("#d8ecff"), "collide": 1.4, "tall": 6.0})
	# Bossarena: Eiszähne
	_ring(h, ForestMap.BOSS_POS, 14, ForestMap.BOSS_ARENA_R + 2.5, "C_CrystalBig", 6.0, {"tint": Color("#c0e8ff"), "emit": Color("#80d8ff"), "emit_e": 0.7, "collide": 1.0, "tall": 8.0})
	_particles(h, Color("#ffffff"), 140, Vector3(60, 6, 60), Vector3(0.4, -1.2, 0.2), 0.045, 6.0, 1.2)


# ---------------------------------------------------------------- Schattenwald
static func _shadow(h: Node3D, rng: RandomNumberGenerator) -> void:
	# Friedhof mit schiefen Grabsäulen und Knochen
	for k in 2:
		var c := _spot(rng, 18.0, 46.0, 7.0)
		for i in 12:
			var p := c + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-7, 7))
			if ForestMap._blocked(p, 1.5) or _on_path(p, 3.5):
				continue
			prop(h, "R_ColumnRoundShort", p, rng.randf_range(0.9, 1.4), rng.randf() * 360.0, {"tint": Color("#8a8aa0"), "tilt": Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)), "collide": 0.45, "tall": 1.6})
		for i in 6:
			prop(h, "D_Bones" if i % 2 == 0 else "R_Skull", c + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), rng.randf_range(1.6, 2.4), rng.randf() * 360.0, {"tint": Color("#c8c0d8")})
		prop(h, "R_StatueStag", c, 1.6, rng.randf() * 360.0, {"tint": Color("#706880"), "collide": 1.4, "tall": 6.0})
	# Riesenpilze mit Leuchtflecken
	for k in 9:
		var c := _spot(rng, 10.0, 54.0, 3.0)
		var s := rng.randf_range(3.0, 6.0)
		var col := Color("#b04aff") if k % 2 == 0 else Color("#4ae0ff")
		prop(h, "C_Mushroom", c, s, rng.randf() * 360.0, {"tint": col.lerp(Color.WHITE, 0.2), "emit": col, "emit_e": 0.45, "collide": 0.6 * s / 3.0, "tall": 3.0 * s * 0.5})
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 0.9
		l.omni_range = 7.0
		l.position = c + Vector3(0, 1.2, 0)
		if k < 5:
			h.add_child(l)
		else:
			l.free()
	# Bleiche tote Bäume
	for i in 26:
		var p := _spot(rng, 8.0, 56.0, 2.0)
		prop(h, "N_BirchTreeDead_%d" % (1 + i % 2), p, rng.randf_range(2.8, 4.2), rng.randf() * 360.0, {"tint": Color("#d8d0e8"), "collide": 0.4})
	for i in 8:
		var p := _spot(rng, 10.0, 54.0, 2.0)
		prop(h, "N_WillowDead_1", p, rng.randf_range(3.0, 4.0), rng.randf() * 360.0, {"tint": Color("#9a90b0"), "collide": 0.4})
	# Spiegelscherben für die Spiegelhexe
	for i in 14:
		var p := _spot(rng, 12.0, 52.0, 3.0)
		var hh := rng.randf_range(3.0, 5.5)
		var mm := Toon.part(h, "box", Vector3(1.6, hh, 0.12), Color("#b8c8ff"), p + Vector3(0, hh * 0.5, 0), Vector3(rng.randf_range(-8, 8), rng.randf() * 360.0, rng.randf_range(-6, 6)), Toon.glow_mat(Color("#8a9aff"), 0.9, 0.7), false)
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Bossarena: Spiegelring
	for i in 10:
		var a := i * TAU / 10.0
		var p := ForestMap.BOSS_POS + Vector3(cos(a), 0, sin(a)) * (ForestMap.BOSS_ARENA_R + 2.0)
		var mm := Toon.part(h, "box", Vector3(2.8, 6.5, 0.2), Color("#d0c0ff"), p + Vector3(0, 3.25, 0), Vector3(0, -rad_to_deg(a) + 90.0, 0), Toon.glow_mat(Color("#c07aff"), 1.1, 0.8), false)
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.3
		sh.height = 6.5
		cs.shape = sh
		cs.position = p + Vector3(0, 3.25, 0)
		sb.add_child(cs)
		h.add_child(sb)
	_particles(h, Color("#c090ff"), 70, Vector3(60, 3, 60), Vector3(0, 0.4, 0), 0.05, 7.0, 3.0)


# ---------------------------------------------------------------- Himmelsfestung
static func _sky(h: Node3D, rng: RandomNumberGenerator) -> void:
	var stone := Color("#e0d8c0")
	# Festungsmauern mit Bögen, Bannern und Statuen
	for t in 4:
		var c := _spot(rng, 20.0, 46.0, 8.0)
		var yaw := rng.randf() * 360.0
		var dir := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
		for i in 3:
			var p := c + dir * (i - 1) * 8.0
			prop(h, "R_WallArchGothic" if i == 1 else "R_WallBroken", p, 2.0, yaw, {"tint": stone, "collide": 1.8 if i != 1 else 0.0, "tall": 4.0})
		prop(h, "R_ColumnSquare", c + dir * 4.0, 2.2, 0, {"tint": stone, "collide": 1.0, "tall": 8.8})
		prop(h, "R_ColumnSquare", c - dir * 4.0, 2.2, 0, {"tint": stone, "collide": 1.0, "tall": 8.8})
		prop(h, "R_FlagWall2", c + Vector3(0, 6.0, 0) + dir.cross(Vector3.UP) * 0.5, 2.4, yaw, {"tint": Color("#ffd870")})
		prop(h, "R_StatueStag" if t % 2 == 0 else "R_StatueFox", c + dir.cross(Vector3.UP) * 5.0, 1.8, yaw + 90.0, {"tint": stone, "collide": 1.5, "tall": 7.0})
	# Goldene Kristalle
	for i in 16:
		var p := _spot(rng, 8.0, 54.0, 3.0)
		var s := rng.randf_range(2.0, 4.5)
		prop(h, "C_CrystalBig", p, s, rng.randf() * 360.0, {"tint": Color("#ffe08a"), "emit": Color("#ffd24a"), "emit_e": 0.6, "collide": 0.6 * s / 3.0, "tall": 1.6 * s})
	for i in 10:
		prop(h, "N_Rock_%d" % (1 + i % 4), _spot(rng, 8.0, 56.0, 2.0), rng.randf_range(3.0, 6.0), rng.randf() * 360.0, {"tint": Color("#d8d0c0"), "collide": 1.2, "tall": 2.4})
	# Schwebende Felsinseln rund um die Arena
	for i in 14:
		var a := i * TAU / 14.0 + rng.randf() * 0.4
		var r := ForestMap.RADIUS + rng.randf_range(14.0, 34.0)
		var s := rng.randf_range(10.0, 22.0)
		var isl := prop(h, "N_Rock_%d" % (1 + i % 4), Vector3(cos(a) * r, rng.randf_range(-14.0, 4.0), sin(a) * r), s, rng.randf() * 360.0, {"tint": Color("#d8d0c0")})
		if isl != null:
			prop(h, "N_CommonTreeAutumn_1", Vector3(cos(a) * r, rng.randf_range(-14.0, 4.0) + s * 0.55, sin(a) * r), s * 0.22, 0)
	# Wolkenmeer
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(ForestMap.RADIUS * 0.6, ForestMap.RADIUS + 70.0)
		var cl := Toon.part(h, "sphere", Vector3(rng.randf_range(10.0, 20.0), 0.35, 0), Color("#ffffff"), Vector3(cos(a) * r, rng.randf_range(-16.0, -8.0), sin(a) * r), Vector3.ZERO, Toon.glow_mat(Color("#f4f8ff"), 0.5, 0.92), false)
		cl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring(h, ForestMap.BOSS_POS, 8, ForestMap.BOSS_ARENA_R + 3.0, "R_ColumnSquare", 2.6, {"tint": Color("#f0e8d0"), "collide": 1.1, "tall": 10.0})
	_particles(h, Color("#fff0a0"), 50, Vector3(60, 3, 60), Vector3(0.6, 0.2, 0.3), 0.04, 6.0, 2.0)
