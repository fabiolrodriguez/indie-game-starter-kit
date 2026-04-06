extends Node

signal language_changed

var current_language := "pt_BR"

var translations = {
	"pt_BR": {
		"menu_start": "JOGAR",
		"menu_load": "CONTINUAR",
		"menu_settings": "CONFIGURAÇÕES",
		"menu_controls": "CONTROLES",
		"menu_back": "VOLTAR",
		"menu_quit": "SAIR",
		"menu_resolution": "RESOLUÇÃO",
		"menu_fullscreen": "TELA CHEIA",
		"menu_language": "IDIOMA",
	},
	"en_US": {
		"menu_start": "START",
		"menu_load": "LOAD",
		"menu_settings": "SETTINGS",
		"menu_controls": "CONTROLS",
		"menu_back": "BACK",
		"menu_quit": "QUIT",
		"menu_resolution": "RESOLUTION",
		"menu_fullscreen": "FULLSCREEN",
		"menu_language": "LANGUAGE",
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
