extends Node

var controls_data = [
	{"label_key": "controls_move_up", "value": "  W / ↑"},
	{"label_key": "controls_move_down", "value": "  S / ↓"},
	{"label_key": "controls_move_left", "value": "  A / ←"},
	{"label_key": "controls_move_right", "value": "  D / →"},
	{"label_key": "controls_confirm", "value": "  Space"},
	{"label_key": "controls_pause", "value": "Esc"}
]

func get_controls_data() -> Array:
	return controls_data

func set_controls_data(data: Array):
	controls_data = data
