extends SceneTree
func _init() -> void:
	var d := DirAccess.open("res://assets/nature")
	var names: Array = []
	for f in d.get_files():
		if f.ends_with(".gltf"):
			names.append(f)
	names.sort()
	for f in names:
		var n: Node3D = load("res://assets/nature/" + f).instantiate()
		var out := []
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = m
			for s in mi.mesh.get_surface_count():
				var mat: Material = mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D and mat.albedo_texture != null:
					var tn: String = mat.albedo_texture.resource_path.get_file()
					if tn.begins_with("Leaves") or tn.begins_with("Leaf"):
						var arr := mi.mesh.surface_get_arrays(s)
						var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
						var img: Image = mat.albedo_texture.get_image()
						if img.is_compressed():
							img.decompress()
						var acc := Color(0, 0, 0)
						var cnt := 0
						for i in range(0, uv.size(), maxi(uv.size() / 200, 1)):
							var px := img.get_pixel(clampi(int(uv[i].x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv[i].y * img.get_height()), 0, img.get_height() - 1))
							if px.a > 0.3:
								acc += px
								cnt += 1
						if cnt > 0:
							acc = acc / cnt
							out.append("%s rgb=(%.2f,%.2f,%.2f)" % [tn, acc.r, acc.g, acc.b])
		if out.size() > 0:
			print("LEAF ", f, " ", out[0])
		n.free()
	quit()
