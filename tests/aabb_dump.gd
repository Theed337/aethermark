extends SceneTree
func _aabb(n: Node, t: Transform3D, acc: Array) -> void:
	if n is MeshInstance3D:
		var bb: AABB = t * n.get_aabb() if n.transform == Transform3D.IDENTITY else (t * n.transform) * n.get_aabb()
		acc.append(bb)
	for c in n.get_children():
		_aabb(c, t * (c.transform if c is Node3D else Transform3D.IDENTITY) if false else t, acc)
func _init() -> void:
	var d := DirAccess.open("res://assets/nature")
	var names: Array = []
	for f in d.get_files():
		if f.ends_with(".gltf"):
			names.append(f)
	names.sort()
	for f in names:
		var n: Node3D = load("res://assets/nature/" + f).instantiate()
		var bb := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.get_aabb()
			b = m.transform * b
			if first:
				bb = b
				first = false
			else:
				bb = bb.merge(b)
		print("AABB ", f, " size=", bb.size, " y0=", bb.position.y)
		n.free()
	quit()
