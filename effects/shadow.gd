@tool
class_name Shadow
extends Node2D
## Pixel ellipse on the ground under a character (see shadow.gdshader). Drawn below every character
## (z_index -1), so it never covers the legs of the one standing just behind; overlapping shadows
## do not get darker.

## Width and height (px) of the ellipse, centered on this node.
@export var size: Vector2i = Vector2i(10, 3):
	set(value):
		size = value
		set_instance_shader_parameter(&"size", Vector2(size))
		queue_redraw()

## The character's (centered) sprite: when its flip_h changes, the shadow is mirrored like the
## sprite's pixels, so it stays under the same part of the body. The axis is halfway between the
## sprite's center (position + offset) unflipped and flipped, as some characters (sheep) also move
## their sprite when they turn.
@export var sprite: AnimatedSprite2D

## x set in the editor, and the sprite's center x, for the unflipped sprite.
var _base_x: float = 0.0
var _base_sprite_x: float = 0.0
var _flipped: bool = false


func _ready() -> void:
	_base_x = position.x
	if sprite:
		_base_sprite_x = sprite.position.x + sprite.offset.x
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(_delta: float) -> void:
	if sprite == null or sprite.flip_h == _flipped:
		return
	_flipped = sprite.flip_h
	var flipped_sprite_x := sprite.position.x + sprite.offset.x
	position.x = _base_sprite_x + flipped_sprite_x - _base_x if _flipped else _base_x
	reset_physics_interpolation()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-(size / 2)), Vector2(size)), Color.WHITE)
