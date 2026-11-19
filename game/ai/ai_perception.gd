class_name AIPerception
extends RefCounted
## What an AI has seen: a short history of every fighter's action, so it can
## look at the fight as it was its reaction time ago (it cannot react faster).
## Positions are read live; humans track motion, they react late to actions.

const HISTORY := 32

var _fighters: int = 0
## Ticks recorded so far.
var _count: int = 0
var _states := PackedInt32Array()
var _moves: Array[MoveData] = []
var _move_ticks := PackedInt32Array()
## Bit 0 holding a charge, bit 1 the move touched someone, bit 2 guard up.
var _flags := PackedInt32Array()
var _extra_recovery := PackedInt32Array()
## Row read by the accessors, set by look().
var _row: int = 0


## Records this tick's actions of every fighter. Call once per tick.
func record(sim: CombatSim) -> void:
	var count := sim.fighters.size()
	if count != _fighters:
		_fighters = count
		_count = 0
		_states.resize(HISTORY * count)
		_moves.resize(HISTORY * count)
		_move_ticks.resize(HISTORY * count)
		_flags.resize(HISTORY * count)
		_extra_recovery.resize(HISTORY * count)
	var base := (_count % HISTORY) * count
	for i in count:
		var fighter := sim.fighters[i]
		_states[base + i] = fighter.state
		_moves[base + i] = fighter.move
		_move_ticks[base + i] = fighter.move_tick
		var flags := 0
		if fighter.holding_charge:
			flags |= 1
		if fighter.contact_hit or fighter.contact_blocked:
			flags |= 2
		if fighter.blocking:
			flags |= 4
		_flags[base + i] = flags
		_extra_recovery[base + i] = fighter.extra_recovery_ticks
	_count += 1


## Looks at the fight delay ticks ago (or as far back as recorded); returns the delay used.
func look(delay: int) -> int:
	var used := clampi(delay, 0, mini(_count - 1, HISTORY - 1))
	_row = posmod(_count - 1 - used, HISTORY) * _fighters
	return used


func state(fighter: int) -> FighterState.State:
	return _states[_row + fighter] as FighterState.State


func move(fighter: int) -> MoveData:
	return _moves[_row + fighter]


func move_tick(fighter: int) -> int:
	return _move_ticks[_row + fighter]


func holding_charge(fighter: int) -> bool:
	return (_flags[_row + fighter] & 1) != 0


func made_contact(fighter: int) -> bool:
	return (_flags[_row + fighter] & 2) != 0


func guarding(fighter: int) -> bool:
	return (_flags[_row + fighter] & 4) != 0


func extra_recovery(fighter: int) -> int:
	return _extra_recovery[_row + fighter]


## Everything seen so far, for rollback.
func snapshot() -> Array:
	return [_fighters, _count, _states.duplicate(), _moves.duplicate(), _move_ticks.duplicate(),
		_flags.duplicate(), _extra_recovery.duplicate()]


func restore(saved: Array) -> void:
	_fighters = saved[0]
	_count = saved[1]
	_states = (saved[2] as PackedInt32Array).duplicate()
	_moves.assign(saved[3])
	_move_ticks = (saved[4] as PackedInt32Array).duplicate()
	_flags = (saved[5] as PackedInt32Array).duplicate()
	_extra_recovery = (saved[6] as PackedInt32Array).duplicate()
