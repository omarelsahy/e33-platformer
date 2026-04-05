extends Control

@onready var _level_select: Control = $LevelSelectOverlay
@onready var _level_grid: GridContainer = $LevelSelectOverlay/Center/Panel/Margin/VBox/LevelButtonGrid


func _ready() -> void:
	set_process_unhandled_input(true)
	_level_select.visible = false
	_populate_level_buttons()


func _populate_level_buttons() -> void:
	for child in _level_grid.get_children():
		child.queue_free()
	var n: int = GameFlow.LEVEL_SCENES.size()
	for i in n:
		var btn := Button.new()
		btn.text = "Level %d" % (i + 1)
		btn.custom_minimum_size.x = 120
		btn.pressed.connect(_on_level_button_pressed.bind(i))
		_level_grid.add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if _level_select.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_close_level_select()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"jump"):
		GameFlow.start_game()
	elif event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()


func _on_play_pressed() -> void:
	GameFlow.start_game()


func _on_level_select_pressed() -> void:
	_level_select.visible = true


func _close_level_select() -> void:
	_level_select.visible = false


func _on_level_select_back_pressed() -> void:
	_close_level_select()


func _on_level_button_pressed(level_idx: int) -> void:
	GameFlow.start_level_at(level_idx)
