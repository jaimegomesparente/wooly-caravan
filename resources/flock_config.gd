class_name FlockConfig
extends Resource

@export_group("Follow")
## A resting sheep only sets off when the shepherd is farther than this (px).
@export var start_follow_radius: float = 70.0
## Each sheep picks its own stop distance in this range once, so the flock spreads over a band.
@export var stop_radius_min: float = 35.0
@export var stop_radius_max: float = 55.0
## Random wait (s) between the shepherd getting out of range and the sheep setting off.
@export var reaction_delay_min: float = 0.1
@export var reaction_delay_max: float = 0.8
## Speed ramps down over this distance (px) above the sheep's stop radius.
@export var elastic_width: float = 30.0

@export_group("Movement")
@export var max_speed: float = 66.0
@export var acceleration: float = 350.0
## A desired speed below this (px/s) becomes 0: no slow creeping or sliding.
@export var min_move_speed: float = 12.0
## Each sheep gets a random speed multiplier in [1 - variation, 1 + variation].
@export_range(0.0, 0.5) var speed_variation: float = 0.15

@export_group("Separation")
## Sheep closer than this (px) push each other away.
@export var separation_radius: float = 12.0
## Desired speed (px/s) added when two sheep fully overlap; fades to 0 at separation_radius.
@export var separation_strength: float = 50.0

@export_group("Animation")
## Below this speed (px/s) the sheep plays idle instead of run.
@export var idle_threshold: float = 5.0
## Minimum |velocity.x| (px/s) to flip the sprite.
@export var flip_threshold: float = 5.0
## run speed_scale = current speed / run_reference_speed.
@export var run_reference_speed: float = 60.0
