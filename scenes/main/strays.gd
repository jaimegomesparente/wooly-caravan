class_name Strays
extends Node
## Now and then a trip meets strays on the trail, between the pastures: a sheep alone, a lamb alone,
## or a ewe with her lamb, grazing away from the trees. They join the flock when the shepherd or the
## flock comes close (`Sheep.join()`), and count as part of it from then on.

## A stray joined the flock (each one, a lamb with its mother too).
signal joined

@export var sheep_scene: PackedScene
@export var lamb_scene: PackedScene
## Chance that a trip meets strays at all.
@export_range(0.0, 1.0) var chance: float = 0.5
## Kept this far (px) from the groves and lone trees.
@export var tree_margin: float = 16.0
## Kept this far (px) from the pastures, beyond the reach of a sheep standing there
## (FlockConfig.stray_join_radius), so it never joins a flock already arrived.
@export var pasture_margin: float = 64.0

enum Kind { SHEEP, LAMB, EWE_AND_LAMB }

## Where a lamb stands beside its mother, and the height (px) of a sheep above its feet.
const LAMB_OFFSET := Vector2(-6, 2)
const SHEEP_HEIGHT := 9.0


func _ready() -> void:
	# Once the forest has planted the trail trees.
	_place.call_deferred()


func _place() -> void:
	if randf() >= chance:
		return
	var trail := get_tree().get_first_node_in_group("trail") as Ground
	var forest := get_tree().get_first_node_in_group("forest") as Forest
	if trail == null:
		return
	var clearance := forest.wall_clearance if forest else 32.0
	var area := Rect2(trail.patch_width + pasture_margin, clearance,
			trail.length - 2.0 * (trail.patch_width + pasture_margin), trail.height - 2.0 * clearance)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var spot := Vector2.INF
	for attempt in 30:
		var point := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)).round()
		if forest == null or forest.is_clear(point, tree_margin) and _in_sight(forest, point):
			spot = point
			break
	if spot == Vector2.INF:
		return
	match randi() % Kind.size():
		Kind.SHEEP:
			_add(sheep_scene, spot)
		Kind.LAMB:
			_add(lamb_scene, spot)
		Kind.EWE_AND_LAMB:
			var ewe := _add(sheep_scene, spot)
			_add(lamb_scene, spot + LAMB_OFFSET, ewe)


## True when no tree drawn in front hides a sheep standing at `feet`, nor a lamb beside it (feet and
## top of each, `Forest.hides()`): the bottom edge's crowns cover the band about 50 px deep.
func _in_sight(forest: Forest, feet: Vector2) -> bool:
	for at: Vector2 in [feet, feet + LAMB_OFFSET]:
		for height: float in [1.0, SHEEP_HEIGHT]:
			if forest.hides(at - Vector2(0, height), at.y):
				return false
	return true


func _add(scene: PackedScene, at: Vector2, mother: Sheep = null) -> Sheep:
	var stray := scene.instantiate() as Sheep
	stray.stray = true
	stray.position = at
	if stray.lamb:
		stray.grow_trips = RunManager.lamb_trips()
		stray.mother = mother
	stray.joined.connect(_on_joined)
	# Beside Main's other children, so it is y-sorted with the flock.
	add_sibling(stray)
	return stray


func _on_joined() -> void:
	RunManager.flock_size += 1
	joined.emit()
