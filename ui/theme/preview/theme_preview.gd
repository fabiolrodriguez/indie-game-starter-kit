extends Panel
## Development-only gallery. Selection is local and never saved to configuration.

const Palette = preload("res://ui/theme/ui_palette.gd")
var configuration = preload("res://ui/theme/theme_config.tres")
const BUILT_INS := ["midnight", "forest", "ocean", "crimson", "amber", "monochrome"]
const FocusSlider = preload("res://ui/theme/focus_slider.gd")

@export var custom_palette: Palette
var palettes: Array[Palette] = []
var selector: OptionButton
var swatches: GridContainer
var palette_title: Label

func _ready() -> void:
	theme_type_variation = &"Backdrop"
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := label("THEME LAB", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	selector = OptionButton.new()
	selector.custom_minimum_size.x = 240
	header.add_child(selector)
	column.add_child(label("Developer preview · selection here does not change your game", "MutedLabel"))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var controls := panel_column(body)
	controls.add_child(label("INTERACTION", "Eyebrow"))
	for entry in [["Primary action", "PrimaryButton"], ["Secondary action", "Button"], ["Unavailable action", "Button"]]:
		var button := Button.new()
		button.text = entry[0]
		button.theme_type_variation = entry[1]
		button.disabled = entry[0] == "Unavailable action"
		controls.add_child(button)
	var checkbox := CheckBox.new()
	checkbox.text = "Enable option"
	checkbox.button_pressed = true
	controls.add_child(checkbox)
	var slider := HSlider.new()
	slider.set_script(FocusSlider)
	slider.custom_minimum_size.y = 32
	slider.value = 65
	controls.add_child(slider)
	var option := OptionButton.new()
	for text in ["Windowed", "Fullscreen", "Borderless"]:
		option.add_item(text)
	controls.add_child(option)
	var input := LineEdit.new()
	input.placeholder_text = "Sample text"
	controls.add_child(input)
	var color_column := panel_column(body)
	color_column.size_flags_stretch_ratio = 1.4
	palette_title = label("", "Title")
	color_column.add_child(palette_title)
	color_column.add_child(label("SEMANTIC COLORS", "Eyebrow"))
	swatches = GridContainer.new()
	swatches.columns = 5
	color_column.add_child(swatches)
	color_column.add_child(label("Ready to continue", "SuccessLabel"))
	color_column.add_child(label("Unsaved changes", "WarningLabel"))
	color_column.add_child(label("Unable to complete action", "DangerLabel"))
	color_column.add_child(label("Use Tab / D-pad to inspect focus.\nHover, press and open the selector to inspect states.", "MutedLabel"))
	for name in BUILT_INS:
		palettes.append(load("res://ui/theme/palettes/%s.tres" % name))
	if custom_palette:
		palettes.append(custom_palette)
	var selected := 0
	for index in palettes.size():
		selector.add_item(palettes[index].display_name)
		if palettes[index] == configuration.palette:
			selected = index
	selector.item_selected.connect(select_palette)
	select_palette(selected)
	selector.grab_focus()

func select_palette(index: int) -> void:
	if index < 0 or index >= palettes.size():
		return
	selector.select(index)
	var palette := palettes[index]
	theme = configuration.visual_style.build(palette)
	palette_title.text = palette.display_name
	for child in swatches.get_children():
		swatches.remove_child(child)
		child.queue_free()
	for role in Palette.ROLES:
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatches.add_child(stack)
		var color := ColorRect.new()
		color.custom_minimum_size = Vector2(84, 30)
		# Swatches visualize palette data rather than styling an individual control.
		color.color = palette.get(role)
		color.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := PanelContainer.new()
		frame.theme_type_variation = &"SwatchFrame"
		stack.add_child(frame)
		frame.add_child(color)
		var caption := label(role.replace("text_", "txt_"), "BindingText")
		stack.add_child(caption)

func label(text: String, variation: String) -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = variation
	return result

func panel_column(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	return column
