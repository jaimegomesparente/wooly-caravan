class_name Wolf
extends CharacterBody2D
## Comes in from off-screen toward the most isolated sheep, stops with a blinking "!", charges,
## then drags the sheep away. The shepherd frees it by reaching the wolf within carry_time.

signal sheep_captured(sheep: Sheep)
signal sheep_lost(sheep: Sheep)

enum State { HIDDEN, PROWL, TELEGRAPH, CHARGE, CARRY, LEAVE }

## Spawns and despawns this far (px) outside the visible screen.
const OFFSCREEN_MARGIN := 24.0
## Must be this far (px) inside the screen edge before telegraphing, so the "!" is seen.
const ONSCREEN_MARGIN := 12.0
## Minimum |velocity.x| (px/s) to flip the placeholder.
const FLIP_THRESHOLD := 5.0

@export var data: EnemyData

var _state: State = State.HIDDEN
var _timer: float = 0.0
var _heading: float = 0.0
var _leave_speed: float = 0.0
var _target: Sheep
var _head_x: float = 0.0

@onready var _head: ColorRect = $Head


func _ready() -> void:
	_head_x = _head.position.x
	_hide(data.first_attack_delay)


## True while charging or dragging a sheep: nearby sheep panic.
func is_dangerous() -> bool:
	return _state == State.CHARGE or _state == State.CARRY


func _physics_process(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
	_timer -= delta
	match _state:
		State.HIDDEN:
			if _timer <= 0.0:
				_appear()
		State.PROWL:
			_prowl(delta)
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			if _target == null:
				_leave(data.prowl_speed)
			elif _timer <= 0.0:
				_state = State.CHARGE
				_timer = data.charge_time
		State.CHARGE:
			_charge(delta)
		State.CARRY:
			_carry(delta)
		State.LEAVE:
			_steer(global_position - _flock_center(), _leave_speed, data.turn_rate, delta)
			if not _view_rect().grow(OFFSCREEN_MARGIN).has_point(global_position):
				_hide(data.attack_interval)
	move_and_slide()
	_update_facing()
	queue_redraw()


func _draw() -> void:
	if _state == State.TELEGRAPH and int(_timer * 8.0) % 2 == 0:
		# Blinking "!" above the head.
		draw_rect(Rect2(-1, -22, 2, 5), Color.RED)
		draw_rect(Rect2(-1, -16, 2, 2), Color.RED)
	if Sheep.debug_draw and _target != null:
		draw_line(Vector2.ZERO, to_local(_target.global_position), Color.MAGENTA, 1.0)


func _appear() -> void:
	_target = _most_isolated_sheep()
	if _target == null:
		_timer = data.attack_interval
		return
	# Come in from the screen edge on the target's side of the flock.
	var view := _view_rect()
	var direction := _target.global_position - _flock_center()
	direction = Vector2.from_angle(randf() * TAU) if direction == Vector2.ZERO else direction.normalized()
	var to_edge := minf(
			view.size.x * 0.5 / maxf(absf(direction.x), 0.001),
			view.size.y * 0.5 / maxf(absf(direction.y), 0.001))
	global_position = view.get_center() + direction * (to_edge + OFFSCREEN_MARGIN)
	_heading = (-direction).angle()
	reset_physics_interpolation()
	visible = true
	_state = State.PROWL


func _prowl(delta: float) -> void:
	if _target == null:
		_target = _most_isolated_sheep()
		if _target == null:
			_leave(data.prowl_speed)
			return
	var to_target := _target.global_position - global_position
	var on_screen := _view_rect().grow(-ONSCREEN_MARGIN).has_point(global_position)
	if on_screen and to_target.length() <= data.prowl_distance:
		velocity = Vector2.ZERO
		_heading = to_target.angle()
		_state = State.TELEGRAPH
		_timer = data.telegraph_time
		return
	_steer(to_target, data.prowl_speed, data.turn_rate, delta)


func _charge(delta: float) -> void:
	if _target == null or not _target.is_in_group("sheep") or _timer <= 0.0:
		_leave(data.prowl_speed)
		return
	var to_target := _target.global_position - global_position
	if to_target.length() <= data.capture_distance:
		_target.capture(self)
		sheep_captured.emit(_target)
		_state = State.CARRY
		_timer = data.carry_time
		return
	_steer(to_target, data.charge_speed, data.charge_turn_rate, delta)


func _carry(delta: float) -> void:
	if _target == null:
		_leave(data.prowl_speed)
		return
	var shepherd := get_tree().get_first_node_in_group("shepherd") as Node2D
	if shepherd and global_position.distance_to(shepherd.global_position) <= data.rescue_radius:
		_target.release()
		_target = null
		_leave(data.charge_speed)
		return
	if _timer <= 0.0:
		sheep_lost.emit(_target)
		_target.queue_free()
		_target = null
		_hide(data.attack_interval)
		return
	_steer(global_position - _flock_center(), data.carry_speed, data.turn_rate, delta)
	# Drag the sheep behind.
	_target.global_position = global_position - Vector2.from_angle(_heading) * data.carry_offset


func _leave(speed: float) -> void:
	_leave_speed = speed
	_state = State.LEAVE


func _hide(delay: float) -> void:
	_state = State.HIDDEN
	_timer = delay
	_target = null
	velocity = Vector2.ZERO
	visible = false


## Turn toward `direction` at a limited rate and move at `speed`.
func _steer(direction: Vector2, speed: float, turn_rate: float, delta: float) -> void:
	if direction != Vector2.ZERO:
		_heading = rotate_toward(_heading, direction.angle(), turn_rate * delta)
	velocity = Vector2.from_angle(_heading) * speed


func _update_facing() -> void:
	var facing_x := velocity.x if velocity.length() > 0.0 else cos(_heading) * FLIP_THRESHOLD * 2.0
	if absf(facing_x) > FLIP_THRESHOLD:
		_head.position.x = -_head_x - _head.size.x if facing_x < 0.0 else _head_x


## The sheep farthest from the flock center (stragglers first).
func _most_isolated_sheep() -> Sheep:
	var center := _flock_center()
	var best: Sheep = null
	var farthest := -1.0
	for sheep: Sheep in get_tree().get_nodes_in_group("sheep"):
		var distance := sheep.global_position.distance_to(center)
		if distance > farthest:
			farthest = distance
			best = sheep
	return best


func _flock_center() -> Vector2:
	var flock := get_tree().get_nodes_in_group("sheep")
	if flock.is_empty():
		return global_position
	var center := Vector2.ZERO
	for sheep: Node2D in flock:
		center += sheep.global_position
	return center / flock.size()


## The part of the world visible on screen.
func _view_rect() -> Rect2:
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	size /= camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)
