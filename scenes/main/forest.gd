class_name Forest
extends Node2D
## The forest all around the trip, made of tree sprites in rows parallel to each wall. Its front line
## stands up to `overflow` px on the walkable band and recedes here and there (a smooth noise), with
## clearings where no tree grows. Its trees are y-sorted with the sheep, the dog and the wolves (keep
## it a direct child of a y-sorted node): the bottom rows hide what walks behind them. A shade laid
## over the whole forest (`effects/forest_shade.gdshader`) darkens it, the trees, the ground and what
## stands there alike, by dithered levels the deeper behind the front line. Between the pastures, lone trees and small
## groves stand on the walkable band, their trunks blocking the shepherd, the sheep and the dog (the
## sheep and the dog steer around them with `avoidance()`), with a flattened shade under each.
## Every tree stops the clods flying through it, as drawn: its silhouette, read from the sheet
## row by row, is turned round its trunk into a solid (`blocks()`).

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
## Added to the trip's seed (RunManager.trip_seed(), another forest each trip of each run).
@export var layout_seed: int = 1

@export_group("Edge")
## How far (px) the front line recedes at most, and how fast it varies along the walls.
@export var edge_wobble: float = 14.0
@export var edge_frequency: float = 0.02
## No tree where the clearing noise is above this (-1 to 1; higher = fewer clearings).
@export var clearing_threshold: float = 0.3
@export var clearing_frequency: float = 0.05

@export_group("Depth")
## The forest's shade: from shade_start to shade_end px behind the front line (negative = in front
## of the trunks), shade_levels levels from no change to shade_darkest (multiplied), dithered from
## one to the next on the world's pixels.
@export var shade_start: float = -4.0
@export var shade_end: float = 40.0
@export_range(2, 16) var shade_levels: int = 5
@export var shade_darkest: Color = Color(0.3, 0.33, 0.42)

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
## (trail_shade_colors) starting at its threshold, dithered across dither_width px around it.
@export var trail_shade_radius: float = 14.0
@export var trail_shade_squash: float = 0.5
@export var trail_shade_levels: Array[float] = [0.05, 0.45, 0.8]
@export var trail_shade_colors: Array[Color] = [Color(0.43, 0.52, 0.31), Color(0.3, 0.4, 0.23), Color(0.17, 0.22, 0.17)]
@export var dither_width: float = 8.0

@export_group("Clod blocking")
## A clod is stopped inside a tree's silhouette shrunk by this many px (one grazing its edge passes).
@export var block_margin: float = 1.0

@export_group("Silhouettes")
## A body hidden behind a tree shows through it as a silhouette dithered over the tree, in this
## color: the flock, the shepherd and the dog; the enemies.
@export var silhouette_friend: Color = Color("f3e8c8")
@export var silhouette_enemy: Color = Color("c0242c")

## Collision layer 5 (obstacle).
const OBSTACLE_LAYER := 1 << 4
## Size (px) of a cell of the grid of tree feet used by `blocks()`.
const BLOCK_CELL := 16.0
## Farthest (px) the middle of a slice of a tree may be from its trunk, when looking for trees near a
## clod.
const PROFILE_SHIFT := 4.0
const SHADE_SHADER := preload("res://effects/forest_shade.gdshader")
## The forest's shade is laid over everything in the world but the night and the indicators
## (`Night.OVERLAY_Z`, `Night.MARKS_Z`).
const SHADE_Z := 7
## Ordered dithering thresholds (4x4 Bayer matrix, 0-15), by (y % 4) * 4 + x % 4, as in
## `effects/dither.gdshaderinc`.
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Visibility layer 2: the bodies' masks (`BodyMask`), drawn only in the mask view, never on screen.
## Layers cull their children too, so the masks' parents (this forest, Main) are on it as well.
const MASK_LAYER := 1 << 1
const TREE_SHADER := preload("res://effects/tree_silhouette.gdshader")
const MASK_SHADER := preload("res://effects/body_mask.gdshader")

var _trail: Ground
## Feet of the trail trees, all together and by grove (a lone tree is a grove of one).
var _trunks: Array[Vector2] = []
var _groves: Array[Array] = []
## What bodies steer around: one disc per grove (x, y: center; z: radius, px).
var _obstacles: Array[Vector3] = []
## Every tree (edge and trail), by grid cell: Vector2i -> Array of Vector3 (x, y: its foot; z: its
## variant, the cell of the sheet).
var _trees_by_cell: Dictionary = {}
## Solid of each variant, by height above the foot (px): Vector2(x of its middle from the trunk,
## radius), radius 0 where nothing is drawn.
var _profiles: Array[PackedVector2Array] = []
## Widest radius (px) of any variant.
var _widest: float = 0.0
var _edge_noise := FastNoiseLite.new()
var _clearing_noise := FastNoiseLite.new()
## The silhouettes: the view of the bodies' masks (the same world, only MASK_LAYER, the same screen),
## the masks (y-sorted like the bodies) and the trees' material that reads the view.
var _mask_view: SubViewport
var _masks: Node2D
var _tree_material: ShaderMaterial


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("forest")
	_trail = get_tree().get_first_node_in_group("trail") as Ground
	if _trail == null or tree_texture == null:
		return
	_setup_silhouettes()
	_read_profiles()
	var seed_value := layout_seed + RunManager.trip_seed()
	_edge_noise.seed = seed_value
	_edge_noise.frequency = edge_frequency
	_clearing_noise.seed = seed_value + 1
	_clearing_noise.frequency = clearing_frequency
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
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
					_plant(rng, _point(side, at, _out(side, at, tree_depth)))
				along += spacing
			depth += row_spacing

	_plant_trail(rng)

	# The forest's shade over everything in it (out past the camera limit).
	var area := _trail.bounds().grow(_trail.edge_depth + cell_size)
	var shade := Node2D.new()
	shade.z_index = SHADE_Z
	shade.material = _shade_material()
	shade.draw.connect(func() -> void: shade.draw_rect(area, Color.WHITE))
	add_child(shade)
	# Below the trees and the entities, above the ground: the groves' shade.
	var grove_shade := Node2D.new()
	grove_shade.z_index = -1
	grove_shade.draw.connect(_draw_grove_shades.bind(grove_shade))
	add_child(grove_shade)


func _plant(rng: RandomNumberGenerator, foot: Vector2) -> void:
	foot = foot.round()
	if _clearing_noise.get_noise_2dv(foot) > clearing_threshold:
		return
	_add_tree(rng, foot)


func _add_tree(rng: RandomNumberGenerator, foot: Vector2) -> Sprite2D:
	var tree := Sprite2D.new()
	tree.texture = tree_texture
	tree.hframes = sheet_cells
	tree.frame = rng.randi() % variants
	_remember(to_global(foot), tree.frame)
	tree.offset = Vector2(cell_size / 2.0 - trunk_x, -cell_size / 2.0)
	tree.position = foot
	tree.material = _tree_material
	add_child(tree)
	return tree


## Shows `body` (its `AnimatedSprite2D`) as a silhouette wherever a tree hides it, an enemy's in red;
## each body calls it once ready.
func track(body: Node2D) -> void:
	var sprite := body.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if _masks == null or sprite == null:
		return
	var mask := BodyMask.new()
	mask.setup(body, sprite, body is Enemy, MASK_LAYER, MASK_SHADER)
	_masks.add_child(mask)


func _setup_silhouettes() -> void:
	visibility_layer |= MASK_LAYER
	var parent := get_parent() as CanvasItem
	if parent:
		parent.visibility_layer |= MASK_LAYER
	get_viewport().canvas_cull_mask &= ~MASK_LAYER
	_masks = Node2D.new()
	_masks.y_sort_enabled = true
	_masks.visibility_layer = MASK_LAYER
	add_child(_masks)
	_mask_view = SubViewport.new()
	_mask_view.world_2d = get_viewport().world_2d
	_mask_view.canvas_cull_mask = MASK_LAYER
	_mask_view.transparent_bg = true
	_mask_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask_view)
	_tree_material = ShaderMaterial.new()
	_tree_material.shader = TREE_SHADER
	_tree_material.set_shader_parameter(&"body_mask", _mask_view.get_texture())
	_tree_material.set_shader_parameter(&"friend_color", silhouette_friend)
	_tree_material.set_shader_parameter(&"enemy_color", silhouette_enemy)
	# Once everything has moved this frame, camera included.
	RenderingServer.frame_pre_draw.connect(_frame_mask_view)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_frame_mask_view):
		RenderingServer.frame_pre_draw.disconnect(_frame_mask_view)


## The mask view covers the screen as drawn: the window's pixels, the camera and the stretch.
func _frame_mask_view() -> void:
	var viewport := get_viewport()
	_mask_view.size = get_window().size
	_mask_view.canvas_transform = viewport.get_final_transform() * viewport.canvas_transform


## Keeps a tree for `blocks()`.
func _remember(foot: Vector2, variant: int) -> void:
	var cell := Vector2i((foot / BLOCK_CELL).floor())
	if not _trees_by_cell.has(cell):
		_trees_by_cell[cell] = []
	(_trees_by_cell[cell] as Array).append(Vector3(foot.x, foot.y, variant))


## Reads the solid of each variant from the sheet: on each row of pixels, the span of what is drawn
## (its middle and half its width), as a disc around the trunk at that height.
func _read_profiles() -> void:
	var image := tree_texture.get_image()
	if image.is_compressed():
		image.decompress()
	for variant in variants:
		var profile := PackedVector2Array()
		for height in cell_size:
			var row := cell_size - 1 - height
			var left := -1
			var right := -1
			for x in cell_size:
				if image.get_pixel(variant * cell_size + x, row).a > 0.5:
					if left < 0:
						left = x
					right = x
			if left < 0:
				profile.append(Vector2.ZERO)
				continue
			var radius := (right + 1 - left) / 2.0
			profile.append(Vector2((left + right + 1) / 2.0 - trunk_x, radius))
			_widest = maxf(_widest, radius)
		_profiles.append(profile)


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
				_add_tree(rng, foot)
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


## True when a clod `height` px above `ground` is inside a tree, as drawn (its silhouette at that
## height, turned round its trunk). A tree spreading over `thrown_from` does not count: a clod
## thrown from under a tree leaves it.
func blocks(ground: Vector2, height: float, thrown_from: Vector2) -> bool:
	var level := int(height)
	if level < 0 or level >= cell_size or _profiles.is_empty():
		return false
	# The widest slice, plus how far off the trunk its middle may be.
	var reach := Vector2.ONE * (_widest + PROFILE_SHIFT)
	var from := Vector2i(((ground - reach) / BLOCK_CELL).floor())
	var to := Vector2i(((ground + reach) / BLOCK_CELL).floor())
	for cx in range(from.x, to.x + 1):
		for cy in range(from.y, to.y + 1):
			for tree: Vector3 in _trees_by_cell.get(Vector2i(cx, cy), []):
				var foot := Vector2(tree.x, tree.y)
				var slice := _profiles[int(tree.z)][level]
				var radius := slice.y - block_margin
				if radius <= 0.0 or thrown_from.distance_to(foot) < _widest:
					continue
				if ground.distance_to(foot + Vector2(slice.x, 0)) <= radius:
					return true
	return false


## True when a tree drawn in front of a body whose feet are at `feet_y` (its foot lower down, y-sorted)
## covers `point` of that body on screen, as drawn (its silhouette, `_profiles`).
func hides(point: Vector2, feet_y: float) -> bool:
	if _profiles.is_empty():
		return false
	var reach := _widest + PROFILE_SHIFT
	var from := Vector2i(floori((point.x - reach) / BLOCK_CELL), floori(feet_y / BLOCK_CELL))
	var to := Vector2i(floori((point.x + reach) / BLOCK_CELL), floori((point.y + cell_size) / BLOCK_CELL))
	for cx in range(from.x, to.x + 1):
		for cy in range(from.y, to.y + 1):
			for tree: Vector3 in _trees_by_cell.get(Vector2i(cx, cy), []):
				var level := int(tree.y - point.y)
				if tree.y <= feet_y or level < 0 or level >= cell_size:
					continue
				var slice := _profiles[int(tree.z)][level]
				if slice.y > 0.0 and absf(point.x - (tree.x + slice.x)) <= slice.y:
					return true
	return false


## True when `point` is at least `margin` px away from every grove and lone tree of the trail.
func is_clear(point: Vector2, margin: float) -> bool:
	for obstacle in _obstacles:
		if point.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + margin:
			return false
	return true


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


## The forest's shade: the shader finds each pixel's depth behind the front line from how far the
## line recedes along each side (one row per side, one texel per px along it, as `_out()` gives it;
## the shader holds the end values past the end of a side).
func _shade_material() -> ShaderMaterial:
	var top := _span(Wall.TOP)
	var size := ceili(top.y) - floori(top.x)
	var recess := Image.create(size, 4, false, Image.FORMAT_RF)
	for row in 4:
		var side: Wall = [Wall.TOP, Wall.BOTTOM, Wall.LEFT, Wall.RIGHT][row]
		var origin := floori(top.x) if row < 2 else 0
		for i in size:
			# How far the front line recedes there (`_out()` = depth - overflow + recess).
			recess.set_pixel(i, row, Color(_out(side, origin + i, 0.0) + overflow, 0.0, 0.0))
	var material := ShaderMaterial.new()
	material.shader = SHADE_SHADER
	material.set_shader_parameter(&"start", shade_start)
	material.set_shader_parameter(&"end", shade_end)
	material.set_shader_parameter(&"levels", shade_levels)
	material.set_shader_parameter(&"darkest", Vector3(shade_darkest.r, shade_darkest.g, shade_darkest.b))
	material.set_shader_parameter(&"overflow", overflow)
	material.set_shader_parameter(&"recess", ImageTexture.create_from_image(recess))
	material.set_shader_parameter(&"along_origin", float(floori(top.x)))
	material.set_shader_parameter(&"band", _trail.bounds().size)
	return material


func _draw_grove_shades(canvas: Node2D) -> void:
	for feet: Array in _groves:
		_draw_grove_shade(canvas, feet)


## The grove's outline in flattened space (y divided by trail_shade_squash): strength 1 inside,
## fading to 0 trail_shade_radius away from it, each level from its threshold, dithered across
## dither_width px around it; drawn line by line, a run of one level per rect.
func _draw_grove_shade(canvas: Node2D, feet: Array) -> void:
	var flat := PackedVector2Array()
	var box := Rect2(feet[0], Vector2.ZERO)
	for foot: Vector2 in feet:
		box = box.expand(foot)
		flat.append(Vector2(foot.x, foot.y / trail_shade_squash))
	var outline := Geometry2D.convex_hull(flat) if flat.size() >= 3 else flat
	# Out to where the dithering of the faintest level ends.
	var radius := trail_shade_radius + dither_width / 2.0
	var reach := Vector2(radius, radius * trail_shade_squash)
	box = box.grow_individual(reach.x, reach.y, reach.x, reach.y)
	var levels := mini(trail_shade_levels.size(), trail_shade_colors.size())
	# The dithering width in strength (it goes from 1 to 0 across trail_shade_radius px).
	var width := maxf(dither_width / trail_shade_radius, 0.001)
	for y in range(floori(box.position.y), ceili(box.end.y)):
		var run_start := 0
		var run_level := -1
		for x in range(floori(box.position.x), ceili(box.end.x) + 1):
			var level := -1
			if x < ceili(box.end.x):
				var point := Vector2(x + 0.5, (y + 0.5) / trail_shade_squash)
				var strength := 1.0 - _outline_distance(outline, point) / trail_shade_radius
				var threshold := (BAYER[posmod(y, 4) * 4 + posmod(x, 4)] + 0.5) / 16.0
				for i in levels:
					if clampf((strength - trail_shade_levels[i]) / width + 0.5, 0.0, 1.0) > threshold:
						level = i
			if level != run_level:
				if run_level >= 0:
					canvas.draw_rect(Rect2(run_start, y, x - run_start, 1), trail_shade_colors[run_level])
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
