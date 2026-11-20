class_name FighterDodge
extends RefCounted
## One fighter's dodge state (T-DEF2). Sim state: only CombatSim (through
## DodgeRules) writes it; FighterState.state_values() includes state_values().
## Frames are the fighter's state_ticks while DASHING: 1 on the press tick.

enum Kind {
	NONE, ## Not dodging.
	DIRECTIONAL, ## Tap Shift + a direction: eased travel.
	SPOT, ## Tap Shift alone: in place, longest i-frames.
	SIDESTEP, ## Locked, tap Shift + A/D: an arc around the target.
}

var kind: Kind = Kind.NONE
## First and last invulnerable frame of this dodge; last < first means none (stale).
var invuln_first: int = 0
var invuln_last: int = -1
## Last frame of the dodge; the fighter is free on the frame after.
var last_frame: int = 0
## Frames of travel (startup + base i-frames), and the sidestep's side (1 right, -1 left).
var travel_ticks: int = 0
var side: int = 1
## This dodge already scored a perfect dodge.
var perfect: bool = false
## Dodges in the current chain, counting this one; 0 after a perfect dodge or a rest.
var chain: int = 0
## Ticks since the last dodge ended, capped.
var since_last: int = 1 << 16
## Dodges left in this airborne spell.
var air_left: int = 2
## Ticks before a perfect dodge can pay ki again.
var ki_cooldown: int = 0
## Grabbed in dodge recovery: the throw is a counter-hit and cannot be teched.
var punished: bool = false


func state_values() -> Array:
	return [kind, invuln_first, invuln_last, last_frame, travel_ticks, side, perfect, chain,
		since_last, air_left, ki_cooldown, punished]


func is_dodging() -> bool:
	return kind != Kind.NONE


## True on an invulnerable frame of the current dodge.
func is_invulnerable(frame: int) -> bool:
	return kind != Kind.NONE and frame >= invuln_first and frame <= invuln_last


## True on the frames that can score a perfect dodge.
func in_perfect_window(frame: int, window: int) -> bool:
	return is_invulnerable(frame) and frame < invuln_first + window and not perfect


## True after the i-frames until the dodge ends: throw bait.
func in_recovery(frame: int) -> bool:
	return kind != Kind.NONE and frame > maxi(invuln_last, invuln_first - 1)
