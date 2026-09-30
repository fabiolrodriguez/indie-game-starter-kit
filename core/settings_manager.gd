extends Node

var volume := 1.0
var fullscreen := false
var resolution_index := 0

var config = ConfigFile.new()
const SETTINGS_PATH := "user://settings.cfg"

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var language = "en_US"

func save() -> Error:
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "resolution_index", resolution_index)
	config.set_value("settings", "language", language)

	return config.save(SETTINGS_PATH)

func load_settings() -> Error:
	# ConfigFile.load merges data and can partially parse corrupt files. Commit
	# only a successful fresh read, preserving the last good state on failure.
	var loaded := ConfigFile.new()
	var err = loaded.load(SETTINGS_PATH)
	if err != OK:
		return err
	config = loaded

	var stored_volume = config.get_value("settings", "volume", 1.0)
	volume = _normalize_volume(stored_volume)
	fullscreen = config.get_value("settings", "fullscreen", false) == true
	var stored_resolution = config.get_value("settings", "resolution_index", 0)
	resolution_index = stored_resolution if stored_resolution is int else 0
	if resolution_index < 0 or resolution_index >= resolutions.size():
		resolution_index = 0
	var stored_language = config.get_value("settings", "language", "en_US")
	language = stored_language if stored_language is String and LocalizationManager.translations.has(stored_language) else "en_US"
	return OK

func apply_resolution():
	if DisplayServer.get_name() == "headless" or fullscreen:
		return
	if resolution_index < 0 or resolution_index >= resolutions.size():
		resolution_index = 0

	var res = resolutions[resolution_index]
	DisplayServer.window_set_size(res)

	var screen = DisplayServer.screen_get_size()
	var pos = (screen - res) / 2
	DisplayServer.window_set_position(pos)

func apply():
	if volume <= 0:
		AudioServer.set_bus_volume_db(0, -80)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))

	if DisplayServer.get_name() != "headless":
		apply_window_mode()

	apply_resolution()
	apply_language()

func apply_window_mode():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func set_resolution_from_value(menu_resolution: Vector2i):
	var index = resolutions.find(menu_resolution)
	if index != -1:
		resolution_index = index
		save()
		apply()

func set_fullscreen(enabled: bool):
	fullscreen = enabled
	save()
	apply()

func fscr(checkbox: bool):
	set_fullscreen(checkbox)

func set_volume(value: float):
	volume = _normalize_volume(value)
	save()
	apply()

func set_language(code: String):
	if not LocalizationManager.translations.has(code):
		return
	language = code
	save()
	apply_language()

func apply_language():
	LocalizationManager.set_language(language)

func _normalize_volume(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 5.0)
	return 1.0

func _ready():
	load_settings()
	apply()
