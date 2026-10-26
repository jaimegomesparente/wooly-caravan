extends Node2D

@export var sheep_scene: PackedScene
@export var sheep_count: int = 10
@export var spawn_radius: float = 60.0
@export var wolf_scene: PackedScene
@export var dog_scene: PackedScene

@onready var _shepherd: Node2D = $Shepherd
@onready var _ground: Ground = $Ground
@onready var _camera: Camera2D = $FlockCamera
@onready var _trip: Trip = $Trip
@onready var _end_screen: CanvasLayer = $EndScreen


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
	if dog_scene:
		var dog := dog_scene.instantiate() as Node2D
		dog.position = _shepherd.position + Vector2(-16, 0)
		add_child(dog)
	if wolf_scene:
		var wolf := wolf_scene.instantiate() as Wolf
		wolf.sheep_lost.connect(_trip.on_sheep_lost)
		add_child(wolf)

	_trip.finished.connect(_end_screen.show_result)
	_trip.begin(sheep_count)
