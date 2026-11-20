class_name FighterSpecials
extends RefCounted
## One fighter's special-move state (T-SP1). Sim state: only SpecialRules writes
## it; FighterState.state_values() includes state_values().

## Planar-or-pitched unit direction of the current special's travel.
var travel_direction: Vector3 = Vector3.ZERO
## Where the current LEAP started and where it lands.
var leap_from: Vector3 = Vector3.ZERO
var leap_to: Vector3 = Vector3.ZERO
## Kael's Momentum stacks (consecutive landed hits since he was last hit).
var momentum: int = 0
## Vexa's afterimage: ticks left (0 = none) and where it stands.
var decoy_ticks: int = 0
var decoy_position: Vector3 = Vector3.ZERO
var decoy_yaw: float = 0.0
## Specials started this round (any key), for the HUD and the AI.
var used: int = 0
## Next lane (T-SP2): transformation state slot. Ticks left transformed, 0 = not.
var transform_ticks: int = 0


## Hash values; empty until a special or mechanic first changes something, so older hashes hold.
func state_values() -> Array:
	if used == 0 and momentum == 0 and decoy_ticks == 0 and transform_ticks == 0:
		return []
	return [travel_direction, leap_from, leap_to, momentum, decoy_ticks, decoy_position, decoy_yaw,
		used, transform_ticks]


func has_decoy() -> bool:
	return decoy_ticks > 0


## Clears everything for a new round.
func reset() -> void:
	travel_direction = Vector3.ZERO
	leap_from = Vector3.ZERO
	leap_to = Vector3.ZERO
	momentum = 0
	decoy_ticks = 0
	decoy_position = Vector3.ZERO
	decoy_yaw = 0.0
	used = 0
	transform_ticks = 0
