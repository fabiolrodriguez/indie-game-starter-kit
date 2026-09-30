extends Node

const SHOWCASE := "res://ui/showcase/developer_showcase.tscn"
const MENU := "res://scenes/main_menu/main_menu.tscn"
var configuration = preload("res://ui/theme/theme_config.tres")
var checks := 0
var failures := 0
var capture_dir: String

func _ready() -> void:
	if not ProjectSettings.get_setting("starter_kit/testing", false):
		push_error("Use tests/run_tests.py to isolate settings and saves")
		get_tree().quit(1)
		return
	capture_dir = ProjectSettings.get_setting("starter_kit/capture_dir", "")
	get_tree().create_timer(45.0).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func send(event: InputEvent) -> void:
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	await send(event)

func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await send(event)

func settle() -> void:
	for frame in range(5):
		await get_tree().process_frame

func capture(name: String) -> void:
	await settle()
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Showcase screenshot failed")

func _run() -> void:
	get_tree().current_scene = null
	# Preserve and compare all persistent/transient data while exploring the scene.
	var settings_file := FileAccess.get_file_as_string(SettingsManager.SETTINGS_PATH)
	SaveManager.set_value("existing", "token", 42)
	check(SaveManager.save_game() == OK, "Save fixture failed")
	var save_file := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	GameSession.start({"existing": 7})
	var session := GameSession.snapshot()
	var original_language: String = LocalizationManager.current_language
	var original_palette = configuration.palette
	var original_music: AudioStream = AudioManager.bgm_player.stream
	check(SceneManager.change_scene(SHOWCASE) == OK, "Showcase scene request failed")
	await SceneManager.transition_finished
	await settle()
	var showcase = get_tree().current_scene
	check(showcase.gallery.selector.has_focus(), "Showcase initial focus missing")
	check(showcase.gallery.palettes[showcase.gallery.selector.selected] == original_palette, "Preview does not select configured palette")
	check(showcase.get_theme_color("background", "Palette") == original_palette.background, "Showcase bypasses shared Theme")
	check(showcase.status_labels.size() == 8 and "Ready" in showcase.status_labels.SceneManager.text, "Foundation overview is missing/stale")
	check("Active" in showcase.status_labels.GameSession.text and "present" in showcase.status_labels.SaveManager.text, "Overview ignores real session/save state")
	await capture("showcase_components")
	# Navigation row uses the same native keyboard/controller controls as menus.
	showcase.navigation[0].grab_focus()
	await key(KEY_RIGHT)
	check(showcase.navigation[1].has_focus(), "Keyboard cannot reach Foundation")
	await key(KEY_ENTER)
	check(showcase.pages[1].visible and not showcase.pages[0].visible, "Keyboard did not open Foundation")
	await key(KEY_DOWN)
	check(showcase.language_selector.has_focus(), "Navigation cannot enter Foundation controls")
	showcase.navigation[1].grab_focus()
	await joy(JOY_BUTTON_DPAD_RIGHT)
	check(showcase.navigation[2].has_focus(), "Controller cannot reach Controls")
	await joy(JOY_BUTTON_A)
	check(showcase.pages[2].visible, "Controller did not open Controls")
	check(showcase.bindings.get_child_count() == ControlsManager.get_controls_data().size() * 2, "Controls descriptions not reused")
	await capture("showcase_controls")
	showcase.show_page(1)
	var other_language := "pt_BR" if original_language == "en_US" else "en_US"
	showcase.language_selector.item_selected.emit(showcase.language_codes.find(other_language))
	check(LocalizationManager.current_language == other_language and LocalizationManager.tr_key("menu_start") in showcase.localized_sample.text, "Live localization preview failed")
	check(SettingsManager.language != other_language, "Preview changed persistent language")
	check(showcase.bindings.get_child(0).text == LocalizationManager.tr_key(ControlsManager.get_controls_data()[0].label_key), "Controls localization stale")
	showcase.action_buttons[0].pressed.emit()
	check(AudioManager.player.stream == AudioManager.click_sound, "Audio preview bypasses AudioManager")
	showcase.music_button.pressed.emit()
	check(AudioManager.bgm_player.playing and AudioManager.bgm_player.stream == AudioManager.bg_music, "Music preview did not use real playback")
	await capture("showcase_foundation")
	showcase.action_buttons[2].grab_focus()
	await joy(JOY_BUTTON_A)
	check(PauseManager.is_paused() and showcase.pause_menu.visible and showcase.pause_menu.resume_button.has_focus(), "Shared pause presenter missing")
	await capture("showcase_pause")
	await joy(JOY_BUTTON_B)
	check(not PauseManager.is_paused() and showcase.action_buttons[2].has_focus(), "Pause did not restore developer focus")
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 600)]:
		get_tree().root.content_scale_size = size
		get_tree().root.size = size
		await settle()
		for page_index in range(3):
			showcase.show_page(page_index)
			await settle()
			check(get_viewport().get_visible_rect().encloses(showcase.pages[page_index].get_global_rect()), "Showcase page exceeds viewport at %s" % size)
			if page_index != 0:
				check(showcase.pages[page_index].get_h_scroll_bar().max_value <= showcase.pages[page_index].size.x, "Page has clipped horizontal content")
			else:
				check(showcase.gallery.body.columns == (1 if size.x < 1120 else 2), "Gallery did not adapt to logical viewport width")
			await capture("showcase_%dx%d_page%d" % [size.x, size.y, page_index])
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	get_tree().root.size = Vector2i(1280, 720)
	await settle()
	showcase.show_page(0)
	showcase.gallery.select_palette(4)
	check(configuration.palette == original_palette and showcase.get_theme_color("background", "Palette") == original_palette.background, "Preview palette escaped into global configuration")
	# Tab can reach every enabled gallery control without custom event handling.
	showcase.gallery.selector.grab_focus()
	var visited: Array = []
	for step in range(20):
		await key(KEY_TAB)
		var focus := get_viewport().gui_get_focus_owner()
		check(is_instance_valid(focus) and focus.is_visible_in_tree(), "Tab lost focus to a hidden control")
		if not visited.has(focus):
			visited.append(focus)
	check(visited.size() >= 8, "Gallery has a focus trap")
	# Mouse activates the real Foundation nav button.
	var position: Vector2 = showcase.navigation[1].get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	var mouse := InputEventMouseButton.new()
	mouse.position = position
	mouse.button_index = MOUSE_BUTTON_LEFT
	await send(mouse)
	check(showcase.pages[1].visible, "Mouse navigation failed")
	showcase.action_buttons[3].pressed.emit()
	check(SceneManager.is_transitioning and get_viewport().is_input_disabled(), "Replay action bypasses SceneManager fade")
	await SceneManager.transition_finished
	showcase = get_tree().current_scene
	await settle()
	check(showcase.gallery.selector.has_focus() and not get_viewport().is_input_disabled(), "Replay did not restore focus/input")
	check(LocalizationManager.current_language == original_language and AudioManager.bgm_player.stream == original_music and not AudioManager.bgm_player.playing, "Temporary language/music leaked across replay")
	check(FileAccess.get_file_as_string(SettingsManager.SETTINGS_PATH) == settings_file and FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == save_file, "Showcase wrote settings or save data")
	check(GameSession.snapshot() == session, "Showcase mutated session state")
	# A configured custom palette must appear without additional Inspector wiring.
	var custom = original_palette.duplicate()
	custom.display_name = "Configured custom"
	configuration.palette = custom
	check(SceneManager.change_scene(SHOWCASE) == OK, "Custom-palette showcase reload failed")
	await SceneManager.transition_finished
	showcase = get_tree().current_scene
	check(showcase.gallery.palettes[showcase.gallery.selector.selected] == custom, "Active custom palette was omitted by gallery")
	configuration.palette = original_palette
	showcase.action_buttons[4].pressed.emit()
	await SceneManager.transition_finished
	check(get_tree().current_scene.scene_file_path == MENU and get_tree().current_scene.start_button.has_focus(), "Main Menu action failed")
	check(GameSession.snapshot() == session, "Showcase exit reset session")
	GameSession.finish()
	AudioManager.player.stop()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.2).timeout
	print("Showcase: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
