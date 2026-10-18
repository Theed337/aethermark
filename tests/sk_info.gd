extends Node
func _ready() -> void:
	var dir := "res://tmp_sk/"
	for n in ["Skeleton_Minion","Skeleton_Warrior","Skeleton_Rogue","Skeleton_Mage"]:
		var m: Node3D = load(dir + n + ".glb").instantiate()
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
		print(n, " anims=", ap.get_animation_list().size() if ap else -1, " bones=", sk.get_bone_count() if sk else -1)
		print("  ", sk.get_children().map(func(x): return x.name))
		if n == "Skeleton_Minion": print("  ", Array(ap.get_animation_list()))
	get_tree().quit()
