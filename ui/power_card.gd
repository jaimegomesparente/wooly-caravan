@tool
class_name PowerCard
extends Button
## A power shown on the card of its target (sheet `power_cards_frames.png`, one 80x112 card per
## `PowerData.Target`): title in the top banner, description on the parchment, artwork behind the
## see-through window (a dark backdrop until the artworks come). It comes in rising and fading in
## (`appear()`), not clickable until it is in place, and goes away once a card is picked
## (`leave()`). Hovered it rises 1 px, brightens, and its description gives way to what it would
## change for this run, before and after (`Cooldown 0.70 » 0.53 s`). Pressed it sinks 1 px. Laid out in
## `power_card.tscn`: in the editor the card shows `preview_power` on the frame of
## `preview_target`, so its labels can be placed by hand.

const SIZE := Vector2(80, 112)
const FRAMES: Texture2D = preload("res://art/ui/power_cards/power_cards_frames.png")
## Title color per target: dark on the crook's wood, light on the sheep's and dog's dark banners.
const TITLE_COLORS: Array[Color] = [Color("1d1410"), Color("f3e8c8"), Color("f3e8c8")]
const HOVER_TINT := Color(1.12, 1.12, 1.12)
## Coming in: how far below its place the card starts (px), and how long it takes to rise (s).
const APPEAR_RISE := 16.0
const APPEAR_TIME := 0.3
## Going away: the picked card flashes this bright and rises PICK_RISE px, holds for PICK_HOLD s,
## then fades out in LEAVE_TIME s; the others sink APPEAR_RISE px while fading out meanwhile.
const PICK_FLASH := Color(1.6, 1.6, 1.6)
const PICK_RISE := 4.0
const PICK_HOLD := 0.25
const LEAVE_TIME := 0.2
## Time (s) a card takes to go away, picked or not.
const LEAVE_TOTAL := PICK_HOLD + LEAVE_TIME
## How each crook setting reads on a hovered card: name, unit, decimals (-1: a percentage). A
## setting missing here is not shown (arc_per_px goes with max_arc).
const STATS := {
	&"throw_cooldown": ["Cooldown", " s", 2],
	&"max_range": ["Reach", " px", 0],
	&"speed": ["Speed", " px/s", 0],
	&"damage": ["Damage", "", 0],
	&"clod_count": ["Clods", "", 0],
	&"clod_size": ["Clod size", " px", 0],
	&"max_arc": ["Arc height", " px", 0],
	&"mud_slow": ["Slow", "%", -1],
	&"mud_time": ["Slow time", " s", 1],
}

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

## Offset below its place while it comes in or goes away (px, negative = above).
var _rise: float = 0.0
## Hover / press offset: -1 hovered, 1 pressed, 0 otherwise.
var _lift: float = 0.0
var _tween: Tween
## The power's description, and what it would change for this run (empty when unknown).
var _description: String = ""
var _changes: String = ""


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	for style in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())


func _ready() -> void:
	_preview()


func setup(power: PowerData) -> void:
	_show(power, power.target)
	_description = power.description
	_changes = changes(power, RunManager.current_crook())


## One line per crook setting `power` changes: its value in `crook` now, and after taking it
## (empty without a crook).
static func changes(power: PowerData, crook: CrookData) -> String:
	if crook == null:
		return ""
	var after := crook.duplicate() as CrookData
	power.apply(after)
	var lines: PackedStringArray = []
	for effect in power.effects:
		if not STATS.has(effect.property):
			continue
		var stat: Array = STATS[effect.property]
		lines.append("%s %s » %s%s" % [stat[0], _stat_value(crook.get(effect.property), stat[2]),
				_stat_value(after.get(effect.property), stat[2]), stat[1]])
	return "\n".join(lines)


static func _stat_value(value: float, decimals: int) -> String:
	if decimals < 0:
		return str(roundi(value * 100.0))
	return ("%." + str(decimals) + "f") % value if decimals > 0 else str(roundi(value))


## Comes in after `delay` s: rises from `APPEAR_RISE` px below with a slight overshoot while fading in.
func appear(delay: float) -> void:
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_rise(APPEAR_RISE)
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_rise, APPEAR_RISE, 0.0, APPEAR_TIME).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"modulate:a", 1.0, APPEAR_TIME * 0.6).set_delay(delay)
	_tween.chain().tween_callback(func() -> void: mouse_filter = Control.MOUSE_FILTER_STOP)


## A card was picked (this one when `picked`): no longer clickable; the picked one flashes, rises
## and fades out, the others sink and fade out. Over after LEAVE_TOTAL s.
func leave(picked: bool) -> void:
	if _tween:
		_tween.kill()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = create_tween().set_parallel()
	if picked:
		modulate = PICK_FLASH
		_tween.tween_property(self, ^"modulate", Color.WHITE, PICK_HOLD)
		_tween.tween_method(_set_rise, _rise, -PICK_RISE, PICK_HOLD) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.chain().tween_property(self, ^"modulate:a", 0.0, LEAVE_TIME)
	else:
		_tween.tween_method(_set_rise, _rise, APPEAR_RISE, LEAVE_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, ^"modulate:a", 0.0, LEAVE_TIME)


func _set_rise(value: float) -> void:
	_rise = value
	_place()


## Whole pixels only.
func _place() -> void:
	(get_node("Body") as Control).position.y = round(_rise + _lift)


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
	var hovered := mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED
	_lift = 1.0 if pressed else -1.0 if mode == DRAW_HOVER else 0.0
	_place()
	body.modulate = HOVER_TINT if hovered else Color.WHITE
	if not _description.is_empty():
		(get_node("Body/Text") as Label).text = _changes if hovered and not _changes.is_empty() else _description
