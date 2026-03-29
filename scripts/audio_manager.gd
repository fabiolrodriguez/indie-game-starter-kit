extends Node

var hover_sound = preload("res://assets/audio/ui/button_hover.mp3")
var click_sound = preload("res://assets/audio/ui/button_click.mp3")

@onready var player = AudioStreamPlayer.new()

func _ready():
	add_child(player)

func play_hover():
	player.stream = hover_sound
	player.play()

func play_click():
	player.stream = click_sound
	player.play()
