class_name FlockConfig
extends Resource

@export_group("Follow")
## Inside this distance from the shepherd, sheep do not move.
@export var follow_radius: float = 40.0
## The pull ramps from 0 at follow_radius to full at follow_radius + elastic_width.
@export var elastic_width: float = 30.0

@export_group("Movement")
@export var max_speed: float = 66.0
@export var acceleration: float = 200.0
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
