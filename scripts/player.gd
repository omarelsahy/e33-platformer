extends CharacterBody2D

## Emitted once when the player first gives meaningful horizontal input or presses jump (starts level timer).
signal first_movement_emitted

const INPUT_DEADZONE := 0.2

## Layer 1: solids (platforms). Layer 2: kill zones only. Both set while vulnerable.
const LAYER_PHYSICS := 1
const LAYER_PLAYER_HURT := 2
const LAYER_PLAYER_FULL := LAYER_PHYSICS | LAYER_PLAYER_HURT

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

@export var dash_speed: float = 520.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 0.45
## Time hazard Areas ignore the player (hurt layer off). Often >= dash_duration.
@export var dash_intangibility_duration: float = 0.2
## Raw left-stick length must exceed this (circular) to steer air dash; keeps a stable angle from the stick.
@export var dash_analog_deadzone: float = 0.12

## After a jump eats a same-frame dash press, air dash can start within this window (Rivals-style leniency).
@export var wavedash_post_jump_dash_buffer: float = 0.14
## Ground slide after landing an air dash; horizontal speed decays until timer ends or you leave the floor.
@export var wavedash_slide_duration: float = 0.22
## Horizontal decay when not steering during wavedash slide (higher = shorter slide).
@export var wavedash_slide_friction: float = 3400.0
## Horizontal speed multiplier when an air dash touches the floor (slight pop feels good on pad).
@export var wavedash_land_speed_scale: float = 1.08
## If the air dash is mostly vertical, still blend this fraction of dash_speed along facing (e.g. keyboard straight down).
@export var wavedash_facing_speed_blend: float = 0.42

var _first_movement_sent: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = true

var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _intangible_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_started_in_air: bool = false
var _wavedash_slide_timer: float = 0.0
## Same-frame jump ate dash: keep trying to start air dash for a short window once airborne.
var _dash_after_jump_buffer_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = LAYER_PLAYER_FULL


func is_hazard_intangible() -> bool:
	return _intangible_timer > 0.0


func _physics_process(delta: float) -> void:
	_was_on_floor = is_on_floor()
	var input_x: float = Input.get_axis(&"move_left", &"move_right")
	var jump_pressed: bool = Input.is_action_just_pressed(&"jump")
	var sprinting: bool = Input.is_action_pressed(&"sprint")
	var dash_just: bool = Input.is_action_just_pressed(&"dash")

	if not _first_movement_sent:
		if absf(input_x) > INPUT_DEADZONE or jump_pressed or dash_just:
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

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)

	var on_floor: bool = is_on_floor()
	var can_jump: bool = on_floor or _coyote_timer > 0.0

	_dash_after_jump_buffer_timer = maxf(0.0, _dash_after_jump_buffer_timer - delta)
	if jump_pressed and can_jump and dash_just:
		_dash_after_jump_buffer_timer = wavedash_post_jump_dash_buffer

	var was_intangible: bool = _intangible_timer > 0.0
	if was_intangible:
		_intangible_timer = maxf(0.0, _intangible_timer - delta)

	if _dash_timer <= 0.0 and _wavedash_slide_timer <= 0.0:
		var auto_air_dash_from_jump: bool = (
			_dash_after_jump_buffer_timer > 0.0
			and not on_floor
			and _can_start_dash()
		)
		if auto_air_dash_from_jump:
			_start_dash(false)
			_dash_after_jump_buffer_timer = 0.0
		elif dash_just and _can_start_dash() and not (jump_pressed and can_jump):
			_start_dash(on_floor)
			_dash_after_jump_buffer_timer = 0.0

	if _intangible_timer > 0.0:
		collision_layer = LAYER_PHYSICS
	else:
		collision_layer = LAYER_PLAYER_FULL
		if was_intangible and _intangible_timer <= 0.0:
			_notify_kill_overlap_if_stuck()

	if _wavedash_slide_timer > 0.0:
		_wavedash_slide_timer = maxf(0.0, _wavedash_slide_timer - delta)
		if not is_on_floor():
			_wavedash_slide_timer = 0.0
		else:
			if _jump_buffer_timer > 0.0 and can_jump:
				velocity.y = jump_velocity
				_jump_buffer_timer = 0.0
				_coyote_timer = 0.0
				_wavedash_slide_timer = 0.0
				Sfx.play_named(&"jump")
				move_and_slide()
				return

			var slide_sprint: bool = Input.is_action_pressed(&"sprint")
			var slide_speed_mult: float = sprint_speed_multiplier if slide_sprint else 1.0
			var slide_target: float = input_x * move_speed * slide_speed_mult
			if absf(input_x) > INPUT_DEADZONE:
				velocity.x = move_toward(velocity.x, slide_target, acceleration * delta * 1.35)
				_sprite.flip_h = input_x > 0.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, wavedash_slide_friction * delta)
			velocity.y = 0.0
			move_and_slide()
			return

	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)
		velocity = _dash_direction * dash_speed
		move_and_slide()
		if _dash_started_in_air and is_on_floor():
			var land_x: float = _dash_direction.x * dash_speed * wavedash_land_speed_scale
			if absf(_dash_direction.x) < 0.18:
				land_x += _facing_sign() * dash_speed * wavedash_facing_speed_blend
			velocity = Vector2(land_x, 0.0)
			_dash_timer = 0.0
			_wavedash_slide_timer = wavedash_slide_duration
			_dash_started_in_air = false
			if not _was_on_floor:
				Sfx.play_named(&"land")
			move_and_slide()
			return
		if is_on_floor() and not _was_on_floor and velocity.y >= -1.0:
			Sfx.play_named(&"land")
		return

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


func _can_start_dash() -> bool:
	return _dash_timer <= 0.0 and _dash_cooldown_timer <= 0.0


func _facing_sign() -> float:
	return 1.0 if _sprite.flip_h else -1.0


func _dash_direction_from_input(on_floor: bool) -> Vector2:
	if on_floor:
		var ix: float = Input.get_axis(&"move_left", &"move_right")
		if absf(ix) > INPUT_DEADZONE:
			return Vector2(signf(ix), 0.0)
		return Vector2(_facing_sign(), 0.0)

	return _air_dash_direction_from_input()


## Uses raw joy axes when a pad is connected so the dash matches stick angle; otherwise keyboard vector.
func _air_dash_direction_from_input() -> Vector2:
	var analog: Vector2 = _strongest_left_stick_vector()
	if analog.length() > dash_analog_deadzone:
		return analog.normalized()

	var digital: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	if digital.length() > INPUT_DEADZONE:
		return digital.normalized()

	return Vector2(_facing_sign(), 0.0)


func _strongest_left_stick_vector() -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_len_sq: float = 0.0
	for device: int in Input.get_connected_joypads():
		var v: Vector2 = Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device, JOY_AXIS_LEFT_Y),
		)
		var len_sq: float = v.length_squared()
		if len_sq > best_len_sq:
			best_len_sq = len_sq
			best = v
	return best


func _start_dash(on_floor: bool) -> void:
	_dash_direction = _dash_direction_from_input(on_floor)
	if _dash_direction.length_squared() < 0.0001:
		_dash_direction = Vector2.RIGHT
	else:
		_dash_direction = _dash_direction.normalized()
	if on_floor:
		_dash_direction = Vector2(signf(_dash_direction.x), 0.0)
		if _dash_direction.x == 0.0:
			_dash_direction = Vector2(_facing_sign(), 0.0)

	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_intangible_timer = dash_intangibility_duration
	_dash_started_in_air = not on_floor


func _notify_kill_overlap_if_stuck() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method(&"check_player_kill_overlap_after_invulnerability"):
		parent.call(&"check_player_kill_overlap_after_invulnerability", self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		GameFlow.restart_level()
