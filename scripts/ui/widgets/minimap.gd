class_name Minimap
extends Control
## Rundes Radar: zeigt Gegner, Mitspieler, Truhen, Schreine, Bossarena und Teich relativ zum Spieler.
## Die Karte dreht sich mit der Kamera (oben = Blickrichtung).

const VIEW_RANGE := 55.0     # Weltmeter vom Mittelpunkt bis zum Rand

var arena: Node
var player: Player


func bind(a: Node, p: Player) -> void:
	arena = a
	player = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _to_map(world: Vector3, origin: Vector3, yaw: float, rad: float) -> Vector2:
	var d := world - origin
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var sx := d.dot(right)
	var sy := d.dot(fwd)
	return Vector2(sx, -sy) * (rad / VIEW_RANGE)


func _draw() -> void:
	var rad := minf(size.x, size.y) * 0.5 - 6.0
	var c := size * 0.5
	draw_circle(c, rad, Color(0.07, 0.1, 0.09, 0.94))
	if player == null or not is_instance_valid(player):
		return
	var origin := player.global_position
	var yaw := player.cam_yaw
	# Gelände: Kartenrand, Teich, Bossarena, Startlichtung
	_ring(c, rad, _to_map(Vector3.ZERO, origin, yaw, rad), ForestMap.RADIUS, Color(0.8, 0.3, 0.3, 0.5), 2.0)
	_disc(c, rad, _to_map(ForestMap.POND_POS, origin, yaw, rad), ForestMap.POND_R, Color(0.25, 0.55, 0.8, 0.45) if str(ForestMap.T["hazard"]) == "none" else Color(0.9, 0.3, 0.15, 0.5))
	_disc(c, rad, _to_map(ForestMap.BOSS_POS, origin, yaw, rad), ForestMap.BOSS_ARENA_R, Color(0.75, 0.7, 0.5, 0.28))
	_disc(c, rad, _to_map(ForestMap.SPAWN_POS, origin, yaw, rad), 7.0, Color(0.85, 0.75, 0.45, 0.22))
	# Objekte
	for ch in arena.get("_chests") if arena.get("_chests") != null else []:
		if not ch["open"] and is_instance_valid(ch["node"]):
			_dot(c, rad, _to_map(ch["node"].global_position, origin, yaw, rad), Color("#ffd24a"), 3.5, true)
	for sh in arena.get("_shrines") if arena.get("_shrines") != null else []:
		if is_instance_valid(sh["node"]) and sh["state"] != "done":
			_dot(c, rad, _to_map(sh["node"].global_position, origin, yaw, rad), Color("#c06aff"), 4.0, true)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead") == true:
			continue
		var is_boss: bool = e is Boss
		var col := Color("#ff4a3a")
		var sz := 3.0
		if e.get("elite_mod") != null and str(e.elite_mod) != "":
			col = Color("#ff9a2a")
			sz = 4.2
		if is_boss:
			col = Color("#ff2a6a")
			sz = 7.0
		_dot(c, rad, _to_map(e.global_position, origin, yaw, rad), col, sz, is_boss)
	for g in ["player", "puppets"]:
		for p in get_tree().get_nodes_in_group(g):
			if is_instance_valid(p) and p != player:
				_dot(c, rad, _to_map(p.global_position, origin, yaw, rad), Color("#5aff8a") if not p.is_down() else Color("#aaaaaa"), 4.0, true)
	# Spieler als Pfeil (zeigt in Blickrichtung der Figur relativ zur Kamera)
	var rel_yaw := player.rotation.y - yaw
	var dir := Vector2(-sin(rel_yaw), -cos(rel_yaw))
	var side := Vector2(-dir.y, dir.x)
	_poly(PackedVector2Array([c + dir * 9.0, c - dir * 6.0 + side * 6.0, c - dir * 2.0, c - dir * 6.0 - side * 6.0]), Color("#fff2c0"))
	# Rahmen
	draw_arc(c, rad + 1.0, 0, TAU, 64, Color("#2a1e0c"), 6.0, true)
	draw_arc(c, rad, 0, TAU, 64, Color("#8a6a2a"), 3.0, true)
	draw_arc(c, rad - 2.5, 0, TAU, 64, Color("#d8b25a"), 1.2, true)
	# Norden-Marke (Welt -Z)
	var f := ThemeDB.fallback_font
	var npos := c + Vector2(sin(yaw), -cos(yaw)) * (rad - 10.0)
	draw_string_outline(f, npos + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(f, npos + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffd98a"))


func _dot(c: Vector2, rad: float, off: Vector2, col: Color, sz: float, edge_arrow: bool) -> void:
	var l := off.length()
	if l > rad - 4.0:
		if not edge_arrow:
			return
		off = off / l * (rad - 5.0)
		sz *= 0.8
		col.a = 0.7
	draw_circle(c + off, sz, col)
	draw_arc(c + off, sz, 0, TAU, 12, Color(0, 0, 0, 0.7), 1.0)


func _disc(c: Vector2, rad: float, off: Vector2, wr: float, col: Color) -> void:
	var rr := wr * rad / VIEW_RANGE
	if off.length() - rr > rad:
		return
	# Auf den Kartenkreis zugeschnitten durch punktweises Zeichnen
	var pts := PackedVector2Array()
	for i in 40:
		var a := i * TAU / 40.0
		var p := off + Vector2(cos(a), sin(a)) * rr
		if p.length() > rad - 3.0:
			p = p / p.length() * (rad - 3.0)
		pts.append(c + p)
	_poly(pts, col)


func _ring(c: Vector2, rad: float, off: Vector2, wr: float, col: Color, w: float) -> void:
	var rr := wr * rad / VIEW_RANGE
	var prev := Vector2.ZERO
	var have := false
	for i in 91:
		var a := i * TAU / 90.0
		var p := off + Vector2(cos(a), sin(a)) * rr
		var inside := p.length() < rad - 3.0
		if inside and have:
			draw_line(c + prev, c + p, col, w)
		prev = p
		have = inside


func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, col)
