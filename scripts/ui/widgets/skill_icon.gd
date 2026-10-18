class_name SkillIcon
extends Control
## Gezeichnetes Fähigkeiten-Symbol (ohne Bilddateien): Farbe und Motiv richten sich nach Element/Art der Fähigkeit.
## Wird im HUD, im Level-Up-Fenster und in der Fähigkeiten-Übersicht verwendet.

var skill_id := ""
var level := 0
var max_level := 0
var cd_frac := 0.0           # 0..1 Anteil der noch laufenden Abklingzeit (Sektor-Anzeige)
var cd_text := ""
var key_text := ""
var dim := false
var empty := true
var rarity_color := Color("#c8c8c8")
var show_pips := true

const COLORS := {
	"fire": Color("#ff7a3a"), "frost": Color("#6fd6ff"), "lightning": Color("#ffe84a"), "earth": Color("#b8905a"),
	"summon": Color("#7affd0"), "crit": Color("#ff5a6e"), "sustain": Color("#e8505a"), "mobility": Color("#7be08a"),
	"defense": Color("#7aa8e8"), "cooldown": Color("#b48aff"), "area": Color("#ffa24a"), "support": Color("#8aef9a"),
	"spell": Color("#c58aff"), "risk": Color("#ff4aa8"), "melee": Color("#d8d8e8"), "_light": Color("#e8e8f0"), "_heavy": Color("#ffb060"),
}


func setup(id: String, lv: int = 0) -> void:
	skill_id = id
	level = lv
	empty = id == ""
	if id != "" and GameData.skills.has(id):
		var d: Dictionary = GameData.skills[id]
		max_level = int(d.get("max_level", 1))
		rarity_color = Color(GameData.skill_cfg["rarity_colors"].get(d["rarity"], "#c8c8c8"))
	elif id == "_light" or id == "_heavy":
		max_level = 0
		rarity_color = Color("#8a7a5a")
	queue_redraw()


func tint() -> Color:
	if skill_id == "_light" or skill_id == "_heavy":
		return COLORS[skill_id]
	if GameData.skills.has(skill_id):
		for t in ["fire", "frost", "lightning", "earth", "summon", "crit", "sustain", "defense", "cooldown", "mobility", "spell", "risk", "support", "area", "melee"]:
			if t in GameData.skills[skill_id].get("tags", []):
				return COLORS[t]
	return Color("#c8c8c8")


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x, size.y) * 0.5
	var rect := Rect2(Vector2.ZERO, size)
	# Hintergrund
	draw_rect(rect, Color(0.035, 0.03, 0.04, 0.96))
	if empty:
		draw_rect(rect.grow(-s * 0.18), Color(1, 1, 1, 0.03))
		_frame(Color("#3a3226"))
		return
	var col := tint()
	draw_rect(rect.grow(-2), col.darkened(0.78))
	draw_circle(c, s * 0.42, col.darkened(0.6))
	_glyph(c, s * 0.34, col)
	if dim:
		draw_rect(rect, Color(0.1, 0.12, 0.3, 0.45))
	# Abklingzeit: dunkler Sektor im Uhrzeigersinn
	if cd_frac > 0.001:
		var pts := PackedVector2Array([c])
		var a0 := -PI * 0.5
		var a1 := a0 + TAU * cd_frac
		var n := maxi(int(32.0 * cd_frac), 2)
		var rr := s * 0.75
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			var p := c + Vector2(cos(a), sin(a)) * rr
			p.x = clampf(p.x, 0.0, size.x)
			p.y = clampf(p.y, 0.0, size.y)
			pts.append(p)
		_poly(pts, Color(0, 0, 0, 0.66))
		if cd_text != "":
			var f := ThemeDB.fallback_font
			var fs := int(s * 0.36)
			var ts := f.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string_outline(f, c + Vector2(-ts.x * 0.5, ts.y * 0.3), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
			draw_string(f, c + Vector2(-ts.x * 0.5, ts.y * 0.3), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	_frame(rarity_color if (skill_id != "_light" and skill_id != "_heavy") else Color("#8a7a5a"))
	# Taste unten rechts
	var f2 := ThemeDB.fallback_font
	if key_text != "":
		var fs2 := int(s * 0.22)
		var ks := f2.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var kp := Vector2(size.x - ks.x - 5, size.y - 5)
		draw_string_outline(f2, kp, key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 4, Color.BLACK)
		draw_string(f2, kp, key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("#f0e6c8"))
	# Stufen-Punkte oben
	if show_pips and max_level > 1 and level > 0:
		var pw := s * 0.1
		var total := max_level * (pw + 2.0) - 2.0
		var x0 := (size.x - total) * 0.5
		for i in max_level:
			var pr := Rect2(x0 + i * (pw + 2.0), 3, pw, pw * 0.7)
			draw_rect(pr, col.lightened(0.25) if i < level else Color(0, 0, 0, 0.7))


func _frame(c: Color) -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, c.darkened(0.45), false, 3.0)
	draw_rect(r.grow(-2), c, false, 1.5)


func _glyph(c: Vector2, r: float, col: Color) -> void:
	var lt := col.lightened(0.35)
	var id := skill_id
	match id:
		"fireball", "volatile_corpses":
			var fl := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, -r * 0.1), c + Vector2(r * 0.5, r * 0.55), c + Vector2(0, r), c + Vector2(-r * 0.5, r * 0.55), c + Vector2(-r * 0.6, -r * 0.1), c + Vector2(-r * 0.15, -r * 0.35)])
			_poly(fl, col)
			_poly(PackedVector2Array([c + Vector2(0, -r * 0.2), c + Vector2(r * 0.28, r * 0.35), c + Vector2(0, r * 0.75), c + Vector2(-r * 0.28, r * 0.35)]), Color("#ffe27a"))
			if id == "volatile_corpses":
				for i in 8:
					var a := i * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * r * 0.9, c + Vector2(cos(a), sin(a)) * r * 1.2, lt, 2.0)
		"frost_nova", "frost_dodge":
			for i in 6:
				var a := i * TAU / 6.0
				var d := Vector2(cos(a), sin(a))
				draw_line(c, c + d * r, lt, 3.0)
				var m := c + d * r * 0.62
				var side := Vector2(-d.y, d.x)
				draw_line(m, m + (d + side) * r * 0.28, lt, 2.0)
				draw_line(m, m + (d - side) * r * 0.28, lt, 2.0)
			draw_circle(c, r * 0.14, Color.WHITE)
			if id == "frost_dodge":
				draw_line(c + Vector2(-r, r * 1.05), c + Vector2(r, r * 1.05), Color("#e8fbff"), 3.0)
		"chain_lightning", "storm_aegis":
			var bolt := PackedVector2Array([c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.55, r * 0.1), c + Vector2(-r * 0.05, r * 0.1), c + Vector2(-r * 0.25, r), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.1, -r * 0.2)])
			_poly(bolt, col)
			draw_polyline(bolt + PackedVector2Array([bolt[0]]), Color.WHITE, 1.5)
		"earthquake":
			_poly(PackedVector2Array([c + Vector2(-r, r * 0.8), c + Vector2(-r * 0.5, -r * 0.3), c + Vector2(-r * 0.1, r * 0.8)]), col)
			_poly(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.8), c + Vector2(r * 0.15, -r), c + Vector2(r * 0.6, r * 0.8)]), lt)
			_poly(PackedVector2Array([c + Vector2(r * 0.3, r * 0.8), c + Vector2(r * 0.65, -r * 0.1), c + Vector2(r, r * 0.8)]), col)
			draw_line(c + Vector2(-r * 1.1, r * 0.9), c + Vector2(r * 1.1, r * 0.9), lt, 2.0)
		"spirit_wisps":
			for i in 3:
				var a := -PI * 0.5 + i * TAU / 3.0
				var p := c + Vector2(cos(a), sin(a)) * r * 0.55
				draw_circle(p, r * 0.26, col)
				draw_circle(p, r * 0.12, Color.WHITE)
				draw_line(p, p + Vector2(-sin(a), cos(a)) * r * 0.5, col.darkened(0.2), 2.0)
		"crit_mastery":
			_poly(_star(c, r, r * 0.3, 4), col)
			draw_circle(c, r * 0.18, Color.WHITE)
		"executioner":
			draw_line(c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, r * 0.8), lt, 4.0)
			draw_line(c + Vector2(r * 0.8, -r * 0.8), c + Vector2(-r * 0.8, r * 0.8), lt, 4.0)
			draw_circle(c, r * 0.18, col)
		"vampiric":
			var drop := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.6, r * 0.25), c + Vector2(r * 0.4, r * 0.75), c + Vector2(0, r), c + Vector2(-r * 0.4, r * 0.75), c + Vector2(-r * 0.6, r * 0.25)])
			_poly(drop, col)
			draw_circle(c + Vector2(-r * 0.2, r * 0.1), r * 0.12, Color(1, 1, 1, 0.7))
		"swift":
			for i in 2:
				var o := c + Vector2(0, (i - 0.5) * r * 0.9)
				draw_polyline(PackedVector2Array([o + Vector2(-r * 0.7, -r * 0.35), o + Vector2(0, r * 0.15), o + Vector2(r * 0.7, -r * 0.35)]), lt if i == 0 else col, 4.0)
		"vitality", "iron_will":
			var sh := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
			_poly(sh, col)
			if id == "iron_will":
				draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.6), Color.WHITE, 3.0)
				draw_line(c + Vector2(-r * 0.55, -r * 0.2), c + Vector2(r * 0.55, -r * 0.2), Color.WHITE, 3.0)
			else:
				_poly(PackedVector2Array([c + Vector2(0, r * 0.65), c + Vector2(-r * 0.3, 0), c + Vector2(-r * 0.12, -r * 0.3), c + Vector2(0, -r * 0.12), c + Vector2(r * 0.12, -r * 0.3), c + Vector2(r * 0.3, 0)]), Color("#ff6a7a"))
		"arcane_focus":
			draw_arc(c, r * 0.9, 0, TAU, 28, lt, 3.0)
			draw_line(c, c + Vector2(0, -r * 0.65), col, 3.0)
			draw_line(c, c + Vector2(r * 0.45, r * 0.2), col, 3.0)
			draw_circle(c, r * 0.1, Color.WHITE)
		"wide_strikes", "_light":
			draw_arc(c + Vector2(0, r * 0.3), r * 0.95, PI * 1.12, PI * 1.88, 18, lt, 6.0)
			draw_arc(c + Vector2(0, r * 0.3), r * 0.65, PI * 1.15, PI * 1.85, 14, col, 4.0)
		"heal_aura":
			draw_arc(c, r * 0.95, 0, TAU, 28, col.darkened(0.2), 2.0)
			draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 0.6), Vector2(r * 0.36, r * 1.2)), col)
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.18), Vector2(r * 1.2, r * 0.36)), col)
		"twin_cast":
			draw_circle(c + Vector2(-r * 0.32, 0), r * 0.55, Color(col, 0.85))
			draw_circle(c + Vector2(r * 0.32, 0), r * 0.55, Color(lt, 0.85))
		"glass_cannon":
			var dm := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)])
			_poly(dm, col)
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.1, -r * 0.8), c + Vector2(-r * 0.15, -r * 0.1), c + Vector2(r * 0.15, r * 0.2), c + Vector2(-r * 0.05, r * 0.8)]), Color.WHITE, 2.0)
		"_heavy":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.8), Vector2(r * 1.4, r * 0.7)), lt)
			draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.1), Vector2(r * 0.24, r * 1.0)), col.darkened(0.2))
		_:
			draw_circle(c, r * 0.7, col)
			draw_circle(c, r * 0.3, lt)


func _star(c: Vector2, ro: float, ri: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI * 0.5 + i * PI / n
		var rr := ro if i % 2 == 0 else ri
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


## Zeichnet ein Polygon sicher: nicht triangulierbare Formen (Selbstüberschneidung) werden als Linienzug gezeichnet.
func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		var closed := pts.duplicate()
		if pts.size() > 0:
			closed.append(pts[0])
		if closed.size() >= 2:
			draw_polyline(closed, col, 2.0)
		return
	draw_colored_polygon(pts, col)
