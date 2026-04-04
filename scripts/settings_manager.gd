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
	Vector2i(3480, 2160)
]

var language = "en_US"

func save():
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "resolution_index", resolution_index)
	config.set_value("settings", "language", language)

	config.save(SETTINGS_PATH)

func load_settings():
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	volume = config.get_value("settings", "volume", 1.0)
	fullscreen = config.get_value("settings", "fullscreen", false)
	resolution_index = config.get_value("settings", "resolution_index", 0)
	language = config.get_value("settings", "language", "pt_BR")

func apply_resolution():
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

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	apply_resolution()
	apply_language()

func set_resolution_from_value(menu_resolution: Vector2i):
	var index = resolutions.find(menu_resolution)
	if index != -1:
		resolution_index = index
		save()
		apply()

func fscr(checkbox):
	fullscreen = checkbox
	save()
	apply()

func apply_language():
	LocalizationManager.set_language(language)  

func _ready():
	load_settings()
	apply()
