class_name FighterState
extends RefCounted
## Simulation state of one fighter. Presentation reads it; only CombatSim
## writes it. Add new fields to state_values() so the state hash covers them.

## What the fighter is doing. Later tasks add attack, hitstun, blockstun etc.
enum State {
	IDLE, ## Standing on the ground.
	MOVING, ## Running or sliding on the ground.
	FALLING, ## Airborne without flying; gravity applies.
	FLYING, ## Free flight, including hovering.
	DASHING, ## Any dash; dash_kind says which.
	VANISHING, ## Vanish step: teleported, briefly unable to act.
	CHARGING, ## Charging ki in place; any other action or a hit ends it.
	GUARD_BROKEN, ## Stunned after the guard meter ran out.
}

## Stored meter units per display unit: meters are integers in sixtieths.
const METER_UNIT := 60

enum DashKind {
	NONE,
	STEP, ## Tapped dash: fixed short distance.
	SUSTAINED, ## Dash held past the step: steerable flight-dash.
	RUSH, ## Dash toward the lock-on target: homes in on it.
}

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Index of the locked-on opponent in CombatSim.fighters, or -1 for none.
var lock_on_target: int = -1
var state: State = State.IDLE
## Ticks spent in the current state, counting the tick it was entered.
var state_ticks: int = 0
## Heading in radians, same convention as FighterInput.view_yaw.
var facing_yaw: float = 0.0
var dash_kind: DashKind = DashKind.NONE
## Unit direction of the current dash, zero when not dashing.
var dash_direction: Vector3 = Vector3.ZERO
## Ticks since each action was last pressed, indexed by Action bit; capped at the buffer length.
var press_ages: Array[int] = []
## Action bits whose latest press was already consumed from the input buffer.
var consumed_presses: int = 0

# Meters, all in sixtieths (display value x METER_UNIT).
## Meter numbers for this fighter. Configuration, so not in the state hash.
var stats: FighterStats
var health: int = 0
## Recoverable damage on top of health; regenerates after a quiet spell.
var grey_health: int = 0
var ki: int = 0
var guard: int = 0
var burst: int = 0
## Ticks since the last hit, counted up to the grey regen delay.
var ticks_since_hit: int = 0
## Ticks since the last block or guard damage, counted up to the guard regen delay.
var ticks_since_block: int = 0
## True while blocking; T-D05 sets it. Blocking pauses guard regeneration.
var blocking: bool = false
## Last Stand gives its free burst once per match.
var last_stand_used: bool = false


## Switches to new_state and restarts the tick counter, even if it is the same state.
func enter_state(new_state: State) -> void:
	state = new_state
	state_ticks = 0


func is_grounded() -> bool:
	return state == State.IDLE or state == State.MOVING


func is_knocked_out() -> bool:
	return health <= 0


# Display values for the HUD.

func health_display() -> float:
	return float(health) / METER_UNIT


func grey_health_display() -> float:
	return float(grey_health) / METER_UNIT


func ki_display() -> float:
	return float(ki) / METER_UNIT


func guard_display() -> float:
	return float(guard) / METER_UNIT


func burst_display() -> float:
	return float(burst) / METER_UNIT


## Every value that defines this fighter, for CombatSim.state_hash().
func state_values() -> Array:
	return [
		position, velocity, lock_on_target, state, state_ticks, facing_yaw,
		dash_kind, dash_direction, press_ages, consumed_presses,
		health, grey_health, ki, guard, burst, ticks_since_hit, ticks_since_block,
		blocking, last_stand_used,
	]
