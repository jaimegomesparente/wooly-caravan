extends Node2D

@export var sheep_scene: PackedScene
@export var sheep_count: int = 10
@export var lamb_scene: PackedScene
## Share of the starting sheep that have a lamb.
@export_range(0.0, 1.0) var lamb_ratio: float = 0.3
## A lamb grows into a sheep after this many trips (drawn between min and max).
@export var lamb_grow_trips: Vector2i = Vector2i(2, 4)
@export var spawn_radius: float = 60.0
@export var dog_scene: PackedScene

@onready var _shepherd: Shepherd = $Shepherd
@onready var _ground: Ground = $Ground
@onready var _camera: Camera2D = $FlockCamera
@onready var _trip: Trip = $Trip
@onready var _attacks: AttackDirector = $AttackDirector
@onready var _end_screen: CanvasLayer = $EndScreen
@onready var _pasture: PastureScreen = $PastureScreen
@onready var _shearing: Shearing = $Shearing
@onready var _dog_mode: DogModeLabel = $Hud/DogMode
@onready var _trip_label: Label = $Hud/TripLabel


func _ready() -> void:
	# The camera never shows past the forest edges.
	var view := _ground.bounds().grow(_ground.edge_depth)
	_camera.limit_left = int(view.position.x)
	_camera.limit_top = int(view.position.y)
	_camera.limit_right = int(view.end.x)
	_camera.limit_bottom = int(view.end.y)

	# The first trip of a run starts with sheep_count sheep and their lambs, the next ones with
	# those that arrived. Each lamb is put by a mother of its own (as long as there are enough).
	if RunManager.sheep < 0:
		RunManager.start_flock(sheep_count, lamb_ratio, lamb_grow_trips)
	var mothers: Array[Sheep] = []
	for i in RunManager.sheep:
		var sheep := sheep_scene.instantiate() as Sheep
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(spawn_radius * 0.5, spawn_radius)
		sheep.position = _shepherd.position + offset
		add_child(sheep)
		mothers.append(sheep)
	mothers.shuffle()
	for i in RunManager.lambs.size():
		var lamb := lamb_scene.instantiate() as Sheep
		lamb.grow_trips = RunManager.lambs[i]
		if mothers.is_empty():
			lamb.position = _shepherd.position + Vector2(-spawn_radius * 0.5, 0)
		else:
			lamb.mother = mothers[i % mothers.size()]
			lamb.position = lamb.mother.position + Vector2(-6, 2)
		add_child(lamb)
	var count := RunManager.sheep + RunManager.lambs.size()
	if dog_scene:
		var dog := dog_scene.instantiate() as Dog
		dog.position = _shepherd.position + Vector2(-16, 0)
		_shepherd.dog_mode_called.connect(dog.next_mode)
		dog.mode_changed.connect(_dog_mode.show_mode)
		add_child(dog)
	_attacks.sheep_lost.connect(_trip.on_sheep_lost)

	_trip_label.text = "Trip %d/%d" % [RunManager.trip, RunManager.TRIPS]
	_trip.finished.connect(_on_trip_finished)
	_pasture.chosen.connect(_shearing.leave)
	_trip.begin(count)


## A flock that arrives on the pasture is shorn, then a power is chosen, unless it was the last trip:
## the run is then over, as when no sheep is left.
func _on_trip_finished(arrived: bool, saved: int, _total: int) -> void:
	if arrived and not RunManager.is_last_trip():
		_shearing.shorn.connect(_pasture.show_choice.bind(saved), CONNECT_ONE_SHOT)
		_shearing.start()
	else:
		get_tree().paused = true
		_end_screen.show_result(arrived, saved, RunManager.flock_size)
