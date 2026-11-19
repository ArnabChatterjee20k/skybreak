class_name WeaponPickup
extends RefCounted
## A weapon lying in the world (or dropping from the sky). Sim state: only
## CombatSim writes it. Add new fields to state_values().

enum Phase {
	TELEGRAPH, ## Light pillar at the drop point; cannot be picked up yet.
	FALLING, ## Dropping to the floor.
	GROUNDED, ## Resting on the floor.
}

## Unique within a match, for the view and events.
var id: int = 0
var kind: Weapon.Kind = Weapon.Kind.NONE
## A power or gadget drop instead of a weapon (T-D26); kind is NONE then.
var power: Power.Kind = Power.Kind.NONE
var position: Vector3 = Vector3.ZERO
## Downward speed while falling, m/s (negative is down).
var fall_speed: float = 0.0
var phase: Phase = Phase.TELEGRAPH
var phase_ticks: int = 0
## Ticks until it despawns.
var ticks_left: int = 0
## Ammo it carries (ranged); dropped weapons keep theirs.
var ammo: int = 0
## Dropped by a fighter rather than spawned; dropped pickups do not count toward the cap.
var dropped: bool = false


func is_power() -> bool:
	return power != Power.Kind.NONE


func can_be_picked_up() -> bool:
	return phase != Phase.TELEGRAPH


func state_values() -> Array:
	return [id, kind, position, fall_speed, phase, phase_ticks, ticks_left, ammo, dropped, power]
