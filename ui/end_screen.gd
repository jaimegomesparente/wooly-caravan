extends CanvasLayer
## Run result over a dark veil (sheep left out of the whole flock); R starts a new run. The veil
## fades in, then the lines come one by one, the sheep count rolling up from 0.

## Times (s): veil fade, pause between two lines, and longest roll of the count.
const FADE_TIME := 0.3
const LINE_DELAY := 0.35
const COUNT_TIME := 0.8
## The count rolls by one at most every COUNT_STEP s.
const COUNT_STEP := 0.06

var _title: String = ""
var _total: int = 0
var _lost: int = 0
## Lines shown so far (0 to 3), and the count shown on the second one.
var _lines: int = 0
var _count: int = 0
var _restarting: bool = false

@onready var _veil: ColorRect = $Veil
## The title (in the theme's large pixel font: the title font has no accents), then the lines.
@onready var _heading: Label = %Title
@onready var _label: Label = %Label


func _ready() -> void:
	visible = false


func show_result(arrived: bool, saved: int, total: int) -> void:
	_title = "Arrivés au pâturage !" if arrived else "Tout le troupeau est perdu"
	_total = total
	_lost = total - saved
	_lines = 0
	_count = 0
	_render()
	_veil.modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(_veil, ^"modulate:a", 1.0, FADE_TIME)
	tween.tween_callback(_show_line.bind(1))
	tween.tween_interval(LINE_DELAY)
	tween.tween_callback(_show_line.bind(2))
	tween.tween_method(_set_count, 0, saved, minf(COUNT_STEP * saved, COUNT_TIME))
	tween.tween_interval(LINE_DELAY)
	tween.tween_callback(_show_line.bind(3))


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _restarting and event.is_action_pressed("restart"):
		_restarting = true
		RunManager.restart()


func _show_line(count: int) -> void:
	_lines = count
	_render()


func _set_count(count: int) -> void:
	_count = count
	_render()


## Every line is always there (hidden or empty until shown), so the text never moves as it grows.
## The losses show once the count is done.
func _render() -> void:
	_heading.text = _title
	_heading.modulate.a = 1.0 if _lines >= 1 else 0.0
	var sheep := ""
	if _lines >= 2:
		sheep = "%d / %d moutons" % [_count, _total]
		if _lines >= 3 and _lost > 0:
			sheep += " - %d perdu%s" % [_lost, "s" if _lost > 1 else ""]
	var restart := "R : recommencer" if _lines >= 3 else ""
	_label.text = "%s\n\n%s" % [sheep, restart]
