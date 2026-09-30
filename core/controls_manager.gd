extends Node
## InputMap owns bindings; entries describe actions or supply a custom value.

signal controls_changed

var controls_data: Array = [
	{"label_key": "controls_move_up", "action": "ui_up"},
	{"label_key": "controls_move_down", "action": "ui_down"},
	{"label_key": "controls_move_left", "action": "ui_left"},
	{"label_key": "controls_move_right", "action": "ui_right"},
	{"label_key": "controls_confirm", "action": "ui_accept"},
	{"label_key": "controls_cancel", "action": "ui_cancel"},
	{"label_key": "controls_pause", "action": "pause"}
]

func get_controls_data() -> Array:
	var result: Array = []
	for entry in controls_data:
		var item: Dictionary = entry.duplicate(true)
		if item.has("action"):
			var labels: PackedStringArray = []
			if InputMap.has_action(item["action"]):
				for event in InputMap.action_get_events(item["action"]):
					labels.append(_binding_label(event))
			item["value"] = " / ".join(labels)
		result.append(item)
	return result

func _binding_label(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	if event is InputEventJoypadButton:
		var names := {
			JOY_BUTTON_A: "A / Cross", JOY_BUTTON_B: "B / Circle",
			JOY_BUTTON_BACK: "Back / Select", JOY_BUTTON_START: "Start / Options",
			JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
			JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →"
		}
		return names.get(event.button_index, event.as_text())
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			return "L-stick ←" if event.axis_value < 0 else "L-stick →"
		if event.axis == JOY_AXIS_LEFT_Y:
			return "L-stick ↑" if event.axis_value < 0 else "L-stick ↓"
	return event.as_text()

func set_controls_data(data: Array) -> void:
	controls_data = data.duplicate(true)
	controls_changed.emit()
