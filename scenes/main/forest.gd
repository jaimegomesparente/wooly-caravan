class_name Forest
extends Node2D
## The forest all around the trip, made of tree sprites in rows parallel to each wall. Its front line
## stands up to `overflow` px on the walkable band and recedes here and there (a smooth noise), with
## clearings where no tree grows. Its trees are y-sorted with the sheep, the dog and the wolves (keep
## it a direct child of a y-sorted node): the bottom rows hide what walks behind them. Trees and the
## ground under them darken by levels toward the back.

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

var _trail: Ground
var _edge_noise := FastNoiseLite.new()
var _clearing_noise := FastNoiseLite.new()


func _ready() -> void:
	y_sort_enabled = true
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

	var shade := Node2D.new()
	# Below the trees and the entities, above the ground.
	shade.z_index = -1
	shade.draw.connect(_draw_shade.bind(shade))
	add_child(shade)


func _plant(rng: RandomNumberGenerator, foot: Vector2, depth: float) -> void:
	foot = foot.round()
	if _clearing_noise.get_noise_2dv(foot) > clearing_threshold:
		return
	var tree := Sprite2D.new()
	tree.texture = tree_texture
	tree.hframes = sheet_cells
	tree.frame = rng.randi() % variants
	tree.offset = Vector2(cell_size / 2.0 - trunk_x, -cell_size / 2.0)
	tree.modulate = tint_colors[_level(tint_starts, depth)] if not tint_colors.is_empty() else Color.WHITE
	tree.position = foot
	add_child(tree)


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
