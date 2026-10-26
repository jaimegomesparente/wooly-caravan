class_name Dust
extends CPUParticles2D
## Square dust puffs at the feet while the parent body runs (faster than min_speed).

## Speed (px/s) above which the parent kicks up dust.
@export var min_speed: float = 36.0

@onready var _body := get_parent() as CharacterBody2D


func _physics_process(_delta: float) -> void:
	emitting = _body != null and _body.is_visible_in_tree() and _body.velocity.length() > min_speed
