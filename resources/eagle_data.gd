class_name EagleData
extends Resource

@export_group("Pass")
## Speed (px/s) of the shadow crossing the screen from left to right.
@export var pass_speed: float = 120.0
## Passes before it gives up when no sheep is free on screen (all out of sight or taken by other
## eagles).
@export var max_passes: int = 1
## Each pass varies a little, at random: its height (up to this many px above or below the flock
## center), a slope (up to this many px/s up or down), and the shadow's flapping speed (up to this
## fraction faster or slower).
@export var pass_height_spread: float = 12.0
@export var pass_drift: float = 8.0
@export var pass_flap_variation: float = 0.15

@export_group("Dive")
## How long (s) the sight stays on the target before the dive.
@export var telegraph_time: float = 1.5
## Duration (s) of the dive from the top right corner of the screen down to the target.
@export var dive_time: float = 0.8

@export_group("Carry")
## Speed (px/s) while flying off to the left with a sheep. Must stay below the dog's speed.
@export var carry_speed: float = 35.0
## Altitude (px) gained per second while carrying; the sheep is lost past carry_altitude_max.
@export var climb_speed: float = 12.0
@export var carry_altitude_max: float = 60.0
## Speed (px/s) when flying away, empty-handed.
@export var leave_speed: float = 90.0

@export_group("Shadow")
## Shadow scale: 1 on the ground, down to shadow_min_scale at shadow_fade_altitude (px) and above,
## in steps of one sixteenth (so the shadow stays made of whole game pixels).
@export var shadow_min_scale: float = 0.5
@export var shadow_fade_altitude: float = 90.0
## Shadow scale while passing over the flock, whatever the altitude, varying at random by up to
## pass_shadow_steps sixteenths each way (sixteenths keep whole game pixels).
@export var pass_shadow_scale: float = 0.75
@export var pass_shadow_steps: int = 1
