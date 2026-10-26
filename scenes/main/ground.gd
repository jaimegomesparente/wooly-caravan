extends Node2D

## Pasture size (px), centered on this node.
@export var size: Vector2 = Vector2(1600, 1000)
## Same seed = same layout every run.
@export var layout_seed: int = 1
@export var tuft_count: int = 1400
@export var stone_count: int = 120

@export_group("Palette")
@export var grass_color: Color = Color(0.29, 0.5, 0.24)
@export var tuft_dark_color: Color = Color(0.23, 0.42, 0.2)
@export var tuft_light_color: Color = Color(0.36, 0.58, 0.28)
@export var stone_color: Color = Color(0.56, 0.56, 0.5)
@export var stone_shade_color: Color = Color(0.4, 0.4, 0.36)


func _draw() -> void:
	var origin := -size / 2.0
	draw_rect(Rect2(origin, size), grass_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	for i in tuft_count:
		var spot := _random_spot(rng, origin)
		var color := tuft_dark_color if rng.randf() < 0.6 else tuft_light_color
		# Two tiny blades: one 2 px tall, one 1 px beside it.
		draw_rect(Rect2(spot, Vector2(1, 2)), color)
		draw_rect(Rect2(spot + Vector2(2, 1), Vector2(1, 1)), color)
	for i in stone_count:
		var spot := _random_spot(rng, origin)
		draw_rect(Rect2(spot, Vector2(2, 1)), stone_color)
		draw_rect(Rect2(spot + Vector2(0, 1), Vector2(2, 1)), stone_shade_color)


func _random_spot(rng: RandomNumberGenerator, origin: Vector2) -> Vector2:
	return (origin + Vector2(rng.randf() * size.x, rng.randf() * size.y)).floor()
