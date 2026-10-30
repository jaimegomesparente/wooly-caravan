class_name Shearing
extends Node
## On the pasture between two trips. The lambs old enough grow into sheep (a burst of fluff), then
## the flock is shorn one sheep at a time (not the lambs), left to right, faster and faster: a burst of fluff, the sheep turns shorn, and its wool flies to the counter (`shorn`
## once all are done). While the power is chosen and recruits are bought the wool may grow back as
## the sheep graze; once the shop is left (`leave`), the next trip starts. Meanwhile the shepherd and the dog stand still, the
## enemies left run off and no attack comes.

signal shorn

@export var attacks: AttackDirector
@export var counter: WoolCounter
@export var fluff_scene: PackedScene
## What a lamb grows into, and a sheep bought in the shop.
@export var sheep_scene: PackedScene
## A lamb bought in the shop.
@export var lamb_scene: PackedScene
## Wool earned per sheep shorn.
@export var wool_per_sheep: int = 1
## Delay (s) between the first two sheep shorn; each next delay is `speed_up` times the last one,
## down to `interval_min`.
@export var interval: float = 0.3
@export_range(0.5, 1.0) var speed_up: float = 0.85
@export var interval_min: float = 0.03


func start() -> void:
	attacks.stopped = true
	get_tree().call_group("enemy", "scare")
	get_tree().set_group("shepherd", "resting", true)
	get_tree().set_group("dog", "resting", true)
	_grow_lambs()
	var flock := get_tree().get_nodes_in_group("sheep").filter(func(sheep: Sheep) -> bool: return not sheep.lamb)
	flock.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	var delay := interval
	for sheep: Sheep in flock:
		if is_instance_valid(sheep) and sheep.is_in_group("sheep"):
			_shear(sheep)
			await get_tree().create_timer(delay, false).timeout
			delay = maxf(delay * speed_up, interval_min)
	shorn.emit()


## A recruit bought in the shop (`sheep` or `lamb`) joins the flock in a burst of fluff, next to a
## sheep drawn at random: a sheep with its wool, or a lamb that sheep is the mother of. A `ram` turns
## a sheep drawn at random among those that are not one yet into a ram.
func recruit(item: StringName) -> void:
	var flock := get_tree().get_nodes_in_group("sheep")
	if flock.is_empty():
		return
	var mothers := flock.filter(func(sheep: Sheep) -> bool: return not sheep.lamb)
	if item == &"ram":
		var ewes := mothers.filter(func(sheep: Sheep) -> bool: return not sheep.ram)
		if not ewes.is_empty():
			var ram: Sheep = ewes.pick_random()
			ram.make_ram()
			_puff(ram.global_position)
		return
	var beside: Sheep = mothers.pick_random() if not mothers.is_empty() else flock.pick_random()
	var newcomer: Sheep
	if item == &"lamb":
		newcomer = lamb_scene.instantiate() as Sheep
		newcomer.grow_trips = RunManager.lamb_trips()
		if not beside.lamb:
			newcomer.mother = beside
		newcomer.position = beside.global_position + Vector2(-6, 2)
	else:
		newcomer = sheep_scene.instantiate() as Sheep
		newcomer.position = beside.global_position + Vector2(-12, 4)
	beside.add_sibling(newcomer)
	_puff(newcomer.position)


## The shop is left: on to the next trip with the flock.
func leave() -> void:
	var sheep := 0
	var rams := 0
	var lambs: Array[int] = []
	for member: Sheep in get_tree().get_nodes_in_group("sheep"):
		if member.lamb:
			lambs.append(member.grow_trips)
		else:
			sheep += 1
			if member.ram:
				rams += 1
	RunManager.go_to_next_trip(sheep, rams, lambs)


## One more trip for every lamb; those that have made enough turn into sheep where they stand.
func _grow_lambs() -> void:
	for lamb: Sheep in get_tree().get_nodes_in_group("sheep"):
		if not lamb.lamb:
			continue
		lamb.grow_trips -= 1
		if lamb.grow_trips > 0:
			continue
		var sheep := sheep_scene.instantiate() as Sheep
		sheep.position = lamb.global_position
		lamb.add_sibling(sheep)
		_puff(lamb.global_position)
		lamb.remove_from_group("sheep")
		lamb.queue_free()


func _puff(at: Vector2) -> void:
	var fluff := fluff_scene.instantiate() as Node2D
	fluff.position = at + Vector2(0, -5)
	add_sibling(fluff)


func _shear(sheep: Sheep) -> void:
	sheep.shear()
	_puff(sheep.global_position)
	RunManager.wool += wool_per_sheep
	counter.collect(sheep.get_global_transform_with_canvas().origin + Vector2(0, -5), wool_per_sheep)
