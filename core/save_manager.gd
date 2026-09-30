extends Node

const SAVE_PATH := "user://savegame.cfg"

var config := ConfigFile.new()
var save_data := {}

func set_value(section: String, key: String, value):
	if not save_data.has(section):
		save_data[section] = {}

	save_data[section][key] = value

func get_value(section: String, key: String, default_value = null):
	if save_data.has(section) and save_data[section].has(key):
		return save_data[section][key]

	return default_value

func save_game() -> Error:
	config.clear()

	for section in save_data.keys():
		for key in save_data[section].keys():
			config.set_value(section, key, save_data[section][key])

	var err = config.save(SAVE_PATH)

	return err

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var loaded := ConfigFile.new()
	var err = loaded.load(SAVE_PATH)
	if err != OK:
		return false
	config = loaded

	save_data.clear()

	for section in config.get_sections():
		save_data[section] = {}

		for key in config.get_section_keys(section):
			save_data[section][key] = config.get_value(section, key)

	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func reset_save() -> Error:
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(SAVE_PATH)
		if error != OK:
			return error
	save_data.clear()
	config.clear()
	return OK
