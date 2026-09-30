extends Node

var hover_sound: AudioStream = preload("res://assets/audio/ui/button_hover.mp3")
var click_sound: AudioStream = preload("res://assets/audio/ui/button_click.mp3")
var bg_music: AudioStream = preload("res://assets/audio/music/piano-bg.mp3")

@onready var bgm_player = AudioStreamPlayer.new()

@onready var player = AudioStreamPlayer.new()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	add_child(bgm_player)

func play_hover():
	player.stream = hover_sound
	player.play()

func play_click():
	player.stream = click_sound
	player.play()


func play_bgm(music: AudioStream):
	if music == null:
		return
	bgm_player.stop()
	bgm_player.stream = music
	bgm_player.play()

func stop_bgm():
	bgm_player.stop()

func _exit_tree() -> void:
	player.stop()
	bgm_player.stop()
