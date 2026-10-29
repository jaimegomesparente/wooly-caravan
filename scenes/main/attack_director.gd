class_name AttackDirector
extends Node
## Sends the attacks of the trip. The attack points are spread evenly between the start and the
## end pastures; each time the shepherd passes the next one, and no enemy is left from the previous
## attack, that attack comes: its wolf pack, alternating between the top and bottom forest edges,
## then its eagles. E sends one more eagle at once, L one more wolf (testing aids).

signal sheep_lost(sheep: Sheep)

@export var wolf_scene: PackedScene
@export var eagle_scene: PackedScene
## Number of wolves of each attack, in order (one attack per entry).
@export var packs: Array[int] = [1, 2, 2]
## Number of eagles of each attack, in the same order (a missing entry is none).
@export var eagles: Array[int] = []
## Delay (s) between two wolves of a pack coming out, so each howl can be read.
@export var pack_stagger: float = 1.5

var _next_attack: int = 0
## True while a pack is still coming out.
var _sending: bool = false
## Set once the flock is on the end pasture: no attack comes anymore.
var stopped: bool = false


func _physics_process(_delta: float) -> void:
	if stopped:
		return
	if Input.is_action_just_pressed("spawn_eagle"):
		_send_eagle()
	if Input.is_action_just_pressed("spawn_wolf"):
		_send_wolf()
	if _sending or _next_attack >= packs.size() or get_tree().get_node_count_in_group("enemy") > 0:
		return
	var shepherd := get_tree().get_first_node_in_group("shepherd") as Node2D
	var trail := get_tree().get_first_node_in_group("trail") as Ground
	if shepherd == null or trail == null:
		return
	var between := trail.length - 2.0 * trail.patch_width
	var point := trail.patch_width + between * (_next_attack + 1) / (packs.size() + 1)
	if shepherd.global_position.x >= point:
		_send_pack(packs[_next_attack], eagles[_next_attack] if _next_attack < eagles.size() else 0)
		_next_attack += 1


func _send_pack(size: int, eagle_count: int) -> void:
	_sending = true
	var edge := Wolf.Edge.NEAREST
	for i in size + eagle_count:
		if i > 0:
			await get_tree().create_timer(pack_stagger, false, true).timeout
		if i >= size:
			_send_eagle()
			continue
		var taken := _send_wolf(edge)
		edge = Wolf.Edge.BOTTOM if taken == Wolf.Edge.TOP else Wolf.Edge.TOP
	_sending = false


## Returns the forest edge the wolf comes out of.
func _send_wolf(edge: Wolf.Edge = Wolf.Edge.NEAREST) -> Wolf.Edge:
	var wolf := wolf_scene.instantiate() as Wolf
	wolf.sheep_lost.connect(sheep_lost.emit)
	# Beside Main's other children, so it is y-sorted with the sheep.
	add_sibling(wolf)
	return wolf.attack(edge)


func _send_eagle() -> void:
	var eagle := eagle_scene.instantiate() as Eagle
	eagle.sheep_lost.connect(sheep_lost.emit)
	add_sibling(eagle)
	eagle.attack()
