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
		check(SettingsManager.master_volume == 0.5 and SettingsManager.music_volume == 0.25 and SettingsManager.sfx_volume == 0.0, "Independent volumes did not survive process restart")
		check(LocalizationManager.current_language == "pt_BR" and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Restart initialization did not apply settings")
		check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.25)) and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Restart did not apply category volume/mute")
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
		await _test_audio()
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
		SettingsManager.music_volume = 0.25
		SettingsManager.sfx_volume = 0.0
		SettingsManager.language = "pt_BR"
		SettingsManager.resolution_index = 1
		SettingsManager.fullscreen = false
		check(SettingsManager.save() == OK, "Restart settings fixture failed")
		SaveManager.set_value("restart", "token", 42)
		check(SaveManager.save_game() == OK, "Restart save fixture failed")
	print("Persistence%s: %d checks, %d failures" % [" restart" if "verify-restart" in OS.get_cmdline_user_args() else "", checks, failures])
	AudioManager.player.stop()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if failures else 0)

func _test_audio() -> void:
	for bus in ["Master", "Music", "SFX"]:
		check(AudioServer.get_bus_index(bus) >= 0, "Missing audio bus: " + bus)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Music")) == &"Master" and AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == &"Master", "Category buses bypass Master")
	check(AudioManager.bgm_player.bus == &"Music" and AudioManager.player.bus == &"SFX", "AudioManager routes to incorrect buses")
	# Exercise playback with a rendered backend; headless checks still cover routing
	# and all bus/settings state without depending on the dummy mixer lifecycle.
	if DisplayServer.get_name() != "headless":
		AudioManager.play_bgm(AudioManager.bg_music)
		await get_tree().process_frame
		check(AudioManager.bgm_player.stream == AudioManager.bg_music and AudioManager.bgm_player.playing, "Music playback regressed")
		AudioManager.play_hover()
		await get_tree().process_frame
		check(AudioManager.player.stream == AudioManager.hover_sound and AudioManager.player.playing, "Hover playback regressed")
		AudioManager.play_sfx(AudioManager.click_sound)
		await get_tree().process_frame
		check(AudioManager.player.stream == AudioManager.click_sound, "Generic SFX playback failed")
		AudioManager.play_sfx(null)
		AudioManager.play_bgm(null)
		check(AudioManager.player.stream == AudioManager.click_sound and AudioManager.bgm_player.stream == AudioManager.bg_music, "Null playback changed streams")
		AudioManager.stop_bgm()
		check(not AudioManager.bgm_player.playing, "Music stop regressed")
		AudioManager.player.stop()
		await get_tree().create_timer(0.2).timeout
	write_file(SettingsManager.SETTINGS_PATH, '[settings]\nvolume=0.5\n')
	check(SettingsManager.load_settings() == OK and SettingsManager.master_volume == 0.5 and SettingsManager.music_volume == 1.0 and SettingsManager.sfx_volume == 1.0, "Legacy settings migration changed output/defaults")
	SettingsManager.apply()
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Legacy Master volume was not applied")
	write_file(SettingsManager.SETTINGS_PATH, '[settings]\nvolume=0.5\nmaster_volume=2.0\nmusic_volume=0.5\nsfx_volume=0.0\n')
	check(SettingsManager.load_settings() == OK and SettingsManager.volume == 2.0 and SettingsManager.music_volume == 0.5 and SettingsManager.sfx_volume == 0.0, "New keys/precedence failed")
	SettingsManager.apply()
	for entry in [["Master", SettingsManager.set_master_volume], ["Music", SettingsManager.set_music_volume], ["SFX", SettingsManager.set_sfx_volume]]:
		var index := AudioServer.get_bus_index(entry[0])
		var other_buses: Dictionary = {}
		for other in ["Master", "Music", "SFX"]:
			if other != entry[0]:
				var other_index := AudioServer.get_bus_index(other)
				other_buses[other_index] = [AudioServer.get_bus_volume_db(other_index), AudioServer.is_bus_mute(other_index)]
		entry[1].call(0.0)
		check(AudioServer.is_bus_mute(index) and is_finite(AudioServer.get_bus_volume_db(index)), "Zero volume is unsafe: " + entry[0])
		entry[1].call(0.5)
		check(not AudioServer.is_bus_mute(index) and is_equal_approx(AudioServer.get_bus_volume_db(index), linear_to_db(0.5)), "Unmute/volume change failed: " + entry[0])
		for other_index in other_buses:
			check(other_buses[other_index] == [AudioServer.get_bus_volume_db(other_index), AudioServer.is_bus_mute(other_index)], "Independent volume changed another bus")
		for invalid in [NAN, INF, -INF]:
			entry[1].call(invalid)
			check(not AudioServer.is_bus_mute(index) and is_equal_approx(AudioServer.get_bus_volume_db(index), 0.0), "Invalid category API volume was not normalized")
	SettingsManager.set_volume(0.5)
	SettingsManager.set_music_volume(2.0)
	SettingsManager.set_sfx_volume(0.0)
	check(SettingsManager.config.get_value("settings", "volume") == 0.5 and SettingsManager.config.get_value("settings", "master_volume") == 0.5, "Legacy saved key diverged from Master")
	SettingsManager.master_volume = 1.0
	SettingsManager.music_volume = 1.0
	SettingsManager.sfx_volume = 1.0
	check(SettingsManager.load_settings() == OK and SettingsManager.volume == 0.5 and SettingsManager.music_volume == 2.0 and SettingsManager.sfx_volume == 0.0, "Independent volume reload failed")
	SettingsManager.config.set_value("settings", "music_volume", NAN)
	SettingsManager.config.set_value("settings", "sfx_volume", "invalid")
	SettingsManager.config.save(SettingsManager.SETTINGS_PATH)
	check(SettingsManager.load_settings() == OK and SettingsManager.music_volume == 1.0 and SettingsManager.sfx_volume == 1.0, "Invalid stored category volumes were not normalized")
	SettingsManager.set_music_volume(-1.0)
	SettingsManager.set_sfx_volume(99.0)
	check(SettingsManager.music_volume == 0.0 and SettingsManager.sfx_volume == 5.0, "Category range differs from legacy Master")
	SettingsManager.set_language("pt_BR")
	check(SettingsManager.reset_audio_volumes() == OK and SettingsManager.master_volume == 1.0 and SettingsManager.music_volume == 1.0 and SettingsManager.sfx_volume == 1.0, "Audio defaults failed")
	check(SettingsManager.language == "pt_BR", "Audio reset changed unrelated settings")
	for bus in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		check(not AudioServer.is_bus_mute(index) and is_equal_approx(AudioServer.get_bus_volume_db(index), 0.0), "Audio reset did not apply to bus")
	SettingsManager.master_volume = 0.0
	SettingsManager.music_volume = 0.0
	SettingsManager.sfx_volume = 0.0
	check(SettingsManager.load_settings() == OK and SettingsManager.volume == 1.0 and SettingsManager.music_volume == 1.0 and SettingsManager.sfx_volume == 1.0, "Audio reset was not saved")
