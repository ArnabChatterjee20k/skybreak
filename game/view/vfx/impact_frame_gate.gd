class_name ImpactFrameGate
extends RefCounted
## Decides when a screen-wide moment (K.O. flash, guard-break burst lines, combo-breaker
## burst) is earned and rations them: only a K.O., a guard break or a combo breaker earns one
## (GAME_DESIGN hit-feedback table; counters get their text pop and spark), and at most one
## plays per COOLDOWN_TICKS.

const E := CombatSim.EventType
## Sim ticks (3 s) between two screen-wide impact moments.
const COOLDOWN_TICKS := 180

var _tick := 0
var _last_fired := -COOLDOWN_TICKS


## Whether an event deserves a screen-wide moment at all; combo_hits is the target's count.
static func earns(event: Dictionary, _combo_hits: int = 0) -> bool:
	return event.get("type", -1) in [E.KO, E.GUARD_BREAK, E.COMBO_BREAKER]


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
