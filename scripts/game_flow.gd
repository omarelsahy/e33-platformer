extends Node

const LEVEL_SCENES: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
	"res://scenes/levels/level_03.tscn",
	"res://scenes/levels/level_04.tscn",
	"res://scenes/levels/level_05.tscn",
]

var level_index: int = 0


func start_game() -> void:
	level_index = 0
	get_tree().change_scene_to_file(LEVEL_SCENES[level_index])


func restart_level() -> void:
	get_tree().reload_current_scene()


func next_level() -> void:
	level_index += 1
	if level_index >= LEVEL_SCENES.size():
		get_tree().change_scene_to_file("res://scenes/victory.tscn")
	else:
		get_tree().change_scene_to_file(LEVEL_SCENES[level_index])


func return_to_menu() -> void:
	level_index = 0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
