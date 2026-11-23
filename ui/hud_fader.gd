class_name HudFader
extends Node
## Keeps the HUD out of the way during a trip: its elements are hidden, and one shows for a moment
## when it changes (`flash()`: hold_time s, then it fades out in fade_time s). While `pinned` (on
## the pasture) they all stay shown. Built in code by Main, given the HUD's elements.

## Time (s) an element stays shown after a change, then time (s) it takes to fade out.
@export var hold_time: float = 2.0
@export var fade_time: float = 0.3

## Shows every element for good.
var pinned: bool = false

## Element (CanvasItem) -> time (s) left shown.
var _timers: Dictionary = {}


## Hides `items` until they change.
func track(items: Array[CanvasItem]) -> void:
	for item in items:
		_timers[item] = 0.0
		item.modulate.a = 0.0


## Shows `item` for a moment (every element when null).
func flash(item: CanvasItem = null) -> void:
	for tracked: CanvasItem in _timers:
		if item == null or tracked == item:
			_timers[tracked] = hold_time + fade_time


func _process(delta: float) -> void:
	for item: CanvasItem in _timers:
		if not is_instance_valid(item):
			continue
		var left: float = maxf(_timers[item] - delta, 0.0)
		_timers[item] = left
		item.modulate.a = 1.0 if pinned else clampf(left / fade_time, 0.0, 1.0)
