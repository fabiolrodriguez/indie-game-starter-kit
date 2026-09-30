extends Node
## Requests are deferred; hooks notify UI without depending on a transition effect.

signal transition_started(scene_path: String)
signal transition_finished(scene: Node)
signal transition_failed(scene_path: String, error: Error)

var is_transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func change_scene(scene_path: String) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		transition_failed.emit(scene_path, ERR_FILE_NOT_FOUND)
		return ERR_FILE_NOT_FOUND
	var scene := load(scene_path) as PackedScene
	if scene == null or not scene.can_instantiate():
		transition_failed.emit(scene_path, ERR_INVALID_DATA)
		return ERR_INVALID_DATA
	is_transitioning = true
	transition_started.emit(scene_path)
	_change_scene.call_deferred(scene, scene_path)
	return OK

func _change_scene(scene: PackedScene, scene_path: String) -> void:
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		is_transitioning = false
		transition_failed.emit(scene_path, error)
		return
	PauseManager.set_paused(false)
	await get_tree().scene_changed
	is_transitioning = false
	transition_finished.emit(get_tree().current_scene)
