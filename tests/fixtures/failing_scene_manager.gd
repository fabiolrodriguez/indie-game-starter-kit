extends "res://core/scene_manager.gd"
## Exercise the engine-error branch after successful validation and fade-out.
func _replace_scene(_scene: PackedScene) -> Error:
	return ERR_CANT_CREATE
