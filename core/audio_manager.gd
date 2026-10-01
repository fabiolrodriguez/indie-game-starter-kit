extends Node

var hover_sound: AudioStream = preload("res://assets/audio/ui/button_hover.mp3")
var click_sound: AudioStream = preload("res://assets/audio/ui/button_click.mp3")
var bg_music: AudioStream = preload("res://assets/audio/music/piano-bg.mp3")

@onready var bgm_player = AudioStreamPlayer.new()

@onready var player = AudioStreamPlayer.new()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = &"SFX"
	bgm_player.bus = &"Music"
	add_child(player)
	add_child(bgm_player)

func play_hover():
	play_sfx(hover_sound)

func play_click():
	play_sfx(click_sound)

func play_sfx(sound: AudioStream):
	if sound == null:
		return
	player.stream = sound
	player.play()


func play_bgm(music: AudioStream):
	if music == null:
		return
	bgm_player.stop()
	bgm_player.stream = music
	bgm_player.play()

func stop_bgm():
	bgm_player.stop()

func set_master_volume(value: float) -> void:
	_set_bus_volume(&"Master", value)

func set_music_volume(value: float) -> void:
	_set_bus_volume(&"Music", value)

func set_sfx_volume(value: float) -> void:
	_set_bus_volume(&"SFX", value)

func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("Missing audio bus: " + str(bus_name))
		return
	var linear := clampf(value, 0.0, 5.0) if is_finite(value) else 1.0
	AudioServer.set_bus_mute(index, linear == 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear) if linear > 0.0 else -80.0)

func _exit_tree() -> void:
	player.stop()
	bgm_player.stop()
