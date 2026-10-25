extends Node2D

@export var sheep_scene: PackedScene
@export var sheep_count: int = 10
@export var spawn_radius: float = 60.0

@onready var _shepherd: Node2D = $Shepherd


func _ready() -> void:
	for i in sheep_count:
		var sheep := sheep_scene.instantiate() as Node2D
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(spawn_radius * 0.5, spawn_radius)
		sheep.position = _shepherd.position + offset
		add_child(sheep)
