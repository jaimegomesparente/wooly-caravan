class_name Trip
extends Node
## One trip: ends when every remaining sheep stands in the end pasture (none being dragged away),
## or when no sheep is left. Reports the result. N (testing aid) takes the whole flock, the shepherd
## and the dog straight to the end pasture.

signal finished(arrived: bool, saved: int, total: int)

var _total: int = 0
var _lost: int = 0
var _running: bool = false


func begin(total: int) -> void:
	_total = total
	_lost = 0
	_running = true


## Spread of the flock (px) around the middle of the end pasture after N.
const SKIP_RADIUS := 40.0


func _unhandled_input(event: InputEvent) -> void:
	if _running and not get_tree().paused and event.is_action_pressed("skip_trip"):
		_skip_to_pasture()


## The enemies run off (dropping any sheep), then everyone is moved to the end pasture.
func _skip_to_pasture() -> void:
	var ground := get_tree().get_first_node_in_group("trail") as Ground
	if ground == null:
		return
	get_tree().call_group("enemy", "scare")
	var middle := Vector2(ground.length - ground.patch_width * 0.5, ground.height * 0.5)
	for shepherd: Shepherd in get_tree().get_nodes_in_group("shepherd"):
		shepherd.teleport(middle + Vector2(SKIP_RADIUS, 0))
	for dog: Dog in get_tree().get_nodes_in_group("dog"):
		dog.global_position = middle - Vector2(SKIP_RADIUS * 1.5, 0)
		dog.reset_physics_interpolation()
	# Sheep first (they joined the group first), so each lamb lands by its mother.
	for sheep: Sheep in get_tree().get_nodes_in_group("sheep"):
		if sheep.lamb and sheep.mother and is_instance_valid(sheep.mother):
			sheep.teleport(sheep.mother.global_position + Vector2(-6, 2))
		else:
			sheep.teleport(middle + Vector2.from_angle(randf() * TAU) * randf() * SKIP_RADIUS)


func on_sheep_lost(_sheep: Sheep) -> void:
	_lost += 1


func _physics_process(_delta: float) -> void:
	if not _running:
		return
	var flock := get_tree().get_nodes_in_group("sheep")
	var saved := _total - _lost
	if saved <= 0:
		_finish(false, 0)
		return
	# A captured sheep leaves the group: wait until it is rescued or lost.
	if flock.size() < saved:
		return
	var ground := get_tree().get_first_node_in_group("trail") as Ground
	if ground == null:
		return
	var finish_x := ground.length - ground.patch_width
	for sheep: Node2D in flock:
		if sheep.global_position.x < finish_x:
			return
	_finish(true, saved)


func _finish(arrived: bool, saved: int) -> void:
	_running = false
	finished.emit(arrived, saved, _total)
