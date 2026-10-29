class_name Trip
extends Node
## One trip: ends when every remaining sheep stands in the end pasture (none being dragged away),
## or when no sheep is left. Reports the result.

signal finished(arrived: bool, saved: int, total: int)

var _total: int = 0
var _lost: int = 0
var _running: bool = false


func begin(total: int) -> void:
	_total = total
	_lost = 0
	_running = true


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
