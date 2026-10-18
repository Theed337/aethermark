extends SceneTree
func _init() -> void:
	var bad := 0
	var d := DirAccess.open("res://assets/audio/sfx")
	for f in d.get_files():
		if f.ends_with(".ogg"):
			var s = load("res://assets/audio/sfx/" + f)
			if s == null or s.get_length() <= 0.01:
				bad += 1
				print("BAD ", f)
	print("sfx files ok, bad=", bad)
	quit()
