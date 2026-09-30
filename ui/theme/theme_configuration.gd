@tool
class_name ThemeConfiguration
extends Resource
## Developer-owned source data. Generated Theme properties are never saved here.

const Palette = preload("res://ui/theme/ui_palette.gd")
const VisualStyle = preload("res://ui/theme/ui_visual_style.gd")

@export var palette: Palette:
	set(value):
		if palette and palette.changed.is_connected(emit_changed):
			palette.changed.disconnect(emit_changed)
		palette = value
		if palette:
			palette.changed.connect(emit_changed)
		emit_changed()
@export var visual_style: VisualStyle:
	set(value):
		if visual_style and visual_style.changed.is_connected(emit_changed):
			visual_style.changed.disconnect(emit_changed)
		visual_style = value
		if visual_style:
			visual_style.changed.connect(emit_changed)
		emit_changed()
