class_name WoolCounter
extends Control
## The run's wool, top left: icon and count. Wool collected pops out of where it was earned as an
## icon, flies to the counter along a curve and adds to the count when it lands, with a pop.

## Time (s) and height (px) of the icon's hop out of the sheep, then time of its flight.
@export var hop_time: float = 0.25
@export var hop_height: float = 10.0
@export var flight_time: float = 0.6
## Scale of the counter icon when wool lands, easing back to 1.
@export var pop_scale: float = 1.4

## Count shown: catches up with RunManager.wool as the icons land.
var _shown: int = 0
var _pop: Tween

@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Label


func _ready() -> void:
	_shown = RunManager.wool
	_label.text = str(_shown)


## `amount` wool earned at `from` (canvas position): flies in, then counts.
func collect(from: Vector2, amount: int) -> void:
	var icon := Sprite2D.new()
	icon.texture = _icon.texture
	icon.position = (from - global_position).round()
	icon.scale = Vector2.ZERO
	add_child(icon)
	var top := icon.position + Vector2(0, -hop_height)
	var target := _icon.position + _icon.size / 2.0
	var tween := create_tween()
	tween.tween_property(icon, "position", top, hop_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2.ONE, hop_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_fly.bind(icon, top, target), 0.0, 1.0, flight_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_land.bind(icon, amount))


## `amount` wool spent: counts down at once.
func spend(amount: int) -> void:
	_shown -= amount
	_label.text = str(_shown)


## Quadratic curve: rises first, then swoops sideways onto the counter.
func _fly(t: float, icon: Sprite2D, from: Vector2, to: Vector2) -> void:
	var bend := Vector2(from.x, to.y)
	icon.position = from.lerp(bend, t).lerp(bend.lerp(to, t), t).round()


func _land(icon: Sprite2D, amount: int) -> void:
	icon.queue_free()
	_shown += amount
	_label.text = str(_shown)
	if _pop:
		_pop.kill()
	_icon.scale = Vector2.ONE * pop_scale
	_pop = create_tween()
	_pop.tween_property(_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
