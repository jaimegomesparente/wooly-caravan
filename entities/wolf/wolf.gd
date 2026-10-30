class_name Wolf
extends Enemy
## Sent by the AttackDirector for one attack: comes out of a forest edge beside the most isolated
## sheep on its side of the flock and howls there with a blinking "!" (at the screen edge while the
## wolf is off screen), charges until it catches a sheep, then backs away to the nearest edge,
## dragging it. The shepherd frees it by reaching the wolf first; once the sheep crosses the edge,
## it is lost. A bark from the dog makes it drop the sheep or give up. Gone once out of sight.

enum State { WAITING, PROWL, TELEGRAPH, CHARGE, CARRY, LEAVE }
## Which forest edge it comes out of: the one nearest its target, or a given one.
enum Edge { NEAREST, TOP, BOTTOM }

## The "!" stays this far (px) inside the screen edge.
const ALERT_MARGIN := 8.0
## The "!" above the head, from the wolf's feet.
const ALERT_OFFSET := Vector2(0, -18)
## Minimum |velocity.x| (px/s) to flip the sprite.
const FLIP_THRESHOLD := 5.0
## Switches to another sheep only if it is clearly better by this much (px): farther from the flock
## center while approaching, closer to the wolf while charging.
const RETARGET_MARGIN := 16.0

@export var data: EnemyData

var _state: State = State.WAITING
## Its forest edge, and its half of the flock (top or bottom) when picking a target.
var _edge: Edge = Edge.NEAREST
var _timer: float = 0.0
var _heading: float = 0.0
var _leave_speed: float = 0.0
var _target: Sheep
## The sheep being dragged away (kept after it is lost, until the wolf is out of sight).
var _prey: Sheep

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
## Where the caught sheep stands (its feet), facing right; mirrored when the sprite is flipped.
@onready var _prey_point: Marker2D = $PreyPoint


## Starts the attack from `edge`; returns the edge taken (never NEAREST). With no sheep left, the
## wolf is freed at once.
func attack(edge: Edge = Edge.NEAREST) -> Edge:
	_edge = edge
	_target = _most_isolated_sheep()
	if _target == null:
		queue_free()
		return Edge.TOP
	if _edge == Edge.NEAREST:
		var band := _band()
		var y := _target.global_position.y
		_edge = Edge.TOP if y - band.position.y < band.end.y - y else Edge.BOTTOM
	_appear()
	return _edge


## True while charging or dragging a sheep: nearby sheep panic.
func is_dangerous() -> bool:
	return _state == State.CHARGE or _state == State.CARRY


## True from the moment it shows up until it leaves: the dog may chase it.
func is_threat() -> bool:
	return _state == State.PROWL or _state == State.TELEGRAPH or _state == State.CHARGE \
			or _state == State.CARRY


## Barked at by the dog: drops the dragged sheep, or gives up the attack, and runs off.
func scare() -> void:
	if _state == State.CARRY and _prey:
		_let_go()
	elif is_threat():
		_leave(data.charge_speed)


func _physics_process(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
	if _prey != null and not is_instance_valid(_prey):
		_prey = null
	_timer -= delta
	if _stun_timer > 0.0:
		# Butted by a ram: stands frozen, then goes on.
		_stun_timer -= delta
		velocity = Vector2.ZERO
		_sprite.pause()
		if _stun_timer <= 0.0:
			_sprite.play()
		return
	match _state:
		State.WAITING:
			return
		State.PROWL:
			_prowl(delta)
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			if _target == null:
				_leave(data.prowl_speed)
			elif _timer <= 0.0 and not _sprite.is_playing():
				# Charges once both the telegraph time and the howl are over.
				_state = State.CHARGE
		State.CHARGE:
			_charge(delta)
		State.CARRY:
			_carry(delta)
		State.LEAVE:
			_steer(_exit_direction(), _leave_speed, data.turn_rate, delta)
			_drag_prey()
			var out_of_band := not _band().has_point(global_position)
			if out_of_band and not _view_rect().grow(OFFSCREEN_MARGIN).has_point(global_position):
				_vanish()
	move_and_slide()
	_update_facing()
	_update_animation()
	queue_redraw()


func _draw() -> void:
	if _state == State.TELEGRAPH and int(_timer * 8.0) % 2 == 0:
		# Blinking "!" above the head, held inside the screen edge while the wolf is off screen.
		var view := _view_rect().grow(-ALERT_MARGIN)
		var alert := global_position + ALERT_OFFSET
		alert = alert.clamp(view.position, view.end)
		alert = (to_local(alert)).round()
		draw_rect(Rect2(alert + Vector2(-1, -4), Vector2(2, 5)), Color.RED)
		draw_rect(Rect2(alert + Vector2(-1, 2), Vector2(2, 2)), Color.RED)
	if Sheep.debug_draw and _target != null:
		draw_line(Vector2.ZERO, to_local(_target.global_position), Color.MAGENTA, 1.0)


func _appear() -> void:
	var view := _view_rect()
	var trail := _trail()
	if trail:
		# Come out of its forest edge, beside the target and out of sight.
		var band := trail.bounds()
		var x := clampf(_target.global_position.x + randf_range(-40.0, 40.0), band.position.x, band.end.x)
		var y := minf(band.position.y, view.position.y) - OFFSCREEN_MARGIN if _edge == Edge.TOP \
				else maxf(band.end.y, view.end.y) + OFFSCREEN_MARGIN
		global_position = Vector2(x, y)
	else:
		# Come in from the screen edge on the target's side of the flock.
		var direction := _target.global_position - _flock_center()
		direction = Vector2.from_angle(randf() * TAU) if direction == Vector2.ZERO else direction.normalized()
		var to_edge := minf(
				view.size.x * 0.5 / maxf(absf(direction.x), 0.001),
				view.size.y * 0.5 / maxf(absf(direction.y), 0.001))
		global_position = view.get_center() + direction * (to_edge + OFFSCREEN_MARGIN)
	_heading = (_target.global_position - global_position).angle()
	reset_physics_interpolation()
	visible = true
	_state = State.PROWL


## Walks toward the most isolated sheep (re-chosen on the way if another strays clearly farther) and
## stops to telegraph as soon as it comes out of the forest edge, on screen or not.
func _prowl(delta: float) -> void:
	var isolated := _most_isolated_sheep()
	if isolated == null:
		_leave(data.prowl_speed)
		return
	if _target == null or not _target.is_in_group("sheep"):
		_target = isolated
	elif isolated != _target:
		var center := _flock_center()
		if isolated.global_position.distance_to(center) \
				> _target.global_position.distance_to(center) + RETARGET_MARGIN:
			_target = isolated
	var to_target := _target.global_position - global_position
	if _band().has_point(global_position):
		velocity = Vector2.ZERO
		_heading = to_target.angle()
		_state = State.TELEGRAPH
		_timer = data.telegraph_time
		return
	_steer(to_target, data.prowl_speed, data.turn_rate, delta)


## Runs at the target until it catches a sheep: never gives up, but switches to another sheep when
## the target is gone or another one is clearly closer (it grabs whatever it can reach first).
func _charge(delta: float) -> void:
	var nearest := _nearest_sheep()
	if nearest == null:
		_leave(data.prowl_speed)
		return
	if _target == null or not _target.is_in_group("sheep") \
			or global_position.distance_to(nearest.global_position) + RETARGET_MARGIN \
			< global_position.distance_to(_target.global_position):
		_target = nearest
	var to_target := _target.global_position - global_position
	if to_target.length() <= data.capture_distance:
		if _target.fends_off(self):
			return
		_target.capture(self)
		_prey = _target
		sheep_captured.emit(_target)
		_state = State.CARRY
		# Backs away from the sheep, so it never turns around.
		velocity = Vector2.ZERO
		_heading = 0.0 if _sprite.flip_h else PI
		_drag_prey()
		return
	_steer(to_target, data.charge_speed, data.charge_turn_rate, delta)


func _carry(delta: float) -> void:
	if _prey == null:
		_leave(data.prowl_speed)
		return
	var shepherd := get_tree().get_first_node_in_group("shepherd") as Node2D
	if shepherd and global_position.distance_to(shepherd.global_position) <= data.rescue_radius:
		_let_go()
		return
	if not _band().has_point(_prey.global_position):
		# Into the forest: the sheep is lost; the wolf keeps dragging it out of sight.
		sheep_lost.emit(_prey)
		_leave(data.carry_speed)
		return
	_steer(_exit_direction(), data.carry_speed, data.turn_rate, delta)
	_drag_prey()


## Keep the caught sheep at the prey point, in front of the muzzle.
func _drag_prey() -> void:
	if _prey:
		var point := _prey_point.position
		if _sprite.flip_h:
			point.x = -point.x
		_prey.global_position = global_position + point


## Drops the dragged sheep (freed, it panics back to the flock) and runs off.
func _let_go() -> void:
	_prey.release()
	_prey = null
	_leave(data.charge_speed)


func _leave(speed: float) -> void:
	_target = null
	_leave_speed = speed
	_state = State.LEAVE


## Out of sight after the attack: gone, with the lost sheep it may still drag.
func _vanish() -> void:
	if _prey:
		_prey.queue_free()
	queue_free()


## Turn toward `direction` at a limited rate and move at `speed` (less while slowed by mud).
func _steer(direction: Vector2, speed: float, turn_rate: float, delta: float) -> void:
	if direction != Vector2.ZERO:
		_heading = rotate_toward(_heading, direction.angle(), turn_rate * delta)
	velocity = Vector2.from_angle(_heading) * speed * _speed_scale


func _update_facing() -> void:
	var facing_x := velocity.x
	if _prey:
		# Backs away while dragging, facing the sheep.
		facing_x = -facing_x
	elif velocity == Vector2.ZERO:
		facing_x = cos(_heading) * FLIP_THRESHOLD * 2.0
	if absf(facing_x) > FLIP_THRESHOLD:
		_sprite.flip_h = facing_x < 0.0


## Howls once while telegraphing, drags while holding a sheep, otherwise runs or stands.
func _update_animation() -> void:
	var animation := &"idle"
	if _state == State.TELEGRAPH:
		animation = &"howl"
	elif _prey:
		animation = &"drag"
	elif velocity.length() > 0.0:
		animation = &"run"
	if _sprite.animation != animation:
		_sprite.play(animation)


## The sheep farthest from the flock center (stragglers first), in the wolf's half of the flock
## (any sheep when that half is empty or the side is not chosen yet).
func _most_isolated_sheep() -> Sheep:
	var center := _flock_center()
	var best: Sheep = null
	var farthest := -1.0
	for sheep: Sheep in get_tree().get_nodes_in_group("sheep"):
		var above := sheep.global_position.y <= center.y
		if (_edge == Edge.TOP and not above) or (_edge == Edge.BOTTOM and above):
			continue
		var distance := sheep.global_position.distance_to(center)
		if distance > farthest:
			farthest = distance
			best = sheep
	if best == null and _edge != Edge.NEAREST:
		var edge := _edge
		_edge = Edge.NEAREST
		best = _most_isolated_sheep()
		_edge = edge
	return best


func _nearest_sheep() -> Sheep:
	var nearest: Sheep = null
	var nearest_distance := INF
	for sheep: Sheep in get_tree().get_nodes_in_group("sheep"):
		var distance := global_position.distance_to(sheep.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = sheep
	return nearest


func _trail() -> Ground:
	return get_tree().get_first_node_in_group("trail") as Ground


## The walkable band, or the visible screen when there is no trail.
func _band() -> Rect2:
	var trail := _trail()
	return trail.bounds() if trail else _view_rect()


## Toward the nearest forest edge (top or bottom), or away from the flock without a trail.
func _exit_direction() -> Vector2:
	if _trail() == null:
		return global_position - _flock_center()
	var band := _band()
	return Vector2.UP if global_position.y - band.position.y < band.end.y - global_position.y else Vector2.DOWN
