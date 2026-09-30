extends CanvasLayer

signal quit_requested

@export var handle_pause_input := true
@onready var resume_button = $PausePanel/MarginContainer/VBoxContainer/resume
@onready var quit_button = $PausePanel/MarginContainer/VBoxContainer/quit
var _previous_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseManager.pause_changed.connect(_on_pause_changed)
	LocalizationManager.language_changed.connect(update_texts)
	update_texts()
	visible = false
	_on_pause_changed(PauseManager.is_paused())

func update_texts() -> void:
	resume_button.text = LocalizationManager.tr_key("menu_resume")
	quit_button.text = LocalizationManager.tr_key("menu_quit")

func pause() -> void:
	PauseManager.set_paused(true)

func resume() -> void:
	AudioManager.play_click()
	PauseManager.set_paused(false)

func _on_pause_changed(paused: bool) -> void:
	if paused:
		_previous_focus = get_viewport().gui_get_focus_owner()
		visible = true
		resume_button.grab_focus()
	else:
		visible = false
		if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
			_previous_focus.grab_focus()
		_previous_focus = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if (handle_pause_input and event.is_action_pressed("pause")) or (visible and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		PauseManager.toggle()

func _on_resume_pressed() -> void:
	resume()

func _on_resume_focus_entered() -> void:
	AudioManager.play_hover()

func _on_quit_pressed() -> void:
	AudioManager.play_click()
	quit_requested.emit()

func _on_quit_focus_entered() -> void:
	AudioManager.play_hover()
