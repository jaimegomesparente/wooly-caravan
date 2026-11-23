class_name Crosshair
extends CanvasLayer
## The mouse cursor while the shepherd can throw: a pixel crosshair, red when the mouse is beyond
## the crook's reach (the clod then falls short). A ring around it fills up during the throw's
## cooldown and flashes once full. The arcs and landing spots of the throw are drawn in the world
## by `AimPreview`. Elsewhere (screens, pause, pasture) the usual cursor shows. Built in code, drawn
## in code.

const COLOR := Color("f3e8c8")
const OUT_OF_REACH_COLOR := Color("c0242c")
const OUTLINE := Color("1d1410")
## Crosshair pixels around the mouse: a center dot and four arms with a 1 px gap.
const CROSS: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(2, 0), Vector2(3, 0), Vector2(-2, 0), Vector2(-3, 0),
	Vector2(0, 2), Vector2(0, 3), Vector2(0, -2), Vector2(0, -3),
]
## Cooldown ring: lengths of the straight runs of pixels going round a quarter of it, from the top
## to the side (the middle one on the diagonal; the other quarters mirror it), color of the part
## still empty, and how long (s) it flashes once full.
const RING_RUNS: Array[int] = [5, 2, 1, 2, 5]
const RING_EMPTY := Color(0.11, 0.08, 0.06, 0.45)
const RING_FLASH_TIME := 0.12

var _canvas: Node2D
var _readiness: float = 1.0
var _flash_timer: float = 0.0
## Pixels of the ring around the mouse, clockwise from the top.
var _ring: Array[Vector2] = []


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_cursor)
	add_child(_canvas)
	_ring = _ring_pixels(RING_RUNS)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var shepherd := _shepherd()
	var active := shepherd != null and not shepherd.resting and not get_tree().paused
	_canvas.visible = active
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if active else Input.MOUSE_MODE_VISIBLE
	if not active:
		return
	var readiness := shepherd.throw_readiness()
	if readiness >= 1.0 and _readiness < 1.0:
		_flash_timer = RING_FLASH_TIME
	_readiness = readiness
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	_canvas.queue_redraw()


func _draw_cursor() -> void:
	var shepherd := _shepherd()
	if shepherd == null:
		return
	var mouse := _canvas.get_local_mouse_position().round()
	var world_mouse := shepherd.get_global_mouse_position()
	var in_reach := shepherd.crook == null \
			or world_mouse.distance_to(shepherd.global_position) <= shepherd.crook.max_range
	_draw_pixels(mouse, CROSS, COLOR if in_reach else OUT_OF_REACH_COLOR)
	if _readiness < 1.0 or _flash_timer > 0.0:
		_draw_ring(mouse)


## Filled clockwise from the top as the cooldown runs out.
func _draw_ring(center: Vector2) -> void:
	var filled := _ring.size() if _flash_timer > 0.0 else int(_readiness * _ring.size())
	for i in _ring.size():
		_canvas.draw_rect(Rect2(center + _ring[i], Vector2.ONE), COLOR if i < filled else RING_EMPTY)


## The ring's pixels around the center, from its `runs`, sorted clockwise from the top.
static func _ring_pixels(runs: Array[int]) -> Array[Vector2]:
	# The top right quarter, from the top center (0, 0) down to the side center.
	var quarter: Array[Vector2] = []
	var middle := runs.size() / 2
	var half_top: int = (runs[0] - 1) / 2
	for x in half_top + 1:
		quarter.append(Vector2(x, 0))
	var at := quarter[-1]
	for k in range(1, runs.size()):
		var length: int = runs[k]
		if k == runs.size() - 1:
			length = (length - 1) / 2 + 1
		for j in length:
			if k < middle:
				quarter.append(at + Vector2(1 + j, 1))
			elif k == middle:
				quarter.append(at + Vector2(1 + j, 1 + j))
			else:
				quarter.append(at + Vector2(1, 1 + j))
		at = quarter[-1]
	# Centered: the side center is level with the center.
	var found := {}
	for pixel in quarter:
		pixel.y -= at.y
		for mirror: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			found[pixel * mirror] = true
	var pixels: Array[Vector2] = []
	pixels.assign(found.keys())
	pixels.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return fposmod(atan2(a.x, -a.y), TAU) < fposmod(atan2(b.x, -b.y), TAU))
	return pixels


func _draw_pixels(at: Vector2, pixels: Array[Vector2], color: Color) -> void:
	for pixel in pixels:
		_canvas.draw_rect(Rect2(at + pixel - Vector2.ONE, Vector2(3, 3)), OUTLINE)
	for pixel in pixels:
		_canvas.draw_rect(Rect2(at + pixel, Vector2.ONE), color)


func _shepherd() -> Shepherd:
	return get_tree().get_first_node_in_group("shepherd") as Shepherd
