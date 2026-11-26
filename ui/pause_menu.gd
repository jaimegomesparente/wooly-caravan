class_name PauseMenu
extends CanvasLayer
## Escape pauses the game and shows this menu over a dark veil that takes the clicks: Resume (or
## Escape again), Settings, Restart run, Quit. Settings swaps the buttons for the player's volumes
## (general, music, effects: `VolumeBar`s, saved at once) and Back (or Escape). It does not open
## while the game is already paused (end screen) nor during a fade to black, so the trip scene never
## reloads frozen.

## Set once Restart run or Quit is clicked: the menu waits for the fade, or for the game to close.
var _leaving: bool = false

@onready var _buttons: Control = %Buttons
@onready var _settings: Control = %Settings
@onready var _resume: Button = %Resume
@onready var _settings_button: Button = %SettingsButton
@onready var _restart: Button = %Restart
@onready var _quit: Button = %Quit
@onready var _back: Button = %Back


func _ready() -> void:
	visible = false
	_resume.pressed.connect(func() -> void:
		Sound.play(&"click")
		close())
	_settings_button.pressed.connect(_show_settings.bind(true))
	_back.pressed.connect(_show_settings.bind(false))
	_restart.pressed.connect(_leave.bind(RunManager.restart))
	_quit.pressed.connect(_leave.bind(get_tree().quit.bind(0)))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not event.is_action_pressed("pause"):
		return
	if visible and _settings.visible:
		_show_settings(false)
	elif visible:
		close()
	elif not get_tree().paused and not RunManager.is_fading():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


## Always opens on the buttons.
func open() -> void:
	get_tree().paused = true
	_buttons.visible = true
	_settings.visible = false
	visible = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _show_settings(shown: bool) -> void:
	Sound.play(&"click")
	_settings.visible = shown
	_buttons.visible = not shown


func _leave(action: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	Sound.play(&"click")
	action.call()
