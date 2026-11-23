class_name Clod
extends Area2D
## A clod of earth lobbed by the shepherd's crook, flying in height above its point on the ground.
## It flies from the crook to the aimed point (a point on the ground at most the crook's max_range
## px away, and a height: 0 on the ground, or the body of an enemy in the air) along an arc, higher
## for a longer throw; if it gets there without hitting anything, it keeps going along the same
## curve down to the ground. Its shadow stays on its point on the ground, showing how high it is.
## It hits an attacking enemy whose body it goes through, at its height (`Enemy.is_hit_at()`): the
## enemy flinches, or runs off once out of health. A tree's trunk or crown stops it
## (`Forest.blocks()`). It crumbles on hitting, on being stopped or on reaching the ground.

@export var crumble_scene: PackedScene

const COLOR := Color("#5b2f1a")
## Past this many times its flight to the aimed point, it crumbles wherever it is (a throw straight
## up never comes down otherwise).
const MAX_FLIGHT := 4.0
## Points of its flight checked against the trees each tick (so it never flies through a trunk).
const TREE_CHECKS := 3

var _from: Vector2
var _to: Vector2
var _start_height: float = 0.0
var _end_height: float = 0.0
var _arc: float = 0.0
var _duration: float = 1.0
var _time: float = 0.0
var _damage: int = 1
var _mud_slow: float = 0.0
var _mud_time: float = 0.0
var _size: Vector2 = Vector2(2, 2)
var _forest: Forest

@onready var _shadow: Node2D = $Shadow


func _ready() -> void:
	# Hits are found in height by the clod itself, not by the area.
	monitoring = false
	monitorable = false
	_forest = get_tree().get_first_node_in_group("forest") as Forest


## Thrown by `crook` from `start_height` px above `from` (on the ground) toward `target` (x, y: point
## on the ground, z: height), within the crook's max_range and max_height.
func launch(crook: CrookData, from: Vector2, target: Vector3, start_height: float) -> void:
	_from = from
	_to = from + (Vector2(target.x, target.y) - from).limit_length(crook.max_range)
	_start_height = start_height
	_end_height = clampf(target.z, 0.0, crook.max_height)
	var distance := _from.distance_to(_to)
	_arc = arc_top(crook, distance)
	_duration = maxf(distance / crook.speed, 0.05)
	_damage = crook.damage
	_mud_slow = crook.mud_slow
	_mud_time = crook.mud_time
	_size = Vector2(crook.clod_size, crook.clod_size)
	_place(flight(_from, _to, _start_height, _end_height, _arc, 0.0))
	reset_physics_interpolation()


## Top of the arc (px) of a throw of `distance` px by `crook`.
static func arc_top(crook: CrookData, distance: float) -> float:
	return minf(distance * crook.arc_per_px, crook.max_arc)


## Where a clod is at `t` of its flight from `start_height` px above `from` to `end_height` px above
## `to` (t 0 to 1; past 1 it keeps going along the same curve) along an arc of top `arc` px: x, y its
## point on the ground, z its height.
static func flight(from: Vector2, to: Vector2, start_height: float, end_height: float, arc: float,
		t: float) -> Vector3:
	var ground := from.lerp(to, t)
	return Vector3(ground.x, ground.y, lerpf(start_height, end_height, t) + 4.0 * arc * t * (1.0 - t))


func _physics_process(delta: float) -> void:
	var last_t := _time / _duration
	_time += delta
	var t := _time / _duration
	if _forest:
		for i in range(1, TREE_CHECKS + 1):
			var check := flight(_from, _to, _start_height, _end_height, _arc, lerpf(last_t, t, float(i) / TREE_CHECKS))
			if _forest.blocks(Vector2(check.x, check.y), check.z, _from):
				_place(check)
				_crumble()
				return
	var point := flight(_from, _to, _start_height, _end_height, _arc, t)
	if point.z <= 0.0:
		point.z = 0.0
	_place(point)
	if _hit_enemy(point):
		return
	if point.z <= 0.0 or t >= MAX_FLIGHT:
		_crumble()


func _draw() -> void:
	draw_rect(Rect2(-_size / 2.0, _size), COLOR)


## The clod at `point` (x, y on the ground, z height), its shadow on the ground below.
func _place(point: Vector3) -> void:
	global_position = Vector2(point.x, point.y - point.z)
	_shadow.position = Vector2(0, roundf(point.z))


## Hits the first attacking enemy whose body it is in (enemies on their way out, or still out of
## reach like a passing eagle, let it fly through), and crumbles.
func _hit_enemy(point: Vector3) -> bool:
	var ground := Vector2(point.x, point.y)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy and enemy.is_threat() and enemy.is_hit_at(ground, point.z, _size.x / 2.0):
			enemy.hit(_to - _from, _damage, _mud_slow, _mud_time)
			_crumble()
			return true
	return false


func _crumble() -> void:
	if is_queued_for_deletion():
		return
	if crumble_scene:
		var crumble := crumble_scene.instantiate() as Node2D
		# Placed before entering the tree, so the burst starts at the right spot.
		crumble.position = position
		add_sibling(crumble)
	queue_free()
