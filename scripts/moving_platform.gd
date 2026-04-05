extends AnimatableBody2D

@export var amplitude: float = 80.0
@export var speed: float = 1.6
@export var horizontal: bool = true

var _origin: Vector2
var _t: float = 0.0


func _ready() -> void:
	_origin = global_position


func _physics_process(delta: float) -> void:
	_t += delta * speed
	var offset: float = sin(_t) * amplitude
	if horizontal:
		global_position.x = _origin.x + offset
	else:
		global_position.y = _origin.y + offset
