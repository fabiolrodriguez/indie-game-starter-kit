extends Node
## The sole owner of SceneTree.paused. Input and presentation belong to UI.

signal pause_changed(paused: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_paused() -> bool:
	return get_tree().paused

func set_paused(paused: bool) -> void:
	if is_paused() == paused:
		return
	get_tree().paused = paused
	pause_changed.emit(paused)

func toggle() -> void:
	set_paused(not is_paused())
