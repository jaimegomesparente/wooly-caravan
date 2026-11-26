class_name TripReport
extends CanvasLayer
## On the pasture, once the flock is shorn, before the power choice: what happened during the trip,
## over a light veil. The sheep that arrived, how many each kind of enemy took (`Trip.losses`),
## the sheep freed. The lines come one by one, then Continue (`closed`): the veil
## fades out while the power choice's fades in.

signal closed

## Times (s): veil fade, and pause between two lines.
const FADE_TIME := 0.2
const LINE_DELAY := 0.3

## Every line of the report, and how many are shown so far.
var _lines: PackedStringArray = []
var _shown: int = 0
var _closing: bool = false

@onready var _veil: ColorRect = $Veil
@onready var _center: Control = $Center
@onready var _title: Label = %Title
@onready var _label: Label = %Label
@onready var _continue: Button = %Continue


func _ready() -> void:
	visible = false
	_continue.pressed.connect(_close)


func show_report(trip: Trip) -> void:
	_closing = false
	_title.text = "Trip %d/%d done" % [RunManager.trip, RunManager.TRIPS]
	_lines = _report_lines(trip)
	_shown = 0
	_render()
	_continue.modulate.a = 0.0
	_continue.disabled = true
	_veil.modulate.a = 0.0
	_center.modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_veil, ^"modulate:a", 1.0, FADE_TIME)
	tween.tween_property(_center, ^"modulate:a", 1.0, FADE_TIME)
	tween.chain()
	for i in _lines.size():
		tween.tween_interval(LINE_DELAY)
		tween.tween_callback(_show_lines.bind(i + 1))
	tween.tween_interval(LINE_DELAY)
	tween.tween_callback(func() -> void: _continue.disabled = false)
	tween.tween_property(_continue, ^"modulate:a", 1.0, FADE_TIME)


## "9 / 11 sheep arrived", one line per taker ("Wolves took 2"), or "No sheep lost!", then the sheep
## freed.
static func _report_lines(trip: Trip) -> PackedStringArray:
	var lines: PackedStringArray = ["%d / %d sheep arrived" % [trip.total() - trip.lost(), trip.total()]]
	if trip.losses.is_empty():
		lines.append("No sheep lost!")
	for taker: String in trip.losses:
		lines.append("%s took %d" % [taker, trip.losses[taker]])
	if trip.rescued() > 0:
		lines.append("%d rescued" % trip.rescued())
	return lines


func _show_lines(count: int) -> void:
	_shown = count
	_render()


## Every line is always there (empty until shown), so the text never moves as it grows.
func _render() -> void:
	var text: PackedStringArray = []
	for i in _lines.size():
		text.append(_lines[i] if i < _shown else "")
	_label.text = "\n".join(text)


## The power choice comes in over the fading veil.
func _close() -> void:
	if _closing:
		return
	_closing = true
	Sound.play(&"click")
	_continue.disabled = true
	closed.emit()
	var fade := create_tween().set_parallel()
	fade.tween_property(_veil, ^"modulate:a", 0.0, FADE_TIME)
	fade.tween_property(_center, ^"modulate:a", 0.0, FADE_TIME)
	await fade.finished
	visible = false
