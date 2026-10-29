extends CanvasLayer
## Run result over a dark veil (sheep left out of the whole flock); R starts a new run.

@onready var _label: Label = $Label


func _ready() -> void:
	visible = false


func show_result(arrived: bool, saved: int, total: int) -> void:
	var title := "Arrivés au pâturage !" if arrived else "Tout le troupeau est perdu"
	var lost := total - saved
	var losses := " — %d emporté%s par le loup" % [lost, "s" if lost > 1 else ""] if lost > 0 else ""
	_label.text = "%s\n%d / %d moutons%s\n\nR : recommencer" % [title, saved, total, losses]
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("restart"):
		RunManager.start_run()
		get_tree().paused = false
		get_tree().reload_current_scene()
