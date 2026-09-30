extends Control

var covered_on_ready := false
var blocked_on_ready := false

func _ready() -> void:
	covered_on_ready = is_equal_approx(SceneManager.get_node("SceneTransition/Cover").modulate.a, 1.0)
	blocked_on_ready = get_viewport().is_input_disabled()
	$Button.grab_focus()
