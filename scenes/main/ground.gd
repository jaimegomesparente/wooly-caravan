class_name Ground
extends Node2D
## One trip: a band from (0, 0) to (length, height) walked from left to right, with a start and
## an end pasture, walls all around; the grass goes on beyond them, under the forest (`Forest`).

## Tuft shapes, as pixel offsets from the tuft's top-left corner.
const TUFT_SHAPES: Array = [
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(2, 1)],  # tall blade + short one
	[Vector2i(0, 0), Vector2i(0, 1)],  # single blade
	[Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1)],  # V
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],  # small clump
	[Vector2i(1, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(3, 1)],  # wide clump
	[Vector2i(0, 0)],  # lone speck
]
## Stone shapes: [lit pixels, shaded pixels], as offsets from the top-left corner.
const STONE_SHAPES: Array = [
	[[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 1), Vector2i(1, 1)]],  # 2x2
	[[], [Vector2i(0, 0)]],  # pebble
	[[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]],  # flat 3x2
	[[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]],  # round 3x3
	[[Vector2i(0, 0)], [Vector2i(0, 1), Vector2i(2, 1)]],  # stone + pebble
]
## Collision layer 5 (obstacle).
const OBSTACLE_LAYER := 1 << 4

## Walkable band size (px).
@export var length: float = 3200.0
@export var height: float = 300.0
## Forest drawn beyond the top and bottom walls (px); the camera never shows past it.
@export var edge_depth: float = 48.0
## Width (px) of the start and end pastures.
@export var patch_width: float = 240.0
## Same seed = same layout every run.
@export var layout_seed: int = 1
@export var tuft_count: int = 840
@export var stone_count: int = 72

@export_group("Palette")
@export var grass_color: Color = Color(0.605, 0.68, 0.415, 1.0)
@export var patch_color: Color = Color(0.502, 0.712, 0.395, 1.0)
@export var tuft_dark_color: Color = Color(0.46, 0.544, 0.289)
@export var tuft_light_color: Color = Color(0.775, 0.806, 0.446)
@export var tuft_bright_color: Color = Color(0.9, 0.85, 0.493)
@export var stone_color: Color = Color(0.7, 0.68, 0.6)
@export var stone_shade_color: Color = Color(0.46, 0.45, 0.42)


func _ready() -> void:
	add_to_group("trail")
	var walls := StaticBody2D.new()
	walls.collision_layer = OBSTACLE_LAYER
	walls.collision_mask = 0
	var e := edge_depth
	for rect: Rect2 in [
			Rect2(-e, -e, length + e * 2.0, e),  # top
			Rect2(-e, height, length + e * 2.0, e),  # bottom
			Rect2(-e, 0, e, height),  # left
			Rect2(length, 0, e, height),  # right
	]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)
	add_child(walls)


## The walkable band, in this node's coordinates (the node sits at the world origin).
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(length, height))


func _draw() -> void:
	var e := edge_depth
	draw_rect(Rect2(-e, -e, length + e * 2.0, height + e * 2.0), grass_color)
	# The pastures run on under the forest at the left and right ends.
	draw_rect(Rect2(-e, 0, patch_width + e, height), patch_color)
	draw_rect(Rect2(length - patch_width, 0, patch_width + e, height), patch_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	for i in tuft_count:
		var spot := _random_spot(rng)
		var roll := rng.randf()
		var color := tuft_dark_color if roll < 0.5 else tuft_light_color if roll < 0.85 else tuft_bright_color
		_draw_pixels(spot, TUFT_SHAPES[rng.randi() % TUFT_SHAPES.size()], color)
	for i in stone_count:
		var spot := _random_spot(rng)
		var shape: Array = STONE_SHAPES[rng.randi() % STONE_SHAPES.size()]
		_draw_pixels(spot, shape[0], stone_color)
		_draw_pixels(spot, shape[1], stone_shade_color)


func _draw_pixels(spot: Vector2, pixels: Array, color: Color) -> void:
	for pixel: Vector2i in pixels:
		draw_rect(Rect2(spot + Vector2(pixel), Vector2.ONE), color)


func _random_spot(rng: RandomNumberGenerator) -> Vector2:
	# Keep 4 px from the bottom and right edges so the widest shapes stay on the grass.
	return Vector2(rng.randf() * (length - 4.0), rng.randf() * (height - 4.0)).floor()
