class_name PureFightAI
extends RefCounted
## Pure Fight opponent (GAME_DESIGN §16.8): spacing, high/low blocking read off the
## opponent's move after a reaction delay, anti-airs, punishes and its own combos.
## Level 1 (easy) to 5 (hard). Deterministic from its seed; never touches the sim's rng.

const A := FighterInput.Action
const BUTTONS := {&"L": A.LIGHT, &"M": A.SPECIAL_1, &"H": A.HEAVY}
## Per level: reaction delay (ticks), chance to block right, anti-air chance, punish chance,
## chance to cancel a confirmed hit into a technique.
const LEVELS := {
	1: [24, 0.35, 0.15, 0.2, 0.2], 2: [18, 0.55, 0.35, 0.4, 0.4], 3: [13, 0.7, 0.55, 0.6, 0.6],
	4: [9, 0.82, 0.75, 0.8, 0.8], 5: [6, 0.92, 0.9, 0.95, 0.95],
}

var index := 0
var level := 3
## Chance per decision to try a move it hasn't used yet (bot coverage runs set it high).
var explore := 0.15
var rng := RandomNumberGenerator.new()
## Moves this AI has started (move id -> count), read by the bot-match test.
var used: Dictionary = {}
var _plan: Array = []
var _previous := FighterInput.new()
var _seen: Array = []
var _wait := 0


func setup(fighter_index: int, ai_level: int, seed_value: int = 1) -> void:
	index = fighter_index
	level = clampi(ai_level, 1, 5)
	rng.seed = seed_value * 92821 + fighter_index * 131 + ai_level


func next_input(sim: PureFightSim) -> FighterInput:
	var me := sim.pf[index]
	var op := sim.opponent(index)
	_remember(op)
	if me.state == PureFighter.State.ATTACK and me.move_tick == 0:
		used[me.move] = int(used.get(me.move, 0)) + 1
	if sim.phase != PureFightSim.Phase.FIGHT:
		_plan.clear()
		return _emit(me, 5, 0)
	if _plan.is_empty():
		_decide(sim, me, op)
	var step: Array = _plan.pop_front() if not _plan.is_empty() else [5, 0]
	return _emit(me, int(step[0]), int(step[1]))


## Input from a facing-relative numpad direction and held buttons.
func _emit(me: PureFighter, dir: int, held: int) -> FighterInput:
	var input := FighterInput.from_held(held, _previous)
	var fwd := ((dir - 1) % 3) - 1
	var up := 1 if dir >= 7 else (-1 if dir <= 3 else 0)
	input.move = Vector2(fwd * me.facing, up)
	_previous = input
	return input


func _remember(op: PureFighter) -> void:
	var data := PureMoves.get_move(op.legend, op.move) if op.state == PureFighter.State.ATTACK else {}
	_seen.push_back([op.state, data.get("guard", &""), op.y, op.vx, op.in_attack_recovery(),
		op.x, data.get("kind", &"")])
	var delay: int = LEVELS[level][0]
	while _seen.size() > delay + 1:
		_seen.pop_front()


func _chance(column: int) -> bool:
	return rng.randf() < float(LEVELS[level][column])


func _decide(sim: PureFightSim, me: PureFighter, op: PureFighter) -> void:
	var S := PureFighter.State
	var dist := absi(op.x - me.x)
	var seen: Array = _seen[0]
	var seen_state: int = seen[0]
	var actionable := me.state in [S.IDLE, S.WALK, S.CROUCH]
	# Confirmed hit: cancel into a technique or finish.
	if me.state == S.ATTACK and me.move_contact_hit and _chance(4):
		var data := PureMoves.get_move(me.legend, me.move)
		if int(data.cancel) >= 1 and me.move_tick < int(data.startup) + int(data.active):
			if me.meter >= PureMoves.METER_MAX and _chance(4):
				_queue(_finisher_steps())
			else:
				_queue(_technique_steps(me, &"236" if rng.randf() < 0.7 else &"623"))
			return
		if int(data.cancel) >= 2:
			for id in PureMoves.ids(me.legend):
				if PureMoves.get_move(me.legend, id).chain_from == me.move:
					_queue([[5, 0], [5, BUTTONS[PureMoves.get_move(me.legend, id).button]]])
					return
	if not actionable and me.state != S.BLOCKSTUN:
		_queue([[5, 0]])
		return
	# Defence: the opponent's attack, seen after the reaction delay.
	if seen_state == S.ATTACK and dist < 2400 and seen[6] != &"throw":
		if _chance(1):
			var guard: StringName = seen[1]
			var low := guard == &"low" or (guard == &"mid" and rng.randf() < 0.5)
			if guard in [&"overhead", &"high"]:
				low = false
			_queue(_hold(1 if low else 4, 10))
		else:
			_queue(_hold(5 if rng.randf() < 0.5 else 2, 6))
		return
	if me.state == S.BLOCKSTUN:
		_queue(_hold(1 if me.crouching else 4, 2))
		return
	# Anti-air.
	if seen_state == S.AIR and int(seen[2]) > 200 and dist < 2600 and _chance(2):
		if rng.randf() < 0.6:
			_queue(_technique_steps(me, &"623"))
		else:
			_queue([[2, 0], [2, BUTTONS[&"H"]]])
		return
	# Punish a whiffed move in recovery.
	if bool(seen[4]) and dist < 1300 and _chance(3):
		_queue(_combo(me, true))
		return
	if _wait > 0:
		_wait -= 1
		_queue(_hold(4 if dist < 1500 else 5, 1))
		return
	if rng.randf() < explore:
		var fresh := _unused_move(me)
		if fresh != &"":
			_queue(_steps_for(me, fresh))
			return
	var roll := rng.randf()
	if me.meter >= PureMoves.METER_MAX and dist < 1400 and roll < 0.2:
		_queue(_finisher_steps())
	elif dist > 2600:
		if roll < 0.15:
			_queue([[9, 0]] + _hold(5, 10) + [[5, BUTTONS[&"H"]]])
		elif roll < 0.3:
			_queue([[6, 0], [5, 0], [6, 0], [6, 0]])
		else:
			_queue(_hold(6, 8))
	elif dist > 1300:
		if roll < 0.3:
			_queue(_hold(6, 6))
		elif roll < 0.45:
			_queue(_technique_steps(me, &"236"))
		elif roll < 0.6:
			_queue([[9, 0]] + _hold(5, 12) + [[5, BUTTONS[[&"M", &"H"][rng.randi() % 2]]]])
		elif roll < 0.75:
			_queue([[2, 0], [2, BUTTONS[&"M"]]] + _hold(5, 8))
		else:
			_queue(_hold(4, 6))
			_wait = 6
	else:
		if roll < 0.12:
			_queue([[5, A.GRAB]])
		elif roll < 0.5:
			_queue(_combo(me, false))
		elif roll < 0.62:
			_queue([[6, 0], [6, BUTTONS[&"M"]]])
		elif roll < 0.74:
			_queue([[3, 0], [3, BUTTONS[&"H"]]])
		elif roll < 0.86:
			_queue(_hold(1, 14))
		else:
			_queue(_hold(4, 10))


func _queue(steps: Array) -> void:
	_plan.append_array(steps)


func _hold(dir: int, ticks: int) -> Array:
	var steps: Array = []
	for _i in ticks:
		steps.append([dir, 0])
	return steps


## A string: light or medium into its target combo, the cancel decided on contact.
func _combo(me: PureFighter, punish: bool) -> Array:
	var starters: Array[StringName] = []
	for id in PureMoves.ids(me.legend):
		var data := PureMoves.get_move(me.legend, id)
		if data.kind == &"target":
			starters.append(data.chain_from)
	var start: StringName = starters[rng.randi() % starters.size()] if not starters.is_empty() else &"5L"
	if punish and rng.randf() < 0.5:
		start = &"2H"
	return _steps_for(me, start)


func _finisher_steps() -> Array:
	return [[5, A.ULTIMATE], [5, 0]]


func _technique_steps(me: PureFighter, motion: StringName) -> Array:
	var button: int = BUTTONS[[&"L", &"M", &"H"][rng.randi() % 3]]
	match motion:
		&"623":
			return [[6, 0], [2, 0], [3, button], [5, 0]]
		&"214":
			return [[2, 0], [1, 0], [4, button], [5, 0]]
	return [[2, 0], [3, 0], [6, button], [5, 0]]


func _unused_move(me: PureFighter) -> StringName:
	var list := PureMoves.ids(me.legend)
	var fresh: Array[StringName] = []
	for id in list:
		if not used.has(id):
			fresh.append(id)
	if fresh.is_empty():
		return &""
	return fresh[rng.randi() % fresh.size()]


## Inputs that start a move from neutral (target combos start with their opener).
func _steps_for(me: PureFighter, id: StringName) -> Array:
	var data := PureMoves.get_move(me.legend, id)
	var button: int = BUTTONS.get(data.button, A.LIGHT)
	match data.kind:
		&"finisher":
			return _finisher_steps() if me.meter >= PureMoves.METER_MAX else [[5, 0]]
		&"throw":
			return [[6, 0], [6, A.GRAB], [5, 0]]
		&"technique":
			if data.stance == &"air":
				return [[9, 0]] + _hold(5, 8) + [[2, button], [5, 0]]
			return _technique_steps(me, data.motion)
		&"target":
			var opener := _steps_for(me, data.chain_from)
			return opener + _hold(5, 7) + [[5, button], [5, 0]]
	var text := String(id)
	if text.begins_with("j."):
		return [[8 + rng.randi_range(-1, 1), 0]] + _hold(5, 9) + [[5, button], [5, 0]]
	var dir := int(text.substr(0, 1))
	return [[dir, 0], [dir, button], [5, 0]]
