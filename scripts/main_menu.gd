extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


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
