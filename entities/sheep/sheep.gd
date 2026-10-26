class_name Sheep
extends CharacterBody2D

enum Gait { REST, WALK, TROT, WANDER }
## Sub-states of REST: head up, lowering the head, grazing, raising the head.
enum Rest { STAND, LOWERING, GRAZING, RAISING }

## Below this speed (px/s) a body counts as stopped.
const GUIDE_STOPPED_SPEED := 2.0
## A guide sheep must be at least this much closer (px) to the shepherd, so guides never loop.
const GUIDE_AHEAD_MARGIN := 4.0
## A guide is kept until it is this much beyond lead_radius / view_radius.
const GUIDE_KEEP_SLACK := 1.25
## A wander step ends this close (px) to its target, or after this many seconds.
const WANDER_ARRIVE_DISTANCE := 2.0
const WANDER_TIMEOUT := 3.0

## Toggled by the debug overlay (F3): each sheep draws a line to its target and a state dot.
static var debug_draw: bool = false

@export var config: FlockConfig

var _gait: Gait = Gait.REST
var _rest: Rest = Rest.STAND
var _rest_timer: float = 0.0
## Gait to take once the head is up again; REST means none.
var _pending_gait: Gait = Gait.REST
## Point of the shepherd's trail when this sheep settled; INF until the shepherd is known.
var _rest_anchor: Vector2 = Vector2.INF
var _wander_target: Vector2
var _wander_timer: float = 0.0
var _fleeing: bool = false
var _debug_drawn: bool = false
var _heading: float = 0.0
var _speed: float = 0.0
var _speed_factor: float = 1.0
var _shepherd_gap: float = 0.0
var _think_timer: float = 0.0
## The shepherd, or the sheep ahead that this sheep follows.
var _guide: Node2D
var _shepherd: Shepherd
var _animation_started: bool = false
## Horizontal offsets of the sprite and collision when facing right, mirrored when flipped.
var _sprite_offset_x: float = 0.0
var _shape_offset_x: float = 0.0
var _sprite_offset_y: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sprite_offset_x = _sprite.position.x
	_shape_offset_x = _shape.position.x
	_sprite_offset_y = _sprite.position.y
	_speed_factor = 1.0 + randf_range(-config.speed_variation, config.speed_variation)
	_shepherd_gap = config.shepherd_gap * (1.0 + randf_range(-config.speed_variation, config.speed_variation))
	_heading = randf() * TAU
	_set_facing_left(cos(_heading) < 0.0)
	_think_timer = randf_range(0.0, config.think_interval_max)
	_sprite.animation_finished.connect(_on_animation_finished)
	_enter_rest()


func _physics_process(delta: float) -> void:
	if _shepherd == null:
		_shepherd = get_tree().get_first_node_in_group("shepherd") as Shepherd
	if _shepherd == null:
		return

	var separation := _separation()
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = randf_range(config.think_interval_min, config.think_interval_max)
		_think()

	var desired := _flee_from(_shepherd.global_position, _shepherd.velocity, config.flight_radius)
	if desired == Vector2.ZERO:
		match _gait:
			Gait.REST:
				desired = _rest_step(delta, separation)
			Gait.WANDER:
				desired = _wander_step(delta, separation)
			_:
				desired = _follow_step(separation)

	# A startled sheep turns and speeds up faster.
	var reflex := config.flight_reflex if _fleeing else 1.0
	if desired != Vector2.ZERO:
		_heading = rotate_toward(_heading, desired.angle(), config.turn_rate * reflex * delta)
	_speed = move_toward(_speed, desired.length(), config.acceleration * reflex * delta)
	velocity = Vector2.from_angle(_heading) * _speed
	move_and_slide()
	_update_animation()
	# Redraw while debugging, plus once after it is turned off to clear the lines.
	if debug_draw or _debug_drawn:
		queue_redraw()
	_debug_drawn = debug_draw


func _draw() -> void:
	if not debug_draw:
		return
	var target := _wander_target if _gait == Gait.WANDER else _guide_target() if _guide else global_position
	draw_line(Vector2.ZERO, to_local(target), _debug_color(), 1.0)
	draw_rect(Rect2(-1, -15, 3, 3), _debug_color())


func _debug_color() -> Color:
	if _fleeing:
		return Color.RED
	match _gait:
		Gait.WALK:
			return Color.DODGER_BLUE
		Gait.TROT:
			return Color.ORANGE
		Gait.WANDER:
			return Color.MEDIUM_PURPLE
	return Color.YELLOW_GREEN if _rest == Rest.GRAZING or _rest == Rest.LOWERING else Color.WHITE


## Keep or pick a guide (shepherd or the nearest sheep ahead) and decide whether to set off.
func _think() -> void:
	var my_distance := global_position.distance_to(_shepherd.global_position)
	if not _guide_still_valid(my_distance):
		_guide = _pick_guide(my_distance)

	if _gait == Gait.REST or _gait == Gait.WANDER:
		var distance := global_position.distance_to(_guide_target())
		var set_off := false
		if _guide == _shepherd:
			# Front sheep set off once the shepherd's trail has really moved since they settled;
			# a straggler with no sheep ahead in view sets off when it is far from the trail.
			set_off = _rest_anchor.distance_to(_shepherd.trail_point(config.trail_lag)) > config.shepherd_start_margin \
					or distance > config.catch_up_distance
		elif _is_travelling(_guide):
			# Imitation: the others follow the sheep ahead when it walks away, with some hesitation.
			set_off = distance > _gap() and randf() < config.imitation_chance
		if set_off:
			_request_gait(Gait.TROT if distance > _gap() + config.trot_margin else Gait.WALK)


## A guide is kept while it stays roughly valid (with some slack), so sheep do not switch guides
## every think and zigzag in the column.
func _guide_still_valid(my_distance: float) -> bool:
	if _guide == null or not is_instance_valid(_guide):
		return false
	if _guide == _shepherd:
		return my_distance <= config.lead_radius * GUIDE_KEEP_SLACK
	var ahead := _guide.global_position.distance_to(_shepherd.global_position) < my_distance
	return ahead and global_position.distance_to(_guide.global_position) <= config.view_radius * GUIDE_KEEP_SLACK


func _pick_guide(my_distance: float) -> Node2D:
	if my_distance <= config.lead_radius:
		return _shepherd
	var guide: Node2D = _shepherd
	var nearest := config.view_radius
	for other: Node2D in get_tree().get_nodes_in_group("sheep"):
		if other == self:
			continue
		if other.global_position.distance_to(_shepherd.global_position) > my_distance - GUIDE_AHEAD_MARGIN:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < nearest:
			nearest = distance
			guide = other
	return guide


## Start walking or trotting; a grazing sheep raises its head first.
func _request_gait(gait: Gait) -> void:
	if _gait == Gait.REST and _rest != Rest.STAND:
		_pending_gait = gait
		if _rest != Rest.RAISING:
			_set_rest(Rest.RAISING)
		return
	_gait = gait


func _enter_rest() -> void:
	_rest_anchor = _shepherd.trail_point(config.trail_lag) if _shepherd else Vector2.INF
	_gait = Gait.REST
	_pending_gait = Gait.REST
	_set_rest(Rest.STAND)


func _set_rest(state: Rest) -> void:
	_rest = state
	match state:
		Rest.STAND:
			_rest_timer = randf_range(config.stand_time_min, config.stand_time_max)
		Rest.LOWERING:
			if not _has_frames(&"to_graze"):
				_set_rest(Rest.GRAZING)
		Rest.GRAZING:
			_rest_timer = randf_range(config.graze_time_min, config.graze_time_max)
		Rest.RAISING:
			if not _has_frames(&"finished_graze"):
				_finish_raising()


func _finish_raising() -> void:
	var next := _pending_gait
	_set_rest(Rest.STAND)
	_pending_gait = Gait.REST
	if next != Gait.REST:
		_gait = next


func _on_animation_finished() -> void:
	if _gait != Gait.REST:
		return
	if _rest == Rest.LOWERING:
		_set_rest(Rest.GRAZING)
	elif _rest == Rest.RAISING:
		_finish_raising()


## Standing: step aside when crowded, then graze or wander. Returns the desired velocity.
func _rest_step(delta: float, separation: Vector2) -> Vector2:
	match _rest:
		Rest.STAND:
			if separation.length() > config.shuffle_threshold:
				return separation.normalized() * config.walk_speed * _speed_factor * 0.5
			_rest_timer -= delta
			if _rest_timer <= 0.0:
				# Sheep on the edge of the flock step inward more often, so a stopped column gathers.
				var flock_radius := config.follow_gap * sqrt(get_tree().get_node_count_in_group("sheep")) * 0.6
				var on_edge := global_position.distance_to(_flock_center()) > flock_radius
				var chance := config.edge_wander_chance if on_edge else config.wander_chance
				if _nearest_neighbor_distance() > config.isolation_radius or randf() < chance:
					_start_wander()
				else:
					_set_rest(Rest.LOWERING)
		Rest.GRAZING:
			_rest_timer -= delta
			if _rest_timer <= 0.0:
				_set_rest(Rest.RAISING)
	return Vector2.ZERO


## A few slow steps, biased toward the neighbors' and the flock's center so no sheep drifts away
## alone and a stopped column slowly gathers into a group.
func _start_wander() -> void:
	var center := Vector2.ZERO
	var count := 0
	for other: Node2D in get_tree().get_nodes_in_group("sheep"):
		if other != self and global_position.distance_to(other.global_position) < config.cohesion_radius:
			center += other.global_position
			count += 1
	var flock_center := _flock_center()

	var to_center := (center / count - global_position) if count > 0 else _shepherd.global_position - global_position
	var direction := Vector2.from_angle(randf() * TAU)
	var distance := randf_range(config.wander_distance_min, config.wander_distance_max)
	if count == 0 or _nearest_neighbor_distance() > config.isolation_radius:
		direction = to_center.normalized()
		distance = maxf(distance, to_center.length() - config.isolation_radius * 0.5)
	else:
		direction += to_center.normalized() + (flock_center - global_position).normalized() * config.flock_center_weight
		direction = direction.normalized()

	_wander_target = global_position + direction * distance
	_wander_timer = WANDER_TIMEOUT
	_gait = Gait.WANDER


func _wander_step(delta: float, separation: Vector2) -> Vector2:
	var to_target := _wander_target - global_position
	_wander_timer -= delta
	if to_target.length() < WANDER_ARRIVE_DISTANCE or _wander_timer <= 0.0:
		_enter_rest()
		return Vector2.ZERO
	var direction := (to_target.normalized() + separation * config.separation_strength).normalized()
	return direction * config.walk_speed * _speed_factor * config.wander_speed_factor


## Step away from a threat closer than `radius`, sideways to its path so the flock parts in front
## of it. Returns the desired velocity, or zero when not fleeing. Reused later for the dog.
func _flee_from(threat_position: Vector2, threat_velocity: Vector2, radius: float) -> Vector2:
	var away := global_position - threat_position
	var distance := away.length()
	if distance > radius + (config.flight_margin if _fleeing else 0.0):
		_fleeing = false
		return Vector2.ZERO

	if not _fleeing and _gait == Gait.REST and _rest != Rest.STAND:
		# Startled: the head comes up at once, no finished_graze.
		_set_rest(Rest.STAND)
		_pending_gait = Gait.REST
	_fleeing = true

	var direction := Vector2.from_angle(randf() * TAU) if distance == 0.0 else away / distance
	if threat_velocity.length() > GUIDE_STOPPED_SPEED:
		var side := threat_velocity.normalized().orthogonal()
		# Mostly sideways: running ahead of a faster threat only gets the sheep caught up.
		direction = (direction * 0.5 + side * signf(side.dot(away) + 0.001)).normalized()
	var walk := config.walk_speed * _speed_factor
	var speed := config.trot_speed * _speed_factor if threat_velocity.length() > walk else walk
	return direction * speed


## Walk or trot after the guide. Once the guide has stopped, keep walking toward the front of the
## flock around the others and stop on reaching the group, so the column gathers like a flock
## arriving on a pasture. Returns the desired velocity.
func _follow_step(separation: Vector2) -> Vector2:
	var guide_moving := _is_travelling(_guide)
	var target := _guide_target() if guide_moving else _shepherd.trail_point(config.trail_lag)
	var gap := _gap() if guide_moving else _shepherd_gap
	var to_guide := target - global_position
	var distance := to_guide.length()
	if not guide_moving and (distance < gap + config.follow_start_margin \
			or separation.length() > config.crowd_stop_threshold):
		_enter_rest()
		return Vector2.ZERO
	if _gait == Gait.WALK and distance > gap + config.trot_margin:
		_gait = Gait.TROT
	elif _gait == Gait.TROT and distance < gap + config.trot_margin * 0.5:
		_gait = Gait.WALK

	var direction := (to_guide.normalized() + separation * config.separation_strength).normalized()
	if _gait == Gait.TROT:
		return direction * config.trot_speed * _speed_factor
	# Close behind a moving guide, match its pace instead of bumping into it.
	var walk := config.walk_speed * _speed_factor
	var speed := walk if distance > gap + config.follow_start_margin * 0.5 else minf(walk, _speed_of(_guide))
	return direction * speed


## Where this sheep heads: a point on the shepherd's trail, or the sheep ahead.
func _guide_target() -> Vector2:
	return _shepherd.trail_point(config.trail_lag) if _guide == _shepherd else _guide.global_position


func _gap() -> float:
	return _shepherd_gap if _guide == _shepherd else config.follow_gap


## True for a walking shepherd or a sheep walking/trotting after its own guide (not a sheep wandering at rest).
func _is_travelling(node: Node2D) -> bool:
	var sheep := node as Sheep
	if sheep:
		return sheep._gait == Gait.WALK or sheep._gait == Gait.TROT
	return _speed_of(node) >= GUIDE_STOPPED_SPEED


func _speed_of(node: Node2D) -> float:
	var body := node as CharacterBody2D
	return body.velocity.length() if body else 0.0


func _flock_center() -> Vector2:
	var center := Vector2.ZERO
	var flock := get_tree().get_nodes_in_group("sheep")
	for other: Node2D in flock:
		center += other.global_position
	return center / flock.size()


func _nearest_neighbor_distance() -> float:
	var nearest := INF
	for other: Node2D in get_tree().get_nodes_in_group("sheep"):
		if other != self:
			nearest = minf(nearest, global_position.distance_to(other.global_position))
	return nearest


## Push away from sheep closer than separation_radius; magnitude fades from 1 to 0 across the radius.
## The shepherd also pushes, over twice the flight radius, so walking sheep curve around him.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	var from_shepherd := global_position - _shepherd.global_position
	var shepherd_radius := config.flight_radius * 2.0
	if from_shepherd.length() < shepherd_radius and from_shepherd != Vector2.ZERO:
		push += from_shepherd.normalized() * (1.0 - from_shepherd.length() / shepherd_radius)
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

	# Trot = 1 px hop on the second run frame (capped leg cadence would otherwise hide it).
	var hop := 1.0 if _gait == Gait.TROT and _sprite.animation == &"run" and _sprite.frame == 1 else 0.0
	_sprite.position.y = _sprite_offset_y - hop

	if _speed > GUIDE_STOPPED_SPEED:
		# Leg cadence follows real speed so feet do not slide, capped so the trot does not flicker.
		_play(&"run", minf(_speed / config.walk_speed, config.max_run_anim_scale))
		return
	if _gait != Gait.REST:
		_play(&"idle", 1.0)
		return
	match _rest:
		Rest.STAND:
			_play(&"idle", 1.0)
		Rest.LOWERING:
			_play(&"to_graze", 1.0)
		Rest.GRAZING:
			_play(&"graze", 1.0)
		Rest.RAISING:
			_play(&"finished_graze", config.raise_speed_scale if _pending_gait != Gait.REST else 1.0)


func _set_facing_left(left: bool) -> void:
	var side := -1.0 if left else 1.0
	_sprite.flip_h = left
	_sprite.position.x = _sprite_offset_x * side
	_shape.position.x = _shape_offset_x * side


func _has_frames(animation: StringName) -> bool:
	var frames := _sprite.sprite_frames
	return frames != null and frames.has_animation(animation) and frames.get_frame_count(animation) > 0


func _play(animation: StringName, speed_scale: float) -> void:
	if not _has_frames(animation):
		return
	_sprite.speed_scale = speed_scale
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
		if not _animation_started:
			_animation_started = true
			_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count(animation)
			_sprite.frame_progress = randf()
