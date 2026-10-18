class_name DropZone
extends PanelContainer
## Fläche, auf die Gegenstände gezogen werden können (Inventarliste, Verkauf, Handelsangebot).

var drop_check := Callable()
var drop_do := Callable()
var highlight := false


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and drop_check.is_valid() and bool(drop_check.call(data))
	if ok != highlight:
		highlight = ok
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	highlight = false
	queue_redraw()
	if drop_do.is_valid():
		drop_do.call(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and highlight:
		highlight = false
		queue_redraw()


func _draw() -> void:
	if highlight:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 1.0, 0.6, 0.12), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#5cff9a"), false, 2.0)
