extends Node

var current_language := "pt_BR"

var translations = {
	"pt_BR": {
		"menu_start": "Jogar",
		"menu_settings": "Configurações",
	},
	"en_US": {
		"menu_start": "Start",
		"menu_settings": "Settings",
	}
}

func set_language(lang: String):
	current_language = lang

func tr_key(key: String) -> String:
	if translations.has(current_language) and translations[current_language].has(key):
		return translations[current_language][key]
	return key
