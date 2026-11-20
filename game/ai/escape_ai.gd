class_name EscapeAI
extends RefCounted
## When an AI fighter uses the escape tools (T-DEF3): combo breaker, air tech,
## chase, tech roll and delayed wakeup, at per-level rates. Reads the sim only,
## and draws from its own rng, so other AI decisions keep their random sequence.

const _S := FighterState.State
const _A := FighterInput.Action
const _W := FighterEscapes.Way
## Chance to break a combo once it reaches BREAKER_MIN_HITS (L1..L5); low health adds BREAKER_LOW_HEALTH.
const BREAKER_CHANCE: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6]
const BREAKER_MIN_HITS: Array[int] = [99, 6, 5, 4, 3]
const BREAKER_LOW_HEALTH := 0.15
## Chance to air tech a techable knockback, and the latest tick past the window start it presses at.
const AIR_TECH_CHANCE: Array[float] = [0.05, 0.2, 0.4, 0.6, 0.8]
const AIR_TECH_SLACK: Array[int] = [11, 9, 6, 3, 1]
## Chance to tech away from the way a chaser visibly picked (L1..L5).
const CHASE_READ: Array[float] = [0.0, 0.0, 0.3, 0.55, 0.75]
## Chance to chase a knockback hit it landed.
const CHASE_CHANCE: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6]
## Chance to roll out of a knockdown, else to delay the wakeup.
const TECH_ROLL_CHANCE: Array[float] = [0.05, 0.25, 0.45, 0.6, 0.75]
const DELAYED_WAKEUP_CHANCE: Array[float] = [0.0, 0.05, 0.15, 0.2, 0.25]

var level: int = 3
var rng := RandomNumberGenerator.new()

var _seen_state: int = -1
var _seen_ticks: int = 0
var _breaker_rolled: bool = false
var _break_now: bool = false
var _tech_tick: int = -1
var _tech_way: int = _W.NONE
var _tech_move := Vector2.ZERO
var _wakeup: int = 0 # 0 neutral, 1 roll, 2 delayed
var _wakeup_tick: int = 0
var _wakeup_move := Vector2.ZERO
var _chase_rolled: bool = false


func _init(level_value: int = 3, seed_value: int = 0) -> void:
	level = clampi(level_value, AIProfile.MIN_LEVEL, AIProfile.MAX_LEVEL)
	rng.seed = seed_value


## Escapes for a fighter in hitstun or knockdown; plan.view_yaw already faces target.
func decide(sim: CombatSim, me: FighterState, target: FighterState, plan: FighterInput) -> void:
	var fresh := me.state != _seen_state or me.state_ticks < _seen_ticks
	_seen_state = me.state
	_seen_ticks = me.state_ticks
	var i := level - 1
	match me.state:
		_S.HITSTUN:
			if fresh:
				_plan_air_tech(sim, me, target, i)
			if not _breaker_rolled and me.combo_hits >= BREAKER_MIN_HITS[i]:
				_breaker_rolled = true
				var low := me.health * 10 < me.stats.max_health * FighterState.METER_UNIT * 3
				_break_now = rng.randf() < BREAKER_CHANCE[i] + (BREAKER_LOW_HEALTH if low else 0.0)
			if _break_now and EscapeRules.can_break(sim, me):
				_break_now = false
				plan.held_actions |= _A.BREAKER
				return
			if _tech_tick >= 0 and me.state_ticks >= _tech_tick and EscapeRules.can_air_tech(sim, me):
				_read_chaser(sim, me, target, i)
				plan.held_actions |= _A.DASH
				plan.move = _tech_move
				plan.vertical = 1 if _tech_way == _W.OVER else (-1 if _tech_way == _W.UNDER else 0)
				_tech_tick = -1
		_S.KNOCKDOWN:
			if fresh and me.state_ticks <= 1:
				_plan_wakeup(i)
			if _wakeup == 1 and me.state_ticks >= _wakeup_tick:
				plan.vertical = 1
				plan.move = _wakeup_move
			elif _wakeup == 2:
				plan.vertical = -1
	if me.state != _S.HITSTUN:
		_breaker_rolled = false
		_break_now = false


## Chases a knockback hit it just landed (Dash, with the way's height key). True when it pressed.
func chase(sim: CombatSim, me: FighterState, plan: FighterInput) -> bool:
	var escapes := me.escapes
	if escapes.chase_window <= 0 or escapes.chase_target < 0:
		_chase_rolled = false
		return false
	if _chase_rolled:
		return false
	var chased := sim.fighters[escapes.chase_target]
	if chased.state != _S.HITSTUN or me.lock_on_target != escapes.chase_target \
			or me.ki < sim.escape_tuning.chase_ki_cost * FighterState.METER_UNIT:
		return false
	if me.state == _S.ATTACKING and not me.contact_hit:
		return false
	_chase_rolled = true
	if rng.randf() >= CHASE_CHANCE[level - 1]:
		return false
	plan.held_actions = _A.DASH
	plan.vertical = [0, 1, -1][rng.randi_range(0, 2)]
	# With third parties around, over and under chases stack fighters (QA-15): straight only.
	if sim.fighters.size() > 2:
		plan.vertical = 0
	plan.move = Vector2.ZERO
	return true


func snapshot() -> Array:
	return [rng.state, _seen_state, _seen_ticks, _breaker_rolled, _break_now, _tech_tick, _tech_way,
		_tech_move, _wakeup, _wakeup_tick, _wakeup_move, _chase_rolled]


func restore(v: Array) -> void:
	rng.state = v[0]; _seen_state = v[1]; _seen_ticks = v[2]; _breaker_rolled = v[3]; _break_now = v[4]
	_tech_tick = v[5]; _tech_way = v[6]; _tech_move = v[7]; _wakeup = v[8]; _wakeup_tick = v[9]
	_wakeup_move = v[10]; _chase_rolled = v[11]


func _plan_air_tech(sim: CombatSim, me: FighterState, target: FighterState, i: int) -> void:
	_tech_tick = -1
	if me.knockback_type not in EscapeRules.TECH_KNOCKBACKS or rng.randf() >= AIR_TECH_CHANCE[i]:
		return
	var tuning := sim.escape_tuning
	_tech_tick = tuning.air_tech_first_tick + rng.randi_range(0, AIR_TECH_SLACK[i])
	_tech_way = [_W.STRAIGHT, _W.STRAIGHT, _W.OVER, _W.UNDER][rng.randi_range(0, 3)]
	if sim.fighters.size() > 2:
		_tech_way = _W.STRAIGHT
	_tech_move = [Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)][rng.randi_range(0, 2)]


## A chaser coming over, under or straight is visible: better players tech another way.
func _read_chaser(sim: CombatSim, me: FighterState, target: FighterState, i: int) -> void:
	if sim.fighters.size() > 2 or target.escapes.chasing != sim.fighters.find(me) \
			or target.escapes.way != _tech_way:
		return
	if rng.randf() < CHASE_READ[i]:
		_tech_way = _W.STRAIGHT if _tech_way != _W.STRAIGHT else [_W.OVER, _W.UNDER][rng.randi_range(0, 1)]


func _plan_wakeup(i: int) -> void:
	_wakeup = 0
	if rng.randf() < TECH_ROLL_CHANCE[i]:
		_wakeup = 1
		_wakeup_tick = rng.randi_range(1, 8 - i)
		_wakeup_move = [Vector2(0, -1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)][rng.randi_range(0, 4)]
	elif rng.randf() < DELAYED_WAKEUP_CHANCE[i]:
		_wakeup = 2
