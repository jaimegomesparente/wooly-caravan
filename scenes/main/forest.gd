class_name Forest
extends Node2D
## The forest all around the trip, made of tree sprites in rows parallel to each wall. Its front line
## stands up to `overflow` px on the walkable band and recedes here and there (a smooth noise), with
## clearings where no tree grows. Its trees are y-sorted with the sheep, the dog and the wolves (keep
## it a direct child of a y-sorted node): the bottom rows hide what walks behind them. Trees and the
## ground under them darken by levels toward the back. Between the pastures, lone trees and small
## groves stand on the walkable band, their trunks blocking the shepherd, the sheep and the dog (the
## sheep and the dog steer around them with `avoidance()`), with a flattened shade under each.

enum Wall { TOP, BOTTOM, LEFT, RIGHT }

## Sheet of tree variants, one per cell, the tree's foot at the bottom of the cell.
@export var tree_texture: Texture2D
## Number of cells of the sheet in a row, and how many of them (from the left) hold a tree.
@export var sheet_cells: int = 9
@export var variants: int = 3
@export var cell_size: int = 48
## Column of the trunk in a cell (px from the cell's left side).
@export var trunk_x: int = 20
## How far (px) the front line stands inside the walkable band, where it does not recede.
@export var overflow: float = 16.0
## Distance (px) between two trees of a row, and between two rows.
@export var spacing: float = 14.0
@export var row_spacing: float = 12.0
## Random shift (px) of each tree, along its row and away from the path.
@export var jitter: float = 4.0
## Same seed = same forest every run.
@export var layout_seed: int = 1

@export_group("Edge")
## How far (px) the front line recedes at most, and how fast it varies along the walls.
@export var edge_wobble: float = 14.0
@export var edge_frequency: float = 0.02
## No tree where the clearing noise is above this (-1 to 1; higher = fewer clearings).
@export var clearing_threshold: float = 0.3
@export var clearing_frequency: float = 0.05

@export_group("Depth")
## Levels from the front to the back, by depth (px behind the front line) where each starts: tree
## tint, and ground shade (later levels draw over earlier ones; negative = in front of the trunks).
@export var tint_starts: Array[float] = [0.0, 10.0, 30.0]
@export var tint_colors: Array[Color] = [Color.WHITE, Color(0.62, 0.66, 0.72), Color(0.32, 0.34, 0.42)]
@export var shade_starts: Array[float] = [-4.0, 4.0, 16.0]
@export var shade_colors: Array[Color] = [Color(0.43, 0.52, 0.31), Color(0.3, 0.4, 0.23), Color(0.17, 0.22, 0.17)]

@export_group("Trail trees")
@export var lone_trees: int = 24
@export var groves: int = 8
@export var grove_size_min: int = 6
@export var grove_size_max: int = 12
## Trunks of a grove stand within grove_radius (px) of its center, at least grove_spacing apart.
@export var grove_radius: float = 18.0
@export var grove_spacing: float = 9.0
## Minimum distance (px) between trunks of different groves or lone trees, so passages remain.
@export var min_gap: float = 40.0
## Minimum distance (px) from the top and bottom walls and from the pastures.
@export var wall_clearance: float = 32.0
## Collision box (px) at the foot of each trail tree; a grove blocks the whole outline of its
## trunks, so nothing gets in between them.
@export var trunk_size: Vector2 = Vector2(4, 3)
## Shade of the trail trees: the whole inside of a grove (the outline of its trunks) is shaded, and
## the shade fades out across trail_shade_radius (px; vertical distances divided by
## trail_shade_squash, for a flat oval) around it; strength 1 inside, 0 at the radius, each level
## starting at its threshold (colors: `shade_colors`).
@export var trail_shade_radius: float = 14.0
@export var trail_shade_squash: float = 0.5
@export var trail_shade_levels: Array[float] = [0.05, 0.45, 0.8]

## Collision layer 5 (obstacle).
const OBSTACLE_LAYER := 1 << 4

var _trail: Ground
## Feet of the trail trees, all together and by grove (a lone tree is a grove of one).
var _trunks: Array[Vector2] = []
var _groves: Array[Array] = []
## What bodies steer around: one disc per grove (x, y: center; z: radius, px).
var _obstacles: Array[Vector3] = []
var _edge_noise := FastNoiseLite.new()
var _clearing_noise := FastNoiseLite.new()


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("forest")
	_trail = get_tree().get_first_node_in_group("trail") as Ground
	if _trail == null or tree_texture == null:
		return
	_edge_noise.seed = layout_seed
	_edge_noise.frequency = edge_frequency
	_clearing_noise.seed = layout_seed + 1
	_clearing_noise.frequency = clearing_frequency
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var e := _trail.edge_depth
	# How far out (px from the wall) trees still show: past -edge_depth a whole tree is above the
	# camera limit; a crown (cell_size tall, about half a cell wide) shows from farther below or beside.
	var limits := {Wall.TOP: e, Wall.BOTTOM: e + cell_size, Wall.LEFT: e + cell_size / 2.0, Wall.RIGHT: e + cell_size / 2.0}
	for side: Wall in limits:
		var span := _span(side)
		var depth := 0.0
		while _out(side, span.x, depth) - edge_wobble < limits[side]:
			var along := span.x + rng.randf() * spacing
			while along < span.y:
				var at := along + rng.randf_range(-jitter, jitter)
				var tree_depth := depth + rng.randf() * jitter
				if _out(side, at, tree_depth) < limits[side]:
					_plant(rng, _point(side, at, _out(side, at, tree_depth)), tree_depth)
				along += spacing
			depth += row_spacing

	_plant_trail(rng)

	var shade := Node2D.new()
	# Below the trees and the entities, above the ground.
	shade.z_index = -1
	shade.draw.connect(_draw_shade.bind(shade))
	add_child(shade)


func _plant(rng: RandomNumberGenerator, foot: Vector2, depth: float) -> void:
	foot = foot.round()
	if _clearing_noise.get_noise_2dv(foot) > clearing_threshold:
		return
	_add_tree(rng, foot, tint_colors[_level(tint_starts, depth)] if not tint_colors.is_empty() else Color.WHITE)


func _add_tree(rng: RandomNumberGenerator, foot: Vector2, tint: Color) -> void:
	var tree := Sprite2D.new()
	tree.texture = tree_texture
	tree.hframes = sheet_cells
	tree.frame = rng.randi() % variants
	tree.offset = Vector2(cell_size / 2.0 - trunk_x, -cell_size / 2.0)
	tree.modulate = tint
	tree.position = foot
	add_child(tree)


## Groves first, then lone trees, each at a random free spot (given up after a few tries).
func _plant_trail(rng: RandomNumberGenerator) -> void:
	var area := Rect2(_trail.patch_width + wall_clearance, wall_clearance,
			_trail.length - 2.0 * (_trail.patch_width + wall_clearance), _trail.height - 2.0 * wall_clearance)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	for i in groves + lone_trees:
		var grove := i < groves
		var clearance := min_gap + (grove_radius if grove else 0.0)
		for attempt in 20:
			var center := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)).round()
			if _trunks.any(func(trunk: Vector2) -> bool: return trunk.distance_to(center) < clearance):
				continue
			var feet: Array[Vector2] = [center]
			if grove:
				var size := rng.randi_range(grove_size_min, grove_size_max)
				for try in size * 10:
					if feet.size() >= size:
						break
					var foot := (center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * grove_radius).round()
					if not feet.any(func(other: Vector2) -> bool: return other.distance_to(foot) < grove_spacing):
						feet.append(foot)
			var corners := PackedVector2Array()
			var middle := Vector2.ZERO
			for foot in feet:
				_add_tree(rng, foot, Color.WHITE)
				middle += foot / feet.size()
				var box := Rect2(foot - Vector2(trunk_size.x / 2.0, trunk_size.y), trunk_size)
				corners.append_array([box.position, Vector2(box.end.x, box.position.y), box.end,
						Vector2(box.position.x, box.end.y)])
			var collision := CollisionPolygon2D.new()
			collision.polygon = Geometry2D.convex_hull(corners)
			body.add_child(collision)
			var reach := 0.0
			for corner in corners:
				reach = maxf(reach, corner.distance_to(middle))
			_obstacles.append(Vector3(middle.x, middle.y, reach))
			_trunks.append_array(feet)
			_groves.append(feet)
			break
	add_child(body)


## Sideways push away from the groves and lone trees ahead of a body at `from` heading `direction`
## (unit vector), each fading from 1 at its edge to 0 radius px away from it. One dead ahead pushes
## to the right.
func avoidance(from: Vector2, direction: Vector2, radius: float) -> Vector2:
	var push := Vector2.ZERO
	var side := direction.orthogonal()
	for obstacle in _obstacles:
		var to_center := Vector2(obstacle.x, obstacle.y) - from
		var gap := maxf(to_center.length() - obstacle.z, 0.0)
		if gap >= radius or to_center.dot(direction) <= 0.0:
			continue
		var lateral := to_center.dot(side)
		push -= side * (signf(lateral) if lateral != 0.0 else -1.0) * (1.0 - gap / radius)
	return push


## Range covered along a side: the top and bottom rows run past the corners, under the side rows.
func _span(side: Wall) -> Vector2:
	if side == Wall.TOP or side == Wall.BOTTOM:
		var reach := _trail.edge_depth + cell_size / 2.0
		return Vector2(-reach, _trail.length + reach)
	return Vector2(0.0, _trail.height)


## Distance (px) out from the wall of a point `depth` px behind the front line.
func _out(side: Wall, along: float, depth: float) -> float:
	var recess := (_edge_noise.get_noise_2d(along, side * 1000.0) * 0.5 + 0.5) * edge_wobble
	return depth - overflow + recess


func _point(side: Wall, along: float, out: float) -> Vector2:
	match side:
		Wall.TOP:
			return Vector2(along, -out)
		Wall.BOTTOM:
			return Vector2(along, _trail.height + out)
		Wall.LEFT:
			return Vector2(-out, along)
	return Vector2(_trail.length + out, along)


## Index of the last level whose start is at or before depth.
func _level(starts: Array[float], depth: float) -> int:
	var level := 0
	for i in starts.size():
		if depth >= starts[i]:
			level = i
	return level


## Each level is drawn 1 px stripe by 1 px stripe along each side, from its start out past the
## camera limit, so its border follows the front line smoothly.
func _draw_shade(canvas: Node2D) -> void:
	var far := _trail.edge_depth + cell_size
	for level in mini(shade_starts.size(), shade_colors.size()):
		for side: Wall in [Wall.TOP, Wall.BOTTOM, Wall.LEFT, Wall.RIGHT]:
			var span := _span(side)
			for along in range(floori(span.x), ceili(span.y)):
				var out := roundf(_out(side, along, shade_starts[level]))
				var from := _point(side, along, out)
				var to := _point(side, along + 1, far)
				canvas.draw_rect(Rect2(from, to - from).abs(), shade_colors[level])
	for feet: Array in _groves:
		_draw_grove_shade(canvas, feet)


## The grove's outline in flattened space (y divided by trail_shade_squash): strength 1 inside,
## fading to 0 trail_shade_radius away from it; drawn line by line, a run of one level per rect.
func _draw_grove_shade(canvas: Node2D, feet: Array) -> void:
	var flat := PackedVector2Array()
	var box := Rect2(feet[0], Vector2.ZERO)
	for foot: Vector2 in feet:
		box = box.expand(foot)
		flat.append(Vector2(foot.x, foot.y / trail_shade_squash))
	var outline := Geometry2D.convex_hull(flat) if flat.size() >= 3 else flat
	var reach := Vector2(trail_shade_radius, trail_shade_radius * trail_shade_squash)
	box = box.grow_individual(reach.x, reach.y, reach.x, reach.y)
	var levels := mini(trail_shade_levels.size(), shade_colors.size())
	for y in range(floori(box.position.y), ceili(box.end.y)):
		var run_start := 0
		var run_level := -1
		for x in range(floori(box.position.x), ceili(box.end.x) + 1):
			var level := -1
			if x < ceili(box.end.x):
				var point := Vector2(x + 0.5, (y + 0.5) / trail_shade_squash)
				var strength := 1.0 - _outline_distance(outline, point) / trail_shade_radius
				for i in levels:
					if strength >= trail_shade_levels[i]:
						level = i
			if level != run_level:
				if run_level >= 0:
					canvas.draw_rect(Rect2(run_start, y, x - run_start, 1), shade_colors[run_level])
				run_start = x
				run_level = level


## 0 inside the outline (a closed convex polygon, or one or two points), else the distance to it.
func _outline_distance(outline: PackedVector2Array, point: Vector2) -> float:
	if outline.size() >= 4 and Geometry2D.is_point_in_polygon(point, outline):
		return 0.0
	if outline.size() == 1:
		return point.distance_to(outline[0])
	var nearest := INF
	for i in outline.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, outline[i], outline[i + 1])
		nearest = minf(nearest, point.distance_to(closest))
	return nearest
