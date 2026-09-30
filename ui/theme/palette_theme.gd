@tool
class_name PaletteTheme
extends Theme
## Shared generated output. Developers edit theme_config.tres instead.

var configuration = preload("res://ui/theme/theme_config.tres")

func _init() -> void:
	configuration.changed.connect(rebuild)
	# Wait for ThemeDB initialization and resource loading to finish. Configuration
	# remains authoritative even if someone saves generated Theme data in the editor.
	rebuild.call_deferred()

func rebuild() -> void:
	if not configuration.palette or not configuration.visual_style:
		return
	var generated: Theme = configuration.visual_style.build(configuration.palette)
	clear()
	merge_with(generated)
	default_font = generated.default_font
	default_font_size = generated.default_font_size
