extends Node2D

# Games connect these requests; the reusable menu owns no gameplay or save policy.
signal start_requested
signal load_requested

@onready var menu_panel = $menu/MainPanel
@onready var settings_panel = $menu/SettingsPanel
@onready var start_button = $menu/MainPanel/MarginContainer/VBoxContainer/start
@onready var back_button = $menu/SettingsPanel/MarginContainer/VBoxContainer/BackButton

@onready var resolution_selector = $menu/SettingsPanel/MarginContainer/VBoxContainer/OptionButton
@onready var language_selector = $menu/SettingsPanel/MarginContainer/VBoxContainer/LanguageSelector
@onready var fullscreen_checkbox = $menu/SettingsPanel/MarginContainer/VBoxContainer/FullscreenCheckbox
@onready var volume_slider = $menu/SettingsPanel/MarginContainer/VBoxContainer/VolumeSlider
@onready var quit_button = $menu/MainPanel/MarginContainer/VBoxContainer/quit
@onready var settings_button = $menu/MainPanel/MarginContainer/VBoxContainer/settings
@onready var load_button = $menu/MainPanel/MarginContainer/VBoxContainer/load
@onready var controls_button = $menu/MainPanel/MarginContainer/VBoxContainer/controls
@onready var settings_label = $menu/SettingsPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var resolution_label = $menu/SettingsPanel/MarginContainer/VBoxContainer/ResolutionLabel
@onready var volume_label = $menu/SettingsPanel/MarginContainer/VBoxContainer/VolumeLabel
@onready var language_label = $menu/SettingsPanel/MarginContainer/VBoxContainer/LanguageLabel

@onready var pause_menu = $PauseMenu

@onready var controls_panel = $menu/ControlsPanel
@onready var controls_list = $menu/ControlsPanel/MarginContainer/VBoxContainer/ControlsListPanel/MarginContainer/ControlsList
@onready var controls_title = $menu/ControlsPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var controls_back_button = $menu/ControlsPanel/MarginContainer/VBoxContainer/BackButton

var language_codes: Array = []

func setup_resolution_selector():
	resolution_selector.clear()

	for res in SettingsManager.resolutions:
		resolution_selector.add_item("%dx%d" % [res.x, res.y])

func _ready() -> void:
	settings_panel.visible = false
	controls_panel.visible = false
	language_codes = LocalizationManager.translations.keys()
	setup_resolution_selector()
	setup_language_selector()
	sync_settings_ui()
	update_texts()
	LocalizationManager.language_changed.connect(update_texts)
	ControlsManager.controls_changed.connect(populate_controls_panel)
	pause_menu.quit_requested.connect(_on_pause_quit_requested)
	start_button.grab_focus()

func get_language_display_name(code: String) -> String:
	match code:
		"pt_BR":
			return "PORTUGUÊS (BR)"
		"en_US":
			return "ENGLISH"
		_:
			return code

func setup_language_selector():
	language_selector.clear()

	for code in language_codes:
		language_selector.add_item(get_language_display_name(code))

func sync_language_selector():
	var index = language_codes.find(SettingsManager.language)

	if index != -1:
		language_selector.select(index)
	else:
		language_selector.select(0)

func update_texts():
	start_button.text = LocalizationManager.tr_key("menu_start")
	load_button.text = LocalizationManager.tr_key("menu_load")
	back_button.text = LocalizationManager.tr_key("menu_back")
	quit_button.text = LocalizationManager.tr_key("menu_quit")
	settings_button.text = LocalizationManager.tr_key("menu_settings")
	controls_button.text = LocalizationManager.tr_key("menu_controls")
	resolution_label.text = LocalizationManager.tr_key("menu_resolution")
	language_label.text = LocalizationManager.tr_key("menu_language")
	settings_label.text = LocalizationManager.tr_key("menu_settings")
	fullscreen_checkbox.text = LocalizationManager.tr_key("menu_fullscreen")
	volume_label.text = LocalizationManager.tr_key("menu_volume")
	sync_language_selector()
	populate_controls_panel()

func sync_settings_ui():
	fullscreen_checkbox.set_pressed_no_signal(SettingsManager.fullscreen)
	volume_slider.set_value_no_signal(SettingsManager.volume)
	resolution_selector.select(SettingsManager.resolution_index)
	sync_language_selector()

# Button Sounds and Actions

func _on_start_pressed() -> void:
	AudioManager.play_click()
	start_requested.emit()
func _on_start_mouse_entered() -> void:
	AudioManager.play_hover()
func _on_start_focus_entered() -> void:
	AudioManager.play_hover()

func _on_load_pressed() -> void:
	AudioManager.play_click()
	load_requested.emit()
func _on_load_mouse_entered() -> void:
	AudioManager.play_hover()
func _on_load_focus_entered() -> void:
	AudioManager.play_hover()

func _on_settings_pressed() -> void:
	AudioManager.play_click()
	menu_panel.visible = false
	settings_panel.visible = true
	pause_menu.handle_pause_input = false
	sync_settings_ui()
	back_button.grab_focus()
func _on_settings_focus_entered() -> void:
	AudioManager.play_hover()
func _on_settings_mouse_entered() -> void:
	AudioManager.play_hover()

func _on_controls_pressed() -> void:
	AudioManager.play_click()
	open_controls_panel()
func _on_controls_focus_entered() -> void:
	AudioManager.play_hover()
func _on_controls_mouse_entered() -> void:
	AudioManager.play_hover()

func _on_quit_pressed() -> void:
	AudioManager.play_click()
	get_tree().quit()
func _on_quit_focus_entered() -> void:
	AudioManager.play_hover()
func _on_quit_mouse_entered() -> void:
	AudioManager.play_hover()

func _on_back_button_pressed() -> void:
	AudioManager.play_click()
	settings_panel.visible = false
	controls_panel.visible = false
	menu_panel.visible = true
	pause_menu.handle_pause_input = true
	start_button.grab_focus()
func _on_back_button_focus_entered() -> void:
	AudioManager.play_hover()
func _on_back_button_mouse_entered() -> void:
	AudioManager.play_hover()

func _on_fullscreen_checkbox_toggled(toggled_on: bool) -> void:
	SettingsManager.set_fullscreen(toggled_on)

func _on_option_button_item_selected(index: int) -> void:
	if index >= 0 and index < SettingsManager.resolutions.size():
		SettingsManager.set_resolution_from_value(SettingsManager.resolutions[index])

func _on_language_selector_item_selected(index: int) -> void:
	if index >= 0 and index < language_codes.size():
		SettingsManager.set_language(language_codes[index])

func _on_volume_slider_value_changed(value: float) -> void:
	SettingsManager.set_volume(value)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if settings_panel.visible or controls_panel.visible:
			get_viewport().set_input_as_handled()
			_on_back_button_pressed()

func _on_pause_quit_requested() -> void:
	pause_menu.resume()
	_on_back_button_pressed()

func populate_controls_panel():
	for child in controls_list.get_children():
		controls_list.remove_child(child)
		child.queue_free()

	var data = ControlsManager.get_controls_data()

	for item in data:
		var row = HBoxContainer.new()

		var action_label = Label.new()
		var key_label = Label.new()
		action_label.theme_type_variation = &"ControlsText"
		key_label.theme_type_variation = &"ControlsText"

		action_label.text = LocalizationManager.tr_key(item["label_key"])
		key_label.text = item["value"]

		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_label.custom_minimum_size.x = 420
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		row.add_child(action_label)
		row.add_child(key_label)

		controls_list.add_child(row)

	controls_title.text = LocalizationManager.tr_key("controls_title")
	controls_back_button.text = LocalizationManager.tr_key("controls_back")

func open_controls_panel():
	menu_panel.visible = false
	settings_panel.visible = false
	controls_panel.visible = true
	pause_menu.handle_pause_input = false
	populate_controls_panel()
	controls_back_button.grab_focus()
