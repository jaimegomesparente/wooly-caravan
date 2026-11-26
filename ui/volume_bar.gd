class_name VolumeBar
extends Control
## The player's volume of one audio bus (`Sound.volume()`), as a row of pixel steps drawn in code in
## the buttons' browns: click or drag to set it (the left half of the first step mutes), mouse wheel
## one step up or down. A change applies and is saved at once; the effects' bar plays a click at the
## new level so it can be heard.

const STEP_SIZE := Vector2(4, 7)
const GAP := 1.0
const FULL := Color(0.952941, 0.909804, 0.784314)
## Opaque, drawn over the border color.
const EMPTY := Color(0.113725, 0.0784314, 0.0627451)
const BORDER := Color(0.545098, 0.360784, 0.211765)

## The bus it sets (`Master`, `Music`, `Sfx`).
@export var bus: StringName = &"Master"

var _level: int = 0


func _ready() -> void:
	_level = Sound.volume(bus)
	custom_minimum_size = Vector2(Sound.VOLUME_STEPS * (STEP_SIZE.x + GAP) - GAP, STEP_SIZE.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed:
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_set_level(_level_at(button.position.x))
			MOUSE_BUTTON_WHEEL_UP:
				_set_level(_level + 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_level(_level - 1)
			_:
				return
		accept_event()
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_set_level(_level_at(motion.position.x))
		accept_event()


func _draw() -> void:
	for i in Sound.VOLUME_STEPS:
		var step := Rect2(Vector2(i * (STEP_SIZE.x + GAP), 0), STEP_SIZE)
		if i < _level:
			draw_rect(step, FULL)
		else:
			draw_rect(step, BORDER)
			draw_rect(step.grow(-1), EMPTY)


## The level clicked at `x` (px from the left): the step under it, none left of the first one's middle.
func _level_at(x: float) -> int:
	if x < STEP_SIZE.x / 2.0:
		return 0
	return clampi(floori(x / (STEP_SIZE.x + GAP)) + 1, 0, Sound.VOLUME_STEPS)


func _set_level(level: int) -> void:
	level = clampi(level, 0, Sound.VOLUME_STEPS)
	if level == _level:
		return
	_level = level
	Sound.set_volume(bus, level)
	queue_redraw()
	if bus == &"Sfx":
		Sound.play(&"click")
