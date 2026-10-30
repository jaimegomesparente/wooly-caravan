class_name Eagle
extends Enemy
## Sent by the AttackDirector for one attack. Its position is the point on the ground below it (its
## shadow); `_altitude` lifts the bird above it. Only its shadow shows at first, crossing the screen
## from left to right; then it picks the most isolated sheep on screen (none free on screen: it
## passes again up to max_passes, then gives up), puts a sight on it, and dives from the top right
## corner of the screen, its shadow growing below it, grabbing it wherever it is. The caught sheep
## is carried off to the left, climbing: lost once out of the screen or too high. A bark from the
## dog below makes it drop the sheep or give up the dive. It always flies off toward the top left
## corner, gone once out of sight.

enum State { WAITING, PASS, TELEGRAPH, DIVE, CARRY, LEAVE }

## Altitude (px) while passing: the bird is out of the screen, only its shadow shows.
const PASS_ALTITUDE := 240.0
## Height (px) of a sheep: the sight is centered this high above its feet, half way.
const SHEEP_HEIGHT := 10.0
const SIGHT_COLOR := Color("#c0242c")
## Half size (px) of the sight around the target's body, and length of its corners.
const SIGHT_HALF := 8.0
const SIGHT_CORNER := 3.0
## A target must stand this far (px) inside the screen edges, its sight included.
const SCREEN_INSET := 16.0
## Size (px) of a frame of the shadow mask (as in shadow_mask.gdshader).
const SHADOW_FRAME := Vector2(32, 48)

@export var data: EagleData

var _state: State = State.WAITING
var _timer: float = 0.0
var _passes: int = 0
var _altitude: float = PASS_ALTITUDE
var _target: Sheep
var _prey: Sheep
## Where the dive starts (ground point and altitude).
var _dive_from: Vector2
var _dive_altitude: float = 0.0
## This pass's slope (px/s), shadow scale and flapping speed.
var _pass_drift: float = 0.0
var _pass_shadow_scale: float = 1.0
var _pass_flap_speed: float = 1.0

## Flapping silhouette, head to the left like the bird, cast over the ground and everything on it.
@onready var _shadow: AnimatedSprite2D = $Shadow
## Always facing left (every move on screen goes left), its talons at its origin.
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
## Where the carried sheep's feet hang, below the talons (also the altitude it grabs at).
@onready var _prey_point: Marker2D = $AnimatedSprite2D/PreyPoint
## The body in the air (for the sling later), lifted with the sprite.
@onready var _body: CollisionShape2D = $CollisionShape2D
@onready var _body_y: float = _body.position.y


## Starts the attack: the first pass.
func attack() -> void:
	# Above everything, its shadow (z 1) included.
	z_index = 2
	_start_pass()


func is_dangerous() -> bool:
	return _state == State.CARRY


func is_threat() -> bool:
	return _state == State.DIVE or _state == State.CARRY


## Barked at by the dog: drops the carried sheep, or gives up the dive, and flies off.
func scare() -> void:
	if _state == State.CARRY and _prey:
		_prey.release()
		_prey = null
		_leave()
	elif _state == State.DIVE:
		_leave()


func _physics_process(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
	if _prey != null and not is_instance_valid(_prey):
		_prey = null
	_timer -= delta
	match _state:
		State.WAITING:
			return
		State.PASS:
			global_position += Vector2(data.pass_speed, _pass_drift) * delta
			if global_position.x > _view_rect().end.x + OFFSCREEN_MARGIN:
				_end_pass()
		State.TELEGRAPH:
			if _target == null or not _target.is_in_group("sheep"):
				_leave()
			elif _timer <= 0.0:
				_start_dive()
		State.DIVE:
			_dive()
		State.CARRY:
			_carry(delta)
		State.LEAVE:
			global_position.x -= data.leave_speed * _speed_scale * delta
			_altitude += data.leave_speed * 0.5 * _speed_scale * delta
			_hold_prey()
			if global_position.x < _view_rect().position.x - OFFSCREEN_MARGIN:
				if _prey:
					_prey.queue_free()
				queue_free()
	_update_shadow()
	_update_sprite()
	queue_redraw()


func _draw() -> void:
	if _state == State.TELEGRAPH and _target:
		_draw_sight(to_local(_target.global_position + Vector2(0, -SHEEP_HEIGHT / 2.0)).round())
	if Sheep.debug_draw and _target != null:
		draw_line(Vector2.ZERO, to_local(_target.global_position), Color.MAGENTA, 1.0)


## Four corner brackets around `center`.
func _draw_sight(center: Vector2) -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var tip := center + corner * SIGHT_HALF
		# Horizontal then vertical arm, each a 1 px rect pointing back toward the center.
		var arm_x := Rect2(tip, Vector2(-corner.x * SIGHT_CORNER, 1.0)).abs()
		var arm_y := Rect2(tip, Vector2(1.0, -corner.y * SIGHT_CORNER)).abs()
		draw_rect(arm_x, SIGHT_COLOR)
		draw_rect(arm_y, SIGHT_COLOR)


## From the left screen edge, about at the height of the flock center, each pass a little different.
func _start_pass() -> void:
	_passes += 1
	_altitude = PASS_ALTITUDE
	var height := _flock_center().y + randf_range(-data.pass_height_spread, data.pass_height_spread)
	global_position = Vector2(_view_rect().position.x - OFFSCREEN_MARGIN, height)
	_pass_drift = randf_range(-data.pass_drift, data.pass_drift)
	var sixteenths := roundi(data.pass_shadow_scale * 16.0) \
			+ randi_range(-data.pass_shadow_steps, data.pass_shadow_steps)
	_pass_shadow_scale = maxi(sixteenths, 1) / 16.0
	_pass_flap_speed = 1.0 + randf_range(-data.pass_flap_variation, data.pass_flap_variation)
	reset_physics_interpolation()
	visible = true
	_state = State.PASS


func _end_pass() -> void:
	_target = _most_isolated_sheep()
	if _target:
		_state = State.TELEGRAPH
		_timer = data.telegraph_time
	elif _passes < data.max_passes:
		_start_pass()
	else:
		queue_free()


## From the top right corner of the screen, so the bird comes in sight right away.
func _start_dive() -> void:
	var view := _view_rect()
	_dive_from = Vector2(view.end.x + OFFSCREEN_MARGIN, _target.global_position.y)
	_dive_altitude = _target.global_position.y - view.position.y
	global_position = _dive_from
	_altitude = _dive_altitude
	reset_physics_interpolation()
	_timer = data.dive_time
	_state = State.DIVE


## Straight down at the target, wherever it runs, and grabs it on landing.
func _dive() -> void:
	if _target == null or not _target.is_in_group("sheep"):
		_leave()
		return
	var t := clampf(1.0 - _timer / data.dive_time, 0.0, 1.0)
	global_position = _dive_from.lerp(_target.global_position, t)
	_altitude = lerpf(_dive_altitude, _prey_point.position.y, t)
	if t < 1.0:
		return
	if _target.fends_off(self):
		# Butted by a ram: gives up whatever its health.
		_leave()
		return
	_target.capture(self, true)
	_prey = _target
	sheep_captured.emit(_prey)
	_state = State.CARRY
	_sprite.play(&"grab")


## Off to the left, slowly climbing; the sheep is lost once out of the screen or too high.
func _carry(delta: float) -> void:
	if _prey == null:
		_leave()
		return
	# Slowed by mud, it climbs and flies off more slowly too.
	global_position.x -= data.carry_speed * _speed_scale * delta
	_altitude += data.climb_speed * _speed_scale * delta
	_hold_prey()
	if _altitude >= data.carry_altitude_max or global_position.x < _view_rect().position.x:
		sheep_lost.emit(_prey)
		_leave()


func _hold_prey() -> void:
	if _prey:
		_prey.global_position = _prey_point.global_position


func _leave() -> void:
	_target = null
	_state = State.LEAVE


## Out of sight while passing and aiming; folded wings in the dive, then grabbing (once) and
## flapping.
func _update_sprite() -> void:
	_sprite.visible = _state == State.DIVE or _state == State.CARRY or _state == State.LEAVE
	_sprite.position.y = -roundf(_altitude)
	_body.position.y = _body_y + _sprite.position.y
	var animation := &"dive" if _state == State.DIVE else &"fly"
	if _sprite.animation == &"grab" and _sprite.is_playing():
		animation = &"grab"
	if _sprite.animation != animation:
		_sprite.play(animation)


## Right below the bird, facing its way, growing by sixteenths as the bird comes down (this pass's
## size while passing, so it stays easy to spot); flapping fast once the attack is over.
func _update_shadow() -> void:
	_shadow.visible = _state != State.WAITING and _state != State.TELEGRAPH
	_shadow.flip_h = _state == State.PASS
	var animation := &"fast_flap" if _state == State.CARRY or _state == State.LEAVE else &"flap"
	if _shadow.animation != animation:
		_shadow.play(animation)
	_shadow.speed_scale = _pass_flap_speed if _state == State.PASS else 1.0
	var t := clampf(_altitude / data.shadow_fade_altitude, 0.0, 1.0)
	var shadow_scale := _pass_shadow_scale if _state == State.PASS \
			else roundf(lerpf(1.0, data.shadow_min_scale, t) * 16.0) / 16.0
	if _shadow.scale.x != shadow_scale:
		_shadow.scale = Vector2.ONE * shadow_scale
		_shadow.set_instance_shader_parameter(&"size", SHADOW_FRAME * shadow_scale)


## The sheep whose nearest neighbor is the farthest, among those on screen (so the sight and the
## dive can be seen) that no other eagle is after.
func _most_isolated_sheep() -> Sheep:
	var view := _view_rect().grow(-SCREEN_INSET)
	var taken: Array[Sheep] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var eagle := enemy as Eagle
		if eagle and eagle != self and eagle._target:
			taken.append(eagle._target)
	var best: Sheep = null
	var farthest := -1.0
	for sheep: Sheep in get_tree().get_nodes_in_group("sheep"):
		if sheep in taken or not view.has_point(sheep.global_position):
			continue
		var distance := _nearest_neighbor_distance(sheep)
		if distance > farthest:
			farthest = distance
			best = sheep
	return best


func _nearest_neighbor_distance(sheep: Sheep) -> float:
	var nearest := INF
	for other: Node2D in get_tree().get_nodes_in_group("sheep"):
		if other != sheep:
			nearest = minf(nearest, sheep.global_position.distance_to(other.global_position))
	return nearest
