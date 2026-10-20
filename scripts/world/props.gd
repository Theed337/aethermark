class_name WorldProps
extends RefCounted
## Interaktive Weltobjekte (Truhe, Schrein, Beute-Kristall). Host (Arena) und Client (ClientArena) bauen sie mit
## demselben Code, damit beide dasselbe sehen. Die Spiellogik (wer öffnet was, was fällt heraus) liegt nur im Host.


static func make_chest(parent: Node3D, pos: Vector3) -> Dictionary:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var closed := ItemModels.make("ChestClosed", 1.25)
	var opened := ItemModels.make("ChestOpen", 1.25)
	if closed != null and opened != null:
		closed.name = "Closed"
		opened.name = "Opened"
		opened.visible = false
		n.add_child(closed)
		n.add_child(opened)
	else:
		var wood := Color("#8a5a2a")
		Toon.outline(Toon.part(n, "box", Vector3(1.0, 0.6, 0.7), wood, Vector3(0, 0.3, 0)), 0.02)
		var lid0 := Toon.part(n, "cyl", Vector3(0.35, 1.0, 0.35), wood.lightened(0.1), Vector3(0, 0.62, 0), Vector3(0, 0, 90))
		lid0.name = "Lid"
	var l := OmniLight3D.new()
	l.light_color = Color("#ffd98a")
	l.omni_range = 4.0
	l.light_energy = 0.8
	l.position.y = 1.0
	n.add_child(l)
	return {"node": n, "open": false, "kind": "chest"}


static func open_chest_visual(c: Dictionary, parent: Node) -> void:
	c["open"] = true
	var nd: Node3D = c["node"]
	if nd.has_node("Closed"):
		nd.get_node("Closed").visible = false
		nd.get_node("Opened").visible = true
	elif nd.has_node("Lid"):
		nd.get_node("Lid").rotation_degrees.x = -70
	FX.burst(parent, c["node"].global_position + Vector3(0, 0.8, 0), Color("#ffd98a"), 14, 5.0)


static func make_shrine(parent: Node3D, pos: Vector3) -> Dictionary:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var stone := Color("#7a7470")
	Toon.outline(Toon.part(n, "cyl", Vector3(0.5, 1.2, 0.7), stone, Vector3(0, 0.6, 0)), 0.02)
	var orb := Toon.part(n, "sphere", Vector3(0.3, 0, 0), Color("#b04aff"), Vector3(0, 1.6, 0), Vector3.ZERO, Toon.glow_mat(Color("#b04aff"), 2.5))
	orb.name = "Orb"
	var l := OmniLight3D.new()
	l.light_color = Color("#b04aff")
	l.omni_range = 7.0
	l.position.y = 1.8
	n.add_child(l)
	return {"node": n, "state": "idle", "kind": "shrine", "enemies": []}


## Setzt die Darstellung eines Schreins auf einen Zustand (idle | active | done).
static func set_shrine_visual(s: Dictionary, state: String, parent: Node) -> void:
	s["state"] = state
	var orb: MeshInstance3D = s["node"].get_node("Orb")
	if state == "done":
		orb.material_override = Toon.glow_mat(Color("#6adf7a"), 1.5)
	elif state == "active":
		FX.ring(parent, s["node"].global_position, 8.0, Color("#b04aff"), 0.7)


## Beute-Kristall mit Lichtsäule und Namensschild. Gibt den Wurzelknoten zurück (Kind "Gem" schwebt/dreht sich).
static func make_pickup(parent: Node3D, pos: Vector3, item: Dictionary) -> Node3D:
	var col := GameData.rarity_color(item["rarity"])
	var n := Node3D.new()
	n.position = Vector3(pos.x, 0.0, pos.z)
	n.top_level = true
	parent.add_child(n)
	var gem: Node3D = Node3D.new()
	gem.position = Vector3(0, 0.7, 0)
	var mdl := ItemModels.make(ItemModels.model_name(item), 1.25 if item.get("slot", "") != "weapon" else 1.7)
	if mdl != null:
		mdl.position.y = -0.4
		gem.add_child(mdl)
		var ring := Toon.part(n, "torus", Vector3(0.62, 0.52, 0), col, Vector3(0, 0.05, 0), Vector3.ZERO, Toon.glow_mat(col, 2.0, 0.8), false)
		ring.name = "Ring"
	else:
		Toon.part(gem, "prism", Vector3(0.35, 0.5, 0.35), col, Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(col, 2.2), false)
	n.add_child(gem)
	gem.name = "Gem"
	var beam := Toon.part(n, "cyl", Vector3(0.07, 4.0, 0.07), col, Vector3(0, 2.0, 0), Vector3.ZERO, Toon.glow_mat(col, 1.4, 0.25), false)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 5.0
	l.position.y = 1.0
	n.add_child(l)
	var lab := Label3D.new()
	lab.text = item["name"]
	lab.modulate = col
	lab.font_size = 36
	lab.pixel_size = 0.008
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.outline_size = 10
	lab.no_depth_test = true
	lab.position.y = 1.5
	n.add_child(lab)
	return n


static func animate_pickup(n: Node3D, t: float, delta: float) -> void:
	var gem: Node3D = n.get_node("Gem")
	gem.position.y = 0.7 + sin(t * 3.0) * 0.12
	gem.rotation.y += delta * 2.0
