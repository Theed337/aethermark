extends SceneTree
func _init() -> void:
	var n: Node = load("res://assets/characters/UAL1.glb").instantiate()
	root.add_child(n)
	var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	var hb := sk.find_bone("hand_r")
	for clip in ["Sword_Idle", "Sword_Attack", "Idle", "Jog_Fwd"]:
		ap.play(clip)
		ap.seek(0.0, true)
		ap.advance(0.0)
		var gp := sk.get_bone_global_pose(hb)
		var D := Vector3(0, 0.45, 0.9).normalized()
		var local := gp.basis.inverse() * D
		print("HAND ", clip, " pos=", gp.origin, " localdir=", local, " rest basis x,y,z=", sk.get_bone_global_rest(hb).basis.x, sk.get_bone_global_rest(hb).basis.y, sk.get_bone_global_rest(hb).basis.z)
	quit()
