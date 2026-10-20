class_name UI
extends RefCounted
## Gemeinsames UI-Theme und Bausteine (Panels, Buttons, Balken). Alle Menüs werden im Code gebaut.

const BG := Color("#0f1a24")
const PANEL := Color("#16283a")
const PANEL2 := Color("#1d3550")
const GOLD := Color("#f0c65a")
const TEAL := Color("#4ecdc4")
const TEXT := Color("#e8f1f5")
const DIM := Color("#8aa3b5")
const RED := Color("#e0605a")

static var _theme: Theme


## Texturierter 9-Slice-Rahmen aus assets/ui (Rückfall: flache Box).
static func tex_box(name: String, margin: int, pad: float, fallback: StyleBox) -> StyleBox:
	var path := "res://assets/ui/%s.png" % name
	if not ResourceLoader.exists(path):
		return fallback
	var tex := load(path) as Texture2D
	if tex == null:
		return fallback
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.set_texture_margin_all(margin)
	s.set_content_margin_all(pad)
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


## Leistenfüllung mit Verlauf/Glanz ("red", "gold", "teal", "blue").
static func bar_fill(kind: String, fallback_color: Color) -> StyleBox:
	var s := tex_box("bar_" + kind, 3, 0.0, box(fallback_color, 5, Color(0, 0, 0, 0), 0, 0))
	if s is StyleBoxTexture:
		s.set_content_margin_all(0.0)
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#5d7080"))
	t.set_stylebox("normal", "Button", tex_box("btn_normal", 12, 10, box(PANEL2, 8, Color("#2c4a68"), 2)))
	t.set_stylebox("hover", "Button", tex_box("btn_hover", 12, 10, box(Color("#27496b"), 8, TEAL, 2)))
	t.set_stylebox("pressed", "Button", tex_box("btn_pressed", 12, 10, box(Color("#12293f"), 8, GOLD, 2)))
	t.set_stylebox("disabled", "Button", tex_box("btn_disabled", 12, 10, box(Color("#131f2b"), 8, Color("#1f2e3d"), 2)))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 8, GOLD, 2))
	t.set_stylebox("panel", "PanelContainer", tex_box("panel", 14, 8, box(PANEL, 12, Color("#2c4a68"), 2)))
	t.set_stylebox("normal", "LineEdit", tex_box("field", 10, 8, box(Color("#0c1620"), 6, Color("#2c4a68"), 2)))
	t.set_stylebox("normal", "OptionButton", tex_box("btn_normal", 12, 10, box(PANEL2, 8, Color("#2c4a68"), 2)))
	t.set_stylebox("hover", "OptionButton", tex_box("btn_hover", 12, 10, box(Color("#27496b"), 8, TEAL, 2)))
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	_theme = t
	return t


static func box(color: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func label(text: String, size: int = 17, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", color)
	return l


static func button(text: String, cb: Callable = Callable(), min_size: Vector2 = Vector2(0, 40)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	if cb.is_valid():
		b.pressed.connect(func():
			Sfx.play("ui", 1.0, -8.0)
			cb.call())
	return b


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func bar(color: Color, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	b.add_theme_stylebox_override("background", box(Color(0.03, 0.05, 0.08, 0.85), 5, Color(0, 0, 0, 0.6), 1, 0))
	b.add_theme_stylebox_override("fill", bar_fill(_bar_kind(color), color))
	return b


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


## Auswahlfeld, das nie breiter wird als sein Container (lange Einträge werden abgeschnitten).
static func option() -> OptionButton:
	var o := OptionButton.new()
	o.clip_text = true
	o.fit_to_longest_item = false
	o.custom_minimum_size = Vector2(60, 0)
	return o


static func _bar_kind(c: Color) -> String:
	if c.r > 0.6 and c.g < 0.5:
		return "red"
	if c.r > 0.7 and c.g > 0.6 and c.b < 0.5:
		return "gold"
	if c.b > 0.7 and c.r < 0.5:
		return "blue"
	return "teal" if c.g > c.r else "red"
