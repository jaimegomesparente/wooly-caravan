class_name PastureScreen
extends CanvasLayer
## Between two trips, over a light veil (the shorn flock grazes behind it): one power is chosen out
## of a few cards (`PowerCard`), then the screen hides (`chosen`). P (testing aid) opens it during a trip with every
## power: the one clicked applies at once and the trip goes on. The veil and the title fade in, the
## cards come in one after another; once one is clicked they go away before the screen hides.

signal chosen

const CHOICES := 3
const CARD_SIZE := Vector2(88, 64)
const CARD_SCENE: PackedScene = preload("res://ui/power_card.tscn")
## Delay between two cards coming in, left to right (s).
const CARD_STAGGER := 0.1
## Time (s) of the veil's and the title's fades.
const FADE_TIME := 0.2

## True when opened with P during a trip.
var _testing: bool = false
## True once a card is clicked, while the cards go away.
var _closing: bool = false

@onready var _veil: ColorRect = $Veil
@onready var _title: Label = %Title
@onready var _cards: GridContainer = %Cards


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible and not get_tree().paused and event.is_action_pressed("pick_power"):
		_testing = true
		get_tree().paused = true
		_show("Pick a power (testing)", RunManager.POWERS)


func show_choice(saved: int) -> void:
	_testing = false
	_show("Trip %d/%d done: %d sheep\nChoose an upgrade" % [RunManager.trip, RunManager.TRIPS, saved],
			RunManager.offer(CHOICES))


func _show(title: String, powers: Array[PowerData]) -> void:
	_closing = false
	_title.text = title
	for child in _cards.get_children():
		child.queue_free()
	for i in powers.size():
		var power := powers[i]
		if not _testing:
			var power_card := CARD_SCENE.instantiate() as PowerCard
			power_card.setup(power)
			power_card.pressed.connect(_choose.bind(power, power_card))
			_cards.add_child(power_card)
			power_card.appear(i * CARD_STAGGER)
			continue
		# Every power at once (P): plain buttons, cards would not fit on screen.
		var card := Button.new()
		card.text = "%s\n\n%s" % [power.title, power.description]
		card.custom_minimum_size = CARD_SIZE
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 8)
		card.pressed.connect(_choose.bind(power, card))
		_cards.add_child(card)
	_veil.modulate.a = 0.0
	_title.modulate.a = 0.0
	var fade := create_tween().set_parallel()
	fade.tween_property(_veil, ^"modulate:a", 1.0, FADE_TIME)
	fade.tween_property(_title, ^"modulate:a", 1.0, FADE_TIME)
	visible = true


## The power applies at once; the cards go away, then the screen hides. Once the choice between two
## trips is made, the veil stays (the shop opens over the same one).
func _choose(power: PowerData, card: Button) -> void:
	if _closing:
		return
	_closing = true
	RunManager.take(power)
	for child in _cards.get_children():
		var power_card := child as PowerCard
		if power_card:
			power_card.leave(child == card)
		else:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := create_tween().set_parallel()
	fade.tween_property(_title, ^"modulate:a", 0.0, PowerCard.LEAVE_TIME)
	if _testing:
		fade.tween_property(_cards, ^"modulate:a", 0.0, PowerCard.LEAVE_TIME)
		fade.tween_property(_veil, ^"modulate:a", 0.0, PowerCard.LEAVE_TIME)
	else:
		fade.tween_interval(PowerCard.LEAVE_TOTAL)
	await fade.finished
	visible = false
	_cards.modulate.a = 1.0
	if _testing:
		get_tree().paused = false
		return
	chosen.emit()
