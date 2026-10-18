class_name TalentView
extends Control
## Interaktive Ansicht des permanenten Talentbaums: Verschieben (ziehen), Zoomen (Mausrad),
## Linksklick = erlernen, Rechtsklick = zurücknehmen. Verbindungen, Voraussetzungen und Bonus-Texte sind sichtbar.

signal changed

var character: Dictionary = {}
var zoom := 0.85
var offset := Vector2.ZERO
var hover := ""
var message := ""
var message_t := 0.0
var _press_pos := Vector2.ZERO
var _dragging := false
var _pressed := false
var _t := 0.0
var _fitted := false

const R_BY_TYPE := {"small": 13.0, "large": 19.0, "specialization": 22.0, "synergy": 21.0, "transform": 26.0}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	resized.connect(_fit)


func bind(c: Dictionary) -> void:
	character = c
	queue_redraw()


func _fit() -> void:
	if size.x < 10:
		return
	# Gesamten Baum einpassen (Mausrad zoomt danach frei)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for id in GameData.talents:
		var p: Array = GameData.talents[id]["pos"]
		lo = Vector2(minf(lo.x, p[0]), minf(lo.y, p[1]))
		hi = Vector2(maxf(hi.x, p[0]), maxf(hi.y, p[1]))
	var ext := (hi - lo) + Vector2(120, 120)
	zoom = clampf(minf(size.x / ext.x, size.y / ext.y), 0.5, 1.5)
	var mid := (lo + hi) * 0.5
	offset = size * 0.5 - mid * zoom


func _to_screen(p: Array) -> Vector2:
	return Vector2(p[0], p[1]) * zoom + offset


func _process(delta: float) -> void:
	_t += delta
	if message_t > 0.0:
		message_t -= delta
	if not _fitted and size.x > 10:
		_fitted = true
		_fit()
	if visible:
		queue_redraw()


func node_at(screen: Vector2) -> String:
	var best := ""
	var best_d := 1e9
	for id in GameData.talents:
		var n: Dictionary = GameData.talents[id]
		var d := _to_screen(n["pos"]).distance_to(screen)
		var r: float = R_BY_TYPE.get(n["type"], 14.0) * zoom + 4.0
		if d <= r and d < best_d:
			best = id
			best_d = d
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _pressed:
			if not _dragging and event.position.distance_to(_press_pos) > 6.0:
				_dragging = true
			if _dragging:
				offset += event.relative
		hover = node_at(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.12)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_press_pos = event.position
			else:
				if _pressed and not _dragging:
					click_node(node_at(event.position), false)
				_pressed = false
				_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			click_node(node_at(event.position), true)


func _zoom_at(p: Vector2, f: float) -> void:
	var nz := clampf(zoom * f, 0.4, 2.0)
	var k := nz / zoom
	offset = p - (p - offset) * k
	zoom = nz


## Erlernen (links) oder Zurücknehmen (rechts). Wird auch von Tests aufgerufen.
func click_node(id: String, refund: bool) -> bool:
	if id == "" or character.is_empty():
		return false
	if refund:
		if TalentTree.refund(character, id):
			SaveSystem.save_game()
			Sfx.play("ui", 0.8, -6.0)
			changed.emit()
			return true
		if id in character["talents"]:
			_msg("Zurücknehmen nicht möglich: andere Talente bauen darauf auf.")
		return false
	var why := TalentTree.can_allocate(id, character["talents"], int(character["talent_points"]))
	if why != "":
		_msg(why)
		return false
	TalentTree.allocate(character, id)
	SaveSystem.save_game()
	Sfx.play("levelup", 1.4, -10.0)
	changed.emit()
	return true


func _msg(t: String) -> void:
	message = t
	message_t = 2.5


func _col(n: Dictionary) -> Color:
	return Color.html(n.get("color", "#ffffff"))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b141d"))
	if character.is_empty():
		return
	var alloc: Array = character["talents"]
	var pts := int(character["talent_points"])
	var center := _to_screen(GameData.talent_center)
	# Verbindungen
	for id in GameData.talents:
		var n: Dictionary = GameData.talents[id]
		var a := _to_screen(n["pos"])
		var req: Array = n.get("requires", [])
		var targets: Array = []
		for r in req:
			targets.append(_to_screen(GameData.talents[r]["pos"]))
		if req.is_empty():
			targets.append(center)
		for i in targets.size():
			var b: Vector2 = targets[i]
			var on: bool = id in alloc and (req.is_empty() or req[i] in alloc)
			var col := _col(n)
			if on:
				draw_line(a, b, col, 5.0 * zoom + 1.0, true)
			else:
				draw_line(a, b, Color(0.28, 0.36, 0.46, 0.7), 2.5 * zoom + 0.5, true)
	# Zentrum
	draw_circle(center, 30.0 * zoom, Color("#1c3347"))
	draw_arc(center, 30.0 * zoom, 0.0, TAU, 40, UI.GOLD, 3.0)
	_text(center + Vector2(-26, 5) * zoom, "START", int(13 * zoom + 2), UI.GOLD)
	# Zweig-Beschriftungen
	for b in GameData.talent_branches:
		var first := ""
		for id in GameData.talents:
			if GameData.talents[id]["branch"] == b["id"] and id.ends_with("_4"):
				first = id
		if first != "":
			var p := _to_screen(GameData.talents[first]["pos"])
			var dir := (p - center).normalized()
			var lbl: String = b["name"].split(" &")[0].split(",")[0].left(20)
			var fs2 := int(13 * zoom + 3)
			var lw := ThemeDB.fallback_font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			_text(p + dir * 50.0 * zoom + Vector2(-lw * 0.5 + dir.x * lw * 0.5, 5), lbl, fs2, Color.html(b["color"]).lightened(0.2))
	# Knoten
	for id in GameData.talents:
		var n: Dictionary = GameData.talents[id]
		var p := _to_screen(n["pos"])
		if p.x < -40 or p.y < -40 or p.x > size.x + 40 or p.y > size.y + 40:
			continue
		var r: float = R_BY_TYPE.get(n["type"], 14.0) * zoom
		var col := _col(n)
		var owned: bool = id in alloc
		var avail := (not owned) and TalentTree.prerequisites_met(id, alloc)
		var afford := avail and TalentTree.cost_of(id) <= pts
		var fill := col if owned else Color("#14222f")
		var ring := col if (owned or avail) else Color(0.3, 0.38, 0.47)
		if afford:
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			draw_circle(p, r + 5.0 * zoom + pulse * 3.0, Color(col.r, col.g, col.b, 0.18 + 0.12 * pulse))
		match n["type"]:
			"synergy":
				_diamond(p, r, fill, ring)
			"transform":
				_poly(p, r, 6, fill, ring)
			"specialization":
				_poly(p, r, 5, fill, ring)
			_:
				draw_circle(p, r, fill)
				draw_arc(p, r, 0.0, TAU, 28, ring, 2.5 if avail or owned else 1.5)
		if n["cost"] > 1:
			_text(p + Vector2(-4, 5) * zoom, str(n["cost"]), int(12 * zoom + 3), Color.BLACK if owned else ring)
		if owned and zoom >= 0.55:
			var fs := int(12.0 * zoom + 4.0)
			var nm: String = n["name"]
			var tw := ThemeDB.fallback_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp := p + Vector2(-tw * 0.5, r + 14.0 * zoom + 4.0)
			draw_string_outline(ThemeDB.fallback_font, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
			draw_string(ThemeDB.fallback_font, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.45))
		if hover == id:
			draw_arc(p, r + 4.0, 0.0, TAU, 28, Color.WHITE, 2.0)
	if hover != "":
		_tooltip(hover, alloc, pts)
	if message_t > 0.0:
		var w := 460.0
		draw_rect(Rect2(size.x * 0.5 - w * 0.5, size.y - 52, w, 34), Color(0.5, 0.1, 0.1, 0.9))
		_text(Vector2(size.x * 0.5 - w * 0.5 + 12, size.y - 29), message, 16, Color.WHITE)


func _text(pos: Vector2, t: String, fs: int, col: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _diamond(p: Vector2, r: float, fill: Color, ring: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, ring, 2.5, true)


func _poly(p: Vector2, r: float, sides: int, fill: Color, ring: Color) -> void:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides - PI / 2.0
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, ring, 2.5, true)


const TYPE_NAMES := {"small": "Kleines Talent", "large": "Großes Talent", "specialization": "Spezialisierung",
		"synergy": "Synergie-Talent", "transform": "Umwandlung"}


func tooltip_lines(id: String, alloc: Array, pts: int) -> Array:
	var n: Dictionary = GameData.talents[id]
	var lines: Array = [n["name"], "%s · Kosten %d" % [TYPE_NAMES.get(n["type"], n["type"]), n["cost"]]]
	lines.append_array(TalentTree.describe_effects(n.get("effects", {})))
	var req: Array = n.get("requires", [])
	if not req.is_empty():
		var names: Array = []
		for r in req:
			names.append(("✓ " if r in alloc else "✗ ") + GameData.talents[r]["name"])
		lines.append(("Benötigt alle: " if n.get("requires_mode", "any") == "all" else "Benötigt eines von: ") + ", ".join(names))
	if id in alloc:
		lines.append("Erlernt – Rechtsklick zum Zurücknehmen")
	else:
		var why := TalentTree.can_allocate(id, alloc, pts)
		lines.append("Linksklick zum Erlernen" if why == "" else why)
	return lines


func _tooltip(id: String, alloc: Array, pts: int) -> void:
	var lines := tooltip_lines(id, alloc, pts)
	var w := 340.0
	var h := 12.0 + lines.size() * 22.0
	var mp := get_local_mouse_position() + Vector2(18, 18)
	mp.x = minf(mp.x, size.x - w - 6)
	mp.y = minf(mp.y, size.y - h - 6)
	draw_rect(Rect2(mp, Vector2(w, h)), Color(0.05, 0.09, 0.13, 0.96))
	draw_rect(Rect2(mp, Vector2(w, h)), _col(GameData.talents[id]), false, 2.0)
	for i in lines.size():
		var c := UI.TEXT
		if i == 0:
			c = UI.GOLD
		elif i == 1:
			c = UI.DIM
		_text(mp + Vector2(10, 22 + i * 22), lines[i], 16 if i > 0 else 18, c)
