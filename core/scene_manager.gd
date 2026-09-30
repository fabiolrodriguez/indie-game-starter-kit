extends Node
## Owns validated scene replacement; the persistent overlay owns presentation.

const FadeOverlay = preload("res://ui/transitions/fade_overlay.tscn")
var default_options: SceneTransitionOptions = preload("res://ui/transitions/fade_options.tres")
var _overlay: CanvasLayer

signal transition_started(scene_path: String)
signal transition_finished(scene: Node)
signal transition_failed(scene_path: String, error: Error)

var is_transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = FadeOverlay.instantiate()
	add_child(_overlay)

func change_scene(scene_path: String, options: SceneTransitionOptions = null) -> Error:
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
	_overlay.begin(options if options != null else default_options)
	transition_started.emit(scene_path)
	_change_scene.call_deferred(scene, scene_path)
	return OK

func _change_scene(scene: PackedScene, scene_path: String) -> void:
	if not await _overlay.fade_out():
		return
	var error := _replace_scene(scene)
	if error != OK:
		if not await _overlay.fade_in():
			return
		_overlay.finish()
		is_transitioning = false
		transition_failed.emit(scene_path, error)
		return
	PauseManager.set_paused(false)
	await get_tree().scene_changed
	if not await _overlay.fade_in():
		return
	_overlay.finish()
	is_transitioning = false
	transition_finished.emit(get_tree().current_scene)

func _replace_scene(scene: PackedScene) -> Error:
	return get_tree().change_scene_to_packed(scene)

func _exit_tree() -> void:
	is_transitioning = false
