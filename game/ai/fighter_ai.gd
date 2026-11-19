class_name FighterAI
extends RefCounted
## A computer opponent that plays through FighterInput like a human: it sees
## actions late (AIPerception, reaction time by level), scores neutral options
## (approach, space, bait, pressure, grab, charge, chase, weapons), guards and
## perfect-blocks what it sees coming, punishes whiffs, techs grabs, runs combo
## routes from the real move set and escapes pressure. It reads the sim but
## never writes it, and only its own seeded rng decides, so the same sim seed,
## slot and inputs always give the same AI inputs (replays, rollback).

## Neutral plans.
enum Plan { WAIT, APPROACH, SPACE, BAIT, PRESSURE, GRAB, CHARGE, CHASE, PICKUP, ZONE }
## Combo enders, in order of skill: light 4, breaker, launcher, launcher + vanish + air string, + spike.
enum Route { LIGHTS, BREAKER, LAUNCHER, AIR, SPIKE }

const _A := FighterInput.Action
const _S := FighterState.State
const _PHASE := FighterState.AttackPhase
## Planar room kept to the arena walls before steering back toward the centre.
const WALL_MARGIN := 20.0
## Goes for weapons within this distance.
const PICKUP_RANGE := 90.0
## Ticks between target choices in free-for-all.
const TARGET_TICKS := 30
## Hits on this AI within this many ticks make the hitter "who attacks it".
const GRUDGE_TICKS := 240
## Ki a vanish needs (MeterTuning.vanish_step_ki_cost), kept here so the AI never asks the sim.
const _VANISH_KI := 20
const _RUSH_KI := 15
## Preferred distance band for ranged weapons: [near, far].
const RANGED_BAND := {
	Weapon.Kind.KI_BOW: Vector2(10, 24), Weapon.Kind.ARC_REVOLVER: Vector2(7, 18),
	Weapon.Kind.STORM_REPEATER: Vector2(6, 16), Weapon.Kind.SCATTER_CANNON: Vector2(2.5, 7),
	Weapon.Kind.HEARTSTRING_BOW: Vector2(8, 20),
}

static var _reach_cache := {}

var fighter_index: int
var profile: AIProfile
var rng := RandomNumberGenerator.new()
var perception := AIPerception.new()
## Team of each fighter slot; same team = never a target. Empty: everyone is an opponent.
var teams := PackedInt32Array()

# Decision state (all covered by snapshot()).
var _previous := FighterInput.new()
var _ticks: int = 0
var _plan: Plan = Plan.APPROACH
var _plan_left: int = 0
var _plan_phase: int = 0
var _strafe: float = 1.0
var _target: int = -1
var _route: Route = Route.LIGHTS
var _string_goal: int = 3
var _air_combo: bool = false
## Move instance (opponent * 2^20 + start tick) the guard/punish rolls were made for.
var _guard_key: int = -1
var _guard_roll: int = 0 # 0 no guard, 1 guard, 2 perfect block
var _punish_key: int = -1
var _punish_until: int = -1
var _link_key: int = -1
var _link_ok: bool = false
var _defend_left: int = 0
var _escape_left: int = 0
var _tech_tick: int = -1
var _hold_left: int = 0
var _hold_move := Vector2.ZERO
var _hold_vertical: int = 0
var _last_state: int = 0
var _grudge: int = -1
var _grudge_tick: int = -1000000
var _push_rolled: bool = false
## Set by _threat_ticks: a seen attack is coming but out of reach, so back off.
var _step_out: bool = false
var _edge_gap: float = INF
## Perfect blocks in a row; Normal and below stop at 2 (fun limiter, GAME_DESIGN §10).
var _perfect_streak: int = 0


## seed_value should come from seed_for(sim seed, slot).
func _init(index: int, level: int = 3, seed_value: int = 0) -> void:
	fighter_index = index
	rng.seed = seed_value
	profile = AIProfile.for_level(level, rng)


## The rng seed of the AI in slot for a match with sim_seed.
static func seed_for(sim_seed: int, slot: int) -> int:
	return hash([sim_seed, slot, "skybreak-ai"])


## This tick's input. Call exactly once per sim tick, before sim.tick().
func next_input(sim: CombatSim) -> FighterInput:
	perception.record(sim)
	_ticks += 1
	var plan := FighterInput.new()
	var me := sim.fighters[fighter_index]
	_note_hits(sim)
	if not sim.round_over and not me.is_knocked_out() and sim.fighters.size() > 1:
		_target = _choose_target(sim)
		if _target >= 0:
			_decide(sim, me, plan)
	_last_state = me.state
	var input := FighterInput.from_held(plan.held_actions, _previous)
	input.move = plan.move.limit_length(1.0)
	input.vertical = plan.vertical
	input.view_yaw = plan.view_yaw
	input.target_switch = plan.target_switch
	_previous = input
	return input


## Decision state, for rollback: restore() on a fresh or rewound AI continues identically.
func snapshot() -> Dictionary:
	return {
		"rng": rng.state, "perception": perception.snapshot(), "previous": _input_values(_previous),
		"values": [_ticks, _plan, _plan_left, _plan_phase, _strafe, _target, _route, _string_goal,
			_air_combo, _guard_key, _guard_roll, _punish_key, _punish_until, _link_key, _link_ok,
			_defend_left, _escape_left, _tech_tick, _hold_left, _hold_move, _hold_vertical,
			_last_state, _grudge, _grudge_tick, _push_rolled, _step_out, _edge_gap, _perfect_streak],
	}


func restore(saved: Dictionary) -> void:
	rng.state = saved.rng
	perception.restore(saved.perception)
	var p: Array = saved.previous
	_previous = FighterInput.new()
	_previous.held_actions = p[0]
	_previous.pressed_actions = p[1]
	_previous.released_actions = p[2]
	_previous.move = p[3]
	_previous.vertical = p[4]
	_previous.view_yaw = p[5]
	_previous.target_switch = p[6]
	var v: Array = saved.values
	_ticks = v[0]; _plan = v[1]; _plan_left = v[2]; _plan_phase = v[3]; _strafe = v[4]
	_target = v[5]; _route = v[6]; _string_goal = v[7]; _air_combo = v[8]; _guard_key = v[9]
	_guard_roll = v[10]; _punish_key = v[11]; _punish_until = v[12]; _link_key = v[13]
	_link_ok = v[14]; _defend_left = v[15]; _escape_left = v[16]; _tech_tick = v[17]
	_hold_left = v[18]; _hold_move = v[19]; _hold_vertical = v[20]; _last_state = v[21]
	_grudge = v[22]; _grudge_tick = v[23]; _push_rolled = v[24]; _step_out = v[25]
	_edge_gap = v[26]; _perfect_streak = v[27]


## How far a move's hitboxes reach from the attacker's centre to a target's centre (planar).
static func move_reach(move: MoveData, hurtbox_radius: float = 0.5) -> float:
	if move == null:
		return 0.0
	if _reach_cache.has(move):
		return _reach_cache[move] + hurtbox_radius
	var reach := 0.0
	for i in move.hitbox_offsets.size():
		var offset := move.hitbox_offsets[i]
		var radius := move.hitbox_radii[mini(i, move.hitbox_radii.size() - 1)]
		var length := 0.0
		if not move.hitbox_lengths.is_empty():
			length = move.hitbox_lengths[mini(i, move.hitbox_lengths.size() - 1)]
		reach = maxf(reach, Vector2(offset.x, offset.z).length() + radius + length * 0.5)
	reach += maxf(move.step_distance, 0.0)
	_reach_cache[move] = reach
	return reach + hurtbox_radius


func _decide(sim: CombatSim, me: FighterState, plan: FighterInput) -> void:
	var target := sim.fighters[_target]
	var to_target := target.position - me.position
	plan.view_yaw = atan2(-to_target.x, -to_target.z)
	var picking := _plan == Plan.PICKUP and _is_free(me)
	if not picking:
		if me.lock_on_target < 0:
			_tap(plan, _A.LOCK_TOGGLE)
		elif me.lock_on_target != _target:
			plan.target_switch = 1
	var distance := to_target.length()
	match me.state:
		_S.GRABBED:
			_tech(me, plan)
			return
		_S.HITSTUN, _S.KNOCKDOWN, _S.GUARD_BROKEN, _S.THROWING, _S.VANISHING:
			_tech_tick = -1
			return
		_S.ATTACKING:
			_continue_attack(sim, me, target, plan)
			return
		_S.BLOCKING, _S.BLOCKSTUN:
			_keep_guard(sim, me, target, distance, plan)
			return
		_S.DASHING:
			if me.dash_kind == FighterState.DashKind.SUSTAINED:
				plan.held_actions |= _A.DASH
				plan.move = Vector2(0, 1)
			return
		_S.CHARGING:
			if me.ki < 85 * FighterState.METER_UNIT and distance > 9.0 and _plan == Plan.CHARGE:
				plan.held_actions |= _A.CHARGE
			return
	_act_free(sim, me, target, distance, plan)


# Defence.

## Holds the guard while pressure continues; escapes with a push-block now and then.
func _keep_guard(sim: CombatSim, me: FighterState, target: FighterState, distance: float,
		plan: FighterInput) -> void:
	if me.state == _S.BLOCKSTUN and not me.blocking:
		return # A push, not a guard.
	var threat := _threat_ticks(sim, me)
	if threat >= 1 and threat <= 5 and _guard_roll == 2 and me.state == _S.BLOCKING \
			and me.perfect_block_lockout == 0 and not me.perfect_block_armed:
		_defend_left = 8
		return # Let go for one tick: the fresh press next tick is a perfect block.
	var pressured := threat < 99 or (distance < 3.6 and target.state == _S.ATTACKING)
	# A seen attack already in recovery is no pressure: let go to punish it.
	if pressured and _seen_whiff(distance):
		pressured = threat < 99
	if not pressured and _defend_left <= 0:
		_push_rolled = false
		return
	_defend_left -= 1
	plan.held_actions |= _A.BLOCK
	var low_guard := me.guard < me.stats.guard_max * FighterState.METER_UNIT * 45 / 100
	if me.state == _S.BLOCKSTUN and not _push_rolled and distance < 3.6:
		_push_rolled = true
		if rng.randf() < profile.escape_chance * (1.6 if low_guard else 0.7):
			_tap(plan, _A.HEAVY)
	if me.state == _S.BLOCKING and target.state == _S.BLOCKING and distance < 2.0 \
			and rng.randf() < profile.grab_guard_chance * 0.2:
		plan.held_actions &= ~_A.BLOCK # Let go to grab next.


## Ticks until the soonest seen attack that will reach this AI turns active, or 99 for none.
## Rolls once per seen move whether to guard it (and whether perfectly).
func _threat_ticks(sim: CombatSim, me: FighterState) -> int:
	var delay := perception.look(profile.reaction_ticks)
	var soonest := 99
	_step_out = false
	_edge_gap = INF
	for j in sim.fighters.size():
		if j == fighter_index or _same_team(j) or perception.state(j) != _S.ATTACKING:
			continue
		var move := perception.move(j)
		if move == null or move.kind != MoveData.Kind.STRIKE or move.hitbox_offsets.is_empty():
			continue
		var attacker := sim.fighters[j]
		var now_tick := perception.move_tick(j) + delay
		var until_active := move.startup_ticks - now_tick
		if perception.holding_charge(j):
			until_active = 4
		if until_active + move.active_ticks <= 0:
			continue
		var to_me := me.position - attacker.position
		var reach := move_reach(move, me.stats.hurtbox_radius)
		if to_me.length() > reach + 3.0:
			continue
		var facing := Basis(Vector3.UP, attacker.facing_yaw) * Vector3.FORWARD
		if Vector2(to_me.x, to_me.z).normalized().dot(Vector2(facing.x, facing.z)) < 0.2:
			continue
		var key := j * 1048576 + (_ticks - delay - perception.move_tick(j))
		if key != _guard_key:
			_guard_key = key
			_guard_roll = 0
			if rng.randf() < profile.block_chance:
				_guard_roll = 2 if rng.randf() < profile.perfect_block_chance else 1
				if _guard_roll == 2 and profile.level <= 2 and _perfect_streak >= 2:
					_guard_roll = 1
		if _guard_roll == 0:
			continue
		if to_me.length() > reach + 0.4:
			# Out of its reach: stay at the edge and let it whiff.
			_step_out = true
			_edge_gap = minf(_edge_gap, to_me.length() - reach)
		# Seen too late for a plain guard: only a planned perfect block still tries.
		elif _guard_roll == 2 or until_active > 3:
			soonest = mini(soonest, maxi(until_active, 0))
	return soonest


## Raises the guard against a seen attack; a planned perfect block waits for the window.
func _guard(me: FighterState, until_active: int, plan: FighterInput) -> bool:
	var window := 5
	if _guard_roll == 2 and me.perfect_block_lockout == 0:
		if until_active > window:
			return true # Waiting for the window: stand still, do not start anything.
		if (_previous.held_actions & _A.BLOCK) != 0 and until_active > 0:
			return true # Let go for a fresh press.
	plan.held_actions |= _A.BLOCK
	_defend_left = 8
	return true


## Ticks until the soonest projectile flying at this AI arrives, or 99; guarding it (a fresh press
## perfect-blocks and reflects).
func _projectile_ticks(sim: CombatSim, me: FighterState) -> int:
	var soonest := 99
	for projectile in sim.projectiles:
		if projectile.owner == fighter_index or _same_team(projectile.owner):
			continue
		var offset := me.position - projectile.position
		var speed := projectile.velocity.length()
		if speed < 1.0 or offset.length() > 30.0:
			continue
		if offset.normalized().dot(projectile.velocity / speed) < 0.95:
			continue
		soonest = mini(soonest, int(offset.length() / speed * CombatSim.TICKS_PER_SECOND))
	return soonest


func _tech(me: FighterState, plan: FighterInput) -> void:
	if me.state_ticks == 0 or _tech_tick < 0:
		var success := rng.randf() < profile.tech_chance
		_tech_tick = rng.randi_range(2, 8) if success else rng.randi_range(12, 20)
	if me.state_ticks == _tech_tick:
		_tap(plan, _A.GRAB)


# Attacking.

## Strings, hit confirms, cancels into the route's ender, and the vanish follow-up.
func _continue_attack(sim: CombatSim, me: FighterState, target: FighterState,
		plan: FighterInput) -> void:
	var move := me.move
	if _hold_left > 0:
		_hold_left -= 1
		plan.move = _hold_move
		plan.vertical = _hold_vertical
	if move == null:
		return
	var moves := _moves(me)
	if me.string_index > 0 and me.string_index < moves.light_string.size() \
			and not WeaponMoves.is_shot(move):
		var opens := move.string_window_start_tick
		var in_window := me.move_tick >= opens and me.move_tick < opens + move.string_window_ticks - 1
		var confirmed := not profile.hit_confirm or me.move_tick >= move.startup_ticks + 1
		var key := me.string_index * 4096 + _ticks - me.move_tick
		if in_window and confirmed and not me.string_queued and key != _link_key:
			_link_key = key
			_link_ok = me.string_index < _string_goal and rng.randf() >= profile.drop_chance
			if profile.hit_confirm and not me.contact_hit:
				# Blocked: stop after two and look for a grab or a reset; whiffed: stop.
				_link_ok = _link_ok and me.contact_blocked and me.string_index < 2
				if me.contact_blocked and me.string_index >= 2 and rng.randf() < profile.mixup:
					_plan = Plan.GRAB
					_plan_left = 30
			if _link_ok:
				_tap(plan, _A.LIGHT)
	if not me.contact_hit:
		return
	# Ender: heavy cancel at the end of the string.
	if me.string_index >= mini(_string_goal, moves.light_string.size()) \
			and sim.can_cancel_into(fighter_index, MoveData.CancelLevel.HEAVY) and _hold_left == 0:
		var ender_move := Vector2.ZERO
		var ender_vertical := 0
		match _route:
			Route.LIGHTS:
				return
			Route.BREAKER:
				ender_move = Vector2(0, 1)
			Route.LAUNCHER, Route.AIR:
				ender_move = Vector2(0, -1)
			Route.SPIKE:
				if _air_combo:
					ender_vertical = -1
				else:
					ender_move = Vector2(0, -1)
		if rng.randf() < profile.drop_chance * 0.5:
			_hold_left = 6 # Dropped: no ender.
			_hold_move = Vector2.ZERO
			_hold_vertical = 0
			return
		_tap(plan, _A.HEAVY)
		_hold_left = 6
		_hold_move = ender_move
		_hold_vertical = ender_vertical
		plan.move = ender_move
		plan.vertical = ender_vertical
		return
	# Launcher hit: vanish along with the target and follow it up in the air.
	if move == moves.launcher and _route >= Route.AIR and me.ki >= _VANISH_KI * FighterState.METER_UNIT \
			and sim.can_cancel_into(fighter_index, MoveData.CancelLevel.VANISH) \
			and target.state == _S.HITSTUN:
		plan.held_actions |= _A.DASH | _A.BLOCK
		plan.move = Vector2.ZERO
		plan.vertical = 0
		_hold_left = 0
		_air_combo = true


## Starts a light string toward the route (and a fresh goal), aimed at the target.
func _start_string(plan: FighterInput, goal: int) -> void:
	_string_goal = goal
	_route = mini(profile.route_skill, Route.SPIKE) as Route
	if _route == Route.LIGHTS:
		_string_goal = 4
	_tap(plan, _A.LIGHT)


func _start_heavy(plan: FighterInput, direction: Vector2, vertical: int = 0) -> void:
	_tap(plan, _A.HEAVY)
	plan.move = direction
	plan.vertical = vertical
	_hold_left = 6
	_hold_move = direction
	_hold_vertical = vertical


# Free states.

func _act_free(sim: CombatSim, me: FighterState, target: FighterState, distance: float,
		plan: FighterInput) -> void:
	_hold_left = 0
	var moves := _moves(me)
	var light_reach := move_reach(moves.light_string[0], target.stats.hurtbox_radius) \
		if not moves.light_string.is_empty() else 2.0
	if Weapon.is_ranged(me.held_weapon()):
		light_reach = 2.0
	# Air follow-up after the launcher vanish.
	if _air_combo:
		if target.state != _S.HITSTUN or distance > 6.0:
			_air_combo = false
		else:
			_match_height(me, target, plan)
			if distance <= light_reach - 0.1 and _may_attack(me):
				_start_string(plan, 3)
				_route = Route.SPIKE if profile.route_skill >= Route.SPIKE else Route.LIGHTS
				_string_goal = 3 if _route == Route.SPIKE else 4
			else:
				plan.move = Vector2(0, 1)
			return
	# Coming out of a beating: get out (vanish away) or guard.
	if _last_state == _S.HITSTUN or _last_state == _S.KNOCKDOWN:
		if distance < 4.5 and rng.randf() < profile.escape_chance:
			if profile.level >= 3 and me.ki >= _VANISH_KI * FighterState.METER_UNIT and rng.randf() < 0.5:
				plan.held_actions |= _A.DASH | _A.BLOCK
				plan.move = Vector2(0, -1)
				return
			_escape_left = 20
	if _escape_left > 0:
		_escape_left -= 1
		plan.held_actions |= _A.BLOCK
		return
	# Seen attacks and shots.
	var threat := _threat_ticks(sim, me)
	if threat < 99 and _guard(me, threat, plan):
		return
	if _step_out:
		_match_height(me, target, plan)
		plan.move = Vector2(0, -1) if _edge_gap < 0.8 else Vector2.ZERO
		return
	var shot := _projectile_ticks(sim, me)
	if shot <= 14:
		plan.held_actions |= _A.BLOCK
		return
	if _defend_left > 0:
		_defend_left -= 1
		plan.held_actions |= _A.BLOCK
		return
	# Whiff punish.
	if _punish(sim, me, target, distance, light_reach, plan):
		return
	_neutral(sim, me, target, distance, light_reach, plan)


## Punishes the target's seen whiff (or a move left open by a perfect block).
func _punish(sim: CombatSim, me: FighterState, target: FighterState, distance: float,
		light_reach: float, plan: FighterInput) -> bool:
	var delay := perception.look(profile.reaction_ticks)
	if perception.state(_target) == _S.ATTACKING:
		var move := perception.move(_target)
		if move != null and not WeaponMoves.is_shot(move) and move.kind != MoveData.Kind.PUSH_BLOCK:
			var seen_tick := perception.move_tick(_target)
			var now_tick := seen_tick + delay
			var open := perception.extra_recovery(_target) > 0 or not perception.made_contact(_target)
			if open and _seen_whiff(distance) and not perception.holding_charge(_target):
				var key := _target * 1048576 + (_ticks - delay - seen_tick)
				if key != _punish_key:
					_punish_key = key
					_punish_until = -1
					if rng.randf() < profile.punish_chance:
						var left := move.total_ticks() + perception.extra_recovery(_target) - now_tick
						_punish_until = _ticks + maxi(left, 0) + 2
	if _punish_until < _ticks or target.state != _S.ATTACKING:
		_punish_until = -1
		return false
	var moves := _moves(me)
	_match_height(me, target, plan)
	if not _may_attack(me):
		plan.move = Vector2(0, 1)
		return true
	var left_ticks := _punish_until - _ticks
	var launcher_reach := move_reach(moves.launcher, target.stats.hurtbox_radius)
	var breaker_reach := move_reach(moves.breaker, target.stats.hurtbox_radius)
	if profile.route_skill >= Route.LAUNCHER and distance <= launcher_reach - 0.15 \
			and moves.launcher and left_ticks > moves.launcher.startup_ticks + 1 and me.is_grounded() == target.is_grounded():
		_route = mini(profile.route_skill, Route.SPIKE) as Route
		_string_goal = 1
		_start_heavy(plan, Vector2(0, -1))
	elif distance <= light_reach - 0.1:
		_start_string(plan, 3)
	elif distance <= breaker_reach - 0.2 and moves.breaker \
			and left_ticks > moves.breaker.startup_ticks + 1:
		_start_heavy(plan, Vector2(0, 1))
	elif distance > 5.0 and me.ki >= _RUSH_KI * FighterState.METER_UNIT and _is_free(me):
		_tap(plan, _A.DASH)
		plan.move = Vector2(0, 1)
	else:
		plan.move = Vector2(0, 1)
	return true


## True when the target's seen move is past its active part, or active but out of reach (its step done).
## Call after perception.look().
func _seen_whiff(distance: float) -> bool:
	if perception.state(_target) != _S.ATTACKING:
		return false
	var move := perception.move(_target)
	if move == null:
		return false
	var seen_tick := perception.move_tick(_target)
	if seen_tick >= move.recovery_start_tick():
		return true
	var reach := move_reach(move) - maxf(move.step_distance, 0.0)
	return seen_tick >= move.startup_ticks and distance > reach + 0.2


func _neutral(sim: CombatSim, me: FighterState, target: FighterState, distance: float,
		light_reach: float, plan: FighterInput) -> void:
	_plan_left -= 1
	if _plan_left <= 0 or (_plan == Plan.PICKUP and _pickup_goal(sim, me, distance) < 0):
		_choose_plan(sim, me, target, distance)
	_weapon_upkeep(me, distance, plan)
	if plan.held_actions != 0:
		return
	if _plan != Plan.PICKUP:
		_match_height(me, target, plan)
	var wall := _wall_strafe(sim, me, target)
	if wall != 0.0:
		_strafe = wall
	var seen_guard := perception.guarding(_target)
	if distance < 3.4 and perception.state(_target) != _S.ATTACKING \
			and rng.randf() < profile.guard_habit * 0.06:
		_defend_left = rng.randi_range(8, 20)
		plan.held_actions |= _A.BLOCK
		return
	match _plan:
		Plan.WAIT:
			plan.move = Vector2.ZERO
		Plan.APPROACH:
			plan.move = Vector2(_strafe * 0.25, 1)
			if distance <= profile.spacing + 0.5:
				_plan_left = 0
		Plan.CHASE:
			plan.move = Vector2(0, 1)
			if distance > 14.0 and me.ki >= (_RUSH_KI + 10) * FighterState.METER_UNIT:
				_tap(plan, _A.DASH)
				_plan_left = mini(_plan_left, 12)
			elif distance <= profile.spacing + 1.0:
				_plan_left = 0
		Plan.SPACE:
			if distance > profile.spacing + 0.6:
				plan.move = Vector2(_strafe * 0.4, 1)
			elif distance < profile.spacing - 0.6:
				plan.move = Vector2(_strafe * 0.4, -1)
			else:
				plan.move = Vector2(_strafe, 0)
			if distance < light_reach - 0.2 and rng.randf() < profile.attack_rate * 0.5 and _may_attack(me):
				_start_string(plan, 3)
		Plan.BAIT:
			# Step into their range, then out, to draw a whiff to punish.
			_plan_phase += 1
			var inside := (_plan_phase / 14) % 2 == 0
			plan.move = Vector2(_strafe * 0.3, 1 if inside and distance > light_reach + 0.4 else -1)
			if not inside and distance > profile.spacing + 1.5:
				plan.move = Vector2(_strafe, 0)
		Plan.PRESSURE:
			if distance > light_reach - 0.15:
				plan.move = Vector2(_strafe * 0.15, 1)
				var breaker := _moves(me).breaker
				if breaker and distance < move_reach(breaker) - 0.3 and distance > light_reach + 0.4 \
						and _may_attack(me) and rng.randf() < 0.04 + profile.mixup * 0.05:
					_start_heavy(plan, Vector2(0, 1))
			elif _may_attack(me) and rng.randf() < profile.attack_rate:
				if seen_guard and rng.randf() < profile.grab_guard_chance:
					_tap(plan, _A.GRAB)
				elif rng.randf() < profile.mixup * 0.15:
					_plan = Plan.BAIT # A delay or a step back: a mix-up.
					_plan_left = 20
					_plan_phase = 14
				elif target.is_grounded() == me.is_grounded() and rng.randf() < profile.mixup * 0.12:
					_start_heavy(plan, Vector2(1 if _strafe > 0 else -1, 0)) # Sweep.
				else:
					_start_string(plan, 3)
		Plan.GRAB:
			if distance > 1.9:
				plan.move = Vector2(0, 1)
			elif _may_attack(me):
				_tap(plan, _A.GRAB)
				_plan_left = 0
		Plan.CHARGE:
			if distance < 10.0 or me.ki >= 85 * FighterState.METER_UNIT:
				_plan_left = 0
			else:
				plan.held_actions |= _A.CHARGE
		Plan.PICKUP:
			_go_for_pickup(sim, me, distance, plan)
		Plan.ZONE:
			_zone(me, distance, plan)


## Utility scores for every neutral plan, plus a little level-scaled noise.
func _choose_plan(sim: CombatSim, me: FighterState, target: FighterState, distance: float) -> void:
	var p := profile
	var unit := FighterState.METER_UNIT
	var lead := float(me.health - target.health) / float(me.stats.max_health * unit)
	var noise := 0.12 + 0.3 * float(AIProfile.MAX_LEVEL - p.level) / 4.0
	var scores := PackedFloat32Array()
	scores.resize(Plan.size())
	scores[Plan.WAIT] = p.idle_chance * 1.4
	scores[Plan.APPROACH] = 0.45 + minf(distance, 30.0) * 0.02 if distance > p.spacing + 1.0 else 0.0
	scores[Plan.CHASE] = 0.5 + p.aggression * 0.6 if distance > 16.0 else 0.0
	scores[Plan.SPACE] = (0.35 + (1.0 - p.aggression) * 0.5 + maxf(lead, 0.0)) if distance < 9.0 else 0.0
	scores[Plan.BAIT] = p.mixup * 0.8 if distance < 7.0 and p.level >= 3 else 0.0
	scores[Plan.PRESSURE] = (p.aggression + 0.25 - minf(lead, 0.0) * 0.5) if distance < p.spacing + 2.0 else 0.0
	scores[Plan.GRAB] = (p.grab_guard_chance * 1.4 if perception.guarding(_target) else p.mixup * 0.15) \
		if distance < 3.5 else 0.0
	scores[Plan.CHARGE] = 0.8 if distance > 16.0 and me.ki < 45 * unit else 0.0
	if _pickup_goal(sim, me, distance) >= 0:
		scores[Plan.PICKUP] = p.weapon_interest * (0.7 + (0.4 if distance > 8.0 else 0.0))
	if Weapon.is_ranged(me.held_weapon()) and distance > 3.0:
		scores[Plan.ZONE] = 1.0 + 0.4 * p.zoning
	var best := 0
	var best_score := -1.0
	for i in scores.size():
		if scores[i] <= 0.0:
			continue
		var score := scores[i] + rng.randf() * noise
		if score > best_score:
			best = i
			best_score = score
	_plan = best as Plan
	_plan_left = p.plan_ticks + rng.randi_range(0, p.plan_ticks / 2)
	_plan_phase = 0
	if rng.randf() < 0.35:
		_strafe = -_strafe


# Weapons.

## Index of the pickup worth going for, or -1.
func _pickup_goal(sim: CombatSim, me: FighterState, distance: float) -> int:
	if sim.pickups.is_empty() or (me.weapon_count() >= 2 and me.held_weapon() != Weapon.Kind.NONE):
		return -1
	if me.held_weapon() != Weapon.Kind.NONE and distance < 5.0:
		return -1
	var best := -1
	var best_distance := PICKUP_RANGE
	for i in sim.pickups.size():
		var pickup := sim.pickups[i]
		if not pickup.can_be_picked_up():
			continue
		var d := me.position.distance_to(pickup.position)
		if d < best_distance:
			best = i
			best_distance = d
	return best


func _go_for_pickup(sim: CombatSim, me: FighterState, distance: float, plan: FighterInput) -> void:
	var goal := _pickup_goal(sim, me, distance)
	if goal < 0:
		_plan_left = 0
		return
	if me.lock_on_target >= 0:
		_tap(plan, _A.LOCK_TOGGLE)
	var pickup := sim.pickups[goal]
	var to_pickup := pickup.position - me.position
	plan.view_yaw = atan2(-to_pickup.x, -to_pickup.z)
	plan.move = Vector2(0, 1) if Vector2(to_pickup.x, to_pickup.z).length() > 0.6 else Vector2.ZERO
	if to_pickup.y > 0.8:
		plan.vertical = 1
	elif to_pickup.y < -0.8:
		plan.vertical = -1
	if to_pickup.length() < sim.pickup_tuning.pickup_reach - 0.4:
		_tap(plan, _A.PICKUP)
		_plan_left = 0
	_plan_left = maxi(_plan_left, 2)


## Picks the weapon for the range, and throws one that is spent or worth throwing.
func _weapon_upkeep(me: FighterState, distance: float, plan: FighterInput) -> void:
	if me.weapon_count() == 0 or not _is_free(me) or me.switch_lockout > 0:
		return
	var held := me.held_weapon()
	var want_ranged := distance > 7.0 * profile.zoning
	var has_ranged := false
	var has_melee := false
	for slot in me.weapons.size():
		var kind := me.weapons[slot] as Weapon.Kind
		if Weapon.is_ranged(kind) and me.ammo[slot] > 0:
			has_ranged = true
		elif Weapon.is_melee(kind):
			has_melee = true
	if held != Weapon.Kind.NONE and Weapon.is_ranged(held) and me.ammo[me.active_slot] <= 0:
		_tap(plan, _A.THROW)
		return
	var switch := (want_ranged and has_ranged and not Weapon.is_ranged(held)) \
		or (not want_ranged and distance < 4.0 and Weapon.is_ranged(held))
	if switch and rng.randf() < 0.2:
		_tap(plan, _A.WEAPON_NEXT)
		return
	if held != Weapon.Kind.NONE and Weapon.is_melee(held) and distance > 6.0 and distance < 14.0 \
			and rng.randf() < 0.004 * profile.level and (has_melee or has_ranged):
		_tap(plan, _A.THROW)


func _zone(me: FighterState, distance: float, plan: FighterInput) -> void:
	var held := me.held_weapon()
	if not RANGED_BAND.has(held):
		_plan_left = 0
		return
	var band: Vector2 = RANGED_BAND[held]
	if distance > band.y:
		plan.move = Vector2(_strafe * 0.3, 1)
	elif distance < band.x:
		plan.move = Vector2(_strafe * 0.5, -1)
	else:
		plan.move = Vector2(_strafe, 0)
	if distance <= band.y * 1.2 and _may_attack(me) and me.reload_ticks == 0:
		if held == Weapon.Kind.STORM_REPEATER:
			plan.held_actions |= _A.LIGHT
		elif rng.randf() < 0.15 + 0.05 * profile.level:
			_tap(plan, _A.LIGHT)


# Targets, movement, small helpers.

## Free-for-all: nearest, weakest, or whoever has been hitting this AI.
func _choose_target(sim: CombatSim) -> int:
	var current := _target
	if current >= 0 and current < sim.fighters.size() and not sim.fighters[current].is_knocked_out() \
			and _ticks % TARGET_TICKS != 1:
		return current
	var me := sim.fighters[fighter_index]
	var best := -1
	var best_score := -INF
	for j in sim.fighters.size():
		var other := sim.fighters[j]
		if j == fighter_index or _same_team(j) or other.is_knocked_out():
			continue
		var health := float(other.health) / float(other.stats.max_health * FighterState.METER_UNIT)
		var score := -me.position.distance_to(other.position) / 12.0 + (1.0 - health) * 1.2
		if j == _grudge and _ticks - _grudge_tick < GRUDGE_TICKS:
			score += 1.5
		if j == current:
			score += 0.4
		if score > best_score:
			best = j
			best_score = score
	return best


func _note_hits(sim: CombatSim) -> void:
	for event in sim.events:
		if event.get("target", -1) == fighter_index:
			if event.type == CombatSim.EventType.PERFECT_BLOCK:
				_perfect_streak += 1
			elif event.type in [CombatSim.EventType.HIT, CombatSim.EventType.COUNTER,
					CombatSim.EventType.BLOCK]:
				_perfect_streak = 0
		if event.get("target", -1) == fighter_index and event.get("attacker", -1) >= 0 \
				and event.type in [CombatSim.EventType.HIT, CombatSim.EventType.COUNTER,
					CombatSim.EventType.BLOCK, CombatSim.EventType.GRAB]:
			_grudge = event.attacker
			_grudge_tick = _ticks


func _match_height(me: FighterState, target: FighterState, plan: FighterInput) -> void:
	var dy := target.position.y - me.position.y
	if dy > 0.8:
		plan.vertical = 1
	elif dy < -0.8:
		plan.vertical = -1


## Strafe side that turns this AI back toward the arena centre when near a wall; 0 when clear.
func _wall_strafe(sim: CombatSim, me: FighterState, target: FighterState) -> float:
	var half := sim.tuning.arena_half_size - WALL_MARGIN
	if absf(me.position.x) < half and absf(me.position.z) < half:
		return 0.0
	var to_target := target.position - me.position
	var right := Vector3(-to_target.z, 0.0, to_target.x)
	return 1.0 if right.dot(-me.position) <= 0.0 else -1.0


func _moves(me: FighterState) -> MoveSet:
	var unarmed := me.stats.move_set
	if unarmed == null:
		unarmed = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
	var held := me.held_weapon()
	return unarmed if held == Weapon.Kind.NONE else WeaponMoves.move_set(held, unarmed)


func _same_team(other: int) -> bool:
	return other < teams.size() and fighter_index < teams.size() and teams[other] == teams[fighter_index] \
		and other != fighter_index


func _is_free(me: FighterState) -> bool:
	return me.state in [_S.IDLE, _S.MOVING, _S.FALLING, _S.FLYING]


func _may_attack(me: FighterState) -> bool:
	return me.switch_lockout == 0 and me.smitten_ticks == 0


## Holds action this tick only if it was not held last tick, so every tap is a fresh press.
func _tap(plan: FighterInput, action: int) -> void:
	if (_previous.held_actions & action) == 0:
		plan.held_actions |= action


static func _input_values(input: FighterInput) -> Array:
	return [input.held_actions, input.pressed_actions, input.released_actions, input.move,
		input.vertical, input.view_yaw, input.target_switch]
