extends Node2D

@onready var pause_panel = $PauseMenu

func _ready():
	pause_panel.visible = false
	
func resume():
	get_tree().paused = false
	pause_panel.visible = false
	
func pause():
	get_tree().paused = true
	pause_panel.visible = true

func _on_resume_pressed() -> void:
	resume()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
