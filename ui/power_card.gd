class_name PowerCard
extends Button
## A power shown on the card of its target (sheet `power_cards_frames.png`, one 80x112 card per
## `PowerData.Target`): title in the top banner, description on the parchment, artwork behind the
## see-through window (a dark backdrop until the artworks come). Hovered it rises 1 px and brightens,
## pressed it sinks 1 px.

const SIZE := Vector2(80, 112)
const FRAMES: Texture2D = preload("res://art/ui/power_cards/power_cards_frames.png")
## Areas inside the card (px).
const WINDOW := Rect2(12, 21, 56, 36)
const TITLE := Rect2(16, 4, 48, 11)
const TEXT := Rect2(8, 61, 64, 37)
## Placeholder font size, until the pixel font comes.
const FONT_SIZE := 6
const INK := Color("1d1410")
const WINDOW_COLOR := Color("3b3532")
## Title color per target: dark on the crook's wood, light on the sheep's and dog's dark banners.
const TITLE_COLORS: Array[Color] = [Color("1d1410"), Color("f3e8c8"), Color("f3e8c8")]
const HOVER_TINT := Color(1.12, 1.12, 1.12)

var _body: Control


func _init() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	for style in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = SIZE
	add_child(_body)


func setup(power: PowerData) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = WINDOW_COLOR
	_place(backdrop, WINDOW)
	var frame := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = FRAMES
	atlas.region = Rect2(Vector2(power.target * SIZE.x, 0), SIZE)
	frame.texture = atlas
	_place(frame, Rect2(Vector2.ZERO, SIZE))
	var title := _label(power.title, TITLE_COLORS[power.target], TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	var text := _label(power.description, INK, TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(content: String, color: Color, area: Rect2) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	_place(label, area)
	return label


func _place(node: Control, area: Rect2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = area.position
	node.size = area.size
	_body.add_child(node)


## The button redraws on every hover or press change: follow its draw mode.
func _draw() -> void:
	var mode := get_draw_mode()
	var pressed := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	_body.position.y = 1.0 if pressed else -1.0 if mode == DRAW_HOVER else 0.0
	_body.modulate = HOVER_TINT if mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED else Color.WHITE
