class_name StunStars
extends Node2D
## Little stars circling over a stunned head, drawn in code: dimmer on the far side of the circle.
## Gone after `time` s.

@export var count: int = 3
## Half width and half height (px) of the circle seen from the side.
@export var radius: Vector2 = Vector2(6, 2)
## Seconds for one turn.
@export var turn_time: float = 0.6
@export var color: Color = Color(1.0, 0.9, 0.3)

## Time (s) left before the stars go.
var time: float = 1.0
var _angle: float = 0.0


func _process(delta: float) -> void:
	time -= delta
	if time <= 0.0:
		queue_free()
		return
	_angle += TAU * delta / turn_time
	queue_redraw()


## Each star is a 1 px dot with four 1 px arms.
func _draw() -> void:
	for i in count:
		var angle := _angle + TAU * i / count
		var point := Vector2(cos(angle) * radius.x, sin(angle) * radius.y).round()
		var tint := color if sin(angle) >= 0.0 else color.darkened(0.4)
		draw_rect(Rect2(point, Vector2.ONE), tint)
		for arm: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_rect(Rect2(point + arm, Vector2.ONE), Color(tint, 0.6))
