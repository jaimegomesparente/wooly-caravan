extends Node2D
## F3 toggles debug drawing: shepherd trail, the trail point front sheep aim at, the flight zones
## of the shepherd (red) and the dog (brown),
## and (drawn by each sheep) a line to its target with a dot colored by state:
## white = standing, yellow-green = grazing, blue = walk, orange = trot, purple = wander, red = fleeing.

@export var flock_config: FlockConfig


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		Sheep.debug_draw = not Sheep.debug_draw
	queue_redraw()


func _draw() -> void:
	if not Sheep.debug_draw:
		return
	var shepherd := get_tree().get_first_node_in_group("shepherd") as Shepherd
	if shepherd == null:
		return
	var trail := shepherd.get_trail()
	if trail.size() >= 2:
		draw_polyline(trail, Color(1, 1, 1, 0.5), 1.0)
	draw_circle(shepherd.trail_point(flock_config.trail_lag), 2.0, Color.CYAN)
	draw_arc(shepherd.global_position, flock_config.flight_radius, 0.0, TAU, 24, Color.RED, 1.0)
	for dog: Dog in get_tree().get_nodes_in_group("dog"):
		var radius := flock_config.dog_flight_radius if dog.is_pushing() else flock_config.flight_radius
		draw_arc(dog.global_position, radius, 0.0, TAU, 32, Color.SADDLE_BROWN, 1.0)
