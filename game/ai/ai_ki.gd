class_name AIKi
extends RefCounted
## The AI's ki game (T-KI1): zoning with tap and charged blasts at range,
## occasional beams (always with their tell), beam whiff punishes, reading a
## beam's tell (sidestep after its aim locks, or block) and the beam clash
## beats. FighterAI owns one and calls it; all randomness from its own seeded rng.

const _A := FighterInput.Action
const _S := FighterState.State

## Per level 1..5. Weight of the ki zoning plan in neutral at range.
const ZONE_WEIGHT: Array[float] = [0.15, 0.25, 0.35, 0.42, 0.5]
## Fewest ticks between two tap blasts while zoning.
const BLAST_GAP_TICKS: Array[int] = [90, 60, 45, 36, 30]
## Ki kept back from tap blasts (display units), so beams stay affordable.
const KI_RESERVE: Array[int] = [0, 15, 20, 25, 30]
## Chance a zoning shot is a charged blast (held Q).
const CHARGED_CHANCE: Array[float] = [0.0, 0.08, 0.14, 0.2, 0.25]
## Chance per zoning tick to start a beam when it has the ki.
const BEAM_CHANCE: Array[float] = [0.0, 0.004, 0.008, 0.012, 0.016]
## Chance to answer a seen whiff at range with a beam.
const BEAM_PUNISH_CHANCE: Array[float] = [0.0, 0.1, 0.3, 0.5, 0.7]
## Chance to sidestep a seen beam tell (else it blocks).
const SIDESTEP_CHANCE: Array[float] = [0.0, 0.15, 0.35, 0.55, 0.75]
## Chance to hit each clash beat with the right key.
const CLASH_ACCURACY: Array[float] = [0.3, 0.5, 0.65, 0.8, 0.9]
## Most ticks off the beat it presses when it hits one.
const CLASH_SLOP: Array[int] = [4, 3, 2, 1, 1]
## Legends' liking for ki zoning (GAME_DESIGN §6: Lyra is the zoner, Brann the brawler).
const LEGEND_TASTE := {&"lyra": 1.8, &"kael": 1.0, &"vexa": 0.8, &"brann": 0.5}
## Legends at or above this taste make their own zoning room.
const ZONER_TASTE := 1.5
## Ki zoning distance band (m).
const ZONE_NEAR := 10.0
const ZONE_FAR := 26.0

## Its own stream, so ki choices never shift FighterAI's other rolls.
var rng := RandomNumberGenerator.new()
var _hold_q: int = 0
var _last_blast: int = -1000
var _beam_key: int = -1
var _beam_answer: int = 0 # 0 none, 1 block, 2 sidestep
var _clash_beat: int = -1
var _clash_press_tick: int = -1
var _clash_button: int = 0
## Holding back blasts (and charging at range) until a beam is affordable.
var _saving: bool = false


func snapshot_values() -> Array:
	return [_hold_q, _last_blast, _beam_key, _beam_answer, _clash_beat, _clash_press_tick, _clash_button, _saving,
		rng.state]


func restore_values(values: Array) -> void:
	if values.size() < 7:
		return
	_hold_q = values[0]; _last_blast = values[1]; _beam_key = values[2]; _beam_answer = values[3]
	_clash_beat = values[4]; _clash_press_tick = values[5]; _clash_button = values[6]
	_saving = values[7] if values.size() > 7 else false
	if values.size() > 8:
		rng.state = values[8]


func saving() -> bool:
	return _saving


## Score for the ki zoning plan, 0 when it makes no sense.
static func zone_score(ai: FighterAI, me: FighterState, distance: float) -> float:
	var kit := KiRules.kit_of(me)
	var taste: float = LEGEND_TASTE.get(ai.legend, 1.0)
	# A zoner backs off to make room for blasts; the others zone only when the fight is already far.
	var zoner := taste >= ZONER_TASTE
	var near := 3.0 if zoner else ZONE_NEAR + 3.0
	if distance < near or me.ki < kit.blast.ki_cost * 3 * FighterState.METER_UNIT \
			or me.held_weapon() != Weapon.Kind.NONE:
		return 0.0
	var level := ai.profile.level - 1
	var score := ZONE_WEIGHT[level] * taste + (0.2 if distance > 18.0 else 0.0)
	return score * (0.6 if distance < ZONE_NEAR else 1.0)


## Neutral at range: keep the band, strafe, fire blasts, sometimes a charged one or a beam.
func zone(ai: FighterAI, sim: CombatSim, me: FighterState, target: FighterState, distance: float,
		plan: FighterInput, now: int) -> void:
	var level := ai.profile.level - 1
	var kit := KiRules.kit_of(me)
	if distance > ZONE_FAR:
		plan.move = Vector2(ai.strafe() * 0.3, 1)
	elif distance < ZONE_NEAR:
		plan.move = Vector2(ai.strafe() * 0.5, -1)
	else:
		plan.move = Vector2(ai.strafe(), 0)
	if not ai.may_attack(me) or me.lock_on_target < 0:
		return
	var unit := FighterState.METER_UNIT
	var target_busy := target.state in [_S.ATTACKING, _S.CHARGING, _S.GUARD_BROKEN] or not target.blocking
	if kit.beam != null and me.ki >= (kit.beam.ki_cost + 10) * unit and distance > ZONE_NEAR \
			and distance < kit.beam_range * 0.9 and target_busy and rng.randf() < BEAM_CHANCE[level]:
		plan.held_actions |= _A.SPECIAL_1
		return
	# Below the reserve it saves up for a beam (charging when safely far), then zones again.
	if KI_RESERVE[level] > 0 and kit.beam != null:
		if me.ki < KI_RESERVE[level] * unit:
			_saving = true
		elif me.ki >= (kit.beam.ki_cost + 10) * unit:
			_saving = false
	if _saving:
		if distance > ZONE_NEAR and not target_busy_close(target, distance):
			plan.held_actions |= _A.CHARGE
			plan.move = Vector2.ZERO
		return
	if now - _last_blast < BLAST_GAP_TICKS[level] or me.ki < kit.blast.ki_cost * unit:
		return
	_last_blast = now
	plan.held_actions |= _A.KI_BLAST
	if me.ki >= (kit.charged.ki_cost + 10) * unit and rng.randf() < CHARGED_CHANCE[level]:
		_hold_q = kit.charged.startup_ticks + 1


## True when the target is close enough and coming: charging now would be punished.
static func target_busy_close(target: FighterState, distance: float) -> bool:
	return target.state == _S.DASHING and target.dash_kind == FighterState.DashKind.RUSH or distance < 8.0


## A seen whiff at beam range: fire a beam into the recovery.
func punish(ai: FighterAI, me: FighterState, target: FighterState, distance: float, plan: FighterInput) -> bool:
	var kit := KiRules.kit_of(me)
	if kit.beam == null or distance < ZONE_NEAR or distance > kit.beam_range * 0.8 or not ai.may_attack(me) \
			or me.ki < kit.beam.ki_cost * FighterState.METER_UNIT:
		return false
	# A long recovery, or charging ki in the open at range: both too slow to get out of a beam.
	var left := target.move_total_ticks() - target.move_tick
	var open := (target.state == _S.ATTACKING and target.attack_phase() == FighterState.AttackPhase.RECOVERY
		and left >= kit.beam.startup_ticks + 4) or (target.state == _S.CHARGING and target.state_ticks >= 10)
	if not open or rng.randf() >= BEAM_PUNISH_CHANCE[ai.profile.level - 1] * 0.1:
		return false
	plan.held_actions |= _A.SPECIAL_1
	return true


## While its own ki move runs: keeps Q held for a charged blast and plays the clash. True if it set the input.
func during_attack(ai: FighterAI, sim: CombatSim, me: FighterState, plan: FighterInput) -> bool:
	var clash := KiRules.clash_of(sim, ai.fighter_index)
	if clash != null:
		_play_clash(ai, sim, me, clash, plan)
		return true
	if _hold_q > 0:
		_hold_q -= 1
		var kit := KiRules.kit_of(me)
		if me.move == kit.blast or me.move == kit.charged:
			plan.held_actions |= _A.KI_BLAST
			return true
		_hold_q = 0
	return false


func _play_clash(ai: FighterAI, sim: CombatSim, me: FighterState, clash: BeamClash, plan: FighterInput) -> void:
	var level := ai.profile.level - 1
	var now := sim.current_tick
	for k in clash.beat_ticks.size():
		var until := clash.beat_ticks[k] - now
		if k != _clash_beat and until >= 0 and until <= 8:
			_clash_beat = k
			_clash_press_tick = -1
			if rng.randf() < CLASH_ACCURACY[level]:
				_clash_press_tick = clash.beat_ticks[k] + rng.randi_range(-CLASH_SLOP[level], CLASH_SLOP[level])
				_clash_button = clash.beat_buttons[k]
			elif rng.randf() < 0.5:
				# A fumble: right time, wrong key.
				_clash_press_tick = clash.beat_ticks[k]
				_clash_button = KiRules.BEAT_BUTTONS[(KiRules.BEAT_BUTTONS.find(clash.beat_buttons[k]) + 1) % 4]
			break
	if now == _clash_press_tick:
		plan.held_actions |= _clash_button
	var side := clash.side_of(ai.fighter_index)
	var behind := (clash.push < 0) if side == 0 else (clash.push > 0)
	if level >= 2 and behind and me.ki >= 30 * FighterState.METER_UNIT and now % 30 == 0:
		plan.held_actions |= _A.SPECIAL_1


## Reads an opponent's beam tell aimed at it: sidesteps once the aim locks, or blocks. True if it acted.
func answer_beams(ai: FighterAI, sim: CombatSim, me: FighterState, plan: FighterInput) -> bool:
	var level := ai.profile.level - 1
	for j in sim.fighters.size():
		var other := sim.fighters[j]
		if j == ai.fighter_index or other.team == me.team or other.state != _S.ATTACKING:
			continue
		var kit := KiRules.kit_of(other)
		if not kit.is_beam(other.move):
			continue
		var to_me := me.position - other.position
		var forward := other.aim_basis() * Vector3.FORWARD
		if to_me.length() > kit.range_for(other.move) + 2.0 or to_me.normalized().dot(forward) < 0.9:
			continue
		if other.move_tick < ai.profile.reaction_ticks:
			continue # Not seen yet.
		var key := j * 1048576 + (sim.current_tick - other.move_tick)
		if key != _beam_key:
			_beam_key = key
			_beam_answer = 2 if rng.randf() < SIDESTEP_CHANCE[level] else 1
		var until_fire := other.move.startup_ticks - other.move_tick
		var gap := to_me.length()
		if gap < 6.0:
			# Up close the tell is a free hit: close in and strike the startup if there is time, else guard.
			if until_fire > 6 and me.state != _S.BLOCKING:
				if gap > 1.8:
					plan.move = Vector2(0, 1)
				elif ai.may_attack(me):
					plan.held_actions |= _A.LIGHT
				return true
			plan.held_actions |= _A.BLOCK
			return true
		if _beam_answer == 2 and until_fire <= sim.ki_tuning.beam_aim_lock_ticks and until_fire > 0 \
				and me.state != _S.DASHING and me.ki >= 10 * FighterState.METER_UNIT:
			plan.held_actions |= _A.DASH
			plan.move = Vector2(ai.strafe(), 0)
			return true
		if _beam_answer == 2 and until_fire > sim.ki_tuning.beam_aim_lock_ticks:
			plan.move = Vector2.ZERO
			return true
		plan.held_actions |= _A.BLOCK
		return true
	return false
