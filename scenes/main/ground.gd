extends Node2D

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

## Pasture size (px), centered on this node.
@export var size: Vector2 = Vector2(1600, 1000)
## Same seed = same layout every run.
@export var layout_seed: int = 1
@export var tuft_count: int = 1400
@export var stone_count: int = 120

@export_group("Palette")
@export var grass_color: Color = Color(0.385, 0.65, 0.318, 1.0)
@export var tuft_dark_color: Color = Color(0.25, 0.52, 0.2)
@export var tuft_light_color: Color = Color(0.5, 0.77, 0.32)
@export var tuft_bright_color: Color = Color(0.66, 0.86, 0.35)
@export var stone_color: Color = Color(0.7, 0.68, 0.6)
@export var stone_shade_color: Color = Color(0.46, 0.45, 0.42)


func _draw() -> void:
	var origin := -size / 2.0
	draw_rect(Rect2(origin, size), grass_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	for i in tuft_count:
		var spot := _random_spot(rng, origin)
		var roll := rng.randf()
		var color := tuft_dark_color if roll < 0.5 else tuft_light_color if roll < 0.85 else tuft_bright_color
		_draw_pixels(spot, TUFT_SHAPES[rng.randi() % TUFT_SHAPES.size()], color)
	for i in stone_count:
		var spot := _random_spot(rng, origin)
		var shape: Array = STONE_SHAPES[rng.randi() % STONE_SHAPES.size()]
		_draw_pixels(spot, shape[0], stone_color)
		_draw_pixels(spot, shape[1], stone_shade_color)


func _draw_pixels(spot: Vector2, pixels: Array, color: Color) -> void:
	for pixel: Vector2i in pixels:
		draw_rect(Rect2(spot + Vector2(pixel), Vector2.ONE), color)


func _random_spot(rng: RandomNumberGenerator, origin: Vector2) -> Vector2:
	return (origin + Vector2(rng.randf() * size.x, rng.randf() * size.y)).floor()
