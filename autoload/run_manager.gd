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
## Drawn at random for each run; every trip lays out its ground and forest from it.
var map_seed: int = randi()

var _crook: CrookData


## A new run: first trip, the whole flock, no power.
func start_run() -> void:
	trip = 1
	sheep = -1
	powers.clear()
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
