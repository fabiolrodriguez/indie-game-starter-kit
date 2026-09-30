@tool
class_name UIVisualStyle
extends Resource

const Palette = preload("res://ui/theme/ui_palette.gd")
## The one supplied visual style. Colors live exclusively in Palette.

@export var body_font: Font:
	set(value):
		body_font = value
		emit_changed()
@export var title_font: Font:
	set(value):
		title_font = value
		emit_changed()
@export_range(12, 24) var font_size := 18:
	set(value):
		font_size = value
		emit_changed()
@export_range(0, 12) var corner_radius := 4:
	set(value):
		corner_radius = value
		emit_changed()
@export_range(8, 24) var spacing := 12:
	set(value):
		spacing = value
		emit_changed()

var _default_title_font: FontFile

func get_title_font() -> Font:
	if title_font:
		return title_font
	if not _default_title_font:
		# Project themes load before the editor's first asset import. Raw font data
		# keeps a fresh clone usable without depending on the .godot import cache.
		if Engine.is_editor_hint():
			_default_title_font = FontFile.new()
			_default_title_font.data = FileAccess.get_file_as_bytes("res://assets/fonts/PublicPixel-rv0pA.ttf")
		else:
			_default_title_font = load("res://assets/fonts/PublicPixel-rv0pA.ttf")
	return _default_title_font

func build(p: Palette) -> Theme:
	var t := Theme.new()
	t.default_font = body_font if body_font else ThemeDB.fallback_font
	t.default_font_size = font_size
	for role in Palette.ROLES:
		t.set_color(role, "Palette", p.get(role))
	for type in ["Label", "Button", "CheckBox", "OptionButton", "PopupMenu", "LineEdit"]:
		t.set_color("font_color", type, p.text_primary)
		t.set_color("font_disabled_color", type, p.text_disabled)
		t.set_color("font_hover_color", type, p.text_primary)
		t.set_color("font_focus_color", type, p.text_primary)
		t.set_color("font_pressed_color", type, p.text_primary)
		t.set_color("font_hover_pressed_color", type, p.text_primary)
	for type in ["HBoxContainer", "VBoxContainer", "GridContainer"]:
		t.set_constant("separation", type, spacing)
		t.set_constant("h_separation", type, spacing * 2)
		t.set_constant("v_separation", type, spacing)
	for type in ["Panel", "PanelContainer"]:
		t.set_stylebox("panel", type, box(p.surface, p.border, 1, 28, 24))
	variation(t, "Backdrop", "Panel")
	t.set_stylebox("panel", "Backdrop", box(p.background, p.background, 0, 0, 0, 0))
	variation(t, "PauseOverlay", "Panel")
	t.set_stylebox("panel", "PauseOverlay", box(p.overlay, p.overlay, 0, 0, 0, 0))
	for type in ["SettingsPanel", "ControlsPanel"]:
		variation(t, type, "PanelContainer")
	variation(t, "ControlsListPanel", "PanelContainer")
	t.set_stylebox("panel", "ControlsListPanel", box(p.background, p.border, 1, 18, 12))
	variation(t, "SwatchFrame", "PanelContainer")
	t.set_stylebox("panel", "SwatchFrame", box(p.border, p.border, 0, 1, 1, 0))
	for type in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", type, box(p.surface_alt, p.border))
		t.set_stylebox("hover", type, box(p.surface_alt.lerp(p.primary, 0.13), p.primary))
		t.set_stylebox("pressed", type, box(p.surface_alt.lerp(p.primary, 0.24), p.primary, 2))
		t.set_stylebox("hover_pressed", type, t.get_stylebox("pressed", type))
		t.set_stylebox("disabled", type, box(p.surface, p.border))
		t.set_stylebox("focus", type, focus_box(p.focus))
		t.set_constant("outline_size", type, 0)
		t.set_constant("h_separation", type, 12)
	variation(t, "PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var fill := p.primary
		if state == "hover":
			fill = fill.lerp(p.text_primary, 0.12)
		elif state != "normal":
			fill = fill.lerp(p.background, 0.12)
		t.set_stylebox(state, "PrimaryButton", box(fill, fill))
		var text_state: String = "font_color" if state == "normal" else "font_" + state + "_color"
		t.set_color(text_state, "PrimaryButton", Palette.ink_on(fill))
	t.set_color("font_focus_color", "PrimaryButton", Palette.ink_on(p.primary))
	variation(t, "BackButton", "Button")
	t.set_stylebox("normal", "BackButton", box(p.surface, p.border))
	for name in ["Title", "Eyebrow", "MutedLabel", "ControlsText", "BindingText", "SuccessLabel", "WarningLabel", "DangerLabel"]:
		variation(t, name, "Label")
	t.set_font("font", "Title", get_title_font())
	t.set_font_size("font_size", "Title", 24)
	t.set_color("font_color", "Eyebrow", p.accent)
	t.set_font_size("font_size", "Eyebrow", 14)
	t.set_color("font_color", "MutedLabel", p.text_secondary)
	t.set_color("font_color", "BindingText", p.text_secondary)
	t.set_font_size("font_size", "BindingText", 16)
	for pair in [["SuccessLabel", p.success], ["WarningLabel", p.warning], ["DangerLabel", p.danger]]:
		t.set_color("font_color", pair[0], pair[1])
	# Native popup menus must share the palette as well as their closed selectors.
	t.set_stylebox("panel", "PopupMenu", box(p.surface, p.border, 1, 8, 8))
	t.set_stylebox("hover", "PopupMenu", box(p.surface_alt, p.primary, 1, 8, 6))
	t.set_stylebox("separator", "PopupMenu", box(p.border, p.border, 0, 0, 1, 0))
	t.set_color("font_accelerator_color", "PopupMenu", p.text_secondary)
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_icon("arrow", "OptionButton", icon('<path d="m5 8 5 5 5-5"/>', p.text_primary))
	t.set_constant("arrow_margin", "OptionButton", 16)
	# Checkbox and slider icons are generated from the same semantic colors.
	for state in ["unchecked", "checked", "unchecked_disabled", "checked_disabled"]:
		var ink := p.text_disabled if state.ends_with("disabled") else p.primary
		var shape := '<rect x="2" y="2" width="16" height="16" rx="2"/>'
		if state.begins_with("checked"):
			shape += '<path d="m6 10 3 3 5-6"/>'
		t.set_icon(state, "CheckBox", icon(shape, ink))
		var radio := '<circle cx="10" cy="10" r="7"/>'
		if state.begins_with("checked"):
			radio += '<circle cx="10" cy="10" r="3" fill="#%s"/>' % ink.to_html(false)
		t.set_icon("radio_" + state, "PopupMenu", icon(radio, ink))
	t.set_stylebox("slider", "HSlider", box(p.surface_alt, p.border, 1, 0, 4, 3))
	t.set_stylebox("grabber_area", "HSlider", box(p.primary, p.primary, 0, 0, 4, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(p.focus, p.focus, 0, 0, 4, 3))
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		var fill := p.primary if state == "grabber" else p.focus
		if state == "grabber_disabled":
			fill = p.text_disabled
		t.set_icon(state, "HSlider", icon('<rect x="3" y="2" width="14" height="16" rx="3" fill="#%s"/>' % fill.to_html(false), p.background))
	# Used in the developer gallery, available for game forms.
	t.set_stylebox("normal", "LineEdit", box(p.background, p.border))
	t.set_stylebox("read_only", "LineEdit", box(p.surface, p.border))
	t.set_stylebox("focus", "LineEdit", focus_box(p.focus))
	t.set_color("font_placeholder_color", "LineEdit", p.text_secondary)
	t.set_color("font_uneditable_color", "LineEdit", p.text_disabled)
	t.set_color("caret_color", "LineEdit", p.focus)
	t.set_color("selection_color", "LineEdit", p.primary)
	t.set_color("font_selected_color", "LineEdit", Palette.ink_on(p.primary))
	return t

func variation(theme: Theme, name: StringName, base: StringName) -> void:
	theme.set_type_variation(name, base)

func box(fill: Color, border: Color, width := 1, horizontal := 18, vertical := 12, radius := -1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(corner_radius if radius < 0 else radius)
	result.content_margin_left = horizontal
	result.content_margin_right = horizontal
	result.content_margin_top = vertical
	result.content_margin_bottom = vertical
	return result

func focus_box(color: Color) -> StyleBoxFlat:
	var result := box(color, color, 2, 0, 0)
	result.draw_center = false
	result.set_expand_margin_all(4)
	return result

func icon(shape: String, stroke: Color) -> Texture2D:
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20"><g fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [stroke.to_html(false), shape])
	return ImageTexture.create_from_image(image)
