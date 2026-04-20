extends CharacterBody2D

## Emitted once when the player first gives meaningful horizontal input or presses jump (starts level timer).
signal first_movement_emitted

const INPUT_DEADZONE := 0.2

@export var move_speed: float = 220.0
## Horizontal target speed multiplier while holding sprint (ground and air).
@export var sprint_speed_multiplier: float = 1.45
@export var acceleration: float = 1200.0
@export var deceleration: float = 1400.0
@export var air_acceleration: float = 800.0
## Extra horizontal acceleration when reversing direction (|opposing input vs current motion).
@export var turn_acceleration_multiplier: float = 1.85
## Minimum horizontal speed (px/s) before reversal counts as a "turn" for boosted accel.
@export var turn_velocity_threshold: float = 35.0
@export var jump_velocity: float = -420.0
## Gravity while moving upward (before apex).
@export var gravity: float = 1500.0
## Gravity while falling (usually higher than rise for snappier landings).
@export var gravity_fall: float = 2200.0
@export var max_fall_speed: float = 600.0
## When releasing jump while rising, vertical velocity is scaled by this (smaller = shorter hop).
@export var jump_cut_multiplier: float = 0.45
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

var _first_movement_sent: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = true

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group(&"player")


func _physics_process(delta: float) -> void:
	_was_on_floor = is_on_floor()
	var input_x: float = Input.get_axis(&"move_left", &"move_right")
	var jump_pressed: bool = Input.is_action_just_pressed(&"jump")
	var sprinting: bool = Input.is_action_pressed(&"sprint")

	if not _first_movement_sent:
		if absf(input_x) > INPUT_DEADZONE or jump_pressed:
			_first_movement_sent = true
			first_movement_emitted.emit()

	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)

	var on_floor: bool = is_on_floor()
	var speed_mult: float = sprint_speed_multiplier if sprinting else 1.0
	var target_speed: float = move_speed * speed_mult
	var target_x: float = input_x * target_speed
	var accel: float = acceleration if on_floor else air_acceleration

	if absf(input_x) > INPUT_DEADZONE:
		var opposing_turn: bool = (
			absf(velocity.x) > turn_velocity_threshold
			and signf(velocity.x) != signf(input_x)
		)
		var step: float = accel * delta
		if opposing_turn:
			step *= turn_acceleration_multiplier
		velocity.x = move_toward(velocity.x, target_x, step)
		_sprite.flip_h = input_x > 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	if not on_floor:
		var g: float = gravity if velocity.y < 0.0 else gravity_fall
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	var can_jump: bool = on_floor or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Sfx.play_named(&"jump")

	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	move_and_slide()

	if is_on_floor() and not _was_on_floor and velocity.y >= -1.0:
		Sfx.play_named(&"land")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		GameFlow.restart_level()
