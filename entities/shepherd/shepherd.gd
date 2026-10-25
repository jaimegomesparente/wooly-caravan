class_name Shepherd
extends CharacterBody2D

@export var speed: float = 32.0
## A trail point is recorded every time the shepherd has walked this far (px).
@export var trail_spacing: float = 6.0
@export var trail_max_points: int = 60

## Past positions, oldest first. The front sheep walk along it instead of cutting toward him.
var _trail: PackedVector2Array = []


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_record_trail()


## The point of the trail `distance_behind` px behind the shepherd, measured along his path.
func trail_point(distance_behind: float) -> Vector2:
	var remaining := distance_behind
	var previous := global_position
	for i in range(_trail.size() - 1, -1, -1):
		var segment := previous.distance_to(_trail[i])
		if segment >= remaining:
			return previous.move_toward(_trail[i], remaining)
		remaining -= segment
		previous = _trail[i]
	return previous


func _record_trail() -> void:
	if _trail.is_empty() or global_position.distance_to(_trail[-1]) >= trail_spacing:
		_trail.append(global_position)
		if _trail.size() > trail_max_points:
			_trail.remove_at(0)
