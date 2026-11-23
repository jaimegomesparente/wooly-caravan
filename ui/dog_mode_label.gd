class_name DogModeLabel
extends Label
## The dog's current mode, top left. A change of mode makes it hop and flash.

## Hop (px, s) and flash color on a change of mode.
const HOP_HEIGHT := 2.0
const HOP_TIME := 0.2
const FLASH := Color(1.0, 0.9, 0.3)

var _home_y: float = 0.0
var _tween: Tween


func _ready() -> void:
	_home_y = position.y
	# The theme's pixel font, at its size.
	remove_theme_font_size_override(&"font_size")


func show_mode(mode_name: String) -> void:
	var first := text.is_empty()
	text = "Chien : %s" % mode_name
	if first:
		return
	if _tween:
		_tween.kill()
	modulate = FLASH
	_tween = create_tween().set_parallel()
	_tween.tween_method(func(t: float) -> void: position.y = _home_y - roundf(sin(t * PI) * HOP_HEIGHT),
			0.0, 1.0, HOP_TIME)
	_tween.tween_property(self, ^"modulate", Color.WHITE, HOP_TIME * 2.0)
