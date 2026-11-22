class_name PressureAI
extends RefCounted
## How an AI fighter answers pressure and escapes from it (#150): it dodges out of a
## blockstring's gap now and then, and now and then punishes a dodge's recovery.
## Reads the sim only and draws from its own rng, so other AI decisions keep theirs.

const _S := FighterState.State
const _A := FighterInput.Action
## Chance per blockstun to let go of the guard and buffer a dodge for the gap (L1..L5).
const DODGE_OUT_CHANCE: Array[float] = [0.0, 0.08, 0.15, 0.22, 0.3]
## Chance that a dodge-out is a sidestep round the attacker rather than a back dodge.
const SIDESTEP_SHARE: Array[float] = [0.0, 0.0, 0.25, 0.5, 0.6]
## Chance to punish a seen dodge whose recovery it can still reach (L1..L5).
const PUNISH_DODGE_CHANCE: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6]

var level: int = 3
var rng := RandomNumberGenerator.new()

## Ticks left of a dodge-out: the guard let go and the direction held.
var _out_left: int = 0
var _out_move := Vector2.ZERO
## Dodge instance (target * 2^20 + its start tick) the punish roll was made for.
var _punish_key: int = -1
var _punish_ok: bool = false


func _init(ai_level: int = 3, seed_value: int = 0) -> void:
	level = ai_level
	rng.seed = seed_value


## In a blockstun: rolls once (the caller says when) to let go of the guard and tap
## Shift with a direction; the sim holds the press until the stun's last tick (#150).
func try_dodge_out(me: FighterState, strafe: float, plan: FighterInput) -> bool:
	var i := clampi(level, 1, 5) - 1
	if me.state != _S.BLOCKSTUN or rng.randf() >= DODGE_OUT_CHANCE[i]:
		return false
	_out_move = Vector2(0, -1)
	if rng.randf() < SIDESTEP_SHARE[i]:
		_out_move = Vector2(strafe, 0)
	_out_left = maxi(me.stun_ticks - me.state_ticks, 0) + 3
	plan.held_actions = (plan.held_actions & ~_A.BLOCK) | _A.DASH
	plan.move = _out_move
	return true


## Keeps a dodge-out going: no guard, the direction held. False when there is none.
func keep_dodging_out(plan: FighterInput) -> bool:
	if _out_left <= 0:
		return false
	_out_left -= 1
	plan.move = _out_move
	return true


## The target is dodging and its recovery is still reachable: grab it close in
## (a counter-hit), else start a string or rush in. Rolled once per dodge.
func punish_dodge(sim: CombatSim, me: FighterState, target_index: int, distance: float,
		light_reach: float, ticks: int, plan: FighterInput) -> bool:
	var target := sim.fighters[target_index]
	if target.state != _S.DASHING or target.dash_kind != FighterState.DashKind.DODGE:
		return false
	var key := target_index * 1048576 + (ticks - target.state_ticks)
	if key != _punish_key:
		_punish_key = key
		_punish_ok = rng.randf() < PUNISH_DODGE_CHANCE[clampi(level, 1, 5) - 1]
	if not _punish_ok:
		return false
	var dodge := target.dodge
	var left := dodge.last_frame - target.state_ticks
	var moves := sim._move_set(me)
	var grab := moves.grab
	if grab != null and distance <= FighterAI.move_reach(grab, target.stats.hurtbox_radius) - 0.1:
		# Lands on the first vulnerable frame or later, before the dodge ends.
		if target.state_ticks + grab.startup_ticks > dodge.invuln_last and grab.startup_ticks < left:
			plan.held_actions |= _A.GRAB
			return true
		return target.state_ticks + grab.startup_ticks <= dodge.invuln_last # Wait for it.
	if distance <= light_reach - 0.1 and not moves.light_string.is_empty():
		var light := moves.light_string[0]
		if target.state_ticks + light.startup_ticks > dodge.invuln_last and light.startup_ticks < left:
			plan.held_actions |= _A.LIGHT
			return true
		return target.state_ticks + light.startup_ticks <= dodge.invuln_last
	plan.move = Vector2(0, 1)
	return left > 0


func snapshot() -> Array:
	return [rng.state, _out_left, _out_move, _punish_key, _punish_ok]


func restore(v: Array) -> void:
	rng.state = v[0]; _out_left = v[1]; _out_move = v[2]; _punish_key = v[3]; _punish_ok = v[4]
