extends Node2D

@export var sheep_scene: PackedScene
@export var sheep_count: int = 10
@export var spawn_radius: float = 60.0
@export var wolf_scene: PackedScene

@onready var _shepherd: Node2D = $Shepherd
@onready var _ground: Ground = $Ground
@onready var _camera: Camera2D = $FlockCamera


func _ready() -> void:
	# The camera never shows past the forest edges.
	var view := _ground.bounds().grow(_ground.edge_depth)
	_camera.limit_left = int(view.position.x)
	_camera.limit_top = int(view.position.y)
	_camera.limit_right = int(view.end.x)
	_camera.limit_bottom = int(view.end.y)

	for i in sheep_count:
		var sheep := sheep_scene.instantiate() as Node2D
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(spawn_radius * 0.5, spawn_radius)
		sheep.position = _shepherd.position + offset
		add_child(sheep)
	if wolf_scene:
		add_child(wolf_scene.instantiate())
