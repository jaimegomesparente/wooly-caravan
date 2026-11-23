class_name BarkWave
extends Node2D
## A ring of 1 px dots spreading out from a barking dog to `radius` px, fading out as it goes; freed
## once over. Drawn in code.

@export var radius: float = 28.0
## Time (s) to spread out.
@export var time: float = 0.3
@export var color: Color = Color("f3e8c8")
## Radius (px) it starts from.
const START_RADIUS := 4.0

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / time
	var r := lerpf(START_RADIUS, radius, 1.0 - (1.0 - t) * (1.0 - t))
	var tint := Color(color, color.a * (1.0 - t))
	# About one dot per pixel of the ring.
	var dots := maxi(8, int(TAU * r))
	for i in dots:
		draw_rect(Rect2((Vector2.from_angle(TAU * i / dots) * r).round(), Vector2.ONE), tint)
