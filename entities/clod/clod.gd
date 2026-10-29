class_name Clod
extends Area2D
## A clod of earth lobbed by the shepherd's crook. Its point on the ground goes straight from the
## shepherd's feet to the aimed spot (at most max_range px away) while the clod rises and falls
## along an arc, higher for a longer throw; its shadow stays on that ground point, showing how high
## it is. It hits what it is seen over: an attacking enemy whose body it crosses takes a hit (it
## flinches, or runs off once out of health). It crumbles on hitting or on landing.

## Speed (px/s) of the ground point, and longest throw (px).
@export var speed: float = 160.0
@export var max_range: float = 140.0
## Top of the arc (px) for each px of throw, and highest top.
@export var arc_per_px: float = 0.25
@export var max_arc: float = 30.0
@export var crumble_scene: PackedScene

const SIZE := Vector2(2, 2)
const COLOR := Color("#5b2f1a")

var _from: Vector2
var _to: Vector2
var _start_height: float = 0.0
var _arc: float = 0.0
var _duration: float = 1.0
var _time: float = 0.0

@onready var _shadow: Node2D = $Shadow


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Thrown from `start_height` px above `from` (on the ground) toward `target`, landing there.
func launch(from: Vector2, target: Vector2, start_height: float) -> void:
	_from = from
	_to = from + (target - from).limit_length(max_range)
	_start_height = start_height
	var distance := _from.distance_to(_to)
	_arc = minf(distance * arc_per_px, max_arc)
	_duration = maxf(distance / speed, 0.05)
	_place(0.0)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_time += delta
	var t := minf(_time / _duration, 1.0)
	_place(t)
	if t >= 1.0:
		_crumble()


func _draw() -> void:
	draw_rect(Rect2(-SIZE / 2.0, SIZE), COLOR)


## The clod at `t` (0 to 1) of its flight, its shadow on the ground below.
func _place(t: float) -> void:
	var height := lerpf(_start_height, 0.0, t) + 4.0 * _arc * t * (1.0 - t)
	global_position = _from.lerp(_to, t) - Vector2(0, height)
	_shadow.position = Vector2(0, roundf(height))


func _on_body_entered(body: Node2D) -> void:
	var enemy := body as Enemy
	# Enemies on their way out (or still out of reach, like a passing eagle) let it fly through.
	if enemy and enemy.is_threat():
		enemy.hit(_to - _from)
		_crumble()


func _crumble() -> void:
	if crumble_scene:
		var crumble := crumble_scene.instantiate() as Node2D
		# Placed before entering the tree, so the burst starts at the right spot.
		crumble.position = position
		add_sibling(crumble)
	queue_free()
