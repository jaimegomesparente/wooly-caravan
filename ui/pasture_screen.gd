class_name PastureScreen
extends CanvasLayer
## Between two trips, over a dark veil: the flock that arrived rests on the pasture and one power is
## chosen out of a few cards; the choice starts the next trip with those sheep. P (testing aid)
## opens it during a trip with every power: the one clicked applies at once and the trip goes on.

const CHOICES := 3
const CARD_SIZE := Vector2(88, 64)

var _saved: int = 0
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
	_saved = saved
	_testing = false
	_show("Trip %d/%d done: %d sheep\nChoose an upgrade" % [RunManager.trip, RunManager.TRIPS, saved],
			RunManager.offer(CHOICES))


func _show(title: String, powers: Array[PowerData]) -> void:
	_title.text = title
	for child in _cards.get_children():
		child.queue_free()
	for power in powers:
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
	get_tree().paused = false
	if _testing:
		visible = false
		return
	RunManager.next_trip(_saved)
	get_tree().reload_current_scene()
