extends Node

var volume := 1.0
var fullscreen := false
var resolution_index := 0
var menu_res = 0

var config = ConfigFile.new()
const SETTINGS_PATH := "user://settings.cfg"

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3480, 2160)
]

func save():
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "resolution_index", menu_res)
	#config.set_value("settings", "language", Localization.current_language)

	config.save(SETTINGS_PATH)

func load_settings():
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	volume = config.get_value("settings", "volume", 1.0)
	fullscreen = config.get_value("settings", "fullscreen", false)
	resolution_index = config.get_value("settings", "resolution_index", 0)

	var lang = config.get_value("settings", "language", "pt_BR")
	#Localization.set_language(lang)

func apply_resolution(menu_resolution):
	var res = menu_resolution
	menu_res = resolutions.find(res)
	DisplayServer.window_set_size(res)
	# center window
	var screen = DisplayServer.screen_get_size()
	var pos = (screen - res) / 2
	DisplayServer.window_set_position(pos)
	save()
	apply()

func apply():
	
	if volume <= 0:
		AudioServer.set_bus_volume_db(0, -80)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
func fscr(checkbox):
	if checkbox:
		fullscreen = true
	else:
		fullscreen = false
	save()
	apply()

func _ready():
	load_settings()
	#apply()		
