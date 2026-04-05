extends Node2D

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

var language_codes = ["pt_BR", "en_US"]

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3480, 2160)	
]

func setup_resolution_selector():
	resolution_selector.clear()

	for res in resolutions:
		resolution_selector.add_item("%dx%d" % [res.x, res.y])

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	settings_panel.visible = false
	setup_resolution_selector()
	start_button.grab_focus()
	SettingsManager.load_settings()
	setup_language_selector()
	sync_language_selector()
	update_texts()
	sync_settings_ui()
	LocalizationManager.language_changed.connect(update_texts)
	
	if SaveManager.has_save():
		print("Existe save")
	else:
		print("Não existe save")
		
	test_save()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_language_display_name(code: String) -> String:
	match code:
		"pt_BR":
			return "Português (BR)"
		"en_US":
			return "English"
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
	back_button.text = LocalizationManager.tr_key("menu_back")
	quit_button.text = LocalizationManager.tr_key("menu_quit")
	settings_button.text = LocalizationManager.tr_key("menu_settings")
	# adicione outros botões aqui

func sync_settings_ui():
	fullscreen_checkbox.button_pressed = SettingsManager.fullscreen
	volume_slider.value = SettingsManager.volume
	resolution_selector.select(SettingsManager.resolution_index)
	sync_language_selector()

# Button Sounds and Actions

func _on_start_pressed() -> void:
	AudioManager.play_click()
func _on_start_mouse_entered() -> void:
	AudioManager.play_hover()
func _on_start_focus_entered() -> void:
	AudioManager.play_hover()

func _on_load_pressed() -> void:
	AudioManager.play_click()
func _on_load_mouse_entered() -> void:
	AudioManager.play_hover()
func _on_load_focus_entered() -> void:
	AudioManager.play_hover()

func _on_settings_pressed() -> void:
	AudioManager.play_click()
	menu_panel.visible = false
	settings_panel.visible = true
	back_button.grab_focus()
func _on_settings_focus_entered() -> void:
	AudioManager.play_hover()
func _on_settings_mouse_entered() -> void:
	AudioManager.play_hover()

func _on_controls_pressed() -> void:
	AudioManager.play_click()
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
	settings_panel.visible=false
	menu_panel.visible=true
func _on_back_button_focus_entered() -> void:
	AudioManager.play_hover()
func _on_back_button_mouse_entered() -> void:
	AudioManager.play_hover()

func _on_volume_slider_changed(value) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_fullscreen_checkbox_toggled(toggled_on: bool) -> void:
	if toggled_on:
		SettingsManager.fscr(true)
	else:
		SettingsManager.fscr(false)

func _on_option_button_item_selected(index) -> void:
	var res = resolutions[index]
	SettingsManager.set_resolution_from_value(res)

func _on_language_selector_item_selected(index: int) -> void:
	if index < 0 or index >= language_codes.size():
		return
	SettingsManager.language = language_codes[index]
	SettingsManager.save()
	SettingsManager.apply_language()
	

func test_save():
	SaveManager.set_value("profile", "player_name", "Fabio")
	SaveManager.set_value("profile", "language", SettingsManager.language)
	SaveManager.set_value("profile", "last_opened_menu", "main")
	SaveManager.save_game()
