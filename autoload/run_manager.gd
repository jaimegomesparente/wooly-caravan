extends Node
## State of the run (autoload `RunManager`), kept while the trip scene reloads: a run is TRIPS trips
## in a row, the flock that arrives starts the next one, and between two trips one power is chosen,
## kept until the run ends. Powers change the run's own copy of the crook settings, never the base
## resource.

const TRIPS := 3
## Every power that can be offered.
const POWERS: Array[PowerData] = [
	preload("res://resources/powers/heavy_clod.tres"),
	preload("res://resources/powers/extra_clod.tres"),
	preload("res://resources/powers/quick_throw.tres"),
]

## Current trip, from 1.
var trip: int = 1
## Sheep that start the current trip (-1: the first trip, Main's own count).
var sheep: int = -1
## Powers taken, in order (a power can appear several times).
var powers: Array[PowerData] = []

var _crook: CrookData


## A new run: first trip, the whole flock, no power.
func start_run() -> void:
	trip = 1
	sheep = -1
	powers.clear()
	_crook = null


func is_last_trip() -> bool:
	return trip >= TRIPS


## The flock that arrived (`saved` sheep) goes on to the next trip.
func next_trip(saved: int) -> void:
	trip += 1
	sheep = saved


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
