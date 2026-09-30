extends Node
## Transient state only. Games decide what to persist through SaveManager.

signal started
signal ended
signal value_changed(key: StringName, value: Variant)

var active := false
var _data: Dictionary = {}

func start(initial_data: Dictionary = {}) -> void:
	_data = initial_data.duplicate(true)
	active = true
	started.emit()

func finish() -> void:
	_data.clear()
	active = false
	ended.emit()

func set_value(key: StringName, value: Variant) -> void:
	_data[key] = value
	value_changed.emit(key, value)

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _data.get(key, default_value)

func snapshot() -> Dictionary:
	return _data.duplicate(true)
