class_name Dog
extends CharacterBody2D
## Gather posture: waits calmly within the flock's reach of the shepherd (usually behind the flock),
## following only when left behind. When the flock stays stretched beyond its reach for a moment,
## runs around the outside to get behind the rearmost sheep (opposite the shepherd) and pushes it,
## and any sheep near it, toward the shepherd; then the next rearmost. Waits again once it is tight.

enum State { WAIT, GATHER }

## Minimum |velocity.x| (px/s) to flip the sprite.
const FLIP_THRESHOLD := 5.0

@export var data: DogData

var _state: State = State.WAIT
## How long (s) the condition to switch state (stretched while waiting, tight while gathering) has held.
var _switch_time: float = 0.0
## True while catching up with the shepherd after being left behind.
var _following: bool = false
## The sheep being pushed.
var _target: Sheep
## True while running around the flock to get behind the target (avoids sheep on the way).
var _flanking: bool = false
var _goal: Vector2
var _heading: float = 0.0
var _speed: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_goal = global_position


func _physics_process(delta: float) -> void:
	var shepherd := get_tree().get_first_node_in_group("shepherd") as Node2D
	if shepherd == null:
		return
	var reach := data.gather_spacing * sqrt(get_tree().get_node_count_in_group("sheep"))
	# A walking flock is a column, much longer than a flock at rest.
	var shepherd_body := shepherd as CharacterBody2D
	if shepherd_body and shepherd_body.velocity.length() > 1.0:
		reach *= data.walking_reach_factor
	var rearmost := _rearmost_sheep(shepherd)
	var rearmost_distance := rearmost.global_position.distance_to(shepherd.global_position) if rearmost else 0.0
	# Time hysteresis: start once the flock has stayed beyond the reach for gather_delay, stop once
	# it has stayed within it for as long.
	var stretched := rearmost_distance > reach
	_switch_time = _switch_time + delta if stretched == (_state == State.WAIT) else 0.0
	if _switch_time >= data.gather_delay:
		_switch_time = 0.0
		if _state == State.WAIT:
			_state = State.GATHER
			_following = false
		else:
			_state = State.WAIT
			_target = null
			_flanking = false

	match _state:
		State.WAIT:
			_goal = _wait_point(shepherd, reach)
		State.GATHER:
			# Keep the target until another sheep is clearly farther behind, so the dog sweeps the
			# rear instead of zigzagging between sheep at about the same distance.
			if _target == null or not is_instance_valid(_target) or not _target.is_in_group("sheep") \
					or rearmost_distance > _target.global_position.distance_to(shepherd.global_position) + data.switch_margin:
				_target = rearmost
			_goal = _push_point(shepherd) if _target else global_position
	_move_to(_goal, delta)
	_update_animation()
	queue_redraw()


## True while actually pushing sheep (behind its target): only then do sheep trot straight away
## from it. Otherwise they just step aside as it passes, like for the shepherd.
func is_pushing() -> bool:
	return _state == State.GATHER and not _flanking


func _draw() -> void:
	if Sheep.debug_draw:
		draw_line(Vector2.ZERO, to_local(_goal), Color.ORANGE_RED if _flanking else Color.SADDLE_BROWN, 1.0)


## Stays where it is while within `reach` of the shepherd. Once farther than reach + follow_slack,
## comes back to `reach` on its own side (usually behind the flock), at the shepherd's pace.
func _wait_point(shepherd: Node2D, reach: float) -> Vector2:
	var from_shepherd := global_position - shepherd.global_position
	var distance := from_shepherd.length()
	if distance > reach + data.follow_slack:
		_following = true
	elif distance <= reach:
		_following = false
	if not _following or distance == 0.0:
		return global_position
	return shepherd.global_position + from_shepherd / distance * reach


## push_distance behind the target, opposite the shepherd, inside its flight zone. While not yet
## behind it, first runs alongside it, detour_distance to the side, so it is not pushed the wrong way.
func _push_point(shepherd: Node2D) -> Vector2:
	var target := _target.global_position
	var away := target - shepherd.global_position
	var depth := away.length()
	away = Vector2.RIGHT if depth == 0.0 else away / depth
	var my_depth := (global_position - shepherd.global_position).dot(away)
	if my_depth < depth - data.flank_margin:
		_flanking = true
	elif my_depth >= depth:
		_flanking = false
	if _flanking:
		var side := away.orthogonal()
		var my_side := signf((global_position - target).dot(side) + 0.001)
		return target + side * my_side * data.detour_distance
	return target + away * data.push_distance


## Heading turned at a limited rate, speed eased down near the goal. Unless pushing, it curves
## around the sheep so it does not scatter the flock on its way.
func _move_to(point: Vector2, delta: float) -> void:
	var to_point := point - global_position
	var distance := to_point.length()
	var wanted := data.run_speed * clampf(distance / data.arrive_distance, 0.0, 1.0)
	if distance > 0.5:
		var direction := to_point / distance
		if not is_pushing():
			direction += _avoid_flock() * data.avoid_strength
		_heading = rotate_toward(_heading, direction.angle(), data.turn_rate * delta)
	else:
		wanted = 0.0
	_speed = move_toward(_speed, wanted, data.acceleration * delta)
	velocity = Vector2.from_angle(_heading) * _speed
	move_and_slide()


## Plays the bark animation once (for the Bark order, later); moving resumes the usual animations.
func play_bark() -> void:
	_sprite.play(&"bark")


func _update_animation() -> void:
	if absf(velocity.x) > FLIP_THRESHOLD:
		_sprite.flip_h = velocity.x < 0.0
	var moving := _speed > FLIP_THRESHOLD
	# Let a bark finish while standing still.
	if not moving and _sprite.animation == &"bark" and _sprite.is_playing():
		return
	var animation := &"run" if moving else &"idle"
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


## Push away from sheep within avoid_radius (not the target); magnitude fades from 1 to 0 across it.
func _avoid_flock() -> Vector2:
	var push := Vector2.ZERO
	for sheep: Node2D in get_tree().get_nodes_in_group("sheep"):
		if sheep == _target:
			continue
		var away := global_position - sheep.global_position
		var distance := away.length()
		if distance > 0.0 and distance < data.avoid_radius:
			push += away / distance * (1.0 - distance / data.avoid_radius)
	return push


## The sheep farthest from the shepherd.
func _rearmost_sheep(shepherd: Node2D) -> Sheep:
	var rearmost: Sheep = null
	var farthest := -1.0
	for sheep: Sheep in get_tree().get_nodes_in_group("sheep"):
		var distance := sheep.global_position.distance_to(shepherd.global_position)
		if distance > farthest:
			farthest = distance
			rearmost = sheep
	return rearmost
