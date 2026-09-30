extends Node

const MENU := "res://scenes/main_menu/main_menu.tscn"
const GALLERY := "res://ui/theme/preview/theme_preview.tscn"
const PROBE := "res://tests/fixtures/transition_probe.tscn"
const FailingManager = preload("res://tests/fixtures/failing_scene_manager.gd")
var configuration = preload("res://ui/theme/theme_config.tres")
var failures := 0
var checks := 0
var received_inputs := 0
var capture_dir: String

func _ready() -> void:
	if not ProjectSettings.get_setting("starter_kit/testing", false):
		push_error("Use tests/run_tests.py to isolate settings and saves")
		get_tree().quit(1)
		return
	capture_dir = ProjectSettings.get_setting("starter_kit/capture_dir", "")
	get_tree().create_timer(30.0).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()

func _input(_event: InputEvent) -> void:
	received_inputs += 1

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Transition capture failed")

func input_attempts() -> void:
	for event in [InputEventKey.new(), InputEventJoypadButton.new()]:
		if event is InputEventKey:
			event.keycode = KEY_ESCAPE
			event.physical_keycode = KEY_ESCAPE
		else:
			event.button_index = JOY_BUTTON_START
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		await get_tree().process_frame

func assert_released() -> void:
	var cover = SceneManager.get_node("SceneTransition/Cover")
	check(not SceneManager.is_transitioning, "Busy state persisted")
	check(not cover.visible and is_zero_approx(cover.modulate.a), "Overlay stayed opaque/visible")
	check(not get_viewport().is_input_disabled(), "Viewport input stayed disabled")

func _run() -> void:
	get_tree().current_scene = null
	var skip := SceneTransitionOptions.new()
	skip.skip_visual = true
	check(SceneManager.change_scene(MENU, skip) == OK, "Initial menu failed")
	check(not SceneManager.get_node("SceneTransition/Cover").visible, "Skipped effect became visible")
	await SceneManager.transition_finished
	assert_released()
	var menu = get_tree().current_scene
	var cover = SceneManager.get_node("SceneTransition/Cover")
	check(menu.start_button.has_focus(), "New menu focus lost")
	var failures_seen: Array = []
	SceneManager.transition_failed.connect(func(path, error): failures_seen.append([path, error]))
	PauseManager.set_paused(true)
	check(SceneManager.change_scene("res://missing.tscn") == ERR_FILE_NOT_FOUND, "Missing scene accepted")
	check(SceneManager.change_scene("res://ui/transitions/fade_options.tres") != OK, "Non-scene resource accepted")
	check(failures_seen.size() == 2 and get_tree().current_scene == menu and PauseManager.is_paused(), "Invalid request altered scene/pause or omitted failure")
	assert_released()
	PauseManager.set_paused(false)
	await capture("transition_menu")
	var options := SceneTransitionOptions.new()
	options.fade_duration = 0.3
	check(SceneManager.change_scene(PROBE, options) == OK, "Normal request failed")
	check(get_viewport().is_input_disabled(), "Input not blocked immediately")
	check(cover.color.is_equal_approx(Color(configuration.palette.background, 1.0)), "Default fade ignores semantic palette")
	check(SceneManager.change_scene(MENU) == ERR_BUSY, "Duplicate request accepted")
	# Timers can expire before the first tween step on a slow render frame.
	for frame in range(60):
		await get_tree().process_frame
		if cover.modulate.a > 0.0:
			break
	check(get_tree().current_scene == menu and cover.modulate.a > 0.0 and cover.modulate.a < 1.0, "Scene replaced before fade-out / no interpolation")
	var inputs_before := received_inputs
	await input_attempts()
	check(received_inputs == inputs_before and not PauseManager.is_paused(), "Keyboard/controller input escaped the fade")
	await capture("transition_fade_out")
	await get_tree().scene_changed
	var probe = get_tree().current_scene
	check(probe.covered_on_ready and probe.blocked_on_ready, "New scene exposed before ready")
	check(SceneManager.change_scene(MENU) == ERR_BUSY, "Request accepted during fade-in")
	await get_tree().create_timer(0.10).timeout
	check(cover.modulate.a > 0.0 and cover.modulate.a < 1.0, "Fade-in did not interpolate")
	await SceneManager.transition_finished
	assert_released()
	check(probe.get_node("Button").has_focus(), "New scene focus stolen after reveal")

	# Real existing scenes in both directions, with screenshots of both fade phases.
	check(SceneManager.change_scene(MENU, skip) == OK, "Return menu failed")
	await SceneManager.transition_finished
	check(SceneManager.change_scene(GALLERY, options) == OK, "Gallery request failed")
	await get_tree().scene_changed
	await capture("transition_covered")
	await get_tree().create_timer(0.10).timeout
	await capture("transition_fade_in")
	await SceneManager.transition_finished
	assert_released()
	await capture("transition_gallery")
	PauseManager.set_paused(true)
	Engine.time_scale = 0.01
	check(SceneManager.change_scene(MENU) == OK, "Paused transition rejected")
	await SceneManager.transition_finished
	Engine.time_scale = 1.0
	check(not PauseManager.is_paused(), "Replacement did not unpause")
	assert_released()
	await capture("transition_return")
	menu = get_tree().current_scene
	check(menu.start_button.has_focus(), "Return menu navigation focus lost")

	menu.settings_button.pressed.emit()
	menu.resolution_selector.grab_focus()
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	await get_tree().process_frame
	accept = accept.duplicate()
	accept.pressed = false
	Input.parse_input_event(accept)
	await get_tree().process_frame
	var popup: PopupMenu = menu.resolution_selector.get_popup()
	check(popup.visible, "Popup transition fixture did not open")
	var popup_failure = FailingManager.new()
	add_child(popup_failure)
	check(popup_failure.change_scene(PROBE, options) == OK, "Popup transition rejected")
	await input_attempts()
	check(popup.visible and not PauseManager.is_paused(), "Popup input escaped transition blocking")
	await popup_failure.transition_failed
	popup.hide()
	popup_failure.queue_free()
	PauseManager.set_paused(false)
	menu._on_back_button_pressed()

	var original_palette = configuration.palette
	configuration.palette = load("res://ui/theme/palettes/amber.tres")
	check(SceneManager.change_scene(PROBE, skip) == OK, "Changed-palette request failed")
	check(cover.color.is_equal_approx(Color(configuration.palette.background, 1.0)), "Fade color does not follow palette changes")
	await SceneManager.transition_finished
	configuration.palette = original_palette
	options.use_palette_background = false
	options.color = Color(0.1, 0.2, 0.3, 0.2)
	options.fade_duration = 0.0
	get_viewport().set_disable_input(true)
	check(SceneManager.change_scene(MENU, options) == OK, "Zero-duration request failed")
	check(cover.color == Color(0.1, 0.2, 0.3, 1.0), "Explicit fade color not opaque")
	await SceneManager.transition_finished
	check(get_viewport().is_input_disabled(), "Pre-existing input lock lost")
	get_viewport().set_disable_input(false)
	assert_released()
	for invalid_duration in [NAN, INF, -INF]:
		options.fade_duration = invalid_duration
		check(SceneManager.change_scene(PROBE, options) == OK, "Invalid-duration recovery rejected request")
		await SceneManager.transition_finished
		assert_released()
	check(SceneManager.change_scene(MENU, skip) == OK, "Return from duration validation failed")
	await SceneManager.transition_finished
	for size in [Vector2i(640, 360), Vector2i(1920, 1080)]:
		get_tree().root.size = size
		await get_tree().process_frame
		check(cover.get_global_rect().is_equal_approx(get_viewport().get_visible_rect()), "Overlay does not cover viewport")
	get_tree().root.size = Vector2i(1280, 720)

	# Late replacement errors must reveal the original paused scene and restore focus.
	var failing = FailingManager.new()
	add_child(failing)
	var late_errors: Array = []
	failing.transition_failed.connect(func(path, error): late_errors.append([path, error]))
	menu = get_tree().current_scene
	PauseManager.set_paused(true)
	var previous_focus := get_viewport().gui_get_focus_owner()
	options.fade_duration = 0.06
	check(failing.change_scene(PROBE, options) == OK, "Failure fixture not accepted")
	await failing.transition_failed
	check(late_errors == [[PROBE, ERR_CANT_CREATE]], "Late error not reported")
	check(not failing.is_transitioning and not failing.get_node("SceneTransition/Cover").visible and not get_viewport().is_input_disabled(), "Late failure did not reveal/unblock")
	check(get_tree().current_scene == menu and PauseManager.is_paused(), "Late failure altered scene/pause")
	check(get_viewport().gui_get_focus_owner() == previous_focus, "Late failure lost previous focus")
	check(failing.change_scene(PROBE, options) == OK, "Failure left manager busy")
	await get_tree().process_frame
	failing.queue_free()
	await get_tree().process_frame
	check(not get_viewport().is_input_disabled(), "Shutdown during fade left input blocked")
	PauseManager.set_paused(false)
	AudioManager.player.stop()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.2).timeout
	print("Transitions: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
