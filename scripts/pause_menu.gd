extends CanvasLayer

@onready var resume_button = $PausePanel/MarginContainer/VBoxContainer/resume
@onready var quit_button = $PausePanel/MarginContainer/VBoxContainer/quit

func _ready():
	visible = false

func pause():
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()

func resume():
	AudioManager.play_click()
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_resume_pressed() -> void:
	resume()

func _on_resume_focus_entered() -> void:
	AudioManager.play_hover()

func _on_quit_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_quit_focus_entered() -> void:
	AudioManager.play_hover()

	
