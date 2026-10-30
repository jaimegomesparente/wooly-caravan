class_name ShopScreen
extends CanvasLayer
## On the pasture, after the power is chosen: wool buys recruits that join the flock at once, or
## turns a sheep into a ram (`bought`). Each offer can be bought again while the wool lasts; Continue hides the screen
## (`closed`).

signal bought(item: StringName)
signal closed

const CARD_SIZE := Vector2(64, 32)

@export var counter: WoolCounter
@export var sheep_price: int = 10
@export var lamb_price: int = 5
@export var ram_price: int = 15

@onready var _title: Label = %Title
@onready var _cards: GridContainer = %Cards
@onready var _continue: Button = %Continue


func _ready() -> void:
	visible = false
	_continue.pressed.connect(_close)


func open() -> void:
	for child in _cards.get_children():
		child.queue_free()
	_add_offer(&"sheep", "Sheep", sheep_price)
	_add_offer(&"lamb", "Lamb", lamb_price)
	_add_offer(&"ram", "Ram", ram_price)
	_refresh()
	visible = true


func _add_offer(item: StringName, title: String, price: int) -> void:
	var card := Button.new()
	card.text = "%s\n%d wool" % [title, price]
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_font_size_override("font_size", 8)
	card.set_meta(&"item", item)
	card.set_meta(&"price", price)
	card.pressed.connect(_buy.bind(item, price))
	_cards.add_child(card)


func _buy(item: StringName, price: int) -> void:
	if RunManager.wool < price:
		return
	RunManager.wool -= price
	counter.spend(price)
	bought.emit(item)
	_refresh()


## Title with the wool left; the offers it cannot pay for are greyed out, and the ram once every
## sheep is one.
func _refresh() -> void:
	_title.text = "Shop: %d wool" % RunManager.wool
	var ewes := get_tree().get_nodes_in_group("sheep").filter(
			func(sheep: Sheep) -> bool: return not sheep.lamb and not sheep.ram)
	for card: Button in _cards.get_children():
		card.disabled = RunManager.wool < int(card.get_meta(&"price")) \
				or card.get_meta(&"item") == &"ram" and ewes.is_empty()


func _close() -> void:
	visible = false
	closed.emit()
