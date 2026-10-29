extends Node
## State of the run (autoload `RunManager`), kept while the trip scene reloads: a run is TRIPS trips
## in a row, the flock that arrives starts the next one, and between two trips one power is chosen,
## kept until the run ends. Powers change the run's own copy of the crook settings, never the base
## resource. Going from one trip to the next fades to black and back.

const TRIPS := 3
## Time (s) of the fade to black, and of the fade back in.
const FADE_TIME := 0.4
## Every power that can be offered.
const POWERS: Array[PowerData] = [
	preload("res://resources/powers/heavy_clod.tres"),
	preload("res://resources/powers/extra_clod.tres"),
	preload("res://resources/powers/quick_throw.tres"),
	preload("res://resources/powers/long_throw.tres"),
	preload("res://resources/powers/flat_throw.tres"),
	preload("res://resources/powers/mudball.tres"),
]

## Current trip, from 1.
var trip: int = 1
## Sheep that start the current trip (-1: the first trip, Main's own count).
var sheep: int = -1
## Powers taken, in order (a power can appear several times).
var powers: Array[PowerData] = []
## Drawn at random for each run; every trip lays out its ground and forest from it.
var map_seed: int = randi()
## Wool shorn on the pastures, kept for the whole run.
var wool: int = 0

var _crook: CrookData
var _veil: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color.BLACK
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


## A new run: first trip, the whole flock, no power.
func start_run() -> void:
	trip = 1
	sheep = -1
	powers.clear()
	wool = 0
	_crook = null
	map_seed = randi()


## Seed of this trip's layout (ground tufts and stones, forest, trail trees): another one each trip.
func trip_seed() -> int:
	return map_seed + trip * 7919


func is_last_trip() -> bool:
	return trip >= TRIPS


## The flock that arrived (`saved` sheep) goes on to the next trip.
func next_trip(saved: int) -> void:
	trip += 1
	sheep = saved


## Fades to black, starts the next trip with the `saved` sheep, then fades back in.
func go_to_next_trip(saved: int) -> void:
	var fade := create_tween()
	fade.tween_property(_veil, "modulate:a", 1.0, FADE_TIME)
	await fade.finished
	next_trip(saved)
	get_tree().reload_current_scene()
	await get_tree().process_frame
	fade = create_tween()
	fade.tween_property(_veil, "modulate:a", 0.0, FADE_TIME)


## The crook settings for this run: a copy of `base` with every power taken applied.
func crook(base: CrookData) -> CrookData:
	if _crook == null:
		_crook = base.duplicate() as CrookData
		for power in powers:
			power.apply(_crook)
	return _crook


func take(power: PowerData) -> void:
	powers.append(power)
	if _crook:
		power.apply(_crook)


## `count` different powers at random (fewer if the pool is smaller).
func offer(count: int) -> Array[PowerData]:
	var pool := POWERS.duplicate()
	pool.shuffle()
	return pool.slice(0, count)
