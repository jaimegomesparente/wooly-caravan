class_name Shearing
extends Node
## On the pasture between two trips. The flock is shorn one sheep at a time, left to right, faster
## and faster: a burst of fluff, the sheep turns shorn, and its wool flies to the counter (`shorn`
## once all are done). While the power is chosen the wool may grow back as the sheep graze; once
## chosen (`leave`), the next trip starts. Meanwhile the shepherd and the dog stand still, the
## enemies left run off and no attack comes.

signal shorn

@export var attacks: AttackDirector
@export var counter: WoolCounter
@export var fluff_scene: PackedScene
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
	var flock := get_tree().get_nodes_in_group("sheep")
	flock.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	var delay := interval
	for sheep: Sheep in flock:
		if is_instance_valid(sheep) and sheep.is_in_group("sheep"):
			_shear(sheep)
			await get_tree().create_timer(delay, false).timeout
			delay = maxf(delay * speed_up, interval_min)
	shorn.emit()


## The power is chosen: on to the next trip with the flock.
func leave() -> void:
	RunManager.go_to_next_trip(get_tree().get_node_count_in_group("sheep"))


func _shear(sheep: Sheep) -> void:
	sheep.shear()
	var fluff := fluff_scene.instantiate() as Node2D
	fluff.position = sheep.global_position + Vector2(0, -5)
	sheep.add_sibling(fluff)
	RunManager.wool += wool_per_sheep
	counter.collect(sheep.get_global_transform_with_canvas().origin + Vector2(0, -5), wool_per_sheep)
