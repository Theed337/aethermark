class_name CharacterModel
extends RefCounted
## Baut das 3D-Modell eines Charakters aus dem gespeicherten Erscheinungsbild.
## Verwendet im Charaktereditor, im Hauptmenü und im Spiel -> was man erstellt, sieht man im Run.
## (Prozedurale Figur im Toon-Stil = Platzhalter-Kunst bis Phase 6, siehe docs/STATUS.md.)

const OUTFIT_COLORS := [Color("#8a6b4a"), Color("#6b4a3a"), Color("#4a3a7a"), Color("#3f6b3a")]


## Gibt ein Dictionary mit "root" und den animierbaren Teilen zurück.
static func build(appearance: Dictionary, weapon_type: String = "sword") -> Dictionary:
	var a: Dictionary = SaveSystem.default_appearance()
	for k in appearance:
		a[k] = appearance[k]
	var root := Node3D.new()
	var body_pivot := Node3D.new()
	root.add_child(body_pivot)
	var origin: Dictionary = GameData.origins.get(a["origin"], GameData.origins["human"])
	var sc_h: float = float(a["body_height"]) * float(origin.get("height", 1.0))
	var sc_b: float = float(a["body_build"]) * float(origin.get("build", 1.0))
	body_pivot.scale = Vector3(sc_b, sc_h, sc_b)

	var skin := Color(a["skin"])
	var accent := Color(a["accent"])
	var outfit_i: int = clampi(int(a["outfit"]), 0, 3)
	var cloth: Color = OUTFIT_COLORS[outfit_i]
	var cloth2: Color = cloth.lightened(0.18)

	# Beine
	var legs: Array = []
	for sx in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.14 * sx, 0.55, 0)
		body_pivot.add_child(pivot)
		var leg := Toon.part(pivot, "capsule", Vector3(0.11, 0.55, 0), cloth.darkened(0.15), Vector3(0, -0.26, 0))
		Toon.outline(leg, 0.02)
		Toon.part(pivot, "box", Vector3(0.2, 0.12, 0.3), Color("#3a2a20"), Vector3(0, -0.52, 0.04))
		legs.append(pivot)
	# Torso
	var torso := Toon.part(body_pivot, "capsule", Vector3(0.28, 0.7, 0), cloth, Vector3(0, 0.95, 0))
	Toon.outline(torso, 0.025)
	Toon.part(body_pivot, "box", Vector3(0.62, 0.09, 0.36), accent, Vector3(0, 0.78, 0))   # Gürtel in Akzentfarbe
	if outfit_i == 1:
		Toon.part(body_pivot, "box", Vector3(0.5, 0.35, 0.34), cloth2, Vector3(0, 1.05, 0.03))
	elif outfit_i == 2:
		Toon.part(body_pivot, "cone", Vector3(0.42, 0.7, 0), cloth2, Vector3(0, 0.45, 0))
	elif outfit_i == 3:
		Toon.part(body_pivot, "prism", Vector3(0.7, 0.5, 0.3), cloth2, Vector3(0, 1.0, -0.2), Vector3(0, 0, 180))   # Umhang
	# Arme
	var arms: Array = []
	for sx in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.38 * sx, 1.18, 0)
		body_pivot.add_child(pivot)
		var arm := Toon.part(pivot, "capsule", Vector3(0.09, 0.5, 0), cloth2, Vector3(0, -0.22, 0))
		Toon.outline(arm, 0.02)
		Toon.part(pivot, "sphere", Vector3(0.1, 0, 0), skin, Vector3(0, -0.5, 0))
		arms.append(pivot)
	# Kopf
	var head := Node3D.new()
	head.position = Vector3(0, 1.58, 0)
	body_pivot.add_child(head)
	var skull := Toon.part(head, "sphere", Vector3(0.24, 1.05, 0), skin)
	Toon.outline(skull, 0.02)
	var eye_c := Color(a["eye_color"])
	for sx in [-1, 1]:
		Toon.part(head, "sphere", Vector3(0.05, 0, 0), Color.WHITE, Vector3(0.09 * sx, 0.03, 0.2), Vector3.ZERO, null, false)
		Toon.part(head, "sphere", Vector3(0.028, 0, 0), eye_c, Vector3(0.09 * sx, 0.03, 0.245), Vector3.ZERO, Toon.glow_mat(eye_c, 0.6), false)
	_hair(head, int(a["hair_style"]), Color(a["hair_color"]))
	_beard(head, int(a["beard"]), Color(a["hair_color"]))
	# Ohren: Herkunft oder Auswahl (0 rund, 1 spitz, 2 Tierohren); Elfen haben immer spitze Ohren
	var ears: int = int(a["ears"])
	if a["origin"] == "elf" or a["origin"] == "faun":
		ears = maxi(ears, 1)
	for sx in [-1, 1]:
		if ears == 0:
			Toon.part(head, "sphere", Vector3(0.06, 0, 0), skin, Vector3(0.24 * sx, 0, 0), Vector3.ZERO, null, false)
		elif ears == 1:
			Toon.part(head, "cone", Vector3(0.05, 0.28, 0), skin, Vector3(0.28 * sx, 0.06, 0), Vector3(0, 0, -80 * sx), null, false)
		else:
			Toon.part(head, "cone", Vector3(0.08, 0.3, 0), skin, Vector3(0.14 * sx, 0.3, 0), Vector3(0, 0, -18 * sx), null, false)
	# Hörner (Faun bekommt Standardhörner, wenn keine gewählt)
	var horns: int = int(a["horns"])
	if a["origin"] == "faun" and horns == 0:
		horns = 2
	_horns(head, horns)
	_face_marks(head, int(a["scar"]), int(a["tattoo"]), accent)
	# Waffe in der rechten Hand
	var weapon := _weapon(weapon_type, accent)
	arms[1].add_child(weapon)
	weapon.position = Vector3(0, -0.5, 0.05)
	root.add_child(Node3D.new())   # Reserve
	return {"root": root, "body": body_pivot, "legs": legs, "arms": arms, "head": head, "weapon": weapon, "torso": torso}


static func _hair(head: Node3D, style: int, c: Color) -> void:
	match style:
		1:
			var m := Toon.part(head, "sphere", Vector3(0.255, 0.6, 0), c, Vector3(0, 0.08, -0.02))
			m.scale = Vector3(1, 0.75, 1.02)
		2:
			Toon.part(head, "sphere", Vector3(0.26, 0.7, 0), c, Vector3(0, 0.06, -0.03))
			Toon.part(head, "capsule", Vector3(0.2, 0.6, 0), c, Vector3(0, -0.2, -0.12))
		3:
			for i in 5:
				Toon.part(head, "cone", Vector3(0.06, 0.2, 0), c, Vector3(0, 0.27 - i * 0.02, 0.12 - i * 0.07), Vector3(-10, 0, 0))
		4:
			Toon.part(head, "sphere", Vector3(0.255, 0.6, 0), c, Vector3(0, 0.08, -0.02))
			var tail := Toon.part(head, "capsule", Vector3(0.07, 0.5, 0), c, Vector3(0, -0.15, -0.3), Vector3(20, 0, 0))
			Toon.outline(tail, 0.015)
		5:
			for i in 7:
				var ang := i * TAU / 7.0
				Toon.part(head, "cone", Vector3(0.05, 0.2, 0), c, Vector3(cos(ang) * 0.14, 0.24, sin(ang) * 0.14), Vector3(0, 0, 0))


static func _beard(head: Node3D, style: int, c: Color) -> void:
	match style:
		1:
			var m := Toon.part(head, "sphere", Vector3(0.2, 0.5, 0), c.darkened(0.2), Vector3(0, -0.1, 0.06))
			m.scale = Vector3(1, 0.5, 1)
		2:
			Toon.part(head, "capsule", Vector3(0.17, 0.5, 0), c, Vector3(0, -0.18, 0.1))
		3:
			for i in 3:
				Toon.part(head, "capsule", Vector3(0.04, 0.4, 0), c, Vector3((i - 1) * 0.07, -0.28, 0.17), Vector3(10, 0, 0))


static func _horns(head: Node3D, style: int) -> void:
	var bone := Color("#e8dcc0")
	for sx in [-1, 1]:
		match style:
			1:
				Toon.part(head, "cone", Vector3(0.04, 0.16, 0), bone, Vector3(0.11 * sx, 0.26, 0.02), Vector3(0, 0, -15 * sx))
			2:
				Toon.part(head, "cone", Vector3(0.05, 0.3, 0), bone, Vector3(0.14 * sx, 0.3, 0), Vector3(0, 0, -35 * sx))
				Toon.part(head, "cone", Vector3(0.035, 0.16, 0), bone, Vector3(0.28 * sx, 0.46, 0), Vector3(0, 0, -75 * sx))
			3:
				Toon.part(head, "torus", Vector3(0.12, 0.05, 0), bone, Vector3(0.2 * sx, 0.1, 0), Vector3(90, 0, 0))


static func _face_marks(head: Node3D, scar: int, tattoo: int, accent: Color) -> void:
	var dark := Color("#6b2a2a")
	match scar:
		1: Toon.part(head, "box", Vector3(0.02, 0.16, 0.01), dark, Vector3(-0.09, 0.03, 0.235), Vector3(0, 0, 15), null, false)
		2: Toon.part(head, "box", Vector3(0.1, 0.02, 0.01), dark, Vector3(0.12, -0.06, 0.2), Vector3(0, 30, -10), null, false)
		3: Toon.part(head, "box", Vector3(0.12, 0.02, 0.01), dark, Vector3(0, 0.16, 0.225), Vector3(0, 0, 8), null, false)
	match tattoo:
		1:
			for i in 2:
				Toon.part(head, "box", Vector3(0.1, 0.018, 0.01), accent, Vector3(0.13, -0.02 - i * 0.05, 0.19), Vector3(0, 40, 0), Toon.glow_mat(accent, 0.8), false)
		2:
			for i in 3:
				Toon.part(head, "sphere", Vector3(0.015, 0, 0), accent, Vector3(-0.12 + i * 0.03, -0.08, 0.21), Vector3.ZERO, Toon.glow_mat(accent, 0.8), false)
		3:
			Toon.part(head, "box", Vector3(0.05, 0.05, 0.01), accent, Vector3(0, 0.2, 0.225), Vector3(0, 0, 45), Toon.glow_mat(accent, 1.0), false)


static func _weapon(wt: String, accent: Color) -> Node3D:
	var w := Node3D.new()
	var steel := Color("#c9d3dc")
	var wood := Color("#6b4a2a")
	match wt:
		"axe":
			Toon.part(w, "cyl", Vector3(0.025, 0.9, 0), wood, Vector3(0, 0, 0.45), Vector3(90, 0, 0))
			Toon.part(w, "box", Vector3(0.05, 0.3, 0.24), steel, Vector3(0, 0.1, 0.8))
		"hammer":
			Toon.part(w, "cyl", Vector3(0.03, 1.0, 0), wood, Vector3(0, 0, 0.5), Vector3(90, 0, 0))
			Toon.part(w, "box", Vector3(0.22, 0.22, 0.4), steel.darkened(0.15), Vector3(0, 0, 1.0))
		"dagger":
			Toon.part(w, "box", Vector3(0.03, 0.06, 0.4), steel, Vector3(0, 0, 0.3))
			Toon.part(w, "box", Vector3(0.12, 0.04, 0.04), accent, Vector3(0, 0, 0.08))
		"bow":
			Toon.part(w, "torus", Vector3(0.45, 0.02, 0), wood, Vector3(0, 0.1, 0.1), Vector3(0, 90, 0))
		"staff":
			Toon.part(w, "cyl", Vector3(0.03, 1.4, 0), wood, Vector3(0, 0.2, 0.2), Vector3(70, 0, 0))
			Toon.part(w, "sphere", Vector3(0.1, 0, 0), accent, Vector3(0, 0.66, 0.67), Vector3.ZERO, Toon.glow_mat(accent, 1.8))
		_:
			Toon.part(w, "box", Vector3(0.05, 0.1, 0.8), steel, Vector3(0, 0, 0.55))
			Toon.part(w, "box", Vector3(0.28, 0.05, 0.06), accent, Vector3(0, 0, 0.12))
			Toon.part(w, "cyl", Vector3(0.03, 0.2, 0), wood, Vector3(0, 0, 0.02), Vector3(90, 0, 0))
	return w
