class_name PowerEffect
extends Resource
## One change a power makes to a setting: the property is multiplied, then the bonus added (an int
## property is rounded).

@export var property: StringName
@export var multiplier: float = 1.0
@export var bonus: float = 0.0


func apply(target: Resource) -> void:
	var value: Variant = target.get(property)
	if value is int:
		target.set(property, roundi(value * multiplier + bonus))
	elif value is float:
		target.set(property, value * multiplier + bonus)
	else:
		push_warning("PowerEffect: no number property '%s' on %s" % [property, target])
