class_name Enemy
extends CharacterBody2D
## What the sheep, the dog and the AttackDirector know of an enemy (group `enemy`).

signal sheep_captured(sheep: Sheep)
signal sheep_lost(sheep: Sheep)

## Spawns and despawns this far (px) outside the visible screen.
const OFFSCREEN_MARGIN := 24.0


## True while nearby sheep should panic.
func is_dangerous() -> bool:
	return false


## True while the dog may chase it.
func is_threat() -> bool:
	return false


## Barked at by the dog.
func scare() -> void:
	pass


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
