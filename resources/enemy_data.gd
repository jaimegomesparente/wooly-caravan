class_name EnemyData
extends Resource

@export_group("Approach")
## Walking speed (px/s) while coming in from off-screen, and when leaving empty-handed.
@export var prowl_speed: float = 30.0
## How fast it turns (rad/s) outside the charge.
@export var turn_rate: float = 5.0
## Minimum time (s) it stands still with a blinking "!" before charging (also lasts the whole howl).
@export var telegraph_time: float = 1.2

@export_group("Charge")
@export var charge_speed: float = 70.0
## Turn rate (rad/s) during the charge. Lower = easier for a sheep to dodge.
@export var charge_turn_rate: float = 3.0
## Grabs the target when this close (px).
@export var capture_distance: float = 6.0

@export_group("Carry")
## Speed (px/s) while dragging a sheep to the nearest forest edge, where the sheep is lost.
## Must stay below the shepherd's speed.
@export var carry_speed: float = 20.0
## The shepherd frees the sheep by coming this close (px).
@export var rescue_radius: float = 16.0
