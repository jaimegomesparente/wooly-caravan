class_name Tutorial
extends CanvasLayer
## Hints during the first trip of a run, until one such trip is over (then never again: kept in the
## player's `Settings`). One line at the bottom of the screen on a dark strip, fading in and out;
## the game goes on meanwhile. A sequence (walk, dog mode, throw, the goal), each hint leaving once
## the player has done it (a hint already done is skipped, one shown stays at least MIN_TIME), and
## notices, once each and first in line, the first time a wolf or an eagle comes or a sheep is
## caught. Built in code.

const SECTION := "tutorial"
const KEY := "done"
const STRIP_COLOR := Color(0, 0, 0, 0.45)
## Height (px) of the strip, and its gap (px) above the bottom of the screen.
const STRIP_HEIGHT := 16.0
const BOTTOM_GAP := 10.0
## Times (s): wait before the first hint (the trip banner), fade, shortest time a hint is shown,
## time of a notice and of the last hint.
const START_DELAY := 2.4
const FADE_TIME := 0.25
const MIN_TIME := 1.5
const NOTICE_TIME := 5.0
## Distance (px) the shepherd walks for the first hint to be done.
const WALK_DISTANCE := 40.0

enum Step { WALK, DOG, THROW, GOAL, DONE }

const STEP_TEXTS: Dictionary[Step, String] = {
	Step.WALK: "Move with WASD or the arrows: the flock follows you",
	Step.DOG: "Space: change the dog's mode (top left)",
	Step.THROW: "Left click: throw a clod at the mouse",
	Step.GOAL: "Bring every sheep to the pasture on the right",
}
const WOLF_TEXT := "A wolf! Hit it with clods, or set the dog on it"
const EAGLE_TEXT := "An eagle's shadow: keep the lone sheep close"
const CAUGHT_TEXT := "Caught! Chase the captor off before the bar empties"

var _step: Step = Step.WALK
## Whether the current step's hint has been shown, and for how long (s).
var _step_shown: bool = false
var _shown_time: float = 0.0
## What the player has done so far.
var _walked: bool = false
var _switched: bool = false
var _threw: bool = false
var _start: Vector2 = Vector2.INF
## Notices waiting, the one shown and its time left (s).
var _notices: Array[String] = []
var _notice: String = ""
var _notice_timer: float = 0.0
var _wolf_seen: bool = false
var _eagle_seen: bool = false
var _caught_seen: bool = false
var _delay: float = START_DELAY
## The text on screen ("" none).
var _text: String = ""
var _tween: Tween

var _box: Control
var _strip: ColorRect
var _label: Label


## True when the tutorial is to be shown: the first trip of a run, never finished before.
static func pending() -> bool:
	return RunManager.trip == 1 and not Settings.get_value(SECTION, KEY, false)


func _init() -> void:
	# Under the crosshair and the pause menu.
	layer = 40
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	add_child(_box)
	_strip = ColorRect.new()
	_strip.color = STRIP_COLOR
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_strip)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_label)


func _process(delta: float) -> void:
	_watch(delta)
	if _delay > 0.0:
		_delay -= delta
		return
	if _notice != "":
		_notice_timer -= delta
		if _notice_timer <= 0.0:
			_notice = ""
	if _notice == "" and not _notices.is_empty():
		_notice = _notices.pop_front()
		_notice_timer = NOTICE_TIME
	if _notice != "":
		_show(_notice)
		return
	while _step != Step.DONE and _step_done() and (not _step_shown or _shown_time >= MIN_TIME):
		_step = (_step + 1) as Step
		_step_shown = false
		_shown_time = 0.0
	if _step == Step.DONE:
		_show("")
		return
	_step_shown = true
	_shown_time += delta
	_show(STEP_TEXTS[_step])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dog_mode"):
		_switched = true
	elif event.is_action_pressed("throw"):
		_threw = true


## A sheep is caught (`AttackDirector.sheep_captured`).
func on_sheep_captured(_sheep: Sheep, _by: Enemy) -> void:
	if not _caught_seen:
		_caught_seen = true
		_notices.append(CAUGHT_TEXT)


## The first trip is over (`Trip.finished`): the tutorial is done, for good.
func finish(_arrived: bool, _saved: int, _total: int) -> void:
	Settings.set_value(SECTION, KEY, true)
	_show("")
	set_process(false)


## Notes what the player does, and the first wolf and eagle in sight.
func _watch(_delta: float) -> void:
	var shepherd := get_tree().get_first_node_in_group("shepherd") as Node2D
	if shepherd:
		if _start == Vector2.INF:
			_start = shepherd.global_position
		elif shepherd.global_position.distance_to(_start) >= WALK_DISTANCE:
			_walked = true
	for enemy: Node2D in get_tree().get_nodes_in_group("enemy"):
		if not enemy.visible:
			continue
		if enemy is Wolf and not _wolf_seen:
			_wolf_seen = true
			_notices.append(WOLF_TEXT)
		elif enemy is Eagle and not _eagle_seen:
			_eagle_seen = true
			_notices.append(EAGLE_TEXT)


func _step_done() -> bool:
	match _step:
		Step.WALK:
			return _walked
		Step.DOG:
			return _switched
		Step.THROW:
			return _threw
		Step.GOAL:
			return _shown_time >= NOTICE_TIME
	return true


## Fades `text` in (after the one shown fades out), or the strip out for "".
func _show(text: String) -> void:
	if text == _text:
		return
	_text = text
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if _box.modulate.a > 0.0:
		_tween.tween_property(_box, ^"modulate:a", 0.0, FADE_TIME * _box.modulate.a)
	if text == "":
		return
	_tween.tween_callback(_place.bind(text))
	_tween.tween_property(_box, ^"modulate:a", 1.0, FADE_TIME)


## The strip across the bottom of the screen, `text` centered on it.
func _place(text: String) -> void:
	var screen := get_viewport().get_visible_rect().size
	var top := screen.y - BOTTOM_GAP - STRIP_HEIGHT
	_strip.position = Vector2(0, top)
	_strip.size = Vector2(screen.x, STRIP_HEIGHT)
	_label.text = text
	_label.size = _label.get_minimum_size()
	_label.position = Vector2(roundf((screen.x - _label.size.x) / 2.0), roundf(top + (STRIP_HEIGHT - _label.size.y) / 2.0))
