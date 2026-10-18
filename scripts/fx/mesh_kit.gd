class_name MeshKit
extends RefCounted
## Prozedurale, organische Meshes (Drehkörper, verformte Kugeln) – glatter und natürlicher als Standard-Primitive.
## Alle Meshes sind gecacht und nutzen gemeinsame Vertices (weiche Normalen ohne Naht).

static var _cache: Dictionary = {}


static func _finish(st: SurfaceTool, smooth: bool = true) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


## Drehkörper aus Profil (x = Radius, y = Höhe), Profil von unten nach oben; erste/letzte Punkte dürfen Radius 0 haben.
static func lathe(profile: PackedVector2Array, segs: int = 20, scale_xz: Vector2 = Vector2.ONE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := profile.size()
	for i in rings:
		for j in segs:
			var a := TAU * j / segs
			st.add_vertex(Vector3(cos(a) * profile[i].x * scale_xz.x, profile[i].y, sin(a) * profile[i].x * scale_xz.y))
	for i in rings - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			var a0 := i * segs + j
			var a1 := i * segs + j2
			var b0 := (i + 1) * segs + j
			var b1 := (i + 1) * segs + j2
			# Umlaufsinn so, dass die Außenseite nach vorn zeigt
			st.add_index(a0); st.add_index(b1); st.add_index(b0)
			st.add_index(a0); st.add_index(a1); st.add_index(b1)
	return _finish(st)


## Hilfsprofil: abgerundete Kappen + beliebige Radien entlang der Länge (r_at: Callable(t 0..1) -> Radius).
static func capsule_profile(length: float, r_at: Callable, cap_steps: int = 5, body_steps: int = 8) -> PackedVector2Array:
	var p := PackedVector2Array()
	var r0: float = r_at.call(0.0)
	var r1: float = r_at.call(1.0)
	var y0 := -length * 0.5
	var y1 := length * 0.5
	p.append(Vector2(0.0, y0 - r0))
	for k in range(1, cap_steps):
		var a := PI * 0.5 * float(k) / cap_steps
		p.append(Vector2(r0 * sin(a), y0 - r0 * cos(a)))
	for k in body_steps + 1:
		var t := float(k) / body_steps
		p.append(Vector2(r_at.call(t), lerpf(y0, y1, t)))
	for k in range(cap_steps - 1, 0, -1):
		var a := PI * 0.5 * float(k) / cap_steps
		p.append(Vector2(r1 * sin(a), y1 + r1 * cos(a)))
	p.append(Vector2(0.0, y1 + r1))
	return p


## Gliedmaße: Radius oben/unten, leichte Muskelwölbung. size: x = Radius oben, y = Länge (Körper), z = Radius unten.
static func limb(r_top: float, length: float, r_bot: float) -> ArrayMesh:
	var key := "limb_%.3f_%.3f_%.3f" % [r_top, length, r_bot]
	if _cache.has(key):
		return _cache[key]
	var f := func(t: float) -> float:
		return lerpf(r_bot, r_top, t) * (1.0 + 0.12 * sin(t * PI))
	var m := lathe(capsule_profile(length, f), 16)
	_cache[key] = m
	return m


## Rumpf: Schultern breit, Taille schmal, Hüfte rund. size: x = Radius Brust, y = Gesamthöhe.
static func torso(radius: float, height: float) -> ArrayMesh:
	var key := "torso_%.3f_%.3f" % [radius, height]
	if _cache.has(key):
		return _cache[key]
	var p := PackedVector2Array()
	var shape := [[0.0, 0.0], [0.7, 0.02], [0.86, 0.1], [0.72, 0.24], [0.66, 0.32], [0.74, 0.5], [0.9, 0.68], [1.0, 0.82], [0.9, 0.9], [0.6, 0.97], [0.38, 0.995], [0.0, 1.0]]
	for s in shape:
		p.append(Vector2(radius * float(s[0]), (float(s[1]) - 0.5) * height))
	var m := lathe(p, 22, Vector2(1.0, 0.72))
	_cache[key] = m
	return m


## Kopf: breite Schädelkalotte, schmaleres Kinn. size: x = Radius.
static func head(radius: float) -> ArrayMesh:
	var key := "head_%.3f" % radius
	if _cache.has(key):
		return _cache[key]
	var p := PackedVector2Array()
	var shape := [[0.0, -1.0], [0.28, -0.96], [0.5, -0.82], [0.68, -0.6], [0.86, -0.3], [0.97, 0.0], [1.0, 0.25], [0.93, 0.55], [0.74, 0.82], [0.4, 0.96], [0.0, 1.0]]
	for s in shape:
		p.append(Vector2(radius * float(s[0]), radius * float(s[1])))
	var m := lathe(p, 22, Vector2(0.92, 1.0))
	_cache[key] = m
	return m


## Verformte Kugel (Fels: kantig, Laub/Busch: weich). seed bestimmt Form deterministisch.
static func blob(radius: float, seed_i: int, rough: float, faceted: bool, detail: int = 2) -> ArrayMesh:
	var key := "blob_%.3f_%d_%.2f_%s_%d" % [radius, seed_i, rough, str(faceted), detail]
	if _cache.has(key):
		return _cache[key]
	var noise := FastNoiseLite.new()
	noise.seed = seed_i
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.1
	# Ikosaeder unterteilen
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
			Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(v.normalized())
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
			[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _d in detail:
		var nf: Array = []
		var mid := {}
		for f in faces:
			var m: Array[int] = []
			for k in 3:
				var a: int = f[k]
				var b: int = f[(k + 1) % 3]
				var key2 := Vector2i(mini(a, b), maxi(a, b))
				if not mid.has(key2):
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
					mid[key2] = verts.size() - 1
				m.append(mid[key2])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var disp: Array[Vector3] = []
	for v in verts:
		var n1 := noise.get_noise_3dv(v * 1.4)
		var n2 := noise.get_noise_3dv(v * 3.6 + Vector3(9, 9, 9)) * 0.4
		disp.append(v * radius * (1.0 + (n1 + n2) * rough))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if faceted:
		for f in faces:
			for k in 3:
				st.add_vertex(disp[f[k]])
	else:
		for v in disp:
			st.add_vertex(v)
		for f in faces:
			st.add_index(f[0]); st.add_index(f[1]); st.add_index(f[2])
	var m := _finish(st)
	_cache[key] = m
	return m


## Baumstamm: unten ausladend (Wurzelanlauf), nach oben schlanker, leichte Rundung. size: x = Radius oben, y = Höhe, z = Radius unten.
static func trunk(r_top: float, height: float, r_bot: float) -> ArrayMesh:
	var key := "trunk_%.3f_%.3f_%.3f" % [r_top, height, r_bot]
	if _cache.has(key):
		return _cache[key]
	var p := PackedVector2Array()
	var steps := 10
	p.append(Vector2(0.0, -height * 0.5))
	for k in steps + 1:
		var t := float(k) / steps
		var flare := 1.0 + 0.55 * pow(1.0 - t, 6.0)
		var r := lerpf(r_bot, r_top, pow(t, 0.8)) * flare
		p.append(Vector2(r, lerpf(-height * 0.5, height * 0.5, t)))
	p.append(Vector2(r_top * 0.6, height * 0.5 + 0.02))
	p.append(Vector2(0.0, height * 0.5 + 0.03))
	var m := lathe(p, 12)
	_cache[key] = m
	return m
