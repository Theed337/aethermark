extends SceneTree
func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var ps: PackedScene = load(path)
	var n: Node = ps.instantiate()
	_dump(n, 0)
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	if ap:
		print("ANIMS ", ap.get_animation_list().size())
		print(", ".join(ap.get_animation_list()))
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		extra = " mesh=%s aabb=%s" % [n.mesh.get_class(), n.get_aabb().size]
	if n is Skeleton3D:
		extra = " bones=%d" % n.get_bone_count()
	if d < 5:
		print("  ".repeat(d), n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_dump(c, d + 1)
