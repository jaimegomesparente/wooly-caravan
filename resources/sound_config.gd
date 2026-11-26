class_name SoundConfig
extends Resource
## Settings of the sound effects and the music played by the `Sound` autoload.

## Each sound effect plays at a pitch drawn within +/- pitch_spread (0.05: 5%), so repeats differ.
@export_range(0.0, 0.5) var pitch_spread: float = 0.05
## The same sound effect never starts again sooner than this (s): a whole flock startled at once
## makes one sound.
@export var repeat_interval: float = 0.05
## Sounds played at a place in the world: how much they pan to the side of the screen they come
## from (0 none, 1 full), and how far (px) from the middle of the screen they fade out to silence.
@export_range(0.0, 1.0) var panning_strength: float = 0.5
@export var max_distance: float = 480.0
## Time (s) of the crossfade from one music to the next.
@export var music_fade: float = 1.0
## Volume (dB) of each sound effect or music, by name (0 when missing): balances the sounds
## without editing the files.
@export var volumes: Dictionary[StringName, float] = {}
