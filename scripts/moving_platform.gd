extends AnimatableBody2D

@export var amplitude: float = 80.0
@export var speed: float = 1.6
@export var horizontal: bool = true

var _origin: Vector2
var _t: float = 0.0


func _ready() -> void:
	_origin = global_position


func _physics_process(delta: float) -> void:
	var prev_pos := global_position
	_t += delta * speed
	var offset: float = sin(_t) * amplitude
	if horizontal:
		global_position.x = _origin.x + offset
	else:
		global_position.y = _origin.y + offset
	# So CharacterBody2D floors receive correct motion (position-only moves do not infer velocity).
	constant_linear_velocity = (global_position - prev_pos) / delta if delta > 0.0 else Vector2.ZERO
