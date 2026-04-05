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

func save_game():
	config.clear()

	for section in save_data.keys():
		for key in save_data[section].keys():
			config.set_value(section, key, save_data[section][key])

	var err = config.save(SAVE_PATH)

	if err == OK:
		print("Save realizado com sucesso.")
	else:
		print("Erro ao salvar: ", err)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Nenhum save encontrado.")
		return false

	var err = config.load(SAVE_PATH)
	if err != OK:
		print("Erro ao carregar save: ", err)
		return false

	save_data.clear()

	for section in config.get_sections():
		save_data[section] = {}

		for key in config.get_section_keys(section):
			save_data[section][key] = config.get_value(section, key)

	print("Save carregado com sucesso.")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func reset_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	save_data.clear()
	print("Save resetado.")
