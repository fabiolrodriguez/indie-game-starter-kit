extends Node

var failures := 0
var checks := 0
const MENU := "res://scenes/main_menu/main_menu.tscn"
const EMPTY := "res://tests/fixtures/empty_scene.tscn"

func _ready() -> void:
	if not ProjectSettings.get_setting("starter_kit/testing", false):
		push_error("Use tests/run_tests.py to isolate save and settings files")
		get_tree().quit(1)
		return
	var storage: String = ProjectSettings.get_setting("starter_kit/user_data_path", "")
	if SettingsManager.SETTINGS_PATH != storage.path_join("settings.cfg") or SaveManager.SAVE_PATH != storage.path_join("savegame.cfg"):
		push_error("Test storage isolation failed")
		get_tree().quit(1)
		return
	get_tree().create_timer(30.0).timeout.connect(func():
		push_error("Foundation tests timed out")
		get_tree().quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func validate_connections(node: Node) -> void:
	for info in node.get_signal_list():
		for connection in node.get_signal_connection_list(info.name):
			check(connection.callable.is_valid(), "Invalid signal on " + str(node.get_path()))
	for child in node.get_children():
		validate_connections(child)

func check_panel_bounds(panel: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "Panel exceeds viewport: " + panel.name)

func _run() -> void:
	# Retain the runner across changes of the current scene.
	get_tree().current_scene = null
	check(not SaveManager.has_save(), "Tests must start without a save")
	check(not FileAccess.file_exists(SettingsManager.SETTINGS_PATH), "Tests must use fresh settings")
	for singleton in ["AudioManager", "LocalizationManager", "SettingsManager", "SaveManager", "ControlsManager", "SceneManager", "PauseManager", "GameSession"]:
		check(get_tree().root.has_node(singleton), "Missing autoload: " + singleton)
	check(SceneManager.change_scene(MENU) == OK, "Menu request failed")
	check(SceneManager.change_scene(EMPTY) == ERR_BUSY, "Concurrent transition was accepted")
	await SceneManager.transition_finished
	var menu = get_tree().current_scene
	await get_tree().process_frame
	check(not SaveManager.has_save(), "Opening menu wrote sample save")
	check(not FileAccess.file_exists(SettingsManager.SETTINGS_PATH), "UI sync wrote settings")
	check(not menu.has_node("SettingsManager"), "Menu duplicates an autoload")
	validate_connections(menu)
	check(menu.start_button.has_focus(), "Initial keyboard focus missing")
	await key(KEY_DOWN)
	check(menu.load_button.has_focus(), "Keyboard menu navigation failed")
	await key(KEY_W)
	check(menu.start_button.has_focus(), "WASD navigation failed")
	await key(KEY_DOWN)
	await joy(JOY_BUTTON_DPAD_DOWN)
	check(menu.settings_button.has_focus(), "Controller menu navigation failed")
	await joy(JOY_BUTTON_A)
	check(menu.settings_panel.visible and menu.back_button.has_focus(), "Controller did not open settings")
	menu.resolution_selector.grab_focus()
	await key(KEY_ENTER)
	check(menu.resolution_selector.get_popup().visible, "Resolution popup did not open")
	await key(KEY_ESCAPE)
	check(not menu.resolution_selector.get_popup().visible and menu.settings_panel.visible and not PauseManager.is_paused(), "Popup cancel escaped its panel")

	menu.volume_slider.value = 0.5
	menu.language_selector.item_selected.emit(menu.language_codes.find("pt_BR"))
	menu.resolution_selector.item_selected.emit(1)
	menu.fullscreen_checkbox.button_pressed = true
	check(is_equal_approx(SettingsManager.volume, 0.5), "Volume not updated")
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Volume not applied")
	check(menu.settings_button.text == "CONFIGURAÇÕES", "Live localization failed")
	check(menu.pause_menu.resume_button.text == "CONTINUAR", "Pause localization failed")
	await check_panel_bounds(menu.settings_panel)
	var persisted := FileAccess.get_file_as_string(SettingsManager.SETTINGS_PATH)
	SettingsManager.volume = 1.0
	SettingsManager.language = "en_US"
	SettingsManager.fullscreen = false
	SettingsManager.resolution_index = 0
	check(SettingsManager.load_settings() == OK, "Settings reload failed")
	check(SettingsManager.volume == 0.5 and SettingsManager.language == "pt_BR" and SettingsManager.fullscreen and SettingsManager.resolution_index == 1, "Settings round trip failed")
	menu.sync_settings_ui()
	check(FileAccess.get_file_as_string(SettingsManager.SETTINGS_PATH) == persisted, "Settings sync rewrote persistence")
	await key(KEY_ESCAPE)
	check(menu.menu_panel.visible and not PauseManager.is_paused(), "Escape should leave settings before pausing")
	await key(KEY_ESCAPE)
	check(PauseManager.is_paused() and menu.pause_menu.visible, "Keyboard pause failed")
	check(menu.pause_menu.resume_button.has_focus(), "Pause focus missing")
	await joy(JOY_BUTTON_A)
	check(not PauseManager.is_paused() and menu == get_tree().current_scene, "Resume replaced the scene")
	check(menu.start_button.has_focus(), "Resume did not restore focus")
	await joy(JOY_BUTTON_START)
	check(PauseManager.is_paused(), "Controller pause failed")
	await joy(JOY_BUTTON_B)
	check(not PauseManager.is_paused(), "Controller cancel did not resume")
	menu.controls_button.pressed.emit()
	check(menu.controls_panel.visible, "Controls panel did not open")
	await check_panel_bounds(menu.controls_panel)
	SettingsManager.set_language("en_US")
	await check_panel_bounds(menu.controls_panel)
	check(menu.controls_list.get_child(0).get_child(0).text == "Navigate up", "Controls localization is stale")
	var original_controls := ControlsManager.controls_data.duplicate(true)
	var extended_controls: Array = []
	for index in range(20):
		extended_controls.append({"label_key": "controls_confirm", "value": "Binding %d" % index})
	ControlsManager.set_controls_data(extended_controls)
	await check_panel_bounds(menu.controls_panel)
	var scrollbar: VScrollBar = menu.controls_list.get_parent().get_v_scroll_bar()
	check(scrollbar.visible, "Extended controls have no scrolling")
	menu.controls_back_button.grab_focus()
	await joy(JOY_BUTTON_DPAD_UP)
	check(scrollbar.has_focus(), "Controller cannot reach controls scroll bar")
	await joy(JOY_BUTTON_DPAD_DOWN)
	check(scrollbar.value > 0, "Controller cannot scroll extended controls")
	var first_scroll := scrollbar.value
	await joy(JOY_BUTTON_DPAD_DOWN)
	check(scrollbar.value > first_scroll and scrollbar.has_focus(), "Controller cannot keep scrolling")
	await joy(JOY_BUTTON_DPAD_LEFT)
	check(menu.controls_back_button.has_focus(), "Controller trapped on scroll bar")
	ControlsManager.set_controls_data(original_controls)
	await joy(JOY_BUTTON_B)
	check(menu.menu_panel.visible, "Controller cancel did not leave controls")
	var requests: Array = []
	menu.start_requested.connect(func(): requests.append("start"))
	menu.load_requested.connect(func(): requests.append("load"))
	menu.start_button.pressed.emit()
	menu.load_button.pressed.emit()
	check(requests == ["start", "load"], "Game integration signals missing")

	SaveManager.set_value("example", "value", {"nested": [1, 2, 3]})
	check(SaveManager.save_game() == OK, "Save failed")
	SaveManager.save_data.clear()
	check(SaveManager.load_game(), "Load failed")
	check(SaveManager.get_value("example", "value") == {"nested": [1, 2, 3]}, "Save data changed")
	check(SaveManager.get_value("missing", "key", 42) == 42, "Save fallback failed")
	var saved := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	check(SceneManager.change_scene(MENU) == OK, "Menu reload failed")
	await SceneManager.transition_finished
	check(FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == saved, "Menu overwrote an existing save")
	check(SaveManager.reset_save() == OK and not SaveManager.has_save(), "Save reset failed")

	var initial := {"token": {"value": 7}}
	GameSession.start(initial)
	initial.token.value = 99
	check(GameSession.active and GameSession.get_value("token").value == 7, "Session did not isolate initial data")
	var snapshot := GameSession.snapshot()
	snapshot.token.value = 11
	check(GameSession.get_value("token").value == 7, "Snapshot changed session")
	GameSession.set_value("flag", true)
	PauseManager.set_paused(true)
	var previous := get_tree().current_scene
	var rejected: Array = []
	SceneManager.transition_failed.connect(func(path, error): rejected.append([path, error]))
	check(SceneManager.change_scene("res://missing.tscn") == ERR_FILE_NOT_FOUND, "Missing scene was accepted")
	check(rejected.size() == 1, "Missing scene did not emit failure hook")
	check(get_tree().current_scene == previous and PauseManager.is_paused(), "Failed transition changed state")
	check(SceneManager.change_scene(EMPTY) == OK, "Generic scene request failed")
	await SceneManager.transition_finished
	check(not PauseManager.is_paused(), "Scene change retained pause")
	check(GameSession.get_value("flag") == true, "Session did not survive scene change")
	var pause_ui = load("res://scenes/pause_menu/pause_menu.tscn").instantiate()
	get_tree().current_scene.add_child(pause_ui)
	await joy(JOY_BUTTON_START)
	check(PauseManager.is_paused() and pause_ui.visible, "Standalone pause menu failed")
	pause_ui.resume()
	check(get_tree().current_scene.name == "EmptyScene", "Standalone resume hardcodes a menu")
	GameSession.finish()
	check(not GameSession.active and GameSession.snapshot().is_empty(), "Session cleanup failed")
	ControlsManager.set_controls_data([{"label_key": "controls_confirm", "value": "Custom"}])
	check(ControlsManager.get_controls_data()[0].value == "Custom", "Legacy controls data failed")
	SettingsManager.config.set_value("settings", "resolution_index", -99)
	SettingsManager.config.set_value("settings", "language", "unknown")
	SettingsManager.config.set_value("settings", "volume", "invalid")
	SettingsManager.config.save(SettingsManager.SETTINGS_PATH)
	SettingsManager.load_settings()
	check(SettingsManager.resolution_index == 0 and SettingsManager.language == "en_US" and SettingsManager.volume == 1.0, "Invalid settings were not normalized")
	print("Foundation: %d checks, %d failures" % [checks, failures])
	# Let the audio server release playback after the last simulated button click.
	AudioManager.player.stop()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if failures else 0)
