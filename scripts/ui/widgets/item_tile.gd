class_name ItemTile
extends Button
## Kachel für einen Gegenstand oder einen leeren Platz – unterstützt Ziehen & Ablegen (Drag & Drop).
## payload: beliebiges Dictionary, das beim Ziehen mitgegeben wird (z. B. {"uid":…, "from":"inv"}).

var payload: Dictionary = {}
var drop_check := Callable()   # (data: Dictionary) -> bool
var drop_do := Callable()      # (data: Dictionary) -> void
var item: Dictionary = {}
var tile_size := Vector2(100, 80)
var drag_enabled := true


func _get_drag_data(_at: Vector2) -> Variant:
	if payload.is_empty() or not drag_enabled:
		return null
	var pv := ItemTile.make(item, "", Vector2(150, 56), false, false)
	pv.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(pv)
	return payload


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and drop_check.is_valid() and bool(drop_check.call(data))


func _drop_data(_at: Vector2, data: Variant) -> void:
	if drop_do.is_valid():
		drop_do.call(data)


static func tooltip_of(it: Dictionary) -> String:
	var lines: Array = ["%s (%s)" % [it["name"], GameData.rarity_name(it["rarity"])]]
	lines.append_array(ItemText.lines(it).slice(1))
	return "\n".join(lines)


## Kachel bauen. Rahmenfarbe = Seltenheit, grün = getragen, gold = gewählt.
static func make(it: Dictionary, slot_name: String, size: Vector2, equipped: bool, selected: bool, price: int = -1) -> ItemTile:
	var b := ItemTile.new()
	b.item = it
	b.tile_size = size
	b.custom_minimum_size = size
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	var empty := it.is_empty()
	var rc: Color = DataColors.rarity(it["rarity"]) if not empty else Color("#33415a")
	var bg := Color("#162033") if empty else Color("#1c2a40")
	if equipped:
		bg = Color("#1d3a2c")
	var bw := 3 if selected else 2
	var border := UI.GOLD if selected else (Color("#5cff9a") if equipped else rc)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := UI.box(bg.lightened(0.08) if st == "hover" else bg, 8, border if st != "hover" else border.lightened(0.3), bw, 6)
		b.add_theme_stylebox_override(st, sb)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 3
	box.offset_bottom = -2
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var nm := Label.new()
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(size.x - 14, 0)
	nm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.add_theme_font_size_override("font_size", 13 if size.y >= 70 else 11)
	var info := Label.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", UI.DIM)
	box.add_child(nm)
	if size.y >= 60:
		box.add_child(info)
	if empty:
		nm.text = slot_name
		nm.add_theme_color_override("font_color", UI.DIM)
		info.text = "— leer —"
	else:
		nm.text = it["name"]
		nm.add_theme_color_override("font_color", rc.lightened(0.3))
		info.text = "Stufe %d%s" % [it["level"], " [gesperrt]" if it.get("locked", false) else ""]
		if price >= 0:
			info.text = "Stufe %d · %d Gold" % [it["level"], price]
		b.tooltip_text = tooltip_of(it)
	return b
