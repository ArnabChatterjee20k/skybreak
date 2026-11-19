class_name ImpactFrameGate
extends RefCounted
## Decides when a screen-wide impact moment (two-tone frame, burst lines) is earned and
## rations them: only a K.O., a heavy counter-hit, a guard break or the hit that ends a
## long combo earn one, and at most one plays per COOLDOWN_TICKS.

const E := CombatSim.EventType
## Sim ticks (3 s) between two screen-wide impact moments.
const COOLDOWN_TICKS := 180
## Hits with at least this much hitstop read as heavy (as in CombatFeedback).
const HEAVY_HITSTOP := 7
## A heavy hit landing this many hits into a combo counts as its finisher.
const LONG_COMBO := 5

var _tick := 0
var _last_fired := -COOLDOWN_TICKS


## Whether an event deserves a screen-wide moment at all; combo_hits is the target's count.
static func earns(event: Dictionary, combo_hits: int = 0) -> bool:
	var heavy: bool = event.get("hitstop", 0) >= HEAVY_HITSTOP
	match event.get("type", -1):
		E.KO, E.GUARD_BREAK:
			return true
		E.COUNTER:
			return heavy
		E.HIT, E.THROW:
			return heavy and combo_hits >= LONG_COMBO
	return false


## Moves the clock one sim tick on.
func tick() -> void:
	_tick += 1


## True (and starts the cooldown) when the event earns a moment and none played recently.
func try_fire(event: Dictionary, combo_hits: int = 0) -> bool:
	if not earns(event, combo_hits) or _tick - _last_fired < COOLDOWN_TICKS:
		return false
	_last_fired = _tick
	return true


## Ticks left before another moment may play.
func cooldown_left() -> int:
	return maxi(COOLDOWN_TICKS - (_tick - _last_fired), 0)
