extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var storage: String = ProjectSettings.get_setting("starter_kit/user_data_path", "")
	if not ProjectSettings.get_setting("starter_kit/testing", false) or SettingsManager.SETTINGS_PATH != storage.path_join("settings.cfg") or SaveManager.SAVE_PATH != storage.path_join("savegame.cfg"):
		push_error("Use tests/run_tests.py with isolated persistence paths")
		get_tree().quit(1)
		return
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _run() -> void:
	if "verify-restart" in OS.get_cmdline_user_args():
		check(SettingsManager.volume == 0.5 and SettingsManager.language == "pt_BR" and SettingsManager.resolution_index == 1 and not SettingsManager.fullscreen, "Settings did not survive process restart")
		check(LocalizationManager.current_language == "pt_BR" and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Restart initialization did not apply settings")
		check(SaveManager.save_data.is_empty() and SaveManager.load_game() and SaveManager.get_value("restart", "token") == 42, "Save restart/explicit loading failed")
	else:
		SettingsManager.set_volume(0.5)
		write_file(SettingsManager.SETTINGS_PATH, '[settings]\nlanguage="pt_BR"\n')
		check(SettingsManager.load_settings() == OK, "Partial settings failed")
		check(SettingsManager.volume == 1.0 and not SettingsManager.fullscreen and SettingsManager.resolution_index == 0 and SettingsManager.language == "pt_BR", "Reload retained removed settings instead of defaults")
		var good_settings := SettingsManager.config.encode_to_text()
		write_file(SettingsManager.SETTINGS_PATH, '[settings]\nvolume=0.25\nbroken=\n')
		# ConfigFile logs expected parser errors. Suppress only these synchronous calls;
		# restore normal reporting before asserting recovery or running any other code.
		var print_errors := Engine.print_error_messages
		Engine.print_error_messages = false
		var settings_error := SettingsManager.load_settings()
		Engine.print_error_messages = print_errors
		check(settings_error == ERR_PARSE_ERROR and SettingsManager.volume == 1.0 and SettingsManager.config.encode_to_text() == good_settings, "Corrupt settings altered last good state")
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)
		check(SettingsManager.load_settings() == ERR_FILE_NOT_FOUND and SettingsManager.config.encode_to_text() == good_settings, "Missing settings altered last good state")
		for value in [NAN, INF, -INF]:
			var invalid := ConfigFile.new()
			invalid.set_value("settings", "volume", value)
			invalid.save(SettingsManager.SETTINGS_PATH)
			check(SettingsManager.load_settings() == OK and SettingsManager.volume == 1.0, "Non-finite stored volume was not normalized")
			SettingsManager.set_volume(value)
			check(is_finite(SettingsManager.volume) and SettingsManager.volume == 1.0 and is_finite(AudioServer.get_bus_volume_db(0)), "Non-finite API volume reached audio server")
		SaveManager.set_value("removed", "token", 7)
		SaveManager.save_game()
		write_file(SaveManager.SAVE_PATH, '[replacement]\ntoken=9\n')
		check(SaveManager.load_game() and SaveManager.get_value("removed", "token", null) == null and SaveManager.get_value("replacement", "token") == 9, "Save reload retained removed sections")
		var good_save := SaveManager.save_data.duplicate(true)
		var good_config := SaveManager.config.encode_to_text()
		write_file(SaveManager.SAVE_PATH, '[replacement]\ntoken=12\nbroken=\n')
		Engine.print_error_messages = false
		var loaded := SaveManager.load_game()
		Engine.print_error_messages = print_errors
		check(not loaded and SaveManager.save_data == good_save and SaveManager.config.encode_to_text() == good_config, "Corrupt save changed last good data/config")
		DirAccess.remove_absolute(SaveManager.SAVE_PATH)
		check(not SaveManager.load_game() and SaveManager.save_data == good_save, "Missing save destroyed in-memory state")
		check(SaveManager.reset_save() == OK and SaveManager.save_data.is_empty(), "Reset without save file failed")
		GameSession.start({"old": true})
		GameSession.start({"new": true})
		check(GameSession.snapshot() == {"new": true}, "Starting a new session leaked previous values")
		GameSession.finish()
		var previous_language: String = LocalizationManager.current_language
		LocalizationManager.set_language("missing-language")
		check(LocalizationManager.current_language == previous_language and LocalizationManager.tr_key("missing-key") == "missing-key", "Localization fallback/rejection failed")
		var existing_controls := ControlsManager.controls_data.duplicate(true)
		InputMap.add_action("audit_action")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_Z
		InputMap.action_add_event("audit_action", key)
		ControlsManager.set_controls_data([{"label_key": "controls_confirm", "action": "audit_action"}])
		check(ControlsManager.get_controls_data()[0].value == "Z", "Controls description ignores runtime InputMap bindings")
		InputMap.action_erase_events("audit_action")
		key.physical_keycode = KEY_X
		InputMap.action_add_event("audit_action", key)
		check(ControlsManager.get_controls_data()[0].value == "X", "Controls description retained stale bindings")
		InputMap.erase_action("audit_action")
		ControlsManager.set_controls_data(existing_controls)
		# The next Godot process verifies actual persisted initialization.
		SettingsManager.volume = 0.5
		SettingsManager.language = "pt_BR"
		SettingsManager.resolution_index = 1
		SettingsManager.fullscreen = false
		check(SettingsManager.save() == OK, "Restart settings fixture failed")
		SaveManager.set_value("restart", "token", 42)
		check(SaveManager.save_game() == OK, "Restart save fixture failed")
	print("Persistence%s: %d checks, %d failures" % [" restart" if "verify-restart" in OS.get_cmdline_user_args() else "", checks, failures])
	AudioManager.player.stop()
	get_tree().quit(1 if failures else 0)
