extends Node

var volume := 1.0
var fullscreen := false
var resolution_index := 0

var config = ConfigFile.new()

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

func save():
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "resolution_index", resolution_index)
	#config.set_value("settings", "language", Localization.current_language)

	config.save("user://settings.cfg")

func load():
	var err = config.load("user://settings.cfg")
	if err != OK:
		return

	volume = config.get_value("settings", "volume", 1.0)
	fullscreen = config.get_value("settings", "fullscreen", false)
	resolution_index = config.get_value("settings", "resolution_index", 0)

	var lang = config.get_value("settings", "language", "pt_BR")
	#Localization.set_language(lang)

func apply():
	# volume
	if volume <= 0:
		AudioServer.set_bus_volume_db(0, -80)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))

	# fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
func _ready():
	#load()
	apply()		
