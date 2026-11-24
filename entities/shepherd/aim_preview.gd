class_name AimPreview
extends Node2D
## While the shepherd can throw: the dotted arc each clod of a throw at the mouse would fly along
## (`Shepherd.aim()`: onto the ground, or up to an enemy's body), and a small cross where it ends:
## there, or where a tree stops it (unless it is under the crosshair). Drawn in the world and
## not snapped to the pixel grid, from the shepherd's position interpolated between physics ticks
## (as the engine draws him), so it moves smoothly with the sprites. Each dot and cross is a small
## node at its point on the ground, drawn as high as the clod would fly there: sorted in depth like
## the clod, a tree in front hides it. Built in code by Main; the crosshair itself is `Crosshair`.

## Clod color, for the dots and the landing marks.
const COLOR := Color("5b2f1a")
## Landing mark: a small x, drawn when farther than LANDING_MIN_DISTANCE px from the mouse.
const LANDING: Array[Vector2] = [Vector2(0, 0), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const LANDING_MIN_DISTANCE := 3.0
## A dot of the arc.
const DOT: Array[Vector2] = [Vector2.ZERO]
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
## Dots and crosses, reused from one frame to the next (the extra ones hidden).
var _marks: Array[Mark] = []
var _used: int = 0


## A dot or a cross of the preview: at its point on the ground, drawn `height` px above it.
class Mark extends Node2D:
	var pixels: Array[Vector2] = []
	var height: float = 0.0

	func _init() -> void:
		# Placed every frame, not every physics tick.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	func _draw() -> void:
		for pixel in pixels:
			draw_rect(Rect2(pixel - Vector2(0.5, 0.5 + height), Vector2.ONE), COLOR)


func _init() -> void:
	# Its marks are sorted in depth with the trees and the characters (Main is y-sorted).
	y_sort_enabled = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_mode = Node.PROCESS_MODE_ALWAYS
	# At night, above the night's veil (no tree hides them then).
	if Night.active:
		z_index = Night.MARKS_Z


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
	_used = 0
	if visible:
		var mouse := get_global_mouse_position()
		var from := shepherd.global_position
		if _tracking:
			from = _previous.lerp(_current, Engine.get_physics_interpolation_fraction())
		for spot in shepherd.landing_spots(shepherd.aim(mouse), from):
			var end := _arc(shepherd.crook, from, spot, mouse)
			if _seen(end).distance_to(mouse) > LANDING_MIN_DISTANCE:
				_mark(end, LANDING)
	for i in range(_used, _marks.size()):
		_marks[i].visible = false


## Dots along the arc a clod would fly from the crook to `target` (x, y on the ground, z height; as
## in Clod), up to the first tree that would stop it, at even distances along its path as seen.
## Returns where it ends (x, y on the ground, z height).
func _arc(crook: CrookData, from: Vector2, target: Vector3, mouse: Vector2) -> Vector3:
	var to := Vector2(target.x, target.y)
	var arc := Clod.arc_top(crook, from.distance_to(to))
	var forest := get_tree().get_first_node_in_group("forest") as Forest
	var end := Clod.flight(from, to, Shepherd.THROW_HEIGHT, target.z, arc, 0.0)
	var previous := _seen(end)
	var dots: Array[Vector3] = []
	var travelled := 0.0
	for step in range(1, ARC_STEPS + 1):
		end = Clod.flight(from, to, Shepherd.THROW_HEIGHT, target.z, arc, float(step) / ARC_STEPS)
		if forest and forest.blocks(Vector2(end.x, end.y), end.z, from):
			break
		var seen := _seen(end)
		travelled += previous.distance_to(seen)
		previous = seen
		if travelled >= ARC_SPACING:
			travelled -= ARC_SPACING
			dots.append(end)
	var seen_end := _seen(end)
	for dot in dots:
		var seen := _seen(dot)
		if seen.distance_to(mouse) > ARC_CLEARANCE and seen.distance_to(seen_end) > ARC_CLEARANCE:
			_mark(dot, DOT)
	return end


## Shows the next mark: `pixels` drawn at `point` (x, y on the ground, z height).
func _mark(point: Vector3, pixels: Array[Vector2]) -> void:
	if _used == _marks.size():
		var mark := Mark.new()
		add_child(mark)
		_marks.append(mark)
	var mark := _marks[_used]
	_used += 1
	mark.visible = true
	mark.position = Vector2(point.x, point.y)
	mark.height = point.z
	mark.pixels = pixels
	mark.queue_redraw()


## A point in height (x, y on the ground, z height) as seen on screen.
static func _seen(point: Vector3) -> Vector2:
	return Vector2(point.x, point.y - point.z)


func _shepherd() -> Shepherd:
	return get_tree().get_first_node_in_group("shepherd") as Shepherd
