class_name Night
extends Node2D
## Now and then a trip is walked at night: a veil laid over the world (`effects/lantern_light.gdshader`,
## at OVERLAY_Z) multiplies every color by what the night leaves of it, except around the lantern
## the shepherd carries, whose light fades out in a few levels, dithered between them: the fade
## follows the shepherd smoothly (as he is drawn, between physics ticks) while the dithering
## pattern stays put on the world's pixels. What is drawn above OVERLAY_Z (MARKS_Z: the sheep's "!"
## and rescue bar, the wolves' "!", the aim preview at night) and the HUD and screens (on their own
## layers) are never darkened. No eagle hunts at night.

const LANTERN_SHADER := preload("res://effects/lantern_light.gdshader")
## The night's veil is drawn at this z index; indicators are drawn at MARKS_Z, above it.
const OVERLAY_Z := 8
const MARKS_Z := 9
## Farther than this (px) in one tick, the shepherd was moved at once: no interpolation.
const TELEPORT_DISTANCE := 32.0

## Chance that a trip is walked at night.
@export_range(0.0, 1.0) var chance: float = 0.3
## Taken away from each color of the world (what is left is the night's color).
@export var darkness: Color = Color(0.985, 0.985, 0.95)
@export var lantern_color: Color = Color(1.0, 0.82, 0.55)
@export var lantern_energy: float = 1.0
## Radius (px) of the lantern's light.
@export var lantern_radius: int = 112
## Fraction of lantern_radius lit at full strength; beyond it the light fades out to the edge.
@export_range(0.0, 1.0) var lantern_core: float = 0.2
## Shape of the fade: above 1 it drops faster near the core, below 1 it holds longer.
@export var lantern_falloff: float = 1.5
## Levels of light from full to none (besides none), dithered between them.
@export_range(1, 16) var lantern_levels: int = 3
## Share of the way from one level to the next that is dithered (the rest is flat): 1, dithered all
## the way; lower, only thin dithered rings.
@export_range(0.05, 1.0) var dither_band: float = 1.0
## Where the lantern hangs, from the shepherd's feet.
@export var lantern_offset: Vector2 = Vector2(0, -6)

## True during a night trip.
static var active: bool = false

var _shepherd: Node2D
var _veil: ShaderMaterial
## What the veil covers: the whole trip and the forest around it.
var _area: Rect2
## The shepherd's position at the last two physics ticks.
var _previous: Vector2
var _current: Vector2


func _ready() -> void:
	active = randf() < chance
	if not active:
		return
	_shepherd = get_tree().get_first_node_in_group("shepherd") as Node2D
	var trail := get_tree().get_first_node_in_group("trail") as Ground
	if _shepherd == null or trail == null:
		return
	_area = trail.bounds().grow(trail.edge_depth + 64.0)
	_veil = ShaderMaterial.new()
	_veil.shader = LANTERN_SHADER
	_veil.set_shader_parameter(&"night", Vector3(1.0 - darkness.r, 1.0 - darkness.g, 1.0 - darkness.b))
	_veil.set_shader_parameter(&"lantern", Vector3(lantern_color.r, lantern_color.g, lantern_color.b))
	_veil.set_shader_parameter(&"energy", lantern_energy)
	_veil.set_shader_parameter(&"radius", float(lantern_radius))
	_veil.set_shader_parameter(&"core", lantern_core)
	_veil.set_shader_parameter(&"falloff", lantern_falloff)
	_veil.set_shader_parameter(&"levels", float(lantern_levels))
	_veil.set_shader_parameter(&"band", dither_band)
	material = _veil
	z_index = OVERLAY_Z
	_previous = _shepherd.global_position
	_current = _previous
	_place_lantern()


func _draw() -> void:
	if _veil:
		draw_rect(_area, Color.WHITE)


func _physics_process(_delta: float) -> void:
	if _veil == null:
		return
	var moved_at_once := _current.distance_to(_shepherd.global_position) >= TELEPORT_DISTANCE
	_previous = _shepherd.global_position if moved_at_once else _current
	_current = _shepherd.global_position


func _process(_delta: float) -> void:
	if _veil:
		_place_lantern()


## The lantern's light centered exactly where the shepherd is drawn.
func _place_lantern() -> void:
	var at := _previous.lerp(_current, Engine.get_physics_interpolation_fraction()) + lantern_offset
	_veil.set_shader_parameter(&"center", at)
