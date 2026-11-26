class_name PauseMenu
extends CanvasLayer
## Escape pauses the game and shows this menu over a dark veil that takes the clicks: Resume (or
## Escape again), Restart run, Quit. It does not open while the game is already paused (end screen)
## nor during a fade to black, so the trip scene never reloads frozen.

## Set once Restart run or Quit is clicked: the menu waits for the fade, or for the game to close.
var _leaving: bool = false

@onready var _resume: Button = %Resume
@onready var _restart: Button = %Restart
@onready var _quit: Button = %Quit


func _ready() -> void:
	visible = false
	_resume.pressed.connect(func() -> void:
		Sound.play(&"click")
		close())
	_restart.pressed.connect(_leave.bind(RunManager.restart))
	_quit.pressed.connect(_leave.bind(get_tree().quit.bind(0)))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not event.is_action_pressed("pause"):
		return
	if visible:
		close()
	elif not get_tree().paused and not RunManager.is_fading():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	visible = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _leave(action: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	Sound.play(&"click")
	action.call()
