extends Node2D

@export var sheep_scene: PackedScene
@export var sheep_count: int = 10
@export var spawn_radius: float = 60.0
@export var dog_scene: PackedScene

@onready var _shepherd: Shepherd = $Shepherd
@onready var _ground: Ground = $Ground
@onready var _camera: Camera2D = $FlockCamera
@onready var _trip: Trip = $Trip
@onready var _attacks: AttackDirector = $AttackDirector
@onready var _end_screen: CanvasLayer = $EndScreen
@onready var _dog_mode: DogModeLabel = $Hud/DogMode


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
		var dog := dog_scene.instantiate() as Dog
		dog.position = _shepherd.position + Vector2(-16, 0)
		_shepherd.dog_mode_called.connect(dog.next_mode)
		dog.mode_changed.connect(_dog_mode.show_mode)
		add_child(dog)
	_attacks.sheep_lost.connect(_trip.on_sheep_lost)

	_trip.finished.connect(_end_screen.show_result)
	_trip.begin(sheep_count)
