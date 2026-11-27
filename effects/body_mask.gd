class_name BodyMask
extends Node2D
## The mask of one body (sheep, shepherd, dog, enemy) for the silhouettes behind the trees: a copy
## of its sprite, drawn only in the forest's mask view (visibility layer `Forest.MASK_LAYER`), its
## color replaced by a code (`body_mask.gdshader`): the height of the body's feet and its camp. It
## stands at the body's feet, so the masks are y-sorted like the bodies. Made by `Forest.track()`,
## freed with its body.

## As in `tree_silhouette.gdshader`: feet heights are coded in quarter pixels from this origin.
const FEET_ORIGIN := 1024.0
## Farther than this (px) in one physics tick, the body was moved at once: no interpolation.
const TELEPORT_DISTANCE := 32.0

var _body: Node2D
var _source: AnimatedSprite2D
var _enemy: bool = false
var _sprite: AnimatedSprite2D
## The body's position at the last two physics ticks, interpolated between when drawn (like the
## bodies themselves, physics interpolation having no getter in 2D).
var _previous: Vector2
var _current: Vector2


func setup(body: Node2D, source: AnimatedSprite2D, enemy: bool, layer: int, shader: Shader) -> void:
	_body = body
	_source = source
	_enemy = enemy
	visibility_layer = layer
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# After the bodies have moved in the tick.
	process_physics_priority = 100
	_sprite = AnimatedSprite2D.new()
	_sprite.visibility_layer = layer
	_sprite.material = ShaderMaterial.new()
	(_sprite.material as ShaderMaterial).shader = shader
	add_child(_sprite)
	_current = body.global_position
	_previous = _current


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_body):
		queue_free()
		return
	var at := _body.global_position
	_previous = at if _current.distance_to(at) >= TELEPORT_DISTANCE else _current
	_current = at


func _process(_delta: float) -> void:
	if not is_instance_valid(_body) or not is_instance_valid(_source):
		queue_free()
		return
	global_position = _previous.lerp(_current, Engine.get_physics_interpolation_fraction())
	_sprite.visible = _source.is_visible_in_tree()
	if not _sprite.visible:
		return
	# The sprite as drawn on the body (hops, lift, squash, flip).
	_sprite.transform = _body.global_transform.affine_inverse() * _source.global_transform
	_sprite.sprite_frames = _source.sprite_frames
	if _sprite.animation != _source.animation:
		_sprite.animation = _source.animation
	_sprite.frame = _source.frame
	_sprite.flip_h = _source.flip_h
	_sprite.flip_v = _source.flip_v
	_sprite.centered = _source.centered
	_sprite.offset = _source.offset
	var feet := clampi(roundi((global_position.y + FEET_ORIGIN) * 4.0), 0, 65535)
	_sprite.self_modulate = Color((feet >> 8) / 255.0, (feet & 255) / 255.0, 1.0 if _enemy else 0.0)
