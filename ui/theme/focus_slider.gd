@tool
extends HSlider
## Sliders have no native focus StyleBox; use the shared button focus indicator.

func _notification(what: int) -> void:
	if what in [NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_THEME_CHANGED]:
		queue_redraw()

func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))
