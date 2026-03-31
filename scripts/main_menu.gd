extends Node2D

@onready var menu_panel = $menu/MainPanel
@onready var settings_panel = $menu/SettingsPanel
@onready var start_button = $menu/MainPanel/MarginContainer/VBoxContainer/start
@onready var back_button = $menu/SettingsPanel/VBoxContainer/BackButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	settings_panel.visible = false
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
