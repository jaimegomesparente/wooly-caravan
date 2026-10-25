class_name Sheep
extends CharacterBody2D

enum Gait { REST, WALK, TROT }

## A sheep this close to its guide's speed counts the guide as stopped (px/s).
const GUIDE_STOPPED_SPEED := 2.0
## A guide sheep must be at least this much closer (px) to the shepherd, so guides never loop.
const GUIDE_AHEAD_MARGIN := 4.0

@export var config: FlockConfig

var _gait: Gait = Gait.REST
var _heading: float = 0.0
var _speed: float = 0.0
var _speed_factor: float = 1.0
var _shepherd_gap: float = 0.0
var _think_timer: float = 0.0
## The shepherd, or the sheep ahead that this sheep follows.
var _guide: Node2D
var _shepherd: Node2D
var _animation_started: bool = false
## Horizontal offsets of the sprite and collision when facing right, mirrored when flipped.
var _sprite_offset_x: float = 0.0
var _shape_offset_x: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sprite_offset_x = _sprite.position.x
	_shape_offset_x = _shape.position.x
	_speed_factor = 1.0 + randf_range(-config.speed_variation, config.speed_variation)
	_shepherd_gap = config.shepherd_gap * (1.0 + randf_range(-config.speed_variation, config.speed_variation))
	_heading = randf() * TAU
	_think_timer = randf_range(0.0, config.think_interval_max)


func _physics_process(delta: float) -> void:
	if _shepherd == null:
		_shepherd = get_tree().get_first_node_in_group("shepherd") as Node2D
	if _shepherd == null:
		return

	var separation := _separation()
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = randf_range(config.think_interval_min, config.think_interval_max)
		_think()

	var direction := Vector2.from_angle(_heading)
	var target_speed := 0.0
	if _gait == Gait.REST:
		if separation.length() > config.shuffle_threshold:
			direction = separation
			target_speed = config.walk_speed * _speed_factor * 0.5
	else:
		var to_guide := _guide.global_position - global_position
		var distance := to_guide.length()
		var gap := _gap()
		var guide_speed := _speed_of(_guide)
		if guide_speed < GUIDE_STOPPED_SPEED and (distance < gap + config.start_margin or _is_blocked(distance)):
			_gait = Gait.REST
		elif _gait == Gait.WALK and distance > gap + config.trot_margin:
			_gait = Gait.TROT
		elif _gait == Gait.TROT and distance < gap + config.trot_margin * 0.5:
			_gait = Gait.WALK

		direction = to_guide.normalized() + separation * config.separation_strength
		match _gait:
			Gait.TROT:
				target_speed = config.trot_speed * _speed_factor
			Gait.WALK:
				# Close behind a moving guide, match its pace instead of bumping into it.
				var walk := config.walk_speed * _speed_factor
				target_speed = walk if distance > gap + config.start_margin * 0.5 else minf(walk, guide_speed)

	if direction != Vector2.ZERO:
		_heading = rotate_toward(_heading, direction.angle(), config.turn_rate * delta)
	_speed = move_toward(_speed, target_speed, config.acceleration * delta)
	velocity = Vector2.from_angle(_heading) * _speed
	move_and_slide()
	_update_animation()


## Pick a guide (shepherd or the nearest sheep ahead) and decide whether to set off.
func _think() -> void:
	var my_distance := global_position.distance_to(_shepherd.global_position)
	_guide = _shepherd
	if my_distance > config.lead_radius:
		var nearest := config.view_radius
		for other: Node2D in get_tree().get_nodes_in_group("sheep"):
			if other == self:
				continue
			if other.global_position.distance_to(_shepherd.global_position) > my_distance - GUIDE_AHEAD_MARGIN:
				continue
			var distance := global_position.distance_to(other.global_position)
			if distance < nearest:
				nearest = distance
				_guide = other

	if _gait == Gait.REST:
		var distance := global_position.distance_to(_guide.global_position)
		# Imitation: set off as soon as the guide walks away, not only once it is far.
		var guide_leaving := _speed_of(_guide) >= GUIDE_STOPPED_SPEED and distance > _gap()
		if distance > _gap() + config.trot_margin:
			_gait = Gait.TROT
		elif guide_leaving or distance > _gap() + config.start_margin:
			_gait = Gait.WALK


func _gap() -> float:
	return _shepherd_gap if _guide == _shepherd else config.follow_gap


## True when a stopped sheep stands right in front, closer to the guide: queue behind it.
func _is_blocked(distance_to_guide: float) -> bool:
	for other: Sheep in get_tree().get_nodes_in_group("sheep"):
		if other == self or other._speed >= GUIDE_STOPPED_SPEED:
			continue
		if global_position.distance_to(other.global_position) < config.separation_radius \
				and other.global_position.distance_to(_guide.global_position) < distance_to_guide:
			return true
	return false


func _speed_of(node: Node2D) -> float:
	var body := node as CharacterBody2D
	return body.velocity.length() if body else 0.0


## Push away from sheep closer than separation_radius; magnitude fades from 1 to 0 across the radius.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other: Node2D in get_tree().get_nodes_in_group("sheep"):
		if other == self:
			continue
		var away := global_position - other.global_position
		var distance := away.length()
		if distance >= config.separation_radius:
			continue
		var direction := Vector2.from_angle(randf() * TAU) if distance == 0.0 else away / distance
		push += direction * (1.0 - distance / config.separation_radius)
	return push


func _update_animation() -> void:
	if absf(velocity.x) > config.flip_threshold:
		_set_facing_left(velocity.x < 0.0)

	if _speed > GUIDE_STOPPED_SPEED:
		# Leg cadence follows real speed so feet do not slide.
		_play(&"run", _speed / config.walk_speed)
	else:
		_play(&"idle", 1.0)


func _set_facing_left(left: bool) -> void:
	var side := -1.0 if left else 1.0
	_sprite.flip_h = left
	_sprite.position.x = _sprite_offset_x * side
	_shape.position.x = _shape_offset_x * side


func _play(animation: StringName, speed_scale: float) -> void:
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
		return
	_sprite.speed_scale = speed_scale
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
		if not _animation_started:
			_animation_started = true
			_sprite.frame = randi() % frames.get_frame_count(animation)
			_sprite.frame_progress = randf()
