class_name Sheep
extends CharacterBody2D

@export var config: FlockConfig

var _speed_factor: float = 1.0
var _shepherd: Node2D
var _animation_started: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_speed_factor = 1.0 + randf_range(-config.speed_variation, config.speed_variation)


func _physics_process(delta: float) -> void:
	if _shepherd == null:
		_shepherd = get_tree().get_first_node_in_group("shepherd") as Node2D
	if _shepherd == null:
		return

	var to_shepherd := _shepherd.global_position - global_position
	var pull := clampf((to_shepherd.length() - config.follow_radius) / config.elastic_width, 0.0, 1.0)
	var max_speed := config.max_speed * _speed_factor
	var desired := to_shepherd.normalized() * max_speed * pull

	velocity = velocity.move_toward(desired, config.acceleration * delta).limit_length(max_speed)
	move_and_slide()
	_update_animation()


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
