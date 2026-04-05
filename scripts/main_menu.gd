extends Control


func _ready() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"jump"):
		GameFlow.start_game()
	elif event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()
