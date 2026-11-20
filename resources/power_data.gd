class_name PowerData
extends Resource
## An upgrade chosen between two trips, kept for the rest of the run. For now every power changes
## the crook's settings (`CrookData`), and can be taken again (its effects add up). Its target picks
## the card it is shown on (`PowerCard`).

## In the order of the cards in `power_cards_frames.png`.
enum Target { CROOK, SHEEP, DOG }

@export var target: Target = Target.CROOK
@export var title: String
@export_multiline var description: String
@export var effects: Array[PowerEffect] = []


func apply(crook: CrookData) -> void:
	for effect in effects:
		effect.apply(crook)
