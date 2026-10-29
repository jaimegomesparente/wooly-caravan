class_name Dog
extends CharacterBody2D
## Gather posture: waits calmly within the flock's reach of the shepherd (usually behind the flock),
## following only when left behind. When the flock stays stretched beyond its reach for a moment,
## runs around the outside to get behind the rearmost sheep (opposite the shepherd) and pushes it,
## and any sheep near it, toward the shepherd; then the next rearmost. Waits again once it is tight.
## Rear guard posture: stays behind the rearmost sheep without pushing, and chases a wolf coming
## near it. Hunt posture: chases any wolf around, otherwise only stays near the shepherd.
## Chasing: runs straight at the wolf (the sheep step aside), stops and barks; the wolf runs off.

signal mode_changed(mode_name: String)

enum Mode { GATHER, REAR_GUARD, HUNT }
enum State { WAIT, GATHER, GUARD, CHASE }

## Minimum |velocity.x| (px/s) to flip the sprite.
const FLIP_THRESHOLD := 5.0
const MODE_NAMES: Array[String] = ["Rassemblement", "Arrière-garde", "Chasse"]

@export var data: DogData

var _mode: Mode = Mode.GATHER
var _state: State = State.WAIT
## How long (s) the condition to switch state (stretched while waiting, tight while gathering) has held.
var _switch_time: float = 0.0
## True while catching up with the shepherd after being left behind.
var _following: bool = false
## The sheep being pushed.
var _target: Sheep
## True while running around the flock to get behind the target (avoids sheep on the way).
var _flanking: bool = false
## The chased enemy, and true once barking at it.
var _enemy: Enemy
var _barking: bool = false
var _goal: Vector2
var _heading: float = 0.0
var _speed: float = 0.0
## On the pasture between two trips: stops where it is and waits.
var resting: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_goal = global_position
	mode_changed.emit(MODE_NAMES[_mode])


func _physics_process(delta: float) -> void:
	if resting:
		_state = State.WAIT
		_move_to(global_position, delta)
		_update_animation()
		return
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
	if _mode == Mode.GATHER:
		# Time hysteresis: start once the flock has stayed beyond the reach for gather_delay, stop
		# once it has stayed within it for as long.
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
	elif _state != State.CHASE:
		_enemy = _threat(rearmost)
		if _enemy:
			_state = State.CHASE
		else:
			_state = State.GUARD if _mode == Mode.REAR_GUARD and rearmost else State.WAIT

	match _state:
		State.WAIT:
			_goal = _wait_point(shepherd, reach)
		State.GUARD:
			_goal = _guard_point(shepherd, rearmost)
		State.CHASE:
			_chase()
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


## Next mode (Space, through the shepherd): barks, and starts it afresh.
func next_mode() -> void:
	_mode = ((_mode + 1) % Mode.size()) as Mode
	_state = State.WAIT
	_switch_time = 0.0
	_target = null
	_flanking = false
	_enemy = null
	_barking = false
	play_bark()
	mode_changed.emit(MODE_NAMES[_mode])


## The nearest enemy to chase: any threat in Hunt, only one near the rearmost sheep or the dog in
## Rear guard.
func _threat(rearmost: Sheep) -> Enemy:
	var nearest: Enemy = null
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_threat():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if _mode == Mode.REAR_GUARD and distance > data.guard_radius and (rearmost == null \
				or rearmost.global_position.distance_to(enemy.global_position) > data.guard_radius):
			continue
		if nearest == null or distance < global_position.distance_to(nearest.global_position):
			nearest = enemy
	return nearest


## Runs at the enemy; within bark_distance, stops and barks, and scares it once the bark is over.
## Gives up when the enemy is no longer a threat (the mode then picks the next state).
func _chase() -> void:
	if not is_instance_valid(_enemy) or not _enemy.is_threat():
		_stop_chase()
		return
	if _barking:
		_goal = global_position
		if _sprite.animation != &"bark" or not _sprite.is_playing():
			_enemy.scare()
			_stop_chase()
		return
	_goal = _enemy.global_position
	if global_position.distance_to(_goal) <= data.bark_distance:
		_barking = true
		_goal = global_position
		play_bark()


func _stop_chase() -> void:
	_state = State.WAIT
	_enemy = null
	_barking = false
	_goal = global_position


## guard_distance behind the rearmost sheep, opposite the shepherd.
func _guard_point(shepherd: Node2D, rearmost: Sheep) -> Vector2:
	var away := rearmost.global_position - shepherd.global_position
	if away == Vector2.ZERO:
		away = Vector2.LEFT
	return rearmost.global_position + away.normalized() * data.guard_distance


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
## around the sheep so it does not scatter the flock on its way; it always curves around trees.
func _move_to(point: Vector2, delta: float) -> void:
	var to_point := point - global_position
	var distance := to_point.length()
	var wanted := data.run_speed * clampf(distance / data.arrive_distance, 0.0, 1.0)
	if distance > 0.5:
		var direction := to_point / distance
		# Chasing is urgent: straight through the flock (curving around it could keep it circling).
		if not is_pushing() and _state != State.CHASE:
			direction += _avoid_flock() * data.avoid_strength
		# Always around the trail trees, even chasing, so it never gets stuck on a trunk.
		var forest := get_tree().get_first_node_in_group("forest") as Forest
		if forest:
			direction += forest.avoidance(global_position, direction.normalized(), data.tree_avoid_radius) \
					* data.tree_avoid_strength
		_heading = rotate_toward(_heading, direction.angle(), data.turn_rate * delta)
	else:
		wanted = 0.0
	_speed = move_toward(_speed, wanted, data.acceleration * delta)
	velocity = Vector2.from_angle(_heading) * _speed
	move_and_slide()


## Plays the bark animation once (mode change, wolf chased); moving resumes the usual animations.
func play_bark() -> void:
	_sprite.play(&"bark")


func _update_animation() -> void:
	if absf(velocity.x) > FLIP_THRESHOLD:
		_sprite.flip_h = velocity.x < 0.0
	var moving := _speed > FLIP_THRESHOLD
	# Let a bark finish while standing still, or while braking to bark at the wolf.
	if (not moving or _barking) and _sprite.animation == &"bark" and _sprite.is_playing():
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
