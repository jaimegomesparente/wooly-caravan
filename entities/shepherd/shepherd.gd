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
## Aiming at an enemy: the mouse may be this far (px) outside its body.
const AIM_MARGIN := 2.0

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


## clod_count clods lobbed from the crook at `landing_spots(aim(mouse))`; turns toward it (walking
## keeps facing the walk).
func _throw(mouse: Vector2) -> void:
	_throw_timer = crook.throw_cooldown
	for landing in landing_spots(aim(mouse)):
		var clod := clod_scene.instantiate() as Clod
		add_sibling(clod)
		clod.launch(crook, global_position, landing, THROW_HEIGHT)
	play_call()
	if mouse.x != global_position.x:
		_sprite.flip_h = mouse.x < global_position.x


## What a throw at `mouse` (a point of the world as seen on screen) aims at: x, y a point on the
## ground, z a height (px). The middle of the body of the attacking enemy seen under the mouse (up
## in the air for a flying one), otherwise the ground under the mouse.
func aim(mouse: Vector2) -> Vector3:
	var target: Enemy = null
	var nearest := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_threat():
			continue
		var body := enemy.seen_body().grow(AIM_MARGIN)
		var distance := body.get_center().distance_to(mouse)
		if body.has_point(mouse) and distance < nearest:
			nearest = distance
			target = enemy
	if target:
		return Vector3(target.global_position.x, target.global_position.y, target.aim_height())
	return Vector3(mouse.x, mouse.y, 0.0)


## True when a throw at `mouse` gets there: close enough on the ground, and not too high.
func can_reach(mouse: Vector2) -> bool:
	if crook == null:
		return true
	var target := aim(mouse)
	var close_enough := Vector2(target.x, target.y).distance_to(global_position) <= crook.max_range
	return close_enough and target.z <= crook.max_height


## Where the clods of a throw at `target` (x, y on the ground, z height) end up: clod_count points
## `spread` px apart across the throw, each at most max_range px from his feet (at `from`, his
## position by default) and max_height px high.
func landing_spots(target: Vector3, from: Vector2 = global_position) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	if crook == null:
		return spots
	var ground := Vector2(target.x, target.y)
	var direction := ground - from
	var across := direction.orthogonal().normalized() if direction != Vector2.ZERO else Vector2.DOWN
	across *= crook.spread
	var height := clampf(target.z, 0.0, crook.max_height)
	for i in crook.clod_count:
		var landing := ground + across * (i - (crook.clod_count - 1) / 2.0)
		landing = from + (landing - from).limit_length(crook.max_range)
		spots.append(Vector3(landing.x, landing.y, height))
	return spots


## 1 when a clod can be thrown, rising from 0 through the cooldown after a throw.
func throw_readiness() -> float:
	if crook == null or crook.throw_cooldown <= 0.0:
		return 1.0
	return 1.0 - _throw_timer / crook.throw_cooldown


## Plays the call animation once (to switch the dog's mode); walking resumes the usual animations.
func play_call() -> void:
	_sprite.play(&"call")


## Moved at once (testing aid): the trail starts afresh there.
func teleport(point: Vector2) -> void:
	global_position = point
	_trail.clear()
	reset_physics_interpolation()


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
