extends CharacterBody2D

## Emitted once when the player first gives meaningful horizontal input or presses jump (starts level timer).
signal first_movement_emitted

const INPUT_DEADZONE := 0.2

## Layer 1: solids (platforms). Layer 2: kill zones only. Both set while vulnerable.
const LAYER_PHYSICS := 1
const LAYER_PLAYER_HURT := 2
const LAYER_PLAYER_FULL := LAYER_PHYSICS | LAYER_PLAYER_HURT

@export var move_speed: float = 220.0
## At full horizontal stick deflection (or keyboard), target speed is move_speed * this. Light stick tilt lerps toward base move_speed.
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

## SSBM-style directional airdodge (shared input with ground parry).
@export var airdodge_speed: float = 480.0
@export var airdodge_duration: float = 12.0 / 60.0
@export var dodge_cooldown: float = 0.45
## Hazard intangibility during airdodge (often slightly longer than movement).
@export var airdodge_intangibility_duration: float = 0.18
## Raw left-stick length must exceed this to steer airdodge angle.
@export var airdodge_analog_deadzone: float = 0.12

## Ground parry: short active intangibility, then punishable endlag.
@export var parry_active_duration: float = 3.0 / 60.0
@export var parry_intangibility_duration: float = 3.0 / 60.0
@export var parry_endlag_duration: float = 16.0 / 60.0

## After a jump eats a same-frame dodge press, airdodge auto-starts within this window once airborne (jump-first buffer).
@export var wavedash_post_jump_dash_buffer: float = 0.14
## After any ground/coyote jump, airdodge within this window gets wavedash-style down-forward angle nudge.
@export var rivals_post_jump_dodge_window: float = 0.12
## Grounded slowdown after a wavedash slide ends (RoA2 cites ~10f landing lag after air dodge into ground).
@export var wavedash_landing_lag_seconds: float = 10.0 / 60.0
## Ground slide after landing an airdodge; horizontal speed decays until timer ends or you leave the floor.
@export var wavedash_slide_duration: float = 0.22
## Horizontal decay when not steering during wavedash slide (higher = shorter slide).
@export var wavedash_slide_friction: float = 3400.0
## Horizontal speed multiplier when an airdodge touches the floor (slight pop feels good on pad).
@export var wavedash_land_speed_scale: float = 1.08
## If the airdodge is mostly vertical, still blend this fraction of airdodge_speed along facing (e.g. keyboard straight down).
@export var wavedash_facing_speed_blend: float = 0.42

var _first_movement_sent: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = true

var _airdodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _intangible_timer: float = 0.0
var _airdodge_direction: Vector2 = Vector2.RIGHT
var _airdodge_started_in_air: bool = false
var _wavedash_slide_timer: float = 0.0
## Same-frame jump ate dodge: keep trying to start airdodge for a short window once airborne.
var _dash_after_jump_buffer_timer: float = 0.0
## Any jump from floor/coyote: next airdodge within this window uses wavedash angle nudge.
var _rivals_post_jump_dodge_timer: float = 0.0
var _wavedash_landing_lag_timer: float = 0.0
var _wavedash_slide_jump_cancelled: bool = false
var _parry_active_timer: float = 0.0
var _parry_endlag_timer: float = 0.0

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
	var dodge_just: bool = Input.is_action_just_pressed(&"dash")

	if not _first_movement_sent:
		if absf(input_x) > INPUT_DEADZONE or jump_pressed or dodge_just:
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

	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)

	var on_floor: bool = is_on_floor()
	var can_jump: bool = on_floor or _coyote_timer > 0.0

	_dash_after_jump_buffer_timer = maxf(0.0, _dash_after_jump_buffer_timer - delta)
	_rivals_post_jump_dodge_timer = maxf(0.0, _rivals_post_jump_dodge_timer - delta)
	if jump_pressed and can_jump and dodge_just:
		_dash_after_jump_buffer_timer = wavedash_post_jump_dash_buffer

	var was_intangible: bool = _intangible_timer > 0.0
	if was_intangible:
		_intangible_timer = maxf(0.0, _intangible_timer - delta)

	if (
		_airdodge_timer <= 0.0
		and _wavedash_slide_timer <= 0.0
		and _wavedash_landing_lag_timer <= 0.0
		and _parry_active_timer <= 0.0
		and _parry_endlag_timer <= 0.0
	):
		var auto_airdodge_from_jump: bool = (
			_dash_after_jump_buffer_timer > 0.0
			and not on_floor
			and _can_use_dodge()
		)
		if auto_airdodge_from_jump:
			_start_airdodge(true)
			_dash_after_jump_buffer_timer = 0.0
			_rivals_post_jump_dodge_timer = 0.0
		elif dodge_just and _can_use_dodge() and not (jump_pressed and can_jump):
			if on_floor:
				_start_parry()
			else:
				var rivals_steer: bool = _rivals_post_jump_dodge_timer > 0.0
				_start_airdodge(rivals_steer)
			_dash_after_jump_buffer_timer = 0.0
			_rivals_post_jump_dodge_timer = 0.0

	if _intangible_timer > 0.0:
		collision_layer = LAYER_PHYSICS
	else:
		collision_layer = LAYER_PLAYER_FULL
		if was_intangible and _intangible_timer <= 0.0:
			_notify_kill_overlap_if_stuck()

	if _wavedash_landing_lag_timer > 0.0:
		_wavedash_landing_lag_timer = maxf(0.0, _wavedash_landing_lag_timer - delta)
		if not is_on_floor():
			_wavedash_landing_lag_timer = 0.0
		else:
			var lag_speed_mult: float = _horizontal_speed_multiplier_from_input(input_x)
			var lag_target_speed: float = move_speed * lag_speed_mult
			var lag_target_x: float = input_x * lag_target_speed
			if absf(input_x) > INPUT_DEADZONE:
				var lag_opposing: bool = (
					absf(velocity.x) > turn_velocity_threshold
					and signf(velocity.x) != signf(input_x)
				)
				var lag_step: float = acceleration * delta
				if lag_opposing:
					lag_step *= turn_acceleration_multiplier
				velocity.x = move_toward(velocity.x, lag_target_x, lag_step)
				_sprite.flip_h = input_x > 0.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			velocity.y = 0.0
			move_and_slide()
			return

	if _parry_active_timer > 0.0:
		_parry_active_timer = maxf(0.0, _parry_active_timer - delta)
		if not is_on_floor():
			_parry_active_timer = 0.0
		else:
			velocity = Vector2.ZERO
			move_and_slide()
			if _parry_active_timer <= 0.0:
				_parry_endlag_timer = parry_endlag_duration
			return

	if _parry_endlag_timer > 0.0:
		_parry_endlag_timer = maxf(0.0, _parry_endlag_timer - delta)
		if not is_on_floor():
			_parry_endlag_timer = 0.0
		else:
			var parry_lag_speed_mult: float = _horizontal_speed_multiplier_from_input(input_x)
			var parry_lag_target_speed: float = move_speed * parry_lag_speed_mult
			var parry_lag_target_x: float = input_x * parry_lag_target_speed
			if absf(input_x) > INPUT_DEADZONE:
				var parry_opposing: bool = (
					absf(velocity.x) > turn_velocity_threshold
					and signf(velocity.x) != signf(input_x)
				)
				var parry_step: float = acceleration * delta * 0.65
				if parry_opposing:
					parry_step *= turn_acceleration_multiplier
				velocity.x = move_toward(velocity.x, parry_lag_target_x, parry_step)
				_sprite.flip_h = input_x > 0.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, deceleration * delta * 1.2)
			velocity.y = 0.0
			move_and_slide()
			return

	if _wavedash_slide_timer > 0.0:
		var prev_slide: float = _wavedash_slide_timer
		_wavedash_slide_timer = maxf(0.0, _wavedash_slide_timer - delta)
		if not is_on_floor():
			_wavedash_slide_timer = 0.0
			_wavedash_slide_jump_cancelled = false
		else:
			if _jump_buffer_timer > 0.0 and can_jump:
				_wavedash_slide_jump_cancelled = true
				velocity.y = jump_velocity
				_jump_buffer_timer = 0.0
				_coyote_timer = 0.0
				_wavedash_slide_timer = 0.0
				_rivals_post_jump_dodge_timer = rivals_post_jump_dodge_window
				Sfx.play_named(&"jump")
				move_and_slide()
				return

			var slide_speed_mult: float = _horizontal_speed_multiplier_from_input(input_x)
			var slide_target: float = input_x * move_speed * slide_speed_mult
			if absf(input_x) > INPUT_DEADZONE:
				velocity.x = move_toward(velocity.x, slide_target, acceleration * delta * 1.35)
				_sprite.flip_h = input_x > 0.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, wavedash_slide_friction * delta)
			velocity.y = 0.0
			move_and_slide()
			if prev_slide > 0.0 and _wavedash_slide_timer <= 0.0 and is_on_floor():
				if not _wavedash_slide_jump_cancelled:
					_wavedash_landing_lag_timer = wavedash_landing_lag_seconds
				_wavedash_slide_jump_cancelled = false
			return

	if _airdodge_timer > 0.0:
		_airdodge_timer = maxf(0.0, _airdodge_timer - delta)
		velocity = _airdodge_direction * airdodge_speed
		if absf(_airdodge_direction.x) > 0.2:
			_sprite.flip_h = _airdodge_direction.x > 0.0
		move_and_slide()
		if _airdodge_started_in_air and is_on_floor():
			var land_x: float = _airdodge_direction.x * airdodge_speed * wavedash_land_speed_scale
			if absf(_airdodge_direction.x) < 0.18:
				land_x += _facing_sign() * airdodge_speed * wavedash_facing_speed_blend
			velocity = Vector2(land_x, 0.0)
			_airdodge_timer = 0.0
			_wavedash_slide_timer = wavedash_slide_duration
			_airdodge_started_in_air = false
			_wavedash_slide_jump_cancelled = false
			if not _was_on_floor:
				Sfx.play_named(&"land")
			move_and_slide()
			return
		if is_on_floor() and not _was_on_floor and velocity.y >= -1.0:
			Sfx.play_named(&"land")
		return

	var speed_mult: float = _horizontal_speed_multiplier_from_input(input_x)
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
		_rivals_post_jump_dodge_timer = rivals_post_jump_dodge_window
		Sfx.play_named(&"jump")

	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	move_and_slide()

	if is_on_floor() and not _was_on_floor and velocity.y >= -1.0:
		Sfx.play_named(&"land")


func _can_use_dodge() -> bool:
	return (
		_airdodge_timer <= 0.0
		and _dodge_cooldown_timer <= 0.0
		and _wavedash_landing_lag_timer <= 0.0
		and _parry_active_timer <= 0.0
		and _parry_endlag_timer <= 0.0
	)


func _facing_sign() -> float:
	return 1.0 if _sprite.flip_h else -1.0


func _horizontal_speed_multiplier_from_input(input_x: float) -> float:
	var ax: float = absf(input_x)
	if ax <= INPUT_DEADZONE:
		return 1.0
	var t: float = clampf((ax - INPUT_DEADZONE) / (1.0 - INPUT_DEADZONE), 0.0, 1.0)
	return lerpf(1.0, sprint_speed_multiplier, t)


## Uses raw joy axes when a pad is connected so the airdodge matches stick angle; otherwise keyboard vector.
func _airdodge_direction_from_input() -> Vector2:
	var analog: Vector2 = _strongest_left_stick_vector()
	if analog.length() > airdodge_analog_deadzone:
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


## Rivals-style: shallow air dodges become a bit more down-forward so landing into slide is consistent.
func _apply_rivals_wavedash_air_angle() -> void:
	var d: Vector2 = _airdodge_direction
	if absf(d.y) >= 0.22:
		return
	var hx: float = signf(d.x) if absf(d.x) > 0.12 else _facing_sign()
	_airdodge_direction = Vector2(hx * 0.88, 0.42).normalized()


func _start_airdodge(rivals_wavedash_steer: bool = false) -> void:
	_airdodge_direction = _airdodge_direction_from_input()
	if _airdodge_direction.length_squared() < 0.0001:
		_airdodge_direction = Vector2.RIGHT
	else:
		_airdodge_direction = _airdodge_direction.normalized()
	if rivals_wavedash_steer:
		_apply_rivals_wavedash_air_angle()

	_airdodge_timer = airdodge_duration
	_dodge_cooldown_timer = dodge_cooldown
	_intangible_timer = airdodge_intangibility_duration
	_airdodge_started_in_air = true


func _start_parry() -> void:
	_parry_active_timer = parry_active_duration
	_dodge_cooldown_timer = dodge_cooldown
	_intangible_timer = parry_intangibility_duration
	velocity = Vector2.ZERO


func _notify_kill_overlap_if_stuck() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method(&"check_player_kill_overlap_after_invulnerability"):
		parent.call(&"check_player_kill_overlap_after_invulnerability", self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		GameFlow.restart_level()
