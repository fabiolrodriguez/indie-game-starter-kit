class_name PaletteImporter
extends RefCounted
## Explicit five-color mapping: background, surface, surface_alt, primary, text.

const Palette = preload("res://ui/theme/ui_palette.gd")

static func parse_hex(text: String, display_name := "Imported") -> Dictionary:
	var colors: Array[Color] = []
	var hex := RegEx.new()
	hex.compile("^#?[0-9a-fA-F]{6}$")
	var lines := text.replace("\r", "").replace(",", "\n").replace(" ", "\n").replace("\t", "\n").split("\n", false)
	for token in lines:
		if not hex.search(token):
			return {"error": "Invalid color '%s'. Use six-digit RGB HEX, with optional #." % token}
		colors.append(Color.html(token))
	if colors.size() != 5:
		return {"error": "Expected 5 colors in order: background, surface, surface_alt, primary, text. Got %d." % colors.size()}
	for index in range(3):
		if Palette.contrast(colors[4], colors[index]) < 4.5:
			return {"error": "Text must contrast at least 4.5:1 with background/surface/surface_alt (color %d). Adjust color 5 or that surface." % (index + 1)}
	var palette := Palette.new()
	palette.display_name = display_name
	palette.background = colors[0]
	palette.surface = colors[1]
	palette.surface_alt = colors[2]
	palette.primary = colors[3]
	palette.text_primary = colors[4]
	palette.secondary = colors[3].lerp(colors[4], 0.3)
	palette.accent = palette.secondary
	palette.text_secondary = colors[4].lerp(colors[1], 0.18)
	for surface in colors.slice(0, 3):
		if Palette.contrast(palette.text_secondary, surface) < 4.5:
			palette.text_secondary = palette.text_primary
	palette.text_disabled = colors[4].lerp(colors[1], 0.35)
	palette.border = colors[4].lerp(colors[1], 0.65)
	palette.focus = colors[4]
	palette.overlay = Color(colors[0], 0.9)
	# Status meaning is retained; light palettes get darker status colors.
	if Palette.luminance(colors[1]) > 0.4:
		palette.success = Color("376343")
		palette.warning = Color("795517")
		palette.danger = Color("a03e3c")
	for role in ["success", "warning", "danger"]:
		palette.set(role, readable_status(palette.get(role), palette.surface))
	return {"palette": palette, "error": ""}

static func readable_status(color: Color, surface: Color) -> Color:
	var ink := Palette.ink_on(surface)
	for step in range(11):
		var candidate := color.lerp(ink, step / 10.0)
		if Palette.contrast(candidate, surface) >= 4.5:
			return candidate
	return ink

static func import_file(input_path: String, output_path: String, display_name := "Imported") -> Dictionary:
	if not input_path.get_extension().to_lower() in ["hex", "txt"]:
		return {"error": "Input must be a local .hex or .txt file."}
	var file := FileAccess.open(input_path, FileAccess.READ)
	if not file:
		return {"error": "Cannot read '%s' (error %d)." % [input_path, FileAccess.get_open_error()]}
	var result := parse_hex(file.get_as_text(), display_name)
	if not result.get("error", "").is_empty():
		return result
	if output_path.get_extension().to_lower() != "tres":
		return {"error": "Output must be a .tres Resource."}
	if FileAccess.file_exists(output_path):
		return {"error": "Refusing to overwrite '%s'. Choose a new resource path." % output_path}
	if not DirAccess.dir_exists_absolute(output_path.get_base_dir()):
		return {"error": "Output directory does not exist: " + output_path.get_base_dir()}
	var error := ResourceSaver.save(result.palette, output_path)
	if error != OK:
		return {"error": "Cannot save palette (error %d)." % error}
	return result
