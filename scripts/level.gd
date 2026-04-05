extends Node2D

const LEVEL_TIME_SEC := 33.0

@onready var _player: CharacterBody2D = $Player
@onready var _timer_label: Label = $UILayer/UI/TimerLabel
@onready var _flash: ColorRect = $UILayer/Flash

var _time_remaining: float = LEVEL_TIME_SEC
var _timer_running: bool = false
var _level_cleared: bool = false
var _is_failing: bool = false


func _ready() -> void:
	_timer_label.text = str(int(ceil(_time_remaining)))
	_player.first_movement_emitted.connect(_on_first_movement)
	_connect_goal($Goal)
	_connect_kill_zones()


func _connect_goal(goal: Node) -> void:
	if goal is Area2D:
		var a := goal as Area2D
		a.body_entered.connect(_on_goal_body_entered)


func _connect_kill_zones() -> void:
	for node in get_tree().get_nodes_in_group(&"kill_zone"):
		if node is Area2D:
			var a := node as Area2D
			if not a.body_entered.is_connected(_on_kill_zone_body_entered):
				a.body_entered.connect(_on_kill_zone_body_entered)


func _process(delta: float) -> void:
	if _level_cleared or _is_failing:
		return
	if _timer_running:
		_time_remaining -= delta
		var display: int = int(ceil(maxf(0.0, _time_remaining)))
		_timer_label.text = str(display)
		if _time_remaining <= 0.0:
			_fail_level()


func _on_first_movement() -> void:
	_timer_running = true


func _on_goal_body_entered(body: Node2D) -> void:
	if _level_cleared or _is_failing:
		return
	if body.is_in_group(&"player"):
		_level_cleared = true
		_timer_running = false
		GameFlow.next_level()


func _on_kill_zone_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_fail_level()


func _fail_level() -> void:
	if _level_cleared or _is_failing:
		return
	_is_failing = true
	_timer_running = false
	_flash_fail()
	await get_tree().create_timer(0.08).timeout
	GameFlow.restart_level()


func _flash_fail() -> void:
	Sfx.play_named(&"fail")
	_flash.color = Color(0.85, 0.15, 0.2, 0.45)
	_flash.visible = true
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.12)
	tw.finished.connect(func() -> void: _flash.visible = false)
