class_name CrookData
extends Resource
## Settings of the shepherd's crook and of the clods it lobs.

## Left click lobs a clod at the mouse, at most once every throw_cooldown s.
@export var throw_cooldown: float = 0.7
## Speed (px/s) of a clod's ground point, and longest throw (px).
@export var speed: float = 160.0
@export var max_range: float = 70.0
## Top of the arc (px) for each px of throw, and highest top.
@export var arc_per_px: float = 0.25
@export var max_arc: float = 30.0
## Damage of one clod (enemy health it takes), clods per throw, spread (px) between their landing
## spots (across the throw), and clod size (px).
@export var damage: int = 1
@export var clod_count: int = 1
@export var spread: float = 16.0
@export var clod_size: int = 2
