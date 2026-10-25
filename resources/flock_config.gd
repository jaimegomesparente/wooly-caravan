class_name FlockConfig
extends Resource

@export_group("Gaits")
@export var walk_speed: float = 24.0
@export var trot_speed: float = 48.0
## How fast a sheep changes speed (px/s²).
@export var acceleration: float = 150.0
## How fast a sheep turns (rad/s). Lower = wider, calmer turns.
@export var turn_rate: float = 5.0
## Each sheep gets a random speed multiplier in [1 - variation, 1 + variation].
@export_range(0.0, 0.5) var speed_variation: float = 0.15

@export_group("Follow")
## Each sheep re-chooses its guide and decides to set off every think interval (s).
@export var think_interval_min: float = 0.2
@export var think_interval_max: float = 0.4
## Sheep closer than this (px) to the shepherd follow him directly.
@export var lead_radius: float = 40.0
## Other sheep follow the nearest sheep ahead of them within this distance (px).
@export var view_radius: float = 40.0
## Distance (px) kept behind the shepherd (randomized per sheep by speed_variation).
@export var shepherd_gap: float = 22.0
## Distance (px) kept behind the sheep ahead.
@export var follow_gap: float = 16.0
## A resting sheep sets off when its guide is farther than gap + start_margin (px).
@export var start_margin: float = 6.0
## A sheep trots when its guide is farther than gap + trot_margin (px).
@export var trot_margin: float = 30.0

@export_group("Separation")
## Sheep closer than this (px) push each other away.
@export var separation_radius: float = 18.0
## Weight of the push when steering; at rest, a push above shuffle_threshold makes the sheep step aside.
@export var separation_strength: float = 1.5
@export_range(0.0, 1.0) var shuffle_threshold: float = 0.25

@export_group("Animation")
## Minimum |velocity.x| (px/s) to flip the sprite.
@export var flip_threshold: float = 5.0
