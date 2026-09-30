extends CanvasLayer
## Presentation only: no scene paths, scene replacement, or pause ownership.

signal fade_completed

@onready var cover: ColorRect = $Cover
var _duration := 0.0
var _tween: Tween
var _blocking := false
var _input_was_disabled := false
var _previous_focus: WeakRef
var _exiting := false

func begin(options: SceneTransitionOptions) -> void:
	_duration = 0.0 if options.skip_visual else maxf(0.0, options.fade_duration)
	if not is_finite(_duration):
		_duration = 0.0
	var tint := options.color
	if options.use_palette_background:
		tint = cover.get_theme_color("background", "Palette")
	tint.a = 1.0
	cover.color = tint
	cover.modulate.a = 0.0
	cover.visible = not options.skip_visual
	var viewport := get_viewport()
	_input_was_disabled = viewport.is_input_disabled()
	var focus := viewport.gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	viewport.gui_release_focus()
	viewport.set_disable_input(true)
	_blocking = true

func fade_out() -> bool:
	return await _fade_to(1.0)

func fade_in() -> bool:
	return await _fade_to(0.0)

func _fade_to(opacity: float) -> bool:
	if _exiting:
		return false
	if _duration == 0.0:
		cover.modulate.a = opacity
		return true
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(cover, "modulate:a", opacity, _duration)
	_tween.finished.connect(func(): fade_completed.emit(), CONNECT_ONE_SHOT)
	await fade_completed
	_tween = null
	return not _exiting

func finish() -> void:
	cover.modulate.a = 0.0
	cover.hide()
	if not _blocking:
		return
	_blocking = false
	var viewport := get_viewport()
	viewport.set_disable_input(_input_was_disabled)
	# Preserve the new scene's own focus; restore old focus after a failed change.
	if not _input_was_disabled and viewport.gui_get_focus_owner() == null and _previous_focus != null:
		var previous = _previous_focus.get_ref()
		if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():
			previous.grab_focus()
	_previous_focus = null

func _exit_tree() -> void:
	_exiting = true
	if _blocking:
		finish()
	if _tween != null and _tween.is_valid():
		_tween.kill()
		fade_completed.emit()
