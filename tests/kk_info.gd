extends SceneTree
func _aabb(n: Node) -> AABB:
	var r := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = c.global_transform * c.get_aabb()
		r = b if first else r.merge(b)
		first = false
	return r
func _init() -> void:
	for body in ["Knight", "Barbarian", "Mage", "Rogue"]:
		var m: Node3D = load("res://assets/kaykit/%s.glb" % body).instantiate()
		var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i)
			if sk.get_bone_parent(i) >= 0 and sk.get_bone_name(sk.get_bone_parent(i)) in ["handslot.r", "handslot.l"]:
				var r := sk.get_bone_rest(i)
				print("WB ", body, " ", bn, " origin=", r.origin, " rot=", r.basis.get_euler() * 57.2958, " scale=", r.basis.get_scale())
	for w in ["sword_1handed", "axe_1handed", "axe_2handed", "dagger", "staff", "crossbow_2handed"]:
		var n: Node3D = load("res://assets/kaykit/weapons/%s.gltf" % w).instantiate()
		print("W ", w, " aabb=", _aabb(n))
	var k: Node3D = load("res://assets/kaykit/Knight.glb").instantiate()
	print("KNIGHT body aabb ", _aabb(k))
	quit()
