extends Node

signal language_changed

var current_language := "pt_BR"

var translations = {
	"pt_BR": {
		"menu_start": "JOGAR",
		"menu_settings": "CONFIGURAÇÕES",
		"menu_back": "VOLTAR",
		"menu_quit": "SAIR",
	},
	"en_US": {
		"menu_start": "START",
		"menu_settings": "SETTINGS",
		"menu_back": "BACK",
		"menu_quit": "QUIT"
	}
}

func set_language(lang: String):
	current_language = lang
	emit_signal("language_changed")

func tr_key(key: String) -> String:
	if translations.has(current_language):
		var lang_dict = translations[current_language]
		if lang_dict.has(key):
			return lang_dict[key]

	# fallback para inglês
	if translations.has("en_US") and translations["en_US"].has(key):
		return translations["en_US"][key]

	return key
