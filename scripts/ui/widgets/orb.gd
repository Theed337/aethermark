class_name Orb
extends Control
## Kugelanzeige (Leben/Mana) mit goldenem Rahmen. Füllstand per Shader, Zahl in der Mitte.

var mat: ShaderMaterial
var fill: ColorRect
var text := ""
var frame_color := Color("#8a6a2a")
var _shown := 1.0


func setup(col_low: Color, col_high: Color) -> void:
	fill = ColorRect.new()
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 7
	fill.offset_top = 7
	fill.offset_right = -7
	fill.offset_bottom = -7
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/orb.gdshader")
	mat.set_shader_parameter("col_low", col_low)
	mat.set_shader_parameter("col_high", col_high)
	fill.material = mat
	add_child(fill)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_level(v: float, delta: float = 1.0) -> void:
	v = clampf(v, 0.0, 1.0)
	_shown = lerpf(_shown, v, clampf(delta * 8.0, 0.0, 1.0))
	mat.set_shader_parameter("level", _shown)


func set_pulse(v: float) -> void:
	mat.set_shader_parameter("pulse", v)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_arc(c, r - 3.0, 0, TAU, 64, Color("#2a1e0c"), 7.0, true)
	draw_arc(c, r - 3.5, 0, TAU, 64, frame_color, 4.0, true)
	draw_arc(c, r - 6.5, 0, TAU, 64, frame_color.lightened(0.35), 1.5, true)
	draw_arc(c, r - 0.5, 0, TAU, 64, Color(0, 0, 0, 0.6), 2.0, true)
	if text != "":
		var f := ThemeDB.fallback_font
		var fs := int(r * 0.26)
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p := Vector2(c.x - ts.x * 0.5, c.y + r * 0.62)
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.95))
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff2dc"))
