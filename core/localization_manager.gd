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
		"menu_volume": "VOLUME",
		"menu_master_volume": "VOLUME GERAL",
		"menu_music_volume": "VOLUME DA MÚSICA",
		"menu_sfx_volume": "VOLUME DOS EFEITOS",
		"menu_reset_audio": "RESTAURAR VOLUMES",
		"menu_fullscreen": "TELA CHEIA",
		"menu_language": "IDIOMA",
		"menu_resume": "CONTINUAR",
		"menu_paused": "PAUSADO",
		"controls_title": "CONTROLES",
		"controls_back": "VOLTAR",
		"controls_move_up": "Navegar para cima",
		"controls_move_down": "Navegar para baixo",
		"controls_move_left": "Navegar à esquerda",
		"controls_move_right": "Navegar à direita",
		"controls_confirm": "Confirmar",
		"controls_cancel": "Voltar",
		"controls_pause": "Pausar"
	},
	"en_US": {
		"menu_start": "START",
		"menu_load": "LOAD",
		"menu_settings": "SETTINGS",
		"menu_controls": "CONTROLS",
		"menu_back": "BACK",
		"menu_quit": "QUIT",
		"menu_resolution": "RESOLUTION",
		"menu_volume": "VOLUME",
		"menu_master_volume": "MASTER VOLUME",
		"menu_music_volume": "MUSIC VOLUME",
		"menu_sfx_volume": "SFX VOLUME",
		"menu_reset_audio": "RESET AUDIO VOLUMES",
		"menu_fullscreen": "FULLSCREEN",
		"menu_language": "LANGUAGE",
		"menu_resume": "RESUME",
		"menu_paused": "PAUSED",
		"controls_title": "CONTROLS",
		"controls_back": "BACK",
		"controls_move_up": "Navigate up",
		"controls_move_down": "Navigate down",
		"controls_move_left": "Navigate left",
		"controls_move_right": "Navigate right",
		"controls_confirm": "Confirm",
		"controls_cancel": "Back",
		"controls_pause": "Pause"
	}
}

func set_language(lang: String):
	if not translations.has(lang) or current_language == lang:
		return
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
