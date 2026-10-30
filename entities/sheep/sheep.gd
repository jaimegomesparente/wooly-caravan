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
## Time (s) of a 1 px hop: on being shorn, or a lamb's little jump at rest.
const HOP_TIME := 0.15
## Time (s) a ram plays its butt animation.
const BUTT_TIME := 0.3

## Toggled by the debug overlay (F3): each sheep draws a line to its target and a state dot.
static var debug_draw: bool = false

@export var config: FlockConfig
## A lamb sticks to its mother instead of following the column, and grows into a sheep after
## grow_trips trips (Shearing swaps it for a sheep on the pasture).
@export var lamb: bool = false

var mother: Sheep
var grow_trips: int = 0
## A ram (`ram.tscn`, bought in the shop) butts away the enemies that come to grab it (see
## FlockConfig ram_*); it is never shorn.
@export var ram: bool = false

## Shorn on the pasture: plays the `_shaved` animations; the wool may grow back at the end of each
## graze (regrow_chance).
var shaved: bool = false

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
var _panicking: bool = false
## Time (s) left moving on because the dog pushed it, or because a pushed sheep pressed it from
## behind. Meanwhile it does not stop on bumping into the flock, and makes the resting sheep just
## ahead set off too, so the push spreads through the flock.
var _push_timer: float = 0.0
var _fleeing_dog: bool = false
## The enemy dragging this sheep away; the sheep has no logic of its own meanwhile.
var _captor: Node2D
## After being freed, the sheep panics away from where it was dropped for release_panic_time.
var _scare_point: Vector2
var _scare_timer: float = 0.0
## Back among the others but still shaken: current restless direction, and when (on the _age clock)
## it changes.
var _agitate_direction: Vector2 = Vector2.RIGHT
var _agitate_until: float = 0.0
var _debug_drawn: bool = false
var _heading: float = 0.0
var _speed: float = 0.0
var _speed_factor: float = 1.0
## Temperament, -1 (timid) to 1 (bold); see FlockConfig.temperament_strength.
var _boldness: float = 0.0
## Clock (s) and per-sheep phases and periods of the meandering walk and breathing pace.
var _age: float = 0.0
var _meander_phase: float = 0.0
var _meander_period: float = 1.0
var _wobble_phase: float = 0.0
var _wobble_period: float = 1.0
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
var _regrow_chance: float = 0.0
## Time (s) left of a 1 px hop.
var _hop_timer: float = 0.0
## Time (s) left before a ram can butt again.
var _butt_timer: float = 0.0
## Distance (px) covered since it last started moving: paces the hops of config.hop_height.
var _hop_distance: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _shadow: Node2D = $Shadow


func _ready() -> void:
	_sprite_offset_x = _sprite.position.x
	_shape_offset_x = _shape.position.x
	_sprite_offset_y = _sprite.position.y
	_speed_factor = 1.0 + randf_range(-config.speed_variation, config.speed_variation)
	_boldness = randf_range(-1.0, 1.0)
	_meander_phase = randf() * TAU
	_meander_period = maxf(config.meander_period, 0.1) * randf_range(0.7, 1.3)
	_wobble_phase = randf() * TAU
	_wobble_period = maxf(config.wobble_period, 0.1) * randf_range(0.7, 1.3)
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
	_butt_timer = maxf(_butt_timer - delta, 0.0)
	if _captor:
		_speed = 0.0
		velocity = Vector2.ZERO
		_update_animation()
		_update_debug_draw()
		return
	if _guide != null and not is_instance_valid(_guide):
		_guide = _shepherd

	var separation := _separation()
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = randf_range(config.think_interval_min, config.think_interval_max) * _temper(1.0)
		_think()

	_push_timer = maxf(_push_timer - delta, 0.0)
	_hop_timer = maxf(_hop_timer - delta, 0.0)
	_scare_timer = maxf(_scare_timer - delta, 0.0)
	# Pressure, checked every frame so a running sheep is never stuck behind a slow one: a pushed
	# sheep running in from behind makes this one run on too (head up at once, whatever its gait),
	# with a weaker push, so the wave dies out after a few sheep instead of feeding itself.
	var pressure := _pressure_from_behind(global_position.distance_to(_shepherd.global_position))
	if pressure >= config.min_push_time and pressure > _push_timer:
		_push_timer = pressure
		_startle()
		_set_off(Gait.TROT)
	var desired := _panic_step(separation)
	var was_fleeing_dog := _fleeing_dog
	_fleeing_dog = false
	if desired == Vector2.ZERO:
		# One flight threat at a time (the nearest), so the flight margin keeps working.
		var dog := get_tree().get_first_node_in_group("dog") as Dog
		if dog and global_position.distance_to(dog.global_position) \
				< global_position.distance_to(_shepherd.global_position):
			if dog.is_pushing():
				desired = _flee_from(dog.global_position, Vector2.ZERO, config.dog_flight_radius * _temper(-1.0), true)
				_fleeing_dog = desired != Vector2.ZERO
				if _fleeing_dog:
					# Keep some room from the neighbors: a flock packed too tight spreads out
					# backward as soon as the dog leaves.
					desired = (desired.normalized() + separation * config.separation_strength).normalized() \
							* desired.length()
			else:
				# Not working: the dog only gets the shepherd's small flight zone.
				desired = _flee_from(dog.global_position, dog.velocity, config.flight_radius * _temper(-1.0))
		else:
			desired = _flee_from(_shepherd.global_position, _shepherd.velocity, config.flight_radius * _temper(-1.0))
	if _fleeing_dog:
		_push_timer = config.push_time
	elif was_fleeing_dog:
		# Out of the dog's reach: keep trotting toward the front instead of stopping there.
		_set_off(Gait.TROT)
	_age += delta
	if desired == Vector2.ZERO:
		match _gait:
			Gait.REST:
				desired = _rest_step(delta, separation)
			Gait.WANDER:
				desired = _wander_step(delta, separation)
			_:
				desired = _follow_step(separation)
		if _gait != Gait.REST:
			# Organic walk: the heading sways and the pace rises and falls, slowly, per sheep.
			var sway := sin(_age * TAU / _meander_period + _meander_phase) * config.meander_angle
			var pace := 1.0 + sin(_age * TAU / _wobble_period + _wobble_phase) * config.speed_wobble
			desired = desired.rotated(sway) * pace

	# A startled sheep turns and speeds up faster.
	var reflex := config.flight_reflex if _fleeing or _panicking else 1.0
	if desired != Vector2.ZERO:
		desired = _avoid_trees(desired)
		_heading = rotate_toward(_heading, desired.angle(), config.turn_rate * reflex * delta)
	_speed = move_toward(_speed, desired.length(), config.acceleration * reflex * delta)
	_hop_distance = _hop_distance + _speed * delta if _speed > GUIDE_STOPPED_SPEED else 0.0
	velocity = Vector2.from_angle(_heading) * _speed
	move_and_slide()
	_update_animation()
	_update_debug_draw()


## Temperament multiplier: 1 +/- temperament_strength, growing with boldness when `direction` is 1
## (slower reactions, longer grazing, farther strays) and shrinking with it when -1 (flight zones).
func _temper(direction: float) -> float:
	return 1.0 + config.temperament_strength * _boldness * direction


## Called by an enemy that grabs this sheep: it leaves the flock until released. Lifted off the
## ground, it has no shadow and is drawn just above the captor (in front of its talons and above
## its shadow).
func capture(by: Node2D, lifted: bool = false) -> void:
	_captor = by
	if lifted:
		_shadow.visible = false
		z_index = by.z_index + 1
	remove_from_group("sheep")
	_fleeing = false
	_panicking = false
	_gait = Gait.REST
	_set_rest(Rest.STAND)
	_pending_gait = Gait.REST


## Called by an enemy about to grab this sheep: a ram ready to butt turns to it, hops and butts it
## back instead of being caught (true).
func fends_off(enemy: Enemy) -> bool:
	if not ram or _butt_timer > 0.0:
		return false
	_butt_timer = config.ram_cooldown
	_hop_timer = HOP_TIME
	var direction := enemy.global_position - global_position
	_set_facing_left(direction.x < 0.0)
	enemy.butted(direction, config.ram_damage, config.ram_push, config.ram_stun_time)
	return true


## Shorn on the pasture: hops, then its wool may grow back at the end of each graze.
func shear() -> void:
	shaved = true
	_regrow_chance = config.regrow_chance
	_hop_timer = HOP_TIME


## Moved at once (testing aid): settles there.
func teleport(point: Vector2) -> void:
	global_position = point
	reset_physics_interpolation()
	_guide = null
	_enter_rest()


## Called by the enemy when the shepherd frees this sheep: it rejoins the flock.
func release() -> void:
	_scare_point = _captor.global_position if _captor else global_position
	_scare_timer = config.release_panic_time
	_captor = null
	_shadow.visible = true
	z_index = 0
	add_to_group("sheep")
	_enter_rest()


# Redraw while debugging, plus once after it is turned off to clear the lines.
func _update_debug_draw() -> void:
	if debug_draw or _debug_drawn:
		queue_redraw()
	_debug_drawn = debug_draw


func _draw() -> void:
	if not debug_draw:
		return
	if _captor:
		draw_rect(Rect2(-1, -15, 3, 3), Color.MAGENTA)
		return
	var target := _wander_target if _gait == Gait.WANDER else _guide_target() if _guide else global_position
	draw_line(Vector2.ZERO, to_local(target), _debug_color(), 1.0)
	draw_rect(Rect2(-1, -15, 3, 3), _debug_color())


func _debug_color() -> Color:
	if _fleeing or _panicking:
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
	if lamb and _find_mother():
		_guide = mother
	elif not _guide_still_valid(my_distance):
		_guide = _pick_guide(my_distance)

	if _gait == Gait.REST or _gait == Gait.WANDER:
		var distance := global_position.distance_to(_guide_target())
		var set_off := false
		if _guide == mother:
			# A lamb runs after its mother as soon as she is a little too far.
			set_off = distance > _gap() + config.follow_start_margin * 2.0
		elif _guide == _shepherd:
			# Front sheep set off once the shepherd's trail has really moved since they settled;
			# a straggler with no sheep ahead in view sets off when it is far from the trail.
			set_off = _rest_anchor.distance_to(_shepherd.trail_point(config.trail_lag)) > config.shepherd_start_margin \
					or distance > config.catch_up_distance
		elif _is_travelling(_guide):
			# Imitation: the others follow the sheep ahead when it walks away, with some hesitation.
			set_off = distance > _gap() and randf() < config.imitation_chance
		if set_off:
			_request_gait(Gait.TROT if distance > _gap() + config.trot_margin else Gait.WALK)


## Keeps its mother, or (she was taken) adopts the nearest sheep. False if there is none.
func _find_mother() -> bool:
	if mother != null and is_instance_valid(mother) and mother.is_in_group("sheep"):
		return true
	mother = null
	var nearest := INF
	for other: Sheep in get_tree().get_nodes_in_group("sheep"):
		var distance := global_position.distance_to(other.global_position)
		if not other.lamb and distance < nearest:
			nearest = distance
			mother = other
	return mother != null


func _is_pushed() -> bool:
	return _push_timer > 0.0


## The push (s) passed on by pushed sheep running in from behind (farther from the shepherd, within
## pressure_radius, faster than a walk): their remaining push times pressure_decay. Zero if none.
func _pressure_from_behind(my_distance: float) -> float:
	var pressure := 0.0
	for other: Sheep in get_tree().get_nodes_in_group("sheep"):
		if other == self or not other._is_pushed() or other._speed <= config.walk_speed:
			continue
		if other.global_position.distance_to(_shepherd.global_position) <= my_distance:
			continue
		if global_position.distance_to(other.global_position) < config.pressure_radius:
			pressure = maxf(pressure, other._push_timer * config.pressure_decay)
	return pressure


## Walk or trot after the guide, from any gait.
func _set_off(gait: Gait) -> void:
	if _gait == Gait.REST or _gait == Gait.WANDER:
		_request_gait(gait)
	else:
		_gait = gait


## A guide is kept while it stays roughly valid (with some slack), so sheep do not switch guides
## every think and zigzag in the column.
func _guide_still_valid(my_distance: float) -> bool:
	if _guide == null or not is_instance_valid(_guide):
		return false
	if _guide == _shepherd:
		return my_distance <= config.lead_radius * GUIDE_KEEP_SLACK
	if not _guide.is_in_group("sheep") or (_guide as Sheep).lamb:
		return false
	var ahead := _guide.global_position.distance_to(_shepherd.global_position) < my_distance
	return ahead and global_position.distance_to(_guide.global_position) <= config.view_radius * GUIDE_KEEP_SLACK


func _pick_guide(my_distance: float) -> Node2D:
	if my_distance <= config.lead_radius:
		return _shepherd
	var guide: Node2D = _shepherd
	var nearest := config.view_radius
	for other: Sheep in get_tree().get_nodes_in_group("sheep"):
		if other == self or other.lamb:
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
	_push_timer = 0.0
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
			_rest_timer = randf_range(config.graze_time_min, config.graze_time_max) * _temper(1.0)
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
				if _nearest_neighbor_distance() > config.isolation_radius * _temper(1.0) or randf() < chance:
					_start_wander()
				else:
					_set_rest(Rest.LOWERING)
		Rest.GRAZING:
			_rest_timer -= delta
			if _rest_timer <= 0.0:
				if shaved and randf() < _regrow_chance:
					shaved = false
				if lamb:
					_hop_timer = HOP_TIME
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
	var isolation := config.isolation_radius * _temper(1.0)
	if count == 0 or _nearest_neighbor_distance() > isolation:
		direction = to_center.normalized()
		distance = maxf(distance, to_center.length() - isolation * 0.5)
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
## of it, at a walk. A `pushed` sheep (by the dog) instead trots straight away, where the dog wants
## it to go.
## Returns the desired velocity, or zero when not fleeing.
func _flee_from(threat_position: Vector2, threat_velocity: Vector2, radius: float, pushed: bool = false) -> Vector2:
	var away := global_position - threat_position
	var distance := away.length()
	if distance > radius + (config.flight_margin if _fleeing else 0.0):
		_fleeing = false
		return Vector2.ZERO

	if not _fleeing:
		_startle()
	_fleeing = true

	var direction := Vector2.from_angle(randf() * TAU) if distance == 0.0 else away / distance
	if threat_velocity.length() > GUIDE_STOPPED_SPEED:
		var side := threat_velocity.normalized().orthogonal()
		# Mostly sideways: running ahead of a faster threat only gets the sheep caught up.
		direction = (direction * 0.5 + side * signf(side.dot(away) + 0.001)).normalized()
	# Only a pushing dog makes it trot: from the shepherd it calmly walks aside.
	return direction * (config.trot_speed if pushed else config.walk_speed) * _speed_factor


## Trot away from the nearest dangerous enemy within panic_radius (or, just after being freed, from
## where the enemy dropped it), toward the flock center but never toward the danger, keeping some
## room from the neighbors. Returns the desired velocity, or zero when not panicking.
func _panic_step(separation: Vector2) -> Vector2:
	var threat := _nearest_threat()
	var radius := config.panic_radius * _temper(-1.0) + (config.panic_margin if _panicking else 0.0)
	var to_mother := lamb and mother != null and is_instance_valid(mother)
	var to_center := (mother.global_position if to_mother else _flock_center()) - global_position
	var packed_radius := config.follow_gap * sqrt(get_tree().get_node_count_in_group("sheep")) * 0.6
	var danger := Vector2.INF
	var scared := false
	if threat and global_position.distance_to(threat.global_position) <= radius:
		danger = threat.global_position
	elif _scare_timer > 0.0:
		if _nearest_neighbor_distance() < config.isolation_radius:
			# Back among the others: still shaken, but it stays with them.
			return _agitate_step(separation)
		else:
			danger = _scare_point
			scared = true
	if danger == Vector2.INF:
		_panicking = false
		return Vector2.ZERO

	if not _panicking and not _fleeing:
		_startle()
	_panicking = true

	var away := global_position - danger
	var away_direction := Vector2.from_angle(randf() * TAU) if away == Vector2.ZERO else away.normalized()
	var direction := away_direction + separation * config.separation_strength
	# The pull toward the center fades out inside the space a packed flock takes up, so the sheep
	# bunch up as a flock instead of all running to the same spot. A freed sheep, alone, keeps the
	# full pull until it reaches the others.
	var pull := 1.0 if scared or to_mother else clampf((to_center.length() - packed_radius) / packed_radius, 0.0, 1.0)
	if to_center != Vector2.ZERO:
		direction += to_center.normalized() * config.panic_center_weight * pull
	# Remove any part pointing at the enemy (the center can lie beyond it).
	var toward_threat := -direction.dot(away_direction)
	if toward_threat > 0.0:
		direction += away_direction * toward_threat
	direction = away_direction if direction.length() < 0.01 else direction.normalized()
	return direction * config.trot_speed * _speed_factor


## A freed sheep back among the others, until release_panic_time is over: trots restlessly in a
## direction that changes every fraction of a second, held among its neighbors by their pull.
func _agitate_step(separation: Vector2) -> Vector2:
	if not _panicking and not _fleeing:
		_startle()
	_panicking = true
	if _age >= _agitate_until:
		_agitate_direction = Vector2.from_angle(randf() * TAU)
		_agitate_until = _age + randf_range(0.3, 0.7)
	var direction := _agitate_direction + separation * config.separation_strength
	var to_neighbors := _neighbors_center() - global_position
	if to_neighbors != Vector2.ZERO:
		# Stronger the farther it gets from them, so it never leaves the group.
		direction += to_neighbors.normalized() * clampf(to_neighbors.length() / (config.isolation_radius * 0.5), 0.0, 2.0)
	direction = _agitate_direction if direction.length() < 0.01 else direction.normalized()
	return direction * config.trot_speed * _speed_factor * config.agitation_speed


## Center of the sheep within cohesion_radius (this sheep's own position if none).
func _neighbors_center() -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for other: Node2D in get_tree().get_nodes_in_group("sheep"):
		if other != self and global_position.distance_to(other.global_position) < config.cohesion_radius:
			center += other.global_position
			count += 1
	return center / count if count > 0 else global_position


func _nearest_threat() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.is_dangerous():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


## Startled: a grazing head comes up at once, no finished_graze.
func _startle() -> void:
	if _gait == Gait.REST and _rest != Rest.STAND:
		_set_rest(Rest.STAND)
		_pending_gait = Gait.REST


## Walk or trot after the guide. Once the guide has stopped, keep walking toward the front of the
## flock around the others and stop on reaching the group, so the column gathers like a flock
## arriving on a pasture. A pushed sheep does not stop on reaching the group: it keeps going
## through it, at its pace, until the push wears off. Returns the desired velocity.
func _follow_step(separation: Vector2) -> Vector2:
	var guide_moving := _is_travelling(_guide)
	# A lamb always heads for its mother, and stops by her side whatever the crowd.
	var by_mother := _guide != null and _guide == mother
	var target := _guide_target() if guide_moving or by_mother else _shepherd.trail_point(config.trail_lag)
	var gap := _gap() if guide_moving or by_mother else _shepherd_gap
	var to_guide := target - global_position
	var distance := to_guide.length()
	var pushed := _is_pushed()
	if not guide_moving and (distance < gap + config.follow_start_margin \
			or (not pushed and not by_mother and separation.length() > config.crowd_stop_threshold)):
		_enter_rest()
		return Vector2.ZERO
	if _gait == Gait.WALK and distance > gap + config.trot_margin:
		_gait = Gait.TROT
	elif _gait == Gait.TROT and not pushed and distance < gap + config.trot_margin * 0.5:
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


## The desired velocity veered around the trail trees ahead, at the same pace.
func _avoid_trees(desired: Vector2) -> Vector2:
	var forest := get_tree().get_first_node_in_group("forest") as Forest
	if forest == null:
		return desired
	var direction := desired.normalized()
	var steered := direction + forest.avoidance(global_position, direction, config.tree_avoid_radius) \
			* config.tree_avoid_strength
	return desired if steered.length() < 0.01 else steered.normalized() * desired.length()


## Push away from sheep closer than separation_radius; magnitude fades from 1 to 0 across the radius.
## The shepherd also pushes, over shepherd_push_radius, so walking sheep curve around him.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	var from_shepherd := global_position - _shepherd.global_position
	var shepherd_radius := config.shepherd_push_radius
	if from_shepherd.length() < shepherd_radius and from_shepherd != Vector2.ZERO:
		push += from_shepherd.normalized() * (1.0 - from_shepherd.length() / shepherd_radius)
	for other: Sheep in get_tree().get_nodes_in_group("sheep"):
		if other == self:
			continue
		var away := global_position - other.global_position
		var distance := away.length()
		# The smaller of the two radii, so a lamb and its mother can stay close.
		var radius := minf(config.separation_radius, other.config.separation_radius)
		if distance >= radius:
			continue
		var direction := Vector2.from_angle(randf() * TAU) if distance == 0.0 else away / distance
		push += direction * (1.0 - distance / radius)
	return push


func _update_animation() -> void:
	if absf(velocity.x) > config.flip_threshold:
		_set_facing_left(velocity.x < 0.0)

	# Trot = 1 px hop on the second run frame (capped leg cadence would otherwise hide it).
	var hop := 1.0 if _gait == Gait.TROT and _sprite.animation == &"run" and _sprite.frame == 1 else 0.0
	if _hop_timer > 0.0:
		hop = 1.0
	if config.hop_height > 0.0 and _speed > GUIDE_STOPPED_SPEED:
		# Moves in hops: one every hop_length px covered.
		hop = roundf(absf(sin(_hop_distance * PI / config.hop_length)) * config.hop_height)
	_sprite.position.y = _sprite_offset_y - hop

	if ram and _butt_timer > config.ram_cooldown - BUTT_TIME:
		_play(&"butt", 1.0)
		return
	if _speed > GUIDE_STOPPED_SPEED:
		# No run_shaved yet: a shorn sheep would show its wool while it moves, so it keeps idle_shaved.
		if shaved and not _has_frames(&"run_shaved"):
			_play(&"idle", 1.0)
			return
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
			var raise_scale := config.raise_speed_scale if _pending_gait != Gait.REST else 1.0
			# No finished_graze_shaved yet: the head comes up through to_graze_shaved played backward.
			if shaved and not _has_frames(&"finished_graze_shaved"):
				_play(&"to_graze_shaved", raise_scale, true)
			else:
				_play(&"finished_graze", raise_scale)


func _set_facing_left(left: bool) -> void:
	var side := -1.0 if left else 1.0
	_sprite.flip_h = left
	_sprite.position.x = _sprite_offset_x * side
	_shape.position.x = _shape_offset_x * side


func _has_frames(animation: StringName) -> bool:
	var frames := _sprite.sprite_frames
	return frames != null and frames.has_animation(animation) and frames.get_frame_count(animation) > 0


## Plays `animation`, or its `_shaved` version when shorn and it exists.
func _play(animation: StringName, speed_scale: float, backward: bool = false) -> void:
	var shaved_animation := StringName(String(animation) + "_shaved")
	if shaved and _has_frames(shaved_animation):
		animation = shaved_animation
	if not _has_frames(animation):
		return
	_sprite.speed_scale = speed_scale
	if _sprite.animation != animation or not _sprite.is_playing():
		if backward:
			_sprite.play_backwards(animation)
		else:
			_sprite.play(animation)
		if not _animation_started:
			_animation_started = true
			_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count(animation)
			_sprite.frame_progress = randf()
