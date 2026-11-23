class_name ShopScreen
extends CanvasLayer
## On the pasture, after the power is chosen: wool buys recruits that join the flock at once, or
## turns a sheep into a ram (`bought`). Each offer can be bought again while the wool lasts; Continue hides the screen
## (`closed`). Its offers fade in; one bought hops, one too dear is greyed and, clicked, shakes and
## flashes red.

signal bought(item: StringName)
signal closed

const CARD_SIZE := Vector2(64, 32)
## Time (s) of the offers' fade in.
const FADE_TIME := 0.2
## Tint of an offer the wool cannot pay for, and its flash when clicked anyway.
const POOR_TINT := Color(0.6, 0.6, 0.6)
const REFUSED_TINT := Color(1.0, 0.35, 0.3)
## Shake of a refused offer: whole-pixel offsets (px) in turn, each held SHAKE_STEP s.
const SHAKE_OFFSETS: Array[float] = [2.0, -2.0, 1.0, -1.0, 0.0]
const SHAKE_STEP := 0.04
## Hop (px, s) of an offer bought.
const HOP_HEIGHT := 2.0
const HOP_TIME := 0.15

@export var counter: WoolCounter
@export var sheep_price: int = 10
@export var lamb_price: int = 5
@export var ram_price: int = 15

@onready var _center: Control = $Center
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
	_center.modulate.a = 0.0
	create_tween().tween_property(_center, ^"modulate:a", 1.0, FADE_TIME)
	visible = true


func _add_offer(item: StringName, title: String, price: int) -> void:
	var card := Button.new()
	card.text = "%s\n%d wool" % [title, price]
	card.custom_minimum_size = CARD_SIZE
	card.set_meta(&"item", item)
	card.set_meta(&"price", price)
	card.pressed.connect(_buy.bind(card, item, price))
	_cards.add_child(card)


func _buy(card: Button, item: StringName, price: int) -> void:
	if RunManager.wool < price:
		_refuse(card)
		return
	RunManager.wool -= price
	counter.spend(price)
	bought.emit(item)
	_refresh()
	_hop(card)


## Greyed out: the offers the wool cannot pay for (still clickable, to say why with a shake).
## Disabled: the ram once every sheep is one.
func _refresh() -> void:
	_title.text = "Shop: %d wool" % RunManager.wool
	var ewes := get_tree().get_nodes_in_group("sheep").filter(
			func(sheep: Sheep) -> bool: return not sheep.lamb and not sheep.ram)
	for card: Button in _cards.get_children():
		card.disabled = card.get_meta(&"item") == &"ram" and ewes.is_empty()
		card.modulate = POOR_TINT if RunManager.wool < int(card.get_meta(&"price")) else Color.WHITE


## Too dear: the offer shakes sideways and flashes red, back to grey.
func _refuse(card: Button) -> void:
	var home := _card_home(card)
	var tween := _card_tween(card)
	var shake_time := SHAKE_STEP * SHAKE_OFFSETS.size()
	card.modulate = REFUSED_TINT
	tween.tween_property(card, ^"modulate", POOR_TINT, shake_time)
	tween.tween_method(func(t: float) -> void:
			var step := mini(int(t * SHAKE_OFFSETS.size()), SHAKE_OFFSETS.size() - 1)
			card.position.x = home.x + SHAKE_OFFSETS[step],
			0.0, 1.0, shake_time)


## Bought: the offer hops up and back down, whole pixels only.
func _hop(card: Button) -> void:
	var home := _card_home(card)
	var tween := _card_tween(card)
	tween.tween_method(func(t: float) -> void: card.position.y = home.y - roundf(sin(t * PI) * HOP_HEIGHT),
			0.0, 1.0, HOP_TIME)


## Where the grid put `card` (kept from its first shake or hop).
func _card_home(card: Button) -> Vector2:
	if not card.has_meta(&"home"):
		card.set_meta(&"home", card.position)
	return card.get_meta(&"home")


## A tween of its own for `card`: the last one is stopped and the card put back in place.
func _card_tween(card: Button) -> Tween:
	if card.has_meta(&"tween"):
		(card.get_meta(&"tween") as Tween).kill()
	card.position = _card_home(card)
	var tween := card.create_tween().set_parallel()
	card.set_meta(&"tween", tween)
	return tween


func _close() -> void:
	visible = false
	closed.emit()
