class_name Shepherd
extends CharacterBody2D

## Space: calls the dog to switch to its next mode.
signal dog_mode_called

@export var speed: float = 32.0
## Left click: lobs clods with the crook at the mouse (base settings in `crook`; the run's powers
## change its copy, from RunManager).
@export var clod_scene: PackedScene
@export var crook: CrookData
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
## On the pasture between two trips: stands still and takes no input.
var resting: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if crook:
		crook = RunManager.crook(crook)


func _physics_process(delta: float) -> void:
	if resting:
		velocity = Vector2.ZERO
		_update_animation()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_record_trail()
	if Input.is_action_just_pressed("dog_mode"):
		play_call()
		dog_mode_called.emit()
	_throw_timer = maxf(_throw_timer - delta, 0.0)
	if Input.is_action_just_pressed("throw") and _throw_timer <= 0.0 and clod_scene and crook:
		_throw(get_global_mouse_position())
	_update_animation()


## clod_count clods lobbed from the crook around `target`, their landing spots `spread` px apart
## across the throw; turns toward it (walking keeps facing the walk).
func _throw(target: Vector2) -> void:
	_throw_timer = crook.throw_cooldown
	var aim := target - global_position
	var across := aim.orthogonal().normalized() if aim != Vector2.ZERO else Vector2.DOWN
	across *= crook.spread
	for i in crook.clod_count:
		var landing := target + across * (i - (crook.clod_count - 1) / 2.0)
		var clod := clod_scene.instantiate() as Clod
		add_sibling(clod)
		clod.launch(crook, global_position, landing, THROW_HEIGHT)
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
