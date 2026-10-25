class_name Sheep
extends CharacterBody2D

enum State { IDLE, FOLLOW }

@export var config: FlockConfig

var _state: State = State.IDLE
var _speed_factor: float = 1.0
var _stop_radius: float = 0.0
## Seconds left before setting off; negative while no reaction is pending.
var _reaction_timer: float = -1.0
var _shepherd: Node2D
var _animation_started: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_speed_factor = 1.0 + randf_range(-config.speed_variation, config.speed_variation)
	_stop_radius = randf_range(config.stop_radius_min, config.stop_radius_max)


func _physics_process(delta: float) -> void:
	if _shepherd == null:
		_shepherd = get_tree().get_first_node_in_group("shepherd") as Node2D
	if _shepherd == null:
		return

	var to_shepherd := _shepherd.global_position - global_position
	var distance := to_shepherd.length()
	_update_state(delta, distance)

	var max_speed := config.max_speed * _speed_factor
	var desired := Vector2.ZERO
	if _state == State.FOLLOW:
		var pull := clampf((distance - _stop_radius) / config.elastic_width, 0.0, 1.0)
		desired = to_shepherd.normalized() * maxf(max_speed * pull, config.min_move_speed)
	desired += _separation() * config.separation_strength
	if desired.length() < config.min_move_speed:
		desired = Vector2.ZERO

	velocity = velocity.move_toward(desired, config.acceleration * delta).limit_length(max_speed)
	move_and_slide()
	_update_animation()


func _update_state(delta: float, distance: float) -> void:
	match _state:
		State.IDLE:
			if distance <= config.start_follow_radius:
				_reaction_timer = -1.0
			elif _reaction_timer < 0.0:
				_reaction_timer = randf_range(config.reaction_delay_min, config.reaction_delay_max)
			else:
				_reaction_timer -= delta
				if _reaction_timer <= 0.0:
					_reaction_timer = -1.0
					_state = State.FOLLOW
		State.FOLLOW:
			if distance <= _stop_radius:
				_state = State.IDLE


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
	var speed := velocity.length()
	if absf(velocity.x) > config.flip_threshold:
		_sprite.flip_h = velocity.x < 0.0

	if speed > config.idle_threshold:
		_play(&"run", speed / config.run_reference_speed)
	else:
		_play(&"idle", 1.0)


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
