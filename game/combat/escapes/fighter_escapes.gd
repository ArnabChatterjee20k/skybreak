class_name FighterEscapes
extends RefCounted
## One fighter's escape-tool state (T-DEF3). Sim state: only CombatSim (through
## EscapeRules) writes it; FighterState.state_values() includes state_values().

## What an ESCAPING fighter is doing.
enum Kind {
	NONE,
	BREAKER, ## Combo-breaker burst pose: intangible, cannot act.
	BLOWN_AWAY, ## Blown out to mid range by an opponent's combo breaker.
	AIR_TECH, ## Recovering out of knockback in the chosen direction.
	TECH_ROLL, ## Rolling out of a knockdown.
	CHASE_MISS, ## Chased the wrong way: braking, cannot act.
}

## Which way a chase (attacker) or an air tech (defender) goes.
enum Way { NONE, STRAIGHT, OVER, UNDER }

var kind: Kind = Kind.NONE
## Ticks left in which hits, grabs and projectiles pass through.
var intangible_ticks: int = 0
## Ticks left before another combo breaker is allowed.
var breaker_cooldown: int = 0
## The air tech of the current knockback is spent (caught or done).
var air_tech_used: bool = false
## Way of the last air tech or chase, for the chase read and the view.
var way: Way = Way.NONE
## Fighter this one may chase (a knockback hit landed on it), or -1, and ticks left to press Dash.
var chase_target: int = -1
var chase_window: int = 0
## Fighter this one is chasing right now (homing rush), or -1.
var chasing: int = -1
## Holding descend while knocked down asked for the delayed wakeup.
var delayed_wakeup: bool = false


func state_values() -> Array:
	return [kind, intangible_ticks, breaker_cooldown, air_tech_used, way,
		chase_target, chase_window, chasing, delayed_wakeup]


## Clears everything for a new round.
func reset() -> void:
	kind = Kind.NONE
	intangible_ticks = 0
	breaker_cooldown = 0
	air_tech_used = false
	way = Way.NONE
	chase_target = -1
	chase_window = 0
	chasing = -1
	delayed_wakeup = false
