extends Node
## Kompiliert alle Skripte im laufenden Projekt (mit Autoloads) und meldet Fehler.
## Start:  godot --headless --path . res://tests/load_all.tscn      Exit-Code 0 = alle Skripte kompilieren.

func _collect(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)


func _ready() -> void:
	var files: Array = []
	_collect("res://scripts", files)
	var bad := 0
	for f in files:
		var s := load(f)
		if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate() and not (s as GDScript).is_abstract():
			# Skripte mit nur statischen Funktionen sind trotzdem instanziierbar; Fehler erkennt man am Reload
			if s == null or (s as GDScript).reload() != OK:
				printerr("FEHLER beim Kompilieren: ", f)
				bad += 1
	print("Skripte geprüft: %d, fehlerhaft: %d" % [files.size(), bad])
	for scene in ["res://scenes/main_menu.tscn", "res://scenes/arena.tscn", "res://scenes/client_arena.tscn"]:
		if load(scene) == null:
			printerr("FEHLER Szene: ", scene)
			bad += 1
	get_tree().quit(1 if bad > 0 else 0)
