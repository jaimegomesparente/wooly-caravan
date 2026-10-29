class_name PastureScreen
extends CanvasLayer
## Between two trips, over a dark veil: the flock that arrived rests on the pasture and one power is
## chosen out of a few cards; the choice starts the next trip with those sheep.

const CHOICES := 3
const CARD_SIZE := Vector2(88, 64)

var _saved: int = 0

@onready var _title: Label = %Title
@onready var _cards: HBoxContainer = %Cards


func _ready() -> void:
	visible = false


func show_choice(saved: int) -> void:
	_saved = saved
	_title.text = "Trip %d/%d done: %d sheep\nChoose an upgrade" \
			% [RunManager.trip, RunManager.TRIPS, saved]
	for child in _cards.get_children():
		child.queue_free()
	for power in RunManager.offer(CHOICES):
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
	RunManager.next_trip(_saved)
	get_tree().paused = false
	get_tree().reload_current_scene()
