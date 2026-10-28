class_name Crumble
extends CPUParticles2D
## One burst of square crumbs that jump and fall back, then frees itself (a clod breaking up).


func _ready() -> void:
	finished.connect(queue_free)
	restart()
