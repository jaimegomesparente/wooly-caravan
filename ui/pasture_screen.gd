class_name PastureScreen
extends CanvasLayer
## Between two trips, over a light veil (the shorn flock grazes behind it): one power is chosen out
## of a few cards (`PowerCard`), then the screen hides (`chosen`). The same choice opens the run,
## before the first trip (`show_opening()`: the game paused, the veil fades out once chosen, then
## `chosen`). P (testing aid) opens it during a trip with every
## power: the one clicked applies at once and the trip goes on. The veil and the title fade in, the
## cards come in one after another; once one is clicked they go away before the screen hides.

signal chosen

const CHOICES := 3
## Size (px) of a button of the testing choice (P).
const CARD_SIZE := Vector2(96, 20)
const CARD_SCENE: PackedScene = preload("res://ui/power_card.tscn")
## Delay between two cards coming in, left to right (s).
const CARD_STAGGER := 0.1
## Time (s) of the veil's and the title's fades.
const FADE_TIME := 0.2

## True when opened with P during a trip.
var _testing: bool = false
## True for the choice before the first trip.
var _opening: bool = false
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
		_opening = false
		get_tree().paused = true
		_show("Pick a power (testing)", RunManager.POWERS)


## After the trip report (`TripReport`).
func show_choice() -> void:
	_testing = false
	_opening = false
	_show("Choose an upgrade", RunManager.offer(CHOICES))


## Before the first trip of a run: the game waits, paused, until a power is chosen.
func show_opening() -> void:
	_testing = false
	_opening = true
	get_tree().paused = true
	_show("Choose an upgrade", RunManager.offer(CHOICES))


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
		# Every power at once (P): plain buttons with its name, cards would not fit on screen.
		var card := Button.new()
		card.text = power.title
		card.custom_minimum_size = CARD_SIZE
		card.pressed.connect(_choose.bind(power, card))
		_cards.add_child(card)
	_veil.modulate.a = 0.0
	_title.modulate.a = 0.0
	var fade := create_tween().set_parallel()
	fade.tween_property(_veil, ^"modulate:a", 1.0, FADE_TIME)
	fade.tween_property(_title, ^"modulate:a", 1.0, FADE_TIME)
	visible = true


## The power applies at once; the cards go away, then the screen hides. Once the choice between two
## trips is made, the veil stays (the shop opens over the same one); otherwise it fades out and the
## game goes on.
func _choose(power: PowerData, card: Button) -> void:
	if _closing:
		return
	_closing = true
	Sound.play(&"power_pick")
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
	elif _opening:
		fade.tween_interval(PowerCard.LEAVE_TOTAL)
		fade.chain().tween_property(_veil, ^"modulate:a", 0.0, FADE_TIME)
	else:
		fade.tween_interval(PowerCard.LEAVE_TOTAL)
	await fade.finished
	visible = false
	_cards.modulate.a = 1.0
	if _testing or _opening:
		get_tree().paused = false
	if _testing:
		return
	chosen.emit()
