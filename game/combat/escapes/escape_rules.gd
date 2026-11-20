class_name EscapeRules
extends RefCounted
## Escape tools (T-DEF3, GAME_DESIGN §5.4, §5.6, §5.7): combo breaker, air tech
## and the chase that reads it, tech roll and wakeups. Pure sim rules: CombatSim
## calls these hooks; numbers live in CombatSim.escape_tuning.

const _S := FighterState.State
const _K := FighterEscapes.Kind
const _W := FighterEscapes.Way
const _UNIT := FighterState.METER_UNIT
## Knockbacks that open a chase for the attacker.
const CHASE_KNOCKBACKS: Array[MoveData.KnockbackType] = [
	MoveData.KnockbackType.BLOWBACK, MoveData.KnockbackType.LAUNCH,
]
## Knockbacks an air tech can recover from (a spike only before its bounce).
const TECH_KNOCKBACKS: Array[MoveData.KnockbackType] = [
	MoveData.KnockbackType.BLOWBACK, MoveData.KnockbackType.LAUNCH,
	MoveData.KnockbackType.SWEEP, MoveData.KnockbackType.SPIKE,
]


## Per unfrozen tick, before anything acts: timers run down, a finished chase lets go.
static func count(fighter: FighterState) -> void:
	var escapes := fighter.escapes
	escapes.intangible_ticks = maxi(escapes.intangible_ticks - 1, 0)
	escapes.breaker_cooldown = maxi(escapes.breaker_cooldown - 1, 0)
	escapes.chase_window = maxi(escapes.chase_window - 1, 0)
	if escapes.chase_window == 0:
		escapes.chase_target = -1
	if escapes.chasing >= 0 and fighter.state != _S.DASHING:
		escapes.chasing = -1


## A landed hit: a chaseable knockback opens the chase window; any hit gives the target a fresh air tech.
static func on_hit(sim: CombatSim, attacker_index: int, target_index: int,
		knockback: MoveData.KnockbackType, from_projectile: bool) -> void:
	var target := sim.fighters[target_index]
	target.escapes.air_tech_used = false
	var attacker := sim.fighters[attacker_index].escapes
	if from_projectile or knockback not in CHASE_KNOCKBACKS:
		return
	attacker.chase_target = target_index
	attacker.chase_window = sim.escape_tuning.chase_window_ticks


## Hitstun, knockdown or escaping: tries this tick's escape. True when it handled the
## state (escaped, woke up, still escaping); false lets the usual timer end it.
static func step(sim: CombatSim, index: int, input: FighterInput) -> bool:
	var fighter := sim.fighters[index]
	match fighter.state:
		_S.HITSTUN:
			return _try_breaker(sim, index) or _try_air_tech(sim, index, input)
		_S.KNOCKDOWN:
			return _step_knockdown(sim, index, input)
		_S.ESCAPING:
			if fighter.state_ticks >= fighter.stun_ticks:
				# Slides stop dead where they end; an air tech keeps its (capped) momentum.
				if fighter.escapes.kind != _K.AIR_TECH:
					fighter.velocity = Vector3.ZERO
				fighter.escapes.kind = _K.NONE
				sim._enter_free_state(fighter)
			return true
	return false


## Velocity while ESCAPING: a constant slide set at the start; a missed chase brakes.
static func move(sim: CombatSim, fighter: FighterState) -> void:
	if fighter.escapes.kind == _K.CHASE_MISS:
		fighter.velocity = fighter.velocity.move_toward(Vector3.ZERO,
			sim.tuning.ground_deceleration * CombatSim.TICK_SECONDS)
	if sim.is_on_floor(fighter) and fighter.velocity.y < 0.0:
		fighter.velocity.y = 0.0
	# Ground slides follow the terrain like walking; a drop past the ledge height leaves them airborne.
	if fighter.escapes.kind != _K.AIR_TECH and fighter.velocity.y == 0.0 and sim.ground_height.is_valid():
		var stand := sim._stand_height(fighter)
		if fighter.position.y <= stand + CombatSim._LEDGE_DROP:
			fighter.position.y = stand


## Dash right after a knockback hit chases: an auto-homing rush whose way (over with
## ascend, under with descend, else straight) a matching air tech cannot escape.
static func try_chase(sim: CombatSim, index: int, input: FighterInput) -> bool:
	var fighter := sim.fighters[index]
	var escapes := fighter.escapes
	var target := escapes.chase_target
	if target < 0 or escapes.chase_window <= 0 or fighter.lock_on_target != target \
			or input.is_held(FighterInput.Action.BLOCK) or not sim.is_buffered(index, FighterInput.Action.DASH):
		return false
	var chased := sim.fighters[target]
	if chased.state != _S.HITSTUN or chased.is_knocked_out():
		return false
	var may := sim._is_free(fighter) or (fighter.state == _S.ATTACKING and fighter.contact_hit)
	if not may or not sim._spend_ki(fighter, sim.escape_tuning.chase_ki_cost):
		return false
	sim.consume_buffered(index, FighterInput.Action.DASH)
	var to_target := chased.position - fighter.position
	fighter.dash_kind = FighterState.DashKind.RUSH
	fighter.dash_direction = to_target.normalized() if to_target != Vector3.ZERO \
		else DetMath.forward(fighter.facing_yaw)
	fighter.enter_state(_S.DASHING)
	escapes.chasing = target
	escapes.way = way_of(input.vertical)
	escapes.chase_target = -1
	escapes.chase_window = 0
	sim.events.append(event(CombatSim.EventType.CHASE, index, target, fighter.position, escapes.way))
	return true


## A chasing rush stays on its target through the target's air-tech window, so the
## way it picked still matters; then it ends beside the target, which is still in hitstun.
static func tailing(sim: CombatSim, fighter: FighterState) -> bool:
	var target := fighter.escapes.chasing
	if target < 0:
		return false
	var chased := sim.fighters[target]
	return chased.state == _S.HITSTUN and not chased.escapes.air_tech_used \
		and chased.state_ticks <= sim.escape_tuning.air_tech_last_tick


## Where a chasing rush aims, relative to its target: above for over, below for under.
static func chase_offset(sim: CombatSim, fighter: FighterState) -> Vector3:
	if fighter.escapes.chasing < 0:
		return Vector3.ZERO
	match fighter.escapes.way:
		_W.OVER:
			return Vector3.UP * sim.escape_tuning.chase_offset_height
		_W.UNDER:
			return Vector3.DOWN * sim.escape_tuning.chase_offset_height
	return Vector3.ZERO


## Ascend reads as over, descend as under, anything else as straight.
static func way_of(vertical: float) -> FighterEscapes.Way:
	if vertical > 0.0:
		return _W.OVER
	if vertical < 0.0:
		return _W.UNDER
	return _W.STRAIGHT


## True while the fighter is in the air-tech window of a techable knockback.
static func can_air_tech(sim: CombatSim, fighter: FighterState) -> bool:
	var tuning := sim.escape_tuning
	return fighter.state == _S.HITSTUN and not fighter.escapes.air_tech_used \
		and fighter.knockback_type in TECH_KNOCKBACKS and not fighter.spike_bounced \
		and fighter.state_ticks >= tuning.air_tech_first_tick \
		and fighter.state_ticks <= tuning.air_tech_last_tick \
		and fighter.state_ticks < fighter.stun_ticks


## True when a combo breaker would fire now (ignoring the button); never inside a beam clash.
static func can_break(sim: CombatSim, fighter: FighterState) -> bool:
	var tuning := sim.escape_tuning
	return fighter.state == _S.HITSTUN and not sim.round_over and not fighter.is_knocked_out() \
		and fighter.escapes.breaker_cooldown == 0 and not KiRules.in_clash(sim, sim.fighters.find(fighter)) \
		and fighter.burst >= tuning.breaker_burst_stocks * sim.meter_tuning.burst_stock_size * _UNIT


## A new event entry: {type, fighter, attacker, target, position, way, caught}.
static func event(type: CombatSim.EventType, fighter: int, target: int, at: Vector3,
		way: FighterEscapes.Way = _W.NONE, caught: bool = false, hitstop: int = 0) -> Dictionary:
	return {
		"type": type, "fighter": fighter, "attacker": fighter, "target": target, "position": at,
		"way": way, "caught": caught, "hitstop": hitstop, "damage": 0, "move_id": &"",
		"knockback_type": MoveData.KnockbackType.NONE, "counter": false,
	}


## X in hitstun: one burst stock blows every nearby opponent out to mid range;
## a big freeze, then the breaker is intangible for a while (its burst pose first).
static func _try_breaker(sim: CombatSim, index: int) -> bool:
	var fighter := sim.fighters[index]
	if not can_break(sim, fighter) or not sim.consume_buffered(index, FighterInput.Action.BREAKER):
		return false
	var tuning := sim.escape_tuning
	sim.try_spend_burst(index, tuning.breaker_burst_stocks)
	_enter_escape(sim, fighter, _K.BREAKER, tuning.breaker_pose_ticks, Vector3.ZERO)
	fighter.escapes.intangible_ticks = tuning.breaker_intangible_ticks
	fighter.escapes.breaker_cooldown = tuning.breaker_cooldown_ticks
	fighter.hitstop_ticks = maxi(fighter.hitstop_ticks, tuning.breaker_hitstop_ticks)
	var pushed := -1
	for other in sim.fighters.size():
		var opponent := sim.fighters[other]
		# Fighters locked in a beam clash stay locked: the breaker does not push them.
		if other == index or opponent.team == fighter.team or opponent.is_knocked_out() \
				or KiRules.in_clash(sim, other):
			continue
		var away := opponent.position - fighter.position
		away.y = 0.0
		if away.length_squared() > tuning.breaker_radius * tuning.breaker_radius:
			continue
		if away.length_squared() < 0.0001:
			away = DetMath.forward(fighter.facing_yaw)
		var reach := maxf(away.length(), tuning.breaker_push_distance)
		var destination := fighter.position + away.normalized() * reach
		destination.y = opponent.position.y
		_enter_escape(sim, opponent, _K.BLOWN_AWAY, tuning.breaker_push_ticks,
			(destination - opponent.position) / (tuning.breaker_push_ticks * CombatSim.TICK_SECONDS))
		opponent.escapes.chasing = -1
		opponent.escapes.chase_target = -1
		opponent.escapes.chase_window = 0
		opponent.hitstop_ticks = maxi(opponent.hitstop_ticks, tuning.breaker_hitstop_ticks)
		if pushed < 0:
			pushed = other
	sim.events.append(event(CombatSim.EventType.COMBO_BREAKER, index, pushed, fighter.position,
		_W.NONE, false, tuning.breaker_hitstop_ticks))
	return true


## Dash + direction in flight ticks 12-24 of a knockback recovers that way, intangible
## at first. A chaser who picked the same way catches it (the tech fails, hitstun runs
## longer); a chaser who picked another way brakes long enough to give the defender +8.
static func _try_air_tech(sim: CombatSim, index: int, input: FighterInput) -> bool:
	var fighter := sim.fighters[index]
	if not can_air_tech(sim, fighter) or not sim.consume_buffered(index, FighterInput.Action.DASH):
		return false
	var tuning := sim.escape_tuning
	var way := way_of(input.vertical)
	fighter.escapes.air_tech_used = true
	fighter.escapes.way = way
	var caught_by := -1
	var missed: Array[int] = []
	for other in sim.fighters.size():
		var chaser := sim.fighters[other]
		if chaser.escapes.chasing != index or chaser.state != _S.DASHING:
			continue
		if chaser.escapes.way == way:
			caught_by = other if caught_by < 0 else caught_by
		else:
			missed.append(other)
	if caught_by >= 0:
		fighter.stun_ticks = maxi(fighter.stun_ticks, fighter.state_ticks + tuning.air_tech_caught_ticks)
		sim.events.append(event(CombatSim.EventType.AIR_TECH, index, caught_by, fighter.position, way, true))
		return true
	var direction := sim._wish_direction(index, input)
	direction.y = signf(input.vertical)
	direction = direction.normalized() if direction != Vector3.ZERO else Vector3.ZERO
	var speed := tuning.air_tech_distance / (tuning.air_tech_ticks * CombatSim.TICK_SECONDS)
	_enter_escape(sim, fighter, _K.AIR_TECH, tuning.air_tech_ticks, direction * speed)
	fighter.escapes.intangible_ticks = tuning.air_tech_invuln_ticks
	for other in missed:
		var chaser := sim.fighters[other]
		_enter_escape(sim, chaser, _K.CHASE_MISS, tuning.air_tech_ticks + tuning.chase_miss_advantage_ticks,
			chaser.velocity)
		# A chaser stepped earlier this tick counts it like the defender does, so fighter order never matters.
		if other < index:
			chaser.state_ticks = 1
		chaser.escapes.chasing = -1
	sim.events.append(event(CombatSim.EventType.AIR_TECH, index, missed[0] if not missed.is_empty() else -1,
		fighter.position, way, false))
	return true


## Knocked down: Space (+ WASD) in the first ticks rolls; at the neutral wakeup,
## holding descend lies on until the delayed wakeup. Every wakeup starts intangible.
static func _step_knockdown(sim: CombatSim, index: int, input: FighterInput) -> bool:
	var fighter := sim.fighters[index]
	var tuning := sim.escape_tuning
	if fighter.is_knocked_out():
		return false
	if input.vertical > 0.0 and fighter.state_ticks <= tuning.tech_roll_window_ticks:
		var direction := sim._wish_direction(index, input)
		direction.y = 0.0
		direction = direction.normalized() if direction != Vector3.ZERO else Vector3.ZERO
		var speed := tuning.tech_roll_distance / (tuning.tech_roll_ticks * CombatSim.TICK_SECONDS)
		_enter_escape(sim, fighter, _K.TECH_ROLL, tuning.tech_roll_ticks, direction * speed)
		fighter.escapes.intangible_ticks = tuning.wakeup_invuln_ticks
		sim.events.append(event(CombatSim.EventType.TECH_ROLL, index, -1, fighter.position))
		return true
	if fighter.state_ticks < fighter.stun_ticks:
		return true
	if input.vertical < 0.0 and not fighter.escapes.delayed_wakeup:
		fighter.escapes.delayed_wakeup = true
		fighter.stun_ticks = maxi(fighter.stun_ticks, tuning.delayed_wakeup_ticks)
		return true
	var delayed := fighter.escapes.delayed_wakeup
	fighter.escapes.delayed_wakeup = false
	sim._enter_free_state(fighter)
	fighter.escapes.intangible_ticks = tuning.wakeup_invuln_ticks
	var wake := event(CombatSim.EventType.WAKEUP, index, -1, fighter.position)
	wake["delayed"] = delayed
	sim.events.append(wake)
	return true


static func _enter_escape(sim: CombatSim, fighter: FighterState, kind: FighterEscapes.Kind, ticks: int,
		velocity: Vector3) -> void:
	sim._enter_stun(fighter, _S.ESCAPING, ticks)
	fighter.escapes.kind = kind
	fighter.velocity = velocity
	fighter.blocking = false
