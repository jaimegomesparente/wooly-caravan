class_name PastureScreen
extends CanvasLayer
## Between two trips, over a light veil (the shorn flock grazes behind it): one power is chosen out
## of a few cards (`PowerCard`), then the screen hides (`chosen`). P (testing aid) opens it during a trip with every
## power: the one clicked applies at once and the trip goes on.

signal chosen

const CHOICES := 3
const CARD_SIZE := Vector2(88, 64)
const CARD_SCENE: PackedScene = preload("res://ui/power_card.tscn")
## Delay between two cards coming in, left to right (s).
const CARD_STAGGER := 0.1

## True when opened with P during a trip.
var _testing: bool = false

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
	_title.text = title
	for child in _cards.get_children():
		child.queue_free()
	for i in powers.size():
		var power := powers[i]
		if not _testing:
			var power_card := CARD_SCENE.instantiate() as PowerCard
			power_card.setup(power)
			power_card.pressed.connect(_choose.bind(power))
			_cards.add_child(power_card)
			power_card.appear(i * CARD_STAGGER)
			continue
		# Every power at once (P): plain buttons, cards would not fit on screen.
		var card := Button.new()
		card.text = "%s\n\n%s" % [power.title, power.description]
		card.custom_minimum_size = CARD_SIZE
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 8)
		card.pressed.connect(_choose.bind(power))
		_cards.add_child(card)
	visible = true


func _choose(power: PowerData) -> void:
	RunManager.take(power)
	visible = false
	if _testing:
		get_tree().paused = false
		return
	chosen.emit()
