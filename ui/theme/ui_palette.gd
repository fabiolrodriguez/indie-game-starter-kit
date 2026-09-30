@tool
class_name UIPalette
extends Resource
## Semantic color data, independent of controls and visual styles.

@export var display_name := "Custom":
	set(value):
		display_name = value
		emit_changed()

const ROLES: PackedStringArray = ["background", "surface", "surface_alt", "primary", "secondary", "accent", "text_primary", "text_secondary", "text_disabled", "border", "success", "warning", "danger", "focus", "overlay"]

@export var background: Color = Color(0.062745, 0.078431, 0.121569, 1):
	set(value):
		background = value
		emit_changed()

@export var surface: Color = Color(0.105882, 0.133333, 0.196078, 1):
	set(value):
		surface = value
		emit_changed()

@export var surface_alt: Color = Color(0.156863, 0.196078, 0.278431, 1):
	set(value):
		surface_alt = value
		emit_changed()

@export var primary: Color = Color(0.713725, 0.737255, 0.94902, 1):
	set(value):
		primary = value
		emit_changed()

@export var secondary: Color = Color(0.533333, 0.729412, 0.733333, 1):
	set(value):
		secondary = value
		emit_changed()

@export var accent: Color = Color(0.890196, 0.737255, 0.52549, 1):
	set(value):
		accent = value
		emit_changed()

@export var text_primary: Color = Color(0.937255, 0.945098, 0.980392, 1):
	set(value):
		text_primary = value
		emit_changed()

@export var text_secondary: Color = Color(0.709804, 0.745098, 0.827451, 1):
	set(value):
		text_secondary = value
		emit_changed()

@export var text_disabled: Color = Color(0.537255, 0.584314, 0.67451, 1):
	set(value):
		text_disabled = value
		emit_changed()

@export var border: Color = Color(0.27451, 0.32549, 0.427451, 1):
	set(value):
		border = value
		emit_changed()

@export var success: Color = Color(0.552941, 0.784314, 0.643137, 1):
	set(value):
		success = value
		emit_changed()

@export var warning: Color = Color(0.901961, 0.756863, 0.533333, 1):
	set(value):
		warning = value
		emit_changed()

@export var danger: Color = Color(0.94902, 0.607843, 0.623529, 1):
	set(value):
		danger = value
		emit_changed()

@export var focus: Color = Color(0.890196, 0.737255, 0.52549, 1):
	set(value):
		focus = value
		emit_changed()

@export var overlay: Color = Color(0.031373, 0.043137, 0.078431, 0.86):
	set(value):
		overlay = value
		emit_changed()

static func contrast(a: Color, b: Color) -> float:
	var x := luminance(a)
	var y := luminance(b)
	return (maxf(x, y) + 0.05) / (minf(x, y) + 0.05)

static func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722

static func ink_on(color: Color) -> Color:
	return Color.BLACK if contrast(color, Color.BLACK) > contrast(color, Color.WHITE) else Color.WHITE
