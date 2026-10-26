class_name DogData
extends Resource

@export var run_speed: float = 80.0
## How fast the dog changes speed (px/s²).
@export var acceleration: float = 300.0
## How fast the dog turns (rad/s).
@export var turn_rate: float = 8.0
## Slows down within this distance (px) of the point it heads to, so it stops without jittering.
@export var arrive_distance: float = 16.0
## While running around the flock, curves around sheep closer than this (px).
@export var avoid_radius: float = 44.0
## Weight of that detour (relative to "toward the point" = 1).
@export var avoid_strength: float = 1.5

@export_group("Wait")
## With nothing to gather, the dog stays put within the reach of the shepherd; it follows once
## farther than reach + this (px).
@export var follow_slack: float = 24.0

@export_group("Gather")
## The flock should fit within gather_spacing * sqrt(sheep count) (px) of the shepherd (the reach);
## beyond that the dog sweeps the rear forward.
@export var gather_spacing: float = 16.0
## While the shepherd walks, the reach is multiplied by this: the flock follows as a column.
@export var walking_reach_factor: float = 2.0
## The flock must stay stretched beyond the reach this long (s) before the dog sets off, and stay
## within it as long before the dog stops.
@export var gather_delay: float = 1.0
## Switches to another sheep only when it is this much (px) farther behind than the current target.
@export var switch_margin: float = 16.0
## Distance (px) kept behind the target, inside its flight zone so it trots toward the shepherd.
@export var push_distance: float = 24.0
## Distance (px) kept to the side of the target while running around it to get behind.
@export var detour_distance: float = 44.0
## Starts running around the target when this far (px) on the shepherd's side of it.
@export var flank_margin: float = 8.0
