class_name SceneTransitionOptions
extends Resource
## Developer configuration. Duration is per fade, in real seconds.

@export_range(0.0, 5.0, 0.01) var fade_duration := 0.22
@export var use_palette_background := true
## Used when palette background is disabled. Opacity is always forced to 1.
@export var color := Color.BLACK
@export var skip_visual := false
