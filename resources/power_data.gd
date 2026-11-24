class_name PowerData
extends Resource
## An upgrade chosen between two trips, kept for the rest of the run. A power changes the settings of
## its target (crook `CrookData`, sheep and lambs `FlockConfig`, dog `DogData`), and can be taken
## again (its effects add up). Its target also picks the card it is shown on (`PowerCard`).

## In the order of the cards in `power_cards_frames.png`.
enum Target { CROOK, SHEEP, DOG }

@export var target: Target = Target.CROOK
@export var title: String
@export_multiline var description: String
@export var effects: Array[PowerEffect] = []


## Changes `settings` if they are its target's, otherwise leaves them as they are.
func apply(settings: Resource) -> void:
	if target_of(settings) != target:
		return
	for effect in effects:
		effect.apply(settings)


## The target whose powers change `settings`.
static func target_of(settings: Resource) -> Target:
	if settings is FlockConfig:
		return Target.SHEEP
	if settings is DogData:
		return Target.DOG
	return Target.CROOK
