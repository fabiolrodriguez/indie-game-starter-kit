extends Node2D

@onready var menu_panel = $menu/MainPanel
@onready var settings_panel = $menu/SettingsPanel
@onready var start_button = $menu/MainPanel/MarginContainer/VBoxContainer/start
@onready var back_button = $menu/SettingsPanel/MarginContainer/VBoxContainer/BackButton

@onready var resolution_selector = $menu/SettingsPanel/MarginContainer/VBoxContainer/OptionButton

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		SettingsManager.fscr(false)
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_option_button_item_selected(index) -> void:
	var res = resolutions[index]
	SettingsManager.apply_resolution(res)
	#DisplayServer.window_set_size(res)
