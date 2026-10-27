class_name DogModeLabel
extends Label
## The dog's current mode, top left.


func show_mode(mode_name: String) -> void:
	text = "Chien : %s" % mode_name
