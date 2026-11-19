class_name Gadget
extends RefCounted
## A thrown or placed gadget in the world (bomb, mine, decoy). Sim state: only
## CombatSim (through PowerRules) writes it. Add new fields to state_values().

enum Phase {
	FLYING, ## Spike Bomb in flight.
	RESTING, ## Spike Bomb on the floor, fuse still burning.
	ARMING, ## Gravity Mine placed, not live yet.
	ARMED, ## Gravity Mine live, waiting for an opponent.
	PULLING, ## Gravity Mine pulling fighters in.
	MIRRORING, ## Mirror Decoy copying its owner.
}

var id: int = 0
var kind: Power.Kind = Power.Kind.NONE
var owner: int = 0
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var phase: Phase = Phase.FLYING
var phase_ticks: int = 0
## Ticks until it goes off (bomb), fizzles (mine) or vanishes (decoy).
var ticks_left: int = 0
## Mirror Decoy: facing and the move id it copies (the owner's last action).
var facing_yaw: float = 0.0
var copied_move: StringName = &""


func state_values() -> Array:
	return [id, kind, owner, position, velocity, phase, phase_ticks, ticks_left, facing_yaw, copied_move]
