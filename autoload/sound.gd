extends Node
## Sound effects and music (autoload `Sound`), found by name: a sound is added by dropping its file
## in the folder, and a name with no file plays nothing.
## Sound effect `name`: `res://audio/sfx/<name>.wav` (or .ogg, .mp3), or variants `<name>_1`,
## `<name>_2`... picked at random; played on the Sfx bus, at a place in the world (panned to its side
## of the screen) or in the middle (interface). Music `name`: `res://audio/music/<name>.ogg` (or
## .wav, .mp3), looped on the Music bus, crossfaded from the one playing; a music with no file
## leaves the one playing on. Settings in `resources/sound_config.tres`.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3"]
## The player's volumes (pause menu, Settings): steps from 0 (muted) to VOLUME_STEPS (full) for each
## bus, kept in the player's `Settings` from one session to the next.
const VOLUME_STEPS := 10
const BUSES: Array[StringName] = [&"Master", &"Music", &"Sfx"]
const SETTINGS_SECTION := "audio"

var config: SoundConfig = preload("res://resources/sound_config.tres")

## The streams found for each path without extension (empty: no file), looked up once.
var _streams: Dictionary[String, Array] = {}
## When each sound effect last started (ms, Time.get_ticks_msec()).
var _last_played: Dictionary[StringName, int] = {}
var _music: AudioStreamPlayer
var _music_name: StringName = &""


func _ready() -> void:
	# Sounds and fades go on while the game is paused (end screen).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		_apply_volume(bus)


## The player's volume of `bus`, in steps (0 muted, VOLUME_STEPS full).
func volume(bus: StringName) -> int:
	return clampi(int(Settings.get_value(SETTINGS_SECTION, bus, VOLUME_STEPS)), 0, VOLUME_STEPS)


## Sets the player's volume of `bus` (steps) at once, and saves it.
func set_volume(bus: StringName, level: int) -> void:
	Settings.set_value(SETTINGS_SECTION, bus, clampi(level, 0, VOLUME_STEPS))
	_apply_volume(bus)


func _apply_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var level := volume(bus)
	AudioServer.set_bus_mute(index, level == 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(float(level) / VOLUME_STEPS) if level > 0 else 0.0)


## Plays the sound effect `sound_name` at `at` (a point of the world), or in the middle of the
## screen when `at` is null.
func play(sound_name: StringName, at: Variant = null) -> void:
	var streams := _find(SFX_DIR + sound_name)
	if streams.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _last_played.has(sound_name) and now - _last_played[sound_name] < config.repeat_interval * 1000.0:
		return
	_last_played[sound_name] = now
	var player: Node
	if at is Vector2:
		var player_2d := AudioStreamPlayer2D.new()
		# Its parent is no Node2D: its position is where it is in the world.
		player_2d.position = at
		player_2d.max_distance = config.max_distance
		player_2d.panning_strength = config.panning_strength
		player = player_2d
	else:
		player = AudioStreamPlayer.new()
	player.set(&"stream", streams.pick_random())
	player.set(&"bus", &"Sfx")
	player.set(&"volume_db", config.volumes.get(sound_name, 0.0))
	player.set(&"pitch_scale", 1.0 + randf_range(-config.pitch_spread, config.pitch_spread))
	player.connect(&"finished", player.queue_free)
	add_child(player)
	player.call(&"play")


## Crossfades to the music `music_name`, looped; nothing changes if it is already playing or has
## no file.
func play_music(music_name: StringName) -> void:
	if music_name == _music_name:
		return
	var streams := _find(MUSIC_DIR + music_name)
	if streams.is_empty():
		return
	_music_name = music_name
	if _music:
		var old := _music
		var fade_out := old.create_tween().set_ignore_time_scale()
		fade_out.tween_property(old, "volume_linear", 0.0, config.music_fade)
		fade_out.tween_callback(old.queue_free)
	_music = AudioStreamPlayer.new()
	_music.stream = streams.pick_random()
	_music.bus = &"Music"
	_music.volume_linear = 0.0
	if &"loop" in _music.stream:
		_music.stream.set(&"loop", true)
	else:
		# A wav imported without a loop starts over at its end.
		_music.finished.connect(_music.play)
	add_child(_music)
	_music.play()
	var fade_in := _music.create_tween().set_ignore_time_scale()
	fade_in.tween_property(_music, "volume_linear", db_to_linear(config.volumes.get(music_name, 0.0)),
			config.music_fade)


## The streams of `path` (without extension) and of its variants `path_1`, `path_2`...
func _find(path: String) -> Array:
	if _streams.has(path):
		return _streams[path]
	var found: Array[AudioStream] = []
	var single := _load(path)
	if single:
		found.append(single)
	var number := 1
	var variant := _load("%s_%d" % [path, number])
	while variant:
		found.append(variant)
		number += 1
		variant = _load("%s_%d" % [path, number])
	_streams[path] = found
	return found


func _load(path: String) -> AudioStream:
	for extension in EXTENSIONS:
		var file := path + "." + extension
		if ResourceLoader.exists(file):
			return load(file) as AudioStream
	return null
