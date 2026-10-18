extends SceneTree
func _init() -> void:
	var n: Node = load("res://assets/characters/UAL1.glb").instantiate()
	var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
	var names := []
	for i in sk.get_bone_count():
		names.append("%d:%s<%d" % [i, sk.get_bone_name(i), sk.get_bone_parent(i)])
	print("BONES ", " | ".join(names))
	var mi: MeshInstance3D = sk.get_child(0)
	print("MAT ", mi.mesh.surface_get_material(0), " surfaces=", mi.mesh.get_surface_count())
	var arr := mi.mesh.surface_get_arrays(0)
	print("verts ", arr[Mesh.ARRAY_VERTEX].size(), " has_bones ", arr[Mesh.ARRAY_BONES] != null, " colors ", arr[Mesh.ARRAY_COLOR] != null)
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	var a := ap.get_animation("Sword_Attack")
	print("sword_attack len ", a.length, " loop ", a.loop_mode, " tracks ", a.get_track_count(), " first ", a.track_get_path(0))
	print("idle ", ap.get_animation("Idle").length, " walk ", ap.get_animation("Walk").length, " jog ", ap.get_animation("Jog_Fwd").length, " roll ", ap.get_animation("Roll").length, " spell ", ap.get_animation("Spell_Simple_Shoot").length)
	quit()
