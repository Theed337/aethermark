extends Node
func _ready() -> void:
	for n in ["Knight","Barbarian"]:
		var m: Node3D = load("res://assets/kaykit/%s.glb" % n).instantiate()
		var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
		for c in sk.get_children():
			if c is BoneAttachment3D and (String(c.name).contains("Shield")):
				print(n, " ", c.name, " bone=", c.bone_name, " T=", c.transform)
				for k in c.get_children(): print("   child ", k.name, k.transform)
		print(sk.get_children().map(func(x): return x.name))
	get_tree().quit()
