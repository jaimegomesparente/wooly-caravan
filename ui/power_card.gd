@tool
class_name PowerCard
extends Button
## A power shown on the card of its target (sheet `power_cards_frames.png`, one 80x112 card per
## `PowerData.Target`): title in the top banner, description on the parchment, artwork behind the
## see-through window (a dark backdrop until the artworks come). Hovered it rises 1 px and brightens,
## pressed it sinks 1 px. Laid out in `power_card.tscn`: in the editor the card shows
## `preview_power` on the frame of `preview_target`, so its labels can be placed by hand.

const SIZE := Vector2(80, 112)
const FRAMES: Texture2D = preload("res://art/ui/power_cards/power_cards_frames.png")
## Title color per target: dark on the crook's wood, light on the sheep's and dog's dark banners.
const TITLE_COLORS: Array[Color] = [Color("1d1410"), Color("f3e8c8"), Color("f3e8c8")]
const HOVER_TINT := Color(1.12, 1.12, 1.12)

## Editor preview only: the power whose title and description are shown.
@export var preview_power: PowerData:
	set(value):
		preview_power = value
		_preview()
## Editor preview only: the frame shown.
@export var preview_target: PowerData.Target = PowerData.Target.CROOK:
	set(value):
		preview_target = value
		_preview()


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	for style in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())


func _ready() -> void:
	_preview()


func setup(power: PowerData) -> void:
	_show(power, power.target)


func _preview() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		_show(preview_power, preview_target)


func _show(power: PowerData, target: PowerData.Target) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = FRAMES
	atlas.region = Rect2(Vector2(target * SIZE.x, 0), SIZE)
	(get_node("Body/Frame") as TextureRect).texture = atlas
	var title := get_node("Body/Title") as Label
	title.add_theme_color_override("font_color", TITLE_COLORS[target])
	title.text = power.title if power else "Title"
	(get_node("Body/Text") as Label).text = power.description if power else "Description"


## The button redraws on every hover or press change: follow its draw mode.
func _draw() -> void:
	if Engine.is_editor_hint():
		return
	var body := get_node("Body") as Control
	var mode := get_draw_mode()
	var pressed := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	body.position.y = 1.0 if pressed else -1.0 if mode == DRAW_HOVER else 0.0
	body.modulate = HOVER_TINT if mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED else Color.WHITE
