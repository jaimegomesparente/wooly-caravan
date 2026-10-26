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
## Front sheep aim at the point of the shepherd's trail this far (px) behind him, along his path.
@export var trail_lag: float = 30.0
## Distance (px) kept from that trail point (randomized per sheep by speed_variation).
@export var shepherd_gap: float = 10.0
## Distance (px) kept behind the sheep ahead.
@export var follow_gap: float = 16.0
## A resting front sheep sets off once the trail point has moved this far (px) since it settled.
@export var shepherd_start_margin: float = 20.0
## A straggler (no sheep ahead in view) sets off when farther than this (px) from the trail point.
@export var catch_up_distance: float = 80.0
## A sheep walking up to a stopped guide halts within gap + this (px); behind a walking guide,
## it matches the guide's pace within half of it.
@export var follow_start_margin: float = 6.0
## Chance, at each think, that a resting sheep follows a guide that starts walking away.
@export_range(0.0, 1.0) var imitation_chance: float = 0.5
## A sheep trots when its guide is farther than gap + trot_margin (px).
@export var trot_margin: float = 30.0

@export_group("Separation")
## Sheep closer than this (px) push each other away.
@export var separation_radius: float = 18.0
## Weight of the push when steering; at rest, a push above shuffle_threshold makes the sheep step aside.
@export var separation_strength: float = 1.5
@export_range(0.0, 1.0) var shuffle_threshold: float = 0.25
## A sheep walking up to a stopped flock halts once the push from its neighbors exceeds this.
@export_range(0.0, 2.0) var crowd_stop_threshold: float = 0.35

@export_group("Flight")
## A sheep closer than this (px) to the shepherd steps away, to the side of his path.
@export var flight_radius: float = 18.0
## It keeps stepping away until it is flight_radius + flight_margin (px) away.
@export var flight_margin: float = 6.0
## Turn rate and acceleration multiplier while stepping away (a startle).
@export var flight_reflex: float = 3.0

@export_group("Rest")
## Time (s) standing with the head up before grazing or wandering.
@export var stand_time_min: float = 0.5
@export var stand_time_max: float = 2.0
## Time (s) grazing with the head down.
@export var graze_time_min: float = 2.0
@export var graze_time_max: float = 6.0
## Chance, after standing, to take a few steps instead of grazing.
@export_range(0.0, 1.0) var wander_chance: float = 0.35
## Same, for sheep on the edge of the flock (they step inward more often).
@export_range(0.0, 1.0) var edge_wander_chance: float = 0.8
@export var wander_distance_min: float = 6.0
@export var wander_distance_max: float = 16.0
## Wander speed as a fraction of walk_speed.
@export_range(0.1, 1.0) var wander_speed_factor: float = 0.6
## Neighbors within this distance (px) pull wander steps toward their center.
@export var cohesion_radius: float = 40.0
## Pull of wander steps toward the center of the whole flock (relative to a random direction = 1).
@export var flock_center_weight: float = 1.0
## A sheep whose nearest neighbor is farther than this (px) walks back to the others.
@export var isolation_radius: float = 25.0
## finished_graze speed when the sheep has to leave (head comes up faster).
@export var raise_speed_scale: float = 3.0

@export_group("Animation")
## Minimum |velocity.x| (px/s) to flip the sprite.
@export var flip_threshold: float = 5.0
