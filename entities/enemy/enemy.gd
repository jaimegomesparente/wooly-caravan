class_name Enemy
extends CharacterBody2D
## What the sheep, the dog and the AttackDirector know of an enemy (group `enemy`).

signal sheep_captured(sheep: Sheep)
signal sheep_lost(sheep: Sheep)

## Spawns and despawns this far (px) outside the visible screen.
const OFFSCREEN_MARGIN := 24.0
## Every hit flashes the sprite white, fading over FLINCH_TIME s; a hit that leaves it some health
## also makes it recoil (px), the last one turns it grey for good.
const FLINCH_TIME := 0.12
const FLINCH_RECOIL := 2.0
const TINT_SHADER := preload("res://effects/enemy_tint.gdshader")
## Strongest slow from mud (fraction of its speed lost).
const MAX_MUD_SLOW := 0.8

## Hits (clods) it takes before it runs off; a bark makes it run off whatever is left.
@export var health: int = 1

## The sprite's tint (flash, grey, mud), made on the first hit.
var _tint: ShaderMaterial
## 1, or less while slowed by mud: each enemy multiplies its speeds by it.
var _speed_scale: float = 1.0
## Mud slows still running (a new hit restarts the count, the last one to end lifts the slow).
var _mud_slows: int = 0


## True while nearby sheep should panic.
func is_dangerous() -> bool:
	return false


## True while the dog may chase it.
func is_threat() -> bool:
	return false


## Barked at by the dog, or out of health: runs off (each enemy says how).
func scare() -> void:
	pass


## Hit by a clod flying along `direction`: flashes and loses `damage` health; at none it turns grey
## and runs off, otherwise it recoils and goes on with what it was doing. A muddy clod also slows it
## by `mud_slow` for `mud_time` s.
func hit(direction: Vector2, damage: int = 1, mud_slow: float = 0.0, mud_time: float = 0.0) -> void:
	health -= damage
	_flash()
	if mud_slow > 0.0 and mud_time > 0.0:
		_slow(mud_slow, mud_time)
	if health <= 0:
		_set_tint(&"grey", 1.0)
		scare()
		return
	global_position += direction.normalized() * FLINCH_RECOIL


func _slow(amount: float, time: float) -> void:
	_speed_scale = 1.0 - minf(amount, MAX_MUD_SLOW)
	_mud_slows += 1
	_set_tint(&"mud", 1.0)
	# Pauses with the game; never called once this enemy is gone.
	get_tree().create_timer(time, false).timeout.connect(_end_slow)


func _end_slow() -> void:
	_mud_slows -= 1
	if _mud_slows == 0:
		_speed_scale = 1.0
		_set_tint(&"mud", 0.0)


func _flash() -> void:
	_set_tint(&"flash", 1.0)
	if _tint:
		create_tween().tween_property(_tint, "shader_parameter/flash", 0.0, FLINCH_TIME)


func _set_tint(parameter: StringName, value: float) -> void:
	if _tint == null:
		var sprite := get_node_or_null("AnimatedSprite2D") as CanvasItem
		if sprite == null:
			return
		_tint = ShaderMaterial.new()
		_tint.shader = TINT_SHADER
		sprite.material = _tint
	_tint.set_shader_parameter(parameter, value)


func _flock_center() -> Vector2:
	var flock := get_tree().get_nodes_in_group("sheep")
	if flock.is_empty():
		return global_position
	var center := Vector2.ZERO
	for sheep: Node2D in flock:
		center += sheep.global_position
	return center / flock.size()


## The part of the world visible on screen at normal zoom (the debug zoom never changes where an
## enemy appears or telegraphs).
func _view_rect() -> Rect2:
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)
