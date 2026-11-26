class_name TripBanner
extends CanvasLayer
## At the start of a trip, once the screen is back from black: a dark strip fades in across the
## screen, the trip's name slides in from the left with a slight overshoot, holds, slides out to the
## right, and the strip fades out. The game goes on meanwhile. Built in code, freed once over.

const FONT: Font = preload("res://art/fonts/alagard.ttf")
const FONT_SIZE := 16
const TEXT_COLOR := Color("f3e8c8")
const STRIP_COLOR := Color(0, 0, 0, 0.45)
## Height (px) of the strip, and its top (px from the top of the screen).
const STRIP_HEIGHT := 22.0
const STRIP_TOP := 40.0
## Times (s): wait before it starts (the fade back from black), strip fade, slide in, hold, slide out.
const DELAY := 0.3
const FADE_TIME := 0.2
const SLIDE_IN_TIME := 0.35
const HOLD_TIME := 1.0
const SLIDE_OUT_TIME := 0.3

var _strip: ColorRect
var _label: Label


func _init() -> void:
	layer = 2
	_strip = ColorRect.new()
	_strip.color = STRIP_COLOR
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_label = Label.new()
	_label.add_theme_font_override(&"font", FONT)
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_label.add_theme_color_override(&"font_color", TEXT_COLOR)
	_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_label.add_theme_constant_override(&"shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Shows `text` once.
func play(text: String) -> void:
	Sound.play(&"banner")
	var width := get_viewport().get_visible_rect().size.x
	_strip.position = Vector2(0, STRIP_TOP)
	_strip.size = Vector2(width, STRIP_HEIGHT)
	_strip.modulate.a = 0.0
	_label.text = text
	_label.size = _label.get_minimum_size()
	_label.position.y = roundf(STRIP_TOP + (STRIP_HEIGHT - _label.size.y) / 2.0)
	var outside_left := -_label.size.x
	var middle := roundf((width - _label.size.x) / 2.0)
	_slide(outside_left)
	var tween := create_tween()
	tween.tween_interval(DELAY)
	tween.tween_property(_strip, ^"modulate:a", 1.0, FADE_TIME)
	tween.parallel().tween_method(_slide, outside_left, middle, SLIDE_IN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_method(_slide, middle, width, SLIDE_OUT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_strip, ^"modulate:a", 0.0, FADE_TIME).set_delay(SLIDE_OUT_TIME - FADE_TIME)
	tween.tween_callback(queue_free)


## Whole pixels only.
func _slide(x: float) -> void:
	_label.position.x = roundf(x)
