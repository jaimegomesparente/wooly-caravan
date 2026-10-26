extends Camera2D

## How far the camera leans from the shepherd toward the flock center (0 = shepherd, 1 = flock).
@export_range(0.0, 1.0) var flock_bias: float = 0.3
## The lean never takes the camera farther than this (px) from the shepherd, so he stays well on screen.
@export var max_lean: float = 60.0
## Higher = the camera catches up faster.
@export var smoothing: float = 3.0

var _focus: Vector2


func _ready() -> void:
	_focus = _target()
	global_position = _focus.round()


# Physics tick, like the bodies it follows, so camera and sprites move in step.
func _physics_process(delta: float) -> void:
	_focus = _focus.lerp(_target(), 1.0 - exp(-smoothing * delta))
	# Whole pixels only: no shimmering with Snap 2D Transforms to Pixel.
	global_position = _focus.round()


func _target() -> Vector2:
	var shepherd := get_tree().get_first_node_in_group("shepherd") as Node2D
	if shepherd == null:
		return global_position
	var flock := get_tree().get_nodes_in_group("sheep")
	if flock.is_empty():
		return shepherd.global_position
	var center := Vector2.ZERO
	for sheep: Node2D in flock:
		center += sheep.global_position
	center /= flock.size()
	var lean := (center - shepherd.global_position) * flock_bias
	return shepherd.global_position + lean.limit_length(max_lean)
