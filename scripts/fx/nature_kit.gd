class_name NatureKit
extends RefCounted
## Echte Naturmodelle (Quaternius Stylized Nature MegaKit, CC0): Bäume, Büsche, Felsen, Pilze, Blumen.
## Fällt automatisch auf die prozeduralen Formen zurück, wenn die Dateien fehlen.

const DIR := "res://assets/nature/"
static var _scenes: Dictionary = {}
static var _avail := -1


static func available() -> bool:
	if _avail < 0:
		_avail = 1 if ResourceLoader.exists(DIR + "CommonTree_1.gltf") else 0
	return _avail == 1


static func has(model: String) -> bool:
	return available() and ResourceLoader.exists("%s%s.gltf" % [DIR, model])


## Neue Instanz eines Modells (Name ohne Endung), optional mit Zielhöhe in Metern (Skalierung) und Zufallsdrehung.
static func make(model: String, target_height: float = 0.0) -> Node3D:
	if not _scenes.has(model):
		_scenes[model] = load("%s%s.gltf" % [DIR, model])
	var n: Node3D = _scenes[model].instantiate()
	var holder := Node3D.new()
	holder.add_child(n)
	if target_height > 0.0:
		var h := _height(n)
		if h > 0.01:
			holder.scale = Vector3.ONE * (target_height / h)
	return holder


static func _height(n: Node) -> float:
	var top := 0.0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).transform * (m as MeshInstance3D).get_aabb()
		top = maxf(top, b.end.y)
	return top


static func pick(prefix: String, count: int, rng: RandomNumberGenerator) -> String:
	return "%s_%d" % [prefix, 1 + rng.randi() % count]
