extends Node

## Optional WAV/OGG at these paths; if missing, calls no-op (no errors).
const PATH_JUMP := "res://audio/jump.wav"
const PATH_LAND := "res://audio/land.wav"
const PATH_FAIL := "res://audio/fail.wav"

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)


func play_named(which: StringName) -> void:
	var path: String = ""
	match which:
		&"jump":
			path = PATH_JUMP
		&"land":
			path = PATH_LAND
		&"fail":
			path = PATH_FAIL
		_:
			return
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_player.stream = stream
	_player.play()
