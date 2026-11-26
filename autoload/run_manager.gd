extends Node
## State of the run (autoload `RunManager`), kept while the trip scene reloads: a run is TRIPS trips
## in a row, the flock that arrives starts the next one, and between two trips one power is chosen,
## kept until the run ends. Powers change the run's own copies of the crook, flock and dog settings,
## never the base resources. Going from one trip to the next, or to a new run, fades to black and back.

const TRIPS := 5
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
	preload("res://resources/powers/swift_hooves.tres"),
	preload("res://resources/powers/tight_flock.tres"),
	preload("res://resources/powers/hot_headed.tres"),
	preload("res://resources/powers/pregnancy.tres"),
	preload("res://resources/powers/loud_bark.tres"),
	preload("res://resources/powers/quick_paws.tres"),
	preload("res://resources/powers/keen_eye.tres"),
	preload("res://resources/powers/relentless.tres"),
]

## Current trip, from 1.
var trip: int = 1
## Sheep that start the current trip (-1: the first trip, Main's own count).
var sheep: int = -1
## Rams among the sheep that start the current trip.
var rams: int = 0
## Lambs that start the current trip: for each, the trips left before it grows into a sheep.
var lambs: Array[int] = []
## A lamb grows into a sheep after a number of trips drawn between these (min, max).
var grow_trips: Vector2i = Vector2i(2, 4)
## Head count (sheep and lambs) the run started with, plus the recruits bought since.
var flock_size: int = 0
## Powers taken, in order (a power can appear several times).
var powers: Array[PowerData] = []
## Drawn at random for each run; every trip lays out its ground and forest from it.
var map_seed: int = randi()
## Wool shorn on the pastures, kept for the whole run.
var wool: int = 0

## The run's copy of each base settings resource asked for (crook, flock, lamb, dog), by base.
var _settings: Dictionary[Resource, Resource] = {}
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
	rams = 0
	lambs.clear()
	powers.clear()
	wool = 0
	_settings.clear()
	map_seed = randi()


## Seed of this trip's layout (ground tufts and stones, forest, trail trees): another one each trip.
func trip_seed() -> int:
	return map_seed + trip * 7919


## The run's starting flock: `count` sheep, and lambs for `lamb_ratio` of them, each growing up
## after a number of trips drawn in `grow_trips` (min, max).
func start_flock(count: int, lamb_ratio: float, lamb_grow_trips: Vector2i) -> void:
	sheep = count
	grow_trips = lamb_grow_trips
	lambs.clear()
	for i in roundi(count * lamb_ratio):
		lambs.append(lamb_trips())
	flock_size = count + lambs.size()


## Trips a new lamb has to make before it grows into a sheep.
func lamb_trips() -> int:
	return randi_range(grow_trips.x, grow_trips.y)


func is_last_trip() -> bool:
	return trip >= TRIPS


## The flock that arrived (`saved` sheep, `saved_rams` of them rams, and `saved_lambs`, trips left
## for each) goes on to the next trip.
func next_trip(saved: int, saved_rams: int, saved_lambs: Array[int]) -> void:
	trip += 1
	sheep = saved
	rams = saved_rams
	lambs = saved_lambs


## Fades to black, starts the next trip with the flock that arrived, then fades back in.
func go_to_next_trip(saved: int, saved_rams: int, saved_lambs: Array[int]) -> void:
	await _fade(1.0).finished
	next_trip(saved, saved_rams, saved_lambs)
	_reload()


## Fades to black (the game paused on the end screen), starts a new run, then fades back in.
func restart() -> void:
	await _fade(1.0).finished
	start_run()
	get_tree().paused = false
	_reload()


## Reloads the trip scene, then fades back in.
func _reload() -> void:
	get_tree().reload_current_scene()
	await get_tree().process_frame
	_fade(0.0)


## True while the screen fades to black or back in (between two trips, or to a new run).
func is_fading() -> bool:
	return _veil.modulate.a > 0.0


## The black veil fades to `alpha`, even while the game is paused.
func _fade(alpha: float) -> Tween:
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_veil, "modulate:a", alpha, FADE_TIME)
	return fade


## The settings for this run (crook, flock, lamb or dog): a copy of `base` with every power taken
## applied (each power only changes the settings of its target).
func settings(base: Resource) -> Resource:
	if not _settings.has(base):
		var copy := base.duplicate()
		for power in powers:
			power.apply(copy)
		_settings[base] = copy
	return _settings[base]


## The run's settings `target`'s powers change, as they are now: the first copy made for it (the
## sheep's before the lambs'), null before any was asked for.
func current(target: PowerData.Target) -> Resource:
	for copy: Resource in _settings.values():
		if PowerData.target_of(copy) == target:
			return copy
	return null


func take(power: PowerData) -> void:
	powers.append(power)
	for copy: Resource in _settings.values():
		power.apply(copy)


## `count` different powers at random (fewer if the pool is smaller).
func offer(count: int) -> Array[PowerData]:
	var pool := POWERS.duplicate()
	pool.shuffle()
	return pool.slice(0, count)
