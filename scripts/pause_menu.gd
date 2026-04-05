extends Control

@onready var _resume_button: Button = $Center/Panel/VBox/ResumeButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_unhandled_input(true)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open_menu() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	call_deferred(&"_focus_resume")


func _focus_resume() -> void:
	if is_instance_valid(_resume_button):
		_resume_button.grab_focus()


func close_menu() -> void:
	get_tree().paused = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _on_resume_button_pressed() -> void:
	close_menu()


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	GameFlow.restart_level()


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	GameFlow.return_to_menu()
