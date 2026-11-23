class_name HitStop
extends RefCounted
## Freezes the game for a few frames on an impact (Engine.time_scale nearly 0), so hits feel heavy.
## A freeze that ends earlier than the one running is ignored.

## Speed of the game while frozen.
const FROZEN_SCALE := 0.05

## When the running freeze ends (ms, Time.get_ticks_msec()).
static var _until: int = 0


## Freezes the game for `time` s (real time).
static func freeze(tree: SceneTree, time: float) -> void:
	var end := Time.get_ticks_msec() + int(time * 1000.0)
	if end <= _until:
		return
	_until = end
	Engine.time_scale = FROZEN_SCALE
	# Real time, even while paused; only the last freeze started puts the speed back.
	tree.create_timer(time, true, false, true).timeout.connect(func() -> void:
		if _until == end:
			Engine.time_scale = 1.0)
