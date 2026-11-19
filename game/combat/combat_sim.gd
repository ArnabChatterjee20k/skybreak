class_name CombatSim
extends RefCounted
## Deterministic combat simulation, advanced in fixed ticks.
## Rules: no Node, Input, scene tree or delta access in here. Time is counted
## in ticks; use TICK_SECONDS when a duration in seconds is needed. All
## randomness comes from rng, so a seed plus the inputs replays a match exactly.

const TICKS_PER_SECOND := 60
const TICK_SECONDS := 1.0 / TICKS_PER_SECOND
## A press stays buffered for this many ticks, counting the tick it happened.
const INPUT_BUFFER_TICKS := 6
const DEFAULT_TUNING := preload("res://game/combat/default_movement_tuning.tres")
const DEFAULT_METER_TUNING := preload("res://game/combat/default_meter_tuning.tres")
const DEFAULT_FIGHTER_STATS := preload("res://game/combat/default_fighter_stats.tres")

const _DASH := FighterInput.Action.DASH
const _BLOCK := FighterInput.Action.BLOCK
const _CHARGE := FighterInput.Action.CHARGE
const _LIGHT := FighterInput.Action.LIGHT
const _HEAVY := FighterInput.Action.HEAVY
const _UNIT := FighterState.METER_UNIT
## Presses that do not interrupt charging.
const _CHARGE_SAFE_ACTIONS := FighterInput.Action.CHARGE | FighterInput.Action.LOCK_TOGGLE
## A rush dash counts as arrived within this many metres of its stop distance.
const _RUSH_ARRIVAL_MARGIN := 0.01
## Planar move input shorter than this makes a neutral heavy.
const _HEAVY_DEADZONE := 0.5
## Move input within 45 degrees of toward/away from the target picks Breaker/Launcher.
const _HEAVY_CONE := 0.7071
## States an attack can start from; charging is ended first by the attack press.
const _ATTACK_START_STATES: Array[FighterState.State] = [
	FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
]

var current_tick: int = 0
var fighters: Array[FighterState] = []
var rng := RandomNumberGenerator.new()
## True once a fighter is knocked out; inputs are ignored until start_round().
var round_over: bool = false
## Index of the fighter who won the round, or -1 while it is undecided.
var round_winner: int = -1
## Movement constants. Not part of the state hash: it is configuration.
var tuning: MovementTuning
## Meter constants shared by all fighters. Configuration, like tuning.
var meter_tuning: MeterTuning


func _init(seed_value: int = 0, movement_tuning: MovementTuning = null,
		meters: MeterTuning = null) -> void:
	rng.seed = seed_value
	tuning = movement_tuning if movement_tuning else DEFAULT_TUNING as MovementTuning
	meter_tuning = meters if meters else DEFAULT_METER_TUNING as MeterTuning


## Adds a fighter with round-start meters; above the floor it hovers, otherwise stands.
func add_fighter(start_position: Vector3, stats: FighterStats = null) -> FighterState:
	var fighter := FighterState.new()
	fighter.stats = stats if stats else DEFAULT_FIGHTER_STATS as FighterStats
	_reset_round_meters(fighter)
	fighter.position = start_position
	for _action in FighterInput.Action.size():
		fighter.press_ages.append(INPUT_BUFFER_TICKS)
	if start_position.y > tuning.ground_height:
		fighter.enter_state(FighterState.State.FLYING)
	else:
		fighter.position.y = tuning.ground_height
	fighters.append(fighter)
	return fighter


## Locks every fighter onto its nearest opponent; a 1v1 match starts this way.
func lock_everyone_onto_nearest() -> void:
	for index in fighters.size():
		fighters[index].lock_on_target = _nearest_opponent(index)


## Advances the sim by one tick. inputs[i] belongs to fighters[i].
func tick(inputs: Array[FighterInput]) -> void:
	assert(inputs.size() == fighters.size(), "one input per fighter")
	for i in fighters.size():
		# After a KO everyone gets neutral input until the next round.
		_step_fighter(i, FighterInput.new() if round_over else inputs[i])
	current_tick += 1


## Starts a new round: health, grey part, ki and guard reset; burst and Last Stand carry over.
func start_round() -> void:
	round_over = false
	round_winner = -1
	for fighter in fighters:
		_reset_round_meters(fighter)
		if fighter.state in [FighterState.State.CHARGING, FighterState.State.GUARD_BROKEN,
				FighterState.State.ATTACKING]:
			_enter_free_state(fighter)


## Hash of everything that defines the sim state; equal hashes mean equal states.
func state_hash() -> int:
	var parts: Array = [current_tick, rng.state, round_over, round_winner]
	for fighter in fighters:
		parts.append_array(fighter.state_values())
	return hash(var_to_bytes(parts))


## True while a press of action is inside the buffer window and not yet consumed.
func is_buffered(fighter_index: int, action: FighterInput.Action) -> bool:
	var fighter := fighters[fighter_index]
	return fighter.press_ages[_action_index(action)] < INPUT_BUFFER_TICKS \
		and (fighter.consumed_presses & action) == 0


## Uses up a buffered press so it acts only once. False if none is buffered.
func consume_buffered(fighter_index: int, action: FighterInput.Action) -> bool:
	if not is_buffered(fighter_index, action):
		return false
	fighters[fighter_index].consumed_presses |= action
	return true


## True when DASH and BLOCK were both pressed within the buffer window, in
## either order, even if one press already started something (vanish input).
func has_vanish_input(fighter_index: int) -> bool:
	var ages := fighters[fighter_index].press_ages
	return ages[_action_index(_DASH)] < INPUT_BUFFER_TICKS \
		and ages[_action_index(_BLOCK)] < INPUT_BUFFER_TICKS


## Spends amount ki (display units) if the fighter has that much. False otherwise.
func try_spend_ki(fighter_index: int, amount: int) -> bool:
	return _spend_ki(fighters[fighter_index], amount)


## Ki gain for landing a hit; T-D04 calls it for the attacker.
func add_landed_hit_ki(fighter_index: int) -> void:
	_add_ki(fighters[fighter_index], meter_tuning.ki_per_landed_hit * _UNIT)


## Ki gain for a blocked hit; T-D05 calls it.
func add_blocked_hit_ki(fighter_index: int) -> void:
	_add_ki(fighters[fighter_index], meter_tuning.ki_per_blocked_hit * _UNIT)


## Burst gain for a perfect block; T-D05 calls it for the blocker.
func add_perfect_block_burst(fighter_index: int) -> void:
	_add_burst(fighters[fighter_index], meter_tuning.burst_per_perfect_block * _UNIT)


## Spends whole burst stocks if the fighter has them. False otherwise.
func try_spend_burst(fighter_index: int, stocks: int) -> bool:
	var fighter := fighters[fighter_index]
	var cost := stocks * meter_tuning.burst_stock_size * _UNIT
	if fighter.burst < cost:
		return false
	fighter.burst -= cost
	return true


## Applies already-scaled damage (display units); attacker -1 means no attacker.
func apply_damage(target_index: int, attacker_index: int, amount: int) -> void:
	var target := fighters[target_index]
	if round_over or amount <= 0 or target.is_knocked_out():
		return
	var dealt := mini(amount * _UNIT, target.health)
	target.health -= dealt
	# Earlier grey health is lost; this hit leaves its own grey part.
	target.grey_health = 0 if target.is_knocked_out() \
		else dealt * meter_tuning.grey_percent / 100
	target.ticks_since_hit = 0
	if target.state == FighterState.State.CHARGING:
		_enter_free_state(target)
	_add_burst(target, dealt * meter_tuning.burst_per_1000_damage_taken / 1000)
	if attacker_index >= 0:
		_add_burst(fighters[attacker_index], dealt * meter_tuning.burst_per_1000_damage_dealt / 1000)
	if target.is_knocked_out():
		_end_round_if_decided()
	elif not target.last_stand_used and target.health * 100 \
			< target.stats.max_health * _UNIT * meter_tuning.last_stand_health_percent:
		target.last_stand_used = true
		_add_burst(target, meter_tuning.last_stand_burst_stocks * meter_tuning.burst_stock_size * _UNIT)


## Removes guard (display units); at 0 the fighter is stunned in GUARD_BROKEN.
func apply_guard_damage(fighter_index: int, amount: int) -> void:
	var fighter := fighters[fighter_index]
	if round_over or amount <= 0:
		return
	fighter.guard = maxi(fighter.guard - amount * _UNIT, 0)
	fighter.ticks_since_block = 0
	if fighter.guard == 0:
		fighter.blocking = false
		fighter.velocity = Vector3.ZERO
		fighter.dash_kind = FighterState.DashKind.NONE
		fighter.dash_direction = Vector3.ZERO
		fighter.enter_state(FighterState.State.GUARD_BROKEN)


## Records that the fighter's current move touched an opponent, which opens
## its cancel window. T-D04 calls it on hit or block; ignored when not attacking.
func register_contact(fighter_index: int, blocked: bool) -> void:
	var fighter := fighters[fighter_index]
	if fighter.state != FighterState.State.ATTACKING or fighter.holding_charge:
		return
	if blocked:
		fighter.contact_blocked = true
	else:
		fighter.contact_hit = true


## True if the current move may be cancelled into a move of this level right
## now: higher level only, inside the cancel window, after contact.
func can_cancel_into(fighter_index: int, level: MoveData.CancelLevel) -> bool:
	var fighter := fighters[fighter_index]
	var move := fighter.move
	if fighter.state != FighterState.State.ATTACKING or fighter.holding_charge \
			or level <= move.cancel_level \
			or fighter.move_tick < move.cancel_start_tick or fighter.move_tick >= move.cancel_end_tick:
		return false
	return (fighter.contact_hit and move.cancel_on_hit) \
		or (fighter.contact_blocked and move.cancel_on_block)


## Uses up a vanish input (both presses). False if there is none.
func consume_vanish_input(fighter_index: int) -> bool:
	if not has_vanish_input(fighter_index):
		return false
	var fighter := fighters[fighter_index]
	fighter.press_ages[_action_index(_DASH)] = INPUT_BUFFER_TICKS
	fighter.press_ages[_action_index(_BLOCK)] = INPUT_BUFFER_TICKS
	fighter.consumed_presses &= ~(_DASH | _BLOCK)
	return true


func _step_fighter(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	_record_presses(fighter, input)
	_update_lock_on(index, input)
	var wish := _wish_direction(input)
	_finish_timed_action(index, input)
	if not round_over:
		_start_buffered_action(index, input, wish)
		_start_attack(index, input, wish)
		_start_charging(index)
	match fighter.state:
		FighterState.State.IDLE, FighterState.State.MOVING:
			_move_on_ground(fighter, input, wish)
		FighterState.State.FALLING:
			_move_falling(fighter, input, wish)
		FighterState.State.FLYING:
			_move_flying(fighter, input, wish)
		FighterState.State.DASHING:
			_move_dashing(index, input, wish)
		FighterState.State.ATTACKING:
			_move_attacking(fighter)
		FighterState.State.VANISHING, FighterState.State.CHARGING, FighterState.State.GUARD_BROKEN:
			fighter.velocity = Vector3.ZERO
	fighter.position += fighter.velocity * TICK_SECONDS
	_clamp_to_arena(fighter)
	_land_if_on_floor(fighter)
	# An attack keeps the facing it started with.
	if fighter.state != FighterState.State.ATTACKING:
		_update_facing(index)
	if not round_over:
		_update_meters(fighter)
	fighter.state_ticks += 1


func _record_presses(fighter: FighterState, input: FighterInput) -> void:
	for index in fighter.press_ages.size():
		var bit := 1 << index
		if (input.pressed_actions & bit) != 0:
			fighter.press_ages[index] = 0
			fighter.consumed_presses &= ~bit
		elif fighter.press_ages[index] < INPUT_BUFFER_TICKS:
			fighter.press_ages[index] += 1
			if fighter.press_ages[index] == INPUT_BUFFER_TICKS:
				fighter.consumed_presses &= ~bit


func _update_lock_on(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	if input.is_pressed(FighterInput.Action.LOCK_TOGGLE):
		fighter.lock_on_target = -1 if fighter.lock_on_target >= 0 else _nearest_opponent(index)
	elif fighter.lock_on_target >= 0 and input.target_switch != 0:
		fighter.lock_on_target = _next_opponent(index, fighter.lock_on_target, input.target_switch)


## Ends dashes, vanishes, charging, guard breaks and attacks that are over, before new actions.
func _finish_timed_action(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	match fighter.state:
		FighterState.State.ATTACKING:
			_advance_attack(index, input)
			return
		FighterState.State.VANISHING:
			if fighter.state_ticks >= tuning.vanish_step_ticks:
				_enter_free_state(fighter)
			return
		FighterState.State.GUARD_BROKEN:
			if fighter.state_ticks >= meter_tuning.guard_break_ticks:
				_enter_free_state(fighter)
			return
		FighterState.State.CHARGING:
			if not input.is_held(_CHARGE) or (input.pressed_actions & ~_CHARGE_SAFE_ACTIONS) != 0:
				_enter_free_state(fighter)
			return
	if fighter.state != FighterState.State.DASHING:
		return
	match fighter.dash_kind:
		FighterState.DashKind.STEP:
			if fighter.state_ticks >= tuning.dash_step_ticks:
				if input.is_held(_DASH):
					fighter.dash_kind = FighterState.DashKind.SUSTAINED
				else:
					_end_dash(fighter)
		FighterState.DashKind.SUSTAINED:
			if not input.is_held(_DASH):
				_end_dash(fighter)
		FighterState.DashKind.RUSH:
			var target := fighter.lock_on_target
			if target < 0 or fighter.state_ticks >= tuning.rush_max_ticks \
					or fighter.position.distance_to(fighters[target].position) \
					<= tuning.rush_stop_distance + _RUSH_ARRIVAL_MARGIN:
				# A rush stops dead in front of the target, ready for a follow-up.
				fighter.velocity = Vector3.ZERO
				_end_dash(fighter)
	# Sustained dashing costs ki every tick; a per-second rate is the per-tick cost in sixtieths.
	if fighter.dash_kind == FighterState.DashKind.SUSTAINED \
			and not _spend_ki_units(fighter, meter_tuning.sustained_dash_ki_per_second):
		_end_dash(fighter)


## Starts a buffered vanish step or dash if affordable; a vanish never falls back to a dash.
func _start_buffered_action(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	var free := _is_free(fighter)
	var can_vanish := free or fighter.state == FighterState.State.DASHING \
		or can_cancel_into(index, MoveData.CancelLevel.VANISH)
	if can_vanish and has_vanish_input(index):
		if _spend_ki(fighter, meter_tuning.vanish_step_ki_cost):
			consume_vanish_input(index)
			_start_vanish(fighter, input, wish)
	elif free and is_buffered(index, _DASH):
		_start_dash(index, input, wish)


## A buffered CHARGE press starts charging on the ground or in flight, not while falling.
func _start_charging(index: int) -> void:
	var fighter := fighters[index]
	if fighter.state == FighterState.State.FALLING or not _is_free(fighter):
		return
	if consume_buffered(index, _CHARGE):
		fighter.velocity = Vector3.ZERO
		fighter.enter_state(FighterState.State.CHARGING)


## Starts a buffered attack from a free state, or a heavy that cancels the current move.
func _start_attack(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	if fighter.state == FighterState.State.ATTACKING:
		if is_buffered(index, _HEAVY) and can_cancel_into(index, MoveData.CancelLevel.HEAVY):
			_begin_heavy(index, input, wish)
		return
	if fighter.state not in _ATTACK_START_STATES:
		return
	if is_buffered(index, _HEAVY):
		_begin_heavy(index, input, wish)
	elif is_buffered(index, _LIGHT):
		_begin_light(index, 1)


## Starts light number (1-based) of the string. False if the fighter lacks the move or its ki.
func _begin_light(index: int, number: int) -> bool:
	var fighter := fighters[index]
	var lights := _move_set(fighter).light_string
	if number > lights.size() or not _spend_ki(fighter, lights[number - 1].ki_cost):
		return false
	consume_buffered(index, _LIGHT)
	_update_facing(index)
	fighter.begin_move(lights[number - 1])
	fighter.string_index = number
	return true


func _begin_heavy(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	var move := _heavy_for(index, input, wish)
	if move == null or not _spend_ki(fighter, move.ki_cost):
		return
	consume_buffered(index, _HEAVY)
	_update_facing(index)
	fighter.begin_move(move)
	if move.can_charge() and input.is_held(_HEAVY):
		fighter.charge_ticks = 1


## Push-block while blocking; else ascend/descend, then direction relative to the target.
func _heavy_for(index: int, input: FighterInput, wish: Vector3) -> MoveData:
	var fighter := fighters[index]
	var moves := _move_set(fighter)
	if fighter.blocking:
		return moves.push_block
	if input.vertical > 0:
		return moves.rising
	if input.vertical < 0:
		return moves.spike
	var planar := Vector3(wish.x, 0.0, wish.z)
	if planar.length() < _HEAVY_DEADZONE:
		return moves.smash
	var along := planar.normalized().dot(_attack_forward(index))
	if along >= _HEAVY_CONE:
		return moves.breaker
	if along <= -_HEAVY_CONE:
		return moves.launcher
	return moves.sweep


## Planar unit direction toward the lock-on target, or the facing when unlocked.
func _attack_forward(index: int) -> Vector3:
	var fighter := fighters[index]
	if fighter.lock_on_target >= 0:
		var to_target := fighters[fighter.lock_on_target].position - fighter.position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	return Basis(Vector3.UP, fighter.facing_yaw) * Vector3.FORWARD


## Moves the attack on by one tick: charge, string, end of the move.
func _advance_attack(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	if fighter.holding_charge:
		_hold_charge(fighter, input)
		return
	fighter.move_tick += 1
	var move := fighter.move
	if fighter.move_tick >= move.total_ticks():
		_enter_free_state(fighter)
		return
	if move.can_charge() and fighter.move_tick < move.startup_ticks:
		# Charge counts only while the button stays held since the press.
		if input.is_held(_HEAVY) and fighter.charge_ticks == fighter.move_tick:
			fighter.charge_ticks += 1
			if fighter.charge_ticks >= move.charge_level_ticks[0]:
				fighter.holding_charge = true
				fighter.move_tick = 0
				_hold_charge(fighter, input, false)
		return
	_advance_string(index)


## Raises the charge level while held; release or the top level performs it.
func _hold_charge(fighter: FighterState, input: FighterInput, count_tick: bool = true) -> void:
	var levels := _move_set(fighter).charged_smash
	if input.is_held(_HEAVY):
		if count_tick:
			fighter.charge_ticks += 1
		var level := 0
		for threshold in fighter.move.charge_level_ticks:
			if fighter.charge_ticks >= threshold:
				level += 1
		fighter.charge_level = mini(level, levels.size())
		if fighter.charge_level < levels.size():
			return
	var reached := fighter.charge_level
	fighter.begin_move(levels[reached - 1])
	fighter.charge_level = reached


## Light string: one press inside the window queues the next hit; any press
## outside it drops the string, and later presses are ignored (no mashing).
func _advance_string(index: int) -> void:
	var fighter := fighters[index]
	var move := fighter.move
	if fighter.string_index == 0 or fighter.string_index >= _move_set(fighter).light_string.size():
		return
	if consume_buffered(index, _LIGHT) and not fighter.string_dropped and not fighter.string_queued:
		var opens := move.string_window_start_tick
		if fighter.move_tick >= opens and fighter.move_tick < opens + move.string_window_ticks:
			fighter.string_queued = true
		else:
			fighter.string_dropped = true
	if fighter.string_queued and fighter.move_tick >= move.recovery_start_tick():
		_begin_light(index, fighter.string_index + 1)


func _start_dash(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	var direction := _steer_direction(fighter, input, wish)
	if direction == Vector3.ZERO:
		direction = _neutral_dash_direction(index, input)
	var rush := _points_at_target(index, direction)
	if not _spend_ki(fighter, meter_tuning.rush_dash_ki_cost if rush else meter_tuning.dash_ki_cost):
		return
	consume_buffered(index, _DASH)
	fighter.dash_kind = FighterState.DashKind.RUSH if rush else FighterState.DashKind.STEP
	fighter.dash_direction = direction
	fighter.enter_state(FighterState.State.DASHING)


func _start_vanish(fighter: FighterState, input: FighterInput, wish: Vector3) -> void:
	var direction := _steer_direction(fighter, input, wish)
	if direction == Vector3.ZERO:
		# Neutral vanish steps straight back from where the fighter faces.
		direction = -(Basis(Vector3.UP, fighter.facing_yaw) * Vector3.FORWARD)
	fighter.position += direction * tuning.vanish_step_distance
	_clamp_to_arena(fighter)
	fighter.velocity = Vector3.ZERO
	fighter.dash_kind = FighterState.DashKind.NONE
	fighter.dash_direction = Vector3.ZERO
	fighter.enter_state(FighterState.State.VANISHING)


func _end_dash(fighter: FighterState) -> void:
	fighter.dash_kind = FighterState.DashKind.NONE
	fighter.dash_direction = Vector3.ZERO
	_enter_free_state(fighter)


## Back to standing on the floor, or flying above it, keeping capped momentum.
func _enter_free_state(fighter: FighterState) -> void:
	if _is_on_floor(fighter):
		fighter.position.y = tuning.ground_height
		fighter.velocity.y = 0.0
		fighter.velocity = fighter.velocity.limit_length(tuning.ground_speed)
		fighter.enter_state(FighterState.State.IDLE)
	else:
		fighter.velocity = fighter.velocity.limit_length(tuning.fly_speed)
		fighter.enter_state(FighterState.State.FLYING)


func _move_on_ground(fighter: FighterState, input: FighterInput, wish: Vector3) -> void:
	if input.vertical > 0:
		# Ascend on the ground jumps straight into flight.
		fighter.velocity.y = tuning.takeoff_speed
		fighter.enter_state(FighterState.State.FLYING)
		return
	var rate := tuning.ground_acceleration if wish != Vector3.ZERO else tuning.ground_deceleration
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z)
	fighter.velocity = planar.move_toward(wish * tuning.ground_speed, rate * TICK_SECONDS)
	fighter.position.y = tuning.ground_height
	var next_state := FighterState.State.IDLE
	if fighter.velocity != Vector3.ZERO:
		next_state = FighterState.State.MOVING
	if fighter.state != next_state:
		fighter.enter_state(next_state)


func _move_falling(fighter: FighterState, input: FighterInput, wish: Vector3) -> void:
	if input.vertical > 0:
		# Ascend while falling takes back control in flight.
		fighter.enter_state(FighterState.State.FLYING)
		_move_flying(fighter, input, wish)
		return
	fighter.velocity.y = maxf(fighter.velocity.y - tuning.gravity * TICK_SECONDS, -tuning.max_fall_speed)


func _move_flying(fighter: FighterState, input: FighterInput, wish: Vector3) -> void:
	var climb := tuning.ascend_speed if input.vertical > 0 else tuning.descend_speed
	var target := wish * tuning.fly_speed + Vector3.UP * (input.vertical * climb)
	var rate := tuning.fly_acceleration if target != Vector3.ZERO else tuning.fly_deceleration
	fighter.velocity = fighter.velocity.move_toward(target, rate * TICK_SECONDS)


func _move_dashing(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	match fighter.dash_kind:
		FighterState.DashKind.STEP:
			var step_speed := tuning.dash_step_distance / (tuning.dash_step_ticks * TICK_SECONDS)
			fighter.velocity = fighter.dash_direction * step_speed
		FighterState.DashKind.SUSTAINED:
			var steer := _steer_direction(fighter, input, wish)
			if steer != Vector3.ZERO:
				fighter.dash_direction = steer
			fighter.velocity = fighter.dash_direction * tuning.sustained_dash_speed
		FighterState.DashKind.RUSH:
			var to_target := fighters[fighter.lock_on_target].position - fighter.position
			if to_target != Vector3.ZERO:
				fighter.dash_direction = to_target.normalized()
			# Never overshoot the stop distance in one tick.
			var room := maxf(to_target.length() - tuning.rush_stop_distance, 0.0)
			fighter.velocity = fighter.dash_direction * minf(tuning.rush_speed, room / TICK_SECONDS)


## Attacks hold position except the move's step, spread over its startup.
func _move_attacking(fighter: FighterState) -> void:
	var move := fighter.move
	fighter.velocity = Vector3.ZERO
	if fighter.holding_charge or fighter.move_tick >= move.startup_ticks:
		return
	var forward := Basis(Vector3.UP, fighter.facing_yaw) * Vector3.FORWARD
	fighter.velocity = forward * (move.step_distance / (move.startup_ticks * TICK_SECONDS))


## Keeps fighters inside the arena box and stops motion into its walls.
func _clamp_to_arena(fighter: FighterState) -> void:
	var half := tuning.arena_half_size
	var low := Vector3(-half, tuning.ground_height, -half)
	var high := Vector3(half, tuning.arena_ceiling, half)
	var clamped := fighter.position.clamp(low, high)
	var velocity := fighter.velocity
	for axis in 3:
		if clamped[axis] != fighter.position[axis]:
			velocity[axis] = 0.0
	fighter.velocity = velocity
	fighter.position = clamped


func _land_if_on_floor(fighter: FighterState) -> void:
	var airborne := fighter.state == FighterState.State.FLYING \
		or fighter.state == FighterState.State.FALLING
	if airborne and _is_on_floor(fighter) and fighter.velocity.y <= 0.0:
		fighter.position.y = tuning.ground_height
		fighter.velocity.y = 0.0
		fighter.enter_state(FighterState.State.IDLE)


## Faces the lock-on target, otherwise the direction of travel.
func _update_facing(index: int) -> void:
	var fighter := fighters[index]
	var look := fighter.velocity
	if fighter.lock_on_target >= 0:
		look = fighters[fighter.lock_on_target].position - fighter.position
	look.y = 0.0
	if look.length_squared() > 0.0001:
		fighter.facing_yaw = atan2(-look.x, -look.z)


## Camera-relative planar direction from the move input; length up to 1.
func _wish_direction(input: FighterInput) -> Vector3:
	var planar := Vector3(input.move.x, 0.0, -input.move.y).limit_length(1.0)
	return Basis(Vector3.UP, input.view_yaw) * planar


## Unit direction from move plus ascend/descend, or zero. Never into the floor.
func _steer_direction(fighter: FighterState, input: FighterInput, wish: Vector3) -> Vector3:
	var direction := wish + Vector3.UP * input.vertical
	if direction.y < 0.0 and _is_on_floor(fighter):
		direction.y = 0.0
	return direction.normalized()


## A dash with no direction goes toward the target, or forward along the view.
func _neutral_dash_direction(index: int, input: FighterInput) -> Vector3:
	var fighter := fighters[index]
	if fighter.lock_on_target >= 0:
		var to_target := fighters[fighter.lock_on_target].position - fighter.position
		if to_target != Vector3.ZERO:
			return to_target.normalized()
	return Basis(Vector3.UP, input.view_yaw) * Vector3.FORWARD


func _points_at_target(index: int, direction: Vector3) -> bool:
	var fighter := fighters[index]
	if fighter.lock_on_target < 0:
		return false
	var to_target := fighters[fighter.lock_on_target].position - fighter.position
	if to_target == Vector3.ZERO:
		return false
	return direction.dot(to_target.normalized()) >= tuning.rush_alignment


func _is_on_floor(fighter: FighterState) -> bool:
	return fighter.position.y <= tuning.ground_height


func _nearest_opponent(index: int) -> int:
	var nearest := -1
	var best := INF
	for other in fighters.size():
		if other == index:
			continue
		var distance := fighters[index].position.distance_squared_to(fighters[other].position)
		if distance < best:
			best = distance
			nearest = other
	return nearest


func _next_opponent(index: int, current: int, step: int) -> int:
	var candidate := current
	for _i in fighters.size():
		candidate = posmod(candidate + step, fighters.size())
		if candidate != index:
			return candidate
	return current


## Passive ki or charging, grey health and guard regeneration, once per tick.
func _update_meters(fighter: FighterState) -> void:
	var ki_rate := meter_tuning.ki_passive_per_second
	if fighter.state == FighterState.State.CHARGING:
		ki_rate = meter_tuning.ki_charge_per_second
	_add_ki(fighter, ki_rate)
	if fighter.ticks_since_hit >= meter_tuning.grey_regen_delay_ticks:
		var regen := mini(meter_tuning.grey_regen_per_second, fighter.grey_health)
		fighter.health += regen
		fighter.grey_health -= regen
	else:
		fighter.ticks_since_hit += 1
	if fighter.blocking:
		fighter.ticks_since_block = 0
	elif fighter.ticks_since_block >= meter_tuning.guard_regen_delay_ticks:
		fighter.guard = mini(fighter.guard + meter_tuning.guard_regen_per_second,
			fighter.stats.guard_max * _UNIT)
	else:
		fighter.ticks_since_block += 1


func _reset_round_meters(fighter: FighterState) -> void:
	fighter.health = fighter.stats.max_health * _UNIT
	fighter.grey_health = 0
	fighter.ki = meter_tuning.round_start_ki * _UNIT
	fighter.guard = fighter.stats.guard_max * _UNIT
	fighter.ticks_since_hit = 0
	fighter.ticks_since_block = 0
	fighter.blocking = false


## The round ends when at most one fighter is still standing.
func _end_round_if_decided() -> void:
	var standing: Array[int] = []
	for index in fighters.size():
		if not fighters[index].is_knocked_out():
			standing.append(index)
	if standing.size() <= 1:
		round_over = true
		round_winner = standing[0] if standing.size() == 1 else -1


## Spends cost ki in display units. False, spending nothing, if there is too little.
func _spend_ki(fighter: FighterState, cost: int) -> bool:
	return _spend_ki_units(fighter, cost * _UNIT)


func _spend_ki_units(fighter: FighterState, units: int) -> bool:
	if fighter.ki < units:
		return false
	fighter.ki -= units
	return true


func _add_ki(fighter: FighterState, units: int) -> void:
	fighter.ki = mini(fighter.ki + units, meter_tuning.ki_max * _UNIT)


func _add_burst(fighter: FighterState, units: int) -> void:
	var cap := meter_tuning.burst_max_stocks * meter_tuning.burst_stock_size * _UNIT
	fighter.burst = mini(fighter.burst + units, cap)


func _move_set(fighter: FighterState) -> MoveSet:
	if fighter.stats.move_set:
		return fighter.stats.move_set
	return (DEFAULT_FIGHTER_STATS as FighterStats).move_set


## Standing, moving, falling or flying: able to start a new action.
func _is_free(fighter: FighterState) -> bool:
	return fighter.state in [
		FighterState.State.IDLE, FighterState.State.MOVING,
		FighterState.State.FALLING, FighterState.State.FLYING,
	]


static func _action_index(action: int) -> int:
	for index in 32:
		if (1 << index) == action:
			return index
	assert(false, "action must be a single FighterInput.Action bit")
	return -1
