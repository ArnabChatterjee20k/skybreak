class_name CombatSim
extends RefCounted
## Deterministic combat simulation, advanced in fixed ticks.
## Rules: no Node, Input, scene tree or delta access in here. Time is counted
## in ticks; use TICK_SECONDS when a duration in seconds is needed. All
## randomness comes from rng, so a seed plus the inputs replays a match exactly.

const TICKS_PER_SECOND := 60
const TICK_SECONDS := 1.0 / TICKS_PER_SECOND

var current_tick: int = 0
var fighters: Array[FighterState] = []
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


func add_fighter(start_position: Vector3) -> FighterState:
	var fighter := FighterState.new()
	fighter.position = start_position
	fighters.append(fighter)
	return fighter


## Advances the sim by one tick. inputs[i] belongs to fighters[i].
func tick(inputs: Array[FighterInput]) -> void:
	assert(inputs.size() == fighters.size(), "one input per fighter")
	for i in fighters.size():
		_step_fighter(fighters[i], inputs[i])
	current_tick += 1


## Hash of everything that defines the sim state; equal hashes mean equal states.
func state_hash() -> int:
	var parts: Array = [current_tick, rng.state]
	for fighter in fighters:
		parts.append_array([fighter.position, fighter.velocity, fighter.lock_on_target])
	return hash(var_to_bytes(parts))


func _step_fighter(fighter: FighterState, _input: FighterInput) -> void:
	# Movement arrives in milestone 1, combat rules in milestone 2.
	fighter.position += fighter.velocity * TICK_SECONDS
