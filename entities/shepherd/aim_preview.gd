class_name AimPreview
extends Node2D
## While the shepherd can throw: the dotted arc each clod of a throw at the mouse would fly along
## (`Shepherd.aim()`: onto the ground, or up to an enemy's body), and a small cross where it ends:
## there, or where a tree stops it (unless it is under the crosshair). Drawn in the world and
## not snapped to the pixel grid, from the shepherd's position interpolated between physics ticks
## (as the engine draws him), so it moves smoothly with the sprites. Built in code by Main; the crosshair itself is `Crosshair`.

## Clod color, for the dots and the landing marks.
const COLOR := Color("5b2f1a")
## Landing mark: a small x, drawn when farther than LANDING_MIN_DISTANCE px from the mouse.
const LANDING: Array[Vector2] = [Vector2(0, 0), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const LANDING_MIN_DISTANCE := 3.0
## A 1 px dot every ARC_SPACING px along an arc, none within ARC_CLEARANCE px of the mouse or of the
## arc's end; each arc is sampled ARC_STEPS times.
const ARC_SPACING := 4.0
const ARC_CLEARANCE := 4.0
const ARC_STEPS := 48
## Farther than this (px) in one tick, the shepherd was moved at once: no interpolation.
const TELEPORT_DISTANCE := 32.0

## The shepherd's position at the last two physics ticks.
var _previous: Vector2
var _current: Vector2
var _tracking: bool = false


func _init() -> void:
	z_index = 10
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	var shepherd := _shepherd()
	if shepherd == null:
		_tracking = false
		return
	var moved_at_once := _current.distance_to(shepherd.global_position) >= TELEPORT_DISTANCE
	_previous = _current if _tracking and not moved_at_once else shepherd.global_position
	_current = shepherd.global_position
	_tracking = true


func _process(_delta: float) -> void:
	var shepherd := _shepherd()
	visible = shepherd != null and shepherd.crook != null and not shepherd.resting and not get_tree().paused
	if visible:
		queue_redraw()


func _draw() -> void:
	var shepherd := _shepherd()
	if shepherd == null or shepherd.crook == null:
		return
	var mouse := get_global_mouse_position()
	var from := shepherd.global_position
	if _tracking:
		from = _previous.lerp(_current, Engine.get_physics_interpolation_fraction())
	for spot in shepherd.landing_spots(shepherd.aim(mouse), from):
		var end := _draw_arc(shepherd.crook, from, spot, mouse)
		if end.distance_to(mouse) > LANDING_MIN_DISTANCE:
			for pixel in LANDING:
				draw_rect(Rect2(end + pixel - Vector2(0.5, 0.5), Vector2.ONE), COLOR)


## The arc a clod would fly along from the crook to `target` (x, y on the ground, z height; as in
## Clod), up to the first tree that would stop it, dotted at even distances along its path as seen.
## Returns where it ends, as seen.
func _draw_arc(crook: CrookData, from: Vector2, target: Vector3, mouse: Vector2) -> Vector2:
	var to := Vector2(target.x, target.y)
	var arc := Clod.arc_top(crook, from.distance_to(to))
	var forest := get_tree().get_first_node_in_group("forest") as Forest
	var previous := _seen(Clod.flight(from, to, Shepherd.THROW_HEIGHT, target.z, arc, 0.0))
	var end := previous
	var dots: Array[Vector2] = []
	var travelled := 0.0
	for step in range(1, ARC_STEPS + 1):
		var point3 := Clod.flight(from, to, Shepherd.THROW_HEIGHT, target.z, arc, float(step) / ARC_STEPS)
		var point := _seen(point3)
		end = point
		if forest and forest.blocks(Vector2(point3.x, point3.y), point3.z, from):
			break
		travelled += previous.distance_to(point)
		previous = point
		if travelled >= ARC_SPACING:
			travelled -= ARC_SPACING
			dots.append(point)
	for dot in dots:
		if dot.distance_to(mouse) > ARC_CLEARANCE and dot.distance_to(end) > ARC_CLEARANCE:
			draw_rect(Rect2(dot - Vector2(0.5, 0.5), Vector2.ONE), COLOR)
	return end


## A point in height (x, y on the ground, z height) as seen on screen.
static func _seen(point: Vector3) -> Vector2:
	return Vector2(point.x, point.y - point.z)


func _shepherd() -> Shepherd:
	return get_tree().get_first_node_in_group("shepherd") as Shepherd
