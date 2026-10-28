class_name Shepherd
extends CharacterBody2D

## Space: calls the dog to switch to its next mode.
signal dog_mode_called

@export var speed: float = 32.0
## Left click: lobs a clod with the crook at the mouse, at most once every throw_cooldown s.
@export var clod_scene: PackedScene
@export var throw_cooldown: float = 0.7
## A trail point is recorded every time the shepherd has walked this far (px).
@export var trail_spacing: float = 6.0
@export var trail_max_points: int = 60

## Minimum |velocity.x| (px/s) to flip the sprite.
const FLIP_THRESHOLD := 5.0
## Height (px) above his feet where a clod leaves the crook.
const THROW_HEIGHT := 10.0

## Past positions, oldest first. The front sheep walk along it instead of cutting toward him.
var _trail: PackedVector2Array = []
var _throw_timer: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_record_trail()
	if Input.is_action_just_pressed("dog_mode"):
		play_call()
		dog_mode_called.emit()
	_throw_timer = maxf(_throw_timer - delta, 0.0)
	if Input.is_action_just_pressed("throw") and _throw_timer <= 0.0 and clod_scene:
		_throw(get_global_mouse_position())
	_update_animation()


## A clod lobbed from the crook to `target`; turns toward it (walking keeps facing the walk).
func _throw(target: Vector2) -> void:
	_throw_timer = throw_cooldown
	var clod := clod_scene.instantiate() as Clod
	add_sibling(clod)
	clod.launch(global_position, target, THROW_HEIGHT)
	play_call()
	if target.x != global_position.x:
		_sprite.flip_h = target.x < global_position.x


## Plays the call animation once (to switch the dog's mode); walking resumes the usual animations.
func play_call() -> void:
	_sprite.play(&"call")


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


## Recorded trail, oldest first (read-only use, e.g. the debug overlay).
func get_trail() -> PackedVector2Array:
	return _trail


func _update_animation() -> void:
	if absf(velocity.x) > FLIP_THRESHOLD:
		_sprite.flip_h = velocity.x < 0.0
	var moving := velocity.length() > 0.0
	# Let a call finish while standing still.
	if not moving and _sprite.animation == &"call" and _sprite.is_playing():
		return
	var animation := &"run" if moving else &"idle"
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _record_trail() -> void:
	if _trail.is_empty() or global_position.distance_to(_trail[-1]) >= trail_spacing:
		_trail.append(global_position)
		if _trail.size() > trail_max_points:
			_trail.remove_at(0)
