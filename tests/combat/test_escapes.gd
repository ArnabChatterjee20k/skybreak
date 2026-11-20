extends GutTest
## T-DEF3 escape tools: combo breaker, air tech and chase, tech roll and wakeups.

const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const DASH := FighterInput.Action.DASH
const BREAKER := FighterInput.Action.BREAKER
const State := FighterState.State
const Event := CombatSim.EventType
const Kind := FighterEscapes.Kind
const Way := FighterEscapes.Way
const UNIT := FighterState.METER_UNIT
const ATTACKER := 0
const DEFENDER := 1

var _sim: CombatSim
var _tuning: EscapeTuning
var _previous: Array[FighterInput] = []
var _held: Array[int] = []
var _move: Array[Vector2] = []
var _vertical: Array[int] = []
var _log: Array[Dictionary] = []


func _start(defender_at := Vector3(0, 0, -2)) -> void:
	_sim = CombatSim.new()
	_tuning = _sim.escape_tuning
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(defender_at)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	_held = [0, 0]
	_move = [Vector2.ZERO, Vector2.ZERO]
	_vertical = [0, 0]
	_log = []
	_tick(10)


func _tick(ticks := 1) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		for index in 2:
			var input := FighterInput.from_held(_held[index], _previous[index])
			input.move = _move[index]
			input.vertical = _vertical[index]
			inputs.append(input)
		_sim.tick(inputs)
		_previous = inputs
		_log.append_array(_sim.events)


func _tap(index: int, action: int) -> void:
	_held[index] |= action
	_tick()
	_held[index] &= ~action


func _fighter(index: int) -> FighterState:
	return _sim.fighters[index]


func _events_of(type: Event) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event in _log:
		if event.type == type:
			found.append(event)
	return found


## The attacker lands a light; ticks to the first unfrozen hitstun tick.
func _land_light() -> void:
	_tap(ATTACKER, LIGHT)
	for _i in 20:
		if _fighter(DEFENDER).state == State.HITSTUN:
			break
		_tick()
	assert_eq(_fighter(DEFENDER).state, State.HITSTUN, "the light lands")
	while _fighter(DEFENDER).hitstop_ticks > 0:
		_tick()


## The attacker lands a heavy (vertical: 0 smash, -1 spike); ticks to the end of its hitstop.
func _land_heavy(vertical := 0) -> void:
	_vertical[ATTACKER] = vertical
	_tap(ATTACKER, HEAVY)
	_vertical[ATTACKER] = 0
	for _i in 30:
		if _fighter(DEFENDER).state == State.HITSTUN:
			break
		_tick()
	assert_eq(_fighter(DEFENDER).state, State.HITSTUN, "the heavy lands")
	while _fighter(DEFENDER).hitstop_ticks > 0:
		_tick()


## Ticks until the defender's knockback flight reaches state_ticks == tick (before the tech press).
func _fly_to(tick: int) -> void:
	while _fighter(DEFENDER).state == State.HITSTUN and _fighter(DEFENDER).state_ticks < tick:
		_tick()


func _give_burst(stocks: int) -> void:
	_fighter(DEFENDER).burst = stocks * _sim.meter_tuning.burst_stock_size * UNIT


# Combo breaker

func test_a_combo_breaker_costs_one_stock_and_blows_the_attacker_out_to_mid_range() -> void:
	_start()
	_give_burst(2)
	_land_light()
	var burst_before := _fighter(DEFENDER).burst
	_tap(DEFENDER, BREAKER)
	var breakers := _events_of(Event.COMBO_BREAKER)
	assert_eq(breakers.size(), 1, "one breaker")
	assert_eq(breakers[0].fighter, DEFENDER)
	assert_eq(breakers[0].target, ATTACKER)
	assert_eq(breakers[0].hitstop, _tuning.breaker_hitstop_ticks, "a big freeze")
	assert_eq(_fighter(DEFENDER).burst, burst_before - _sim.meter_tuning.burst_stock_size * UNIT, "one stock spent")
	assert_eq(_fighter(DEFENDER).state, State.ESCAPING)
	assert_eq(_fighter(DEFENDER).escapes.kind, Kind.BREAKER)
	assert_eq(_fighter(ATTACKER).escapes.kind, Kind.BLOWN_AWAY)
	assert_eq(_fighter(DEFENDER).combo_hits, 0, "the combo is over")
	# The freeze, the slide, then the tick it recovers on.
	_tick(_tuning.breaker_hitstop_ticks + _tuning.breaker_push_ticks + 1)
	var gap := _fighter(ATTACKER).position - _fighter(DEFENDER).position
	gap.y = 0.0
	assert_almost_eq(gap.length(), _tuning.breaker_push_distance, 0.05, "pushed out to mid range")
	assert_eq(_fighter(ATTACKER).state, State.IDLE, "the attacker recovers after the push")


func test_a_combo_breaker_without_a_burst_stock_does_nothing() -> void:
	_start()
	_fighter(DEFENDER).burst = 0
	_land_light()
	assert_lt(_fighter(DEFENDER).burst, _sim.meter_tuning.burst_stock_size * UNIT, "the hit gave less than a stock")
	_tap(DEFENDER, BREAKER)
	assert_eq(_events_of(Event.COMBO_BREAKER).size(), 0)
	assert_eq(_fighter(DEFENDER).state, State.HITSTUN, "still in the combo")


func test_a_breaker_press_outside_hitstun_does_nothing_and_costs_nothing() -> void:
	_start()
	_give_burst(1)
	_tap(DEFENDER, BREAKER)
	_tick(5)
	assert_eq(_events_of(Event.COMBO_BREAKER).size(), 0)
	assert_eq(_fighter(DEFENDER).burst, _sim.meter_tuning.burst_stock_size * UNIT)


func test_the_breaker_is_intangible_for_exactly_its_window_after_the_freeze() -> void:
	_start()
	_give_burst(1)
	_land_light()
	_tap(DEFENDER, BREAKER)
	var defender := _fighter(DEFENDER)
	var intangible := 0
	for _i in _tuning.breaker_hitstop_ticks + _tuning.breaker_intangible_ticks + 5:
		if not defender.can_be_hit():
			intangible += 1
		_tick()
	# The breaker tick itself, the freeze, then the intangible ticks.
	assert_eq(intangible, _tuning.breaker_hitstop_ticks + _tuning.breaker_intangible_ticks)
	assert_true(defender.can_be_hit(), "vulnerable afterwards")


func test_starting_an_attack_ends_the_breaker_intangibility() -> void:
	_start()
	_give_burst(1)
	_land_light()
	_tap(DEFENDER, BREAKER)
	_tick(_tuning.breaker_hitstop_ticks + _tuning.breaker_pose_ticks)
	assert_false(_fighter(DEFENDER).can_be_hit(), "still intangible after the pose")
	_tap(DEFENDER, LIGHT)
	assert_eq(_fighter(DEFENDER).state, State.ATTACKING)
	assert_true(_fighter(DEFENDER).can_be_hit(), "no invincible reversal")


func test_the_breaker_pose_cannot_act() -> void:
	_start()
	_give_burst(1)
	_land_light()
	_tap(DEFENDER, BREAKER)
	_tick(_tuning.breaker_hitstop_ticks + 2)
	_tap(DEFENDER, LIGHT)
	assert_eq(_fighter(DEFENDER).state, State.ESCAPING, "the burst pose plays out")


func test_the_combo_breaker_cannot_be_chained_inside_its_cooldown() -> void:
	_start()
	_give_burst(3)
	_land_light()
	_tap(DEFENDER, BREAKER)
	assert_eq(_events_of(Event.COMBO_BREAKER).size(), 1)
	# Walk back in and combo again as soon as both can act.
	_tick(_tuning.breaker_hitstop_ticks + _tuning.breaker_push_ticks + 2)
	_fighter(DEFENDER).position = Vector3(_fighter(ATTACKER).position.x, _fighter(DEFENDER).position.y,
		_fighter(ATTACKER).position.z - 2.0)
	_tick(_tuning.breaker_intangible_ticks)
	_land_light()
	var burst_before := _fighter(DEFENDER).burst
	_tap(DEFENDER, BREAKER)
	assert_eq(_events_of(Event.COMBO_BREAKER).size(), 1, "inside the cooldown: no second breaker")
	assert_eq(_fighter(DEFENDER).burst, burst_before, "and no stock spent")
	assert_gt(_fighter(DEFENDER).escapes.breaker_cooldown, 0)


func test_a_breaker_mash_over_a_long_combo_spends_at_most_one_stock_per_cooldown() -> void:
	_start()
	_give_burst(3)
	# The defender mashes X every 4 ticks for 10 s while the attacker keeps attacking in reach.
	for tick in 600:
		if tick % 4 == 0:
			_held[DEFENDER] |= BREAKER
		if tick % 9 == 0:
			_held[ATTACKER] |= LIGHT
		var gap := _fighter(DEFENDER).position - _fighter(ATTACKER).position
		_move[ATTACKER] = Vector2(0, 1) if Vector2(gap.x, gap.z).length() > 1.8 else Vector2.ZERO
		_tick()
		_held[DEFENDER] &= ~BREAKER
		_held[ATTACKER] &= ~LIGHT
	var count := _events_of(Event.COMBO_BREAKER).size()
	assert_between(count, 1, 600 / _tuning.breaker_cooldown_ticks + 1, "breakers are rationed by the cooldown")


# Air tech and chase

func test_an_air_tech_works_on_every_tick_of_the_window_and_not_outside_it() -> void:
	for tick in range(_tuning.air_tech_first_tick - 1, _tuning.air_tech_last_tick + 2):
		_start()
		_land_heavy()
		_fly_to(tick)
		_tap(DEFENDER, DASH)
		var teched := _events_of(Event.AIR_TECH).size() == 1
		var inside := tick >= _tuning.air_tech_first_tick and tick <= _tuning.air_tech_last_tick
		assert_eq(teched, inside, "tech on knockback tick %d" % tick)


func test_lights_without_knockback_cannot_be_air_teched() -> void:
	_start()
	_land_light()
	_fighter(DEFENDER).stun_ticks = 40
	_fly_to(_tuning.air_tech_first_tick)
	_tap(DEFENDER, DASH)
	assert_eq(_events_of(Event.AIR_TECH).size(), 0)


func test_an_air_tech_recovers_the_held_way_intangible_at_first() -> void:
	_start()
	_land_heavy()
	_fly_to(_tuning.air_tech_first_tick)
	_vertical[DEFENDER] = 1
	_tap(DEFENDER, DASH)
	_vertical[DEFENDER] = 0
	var defender := _fighter(DEFENDER)
	assert_eq(defender.state, State.ESCAPING)
	assert_eq(defender.escapes.kind, Kind.AIR_TECH)
	assert_eq(defender.escapes.way, Way.OVER)
	assert_gt(defender.velocity.y, 0.0, "recovers upward")
	var intangible := 0
	var start_y := defender.position.y
	while defender.state == State.ESCAPING:
		if not defender.can_be_hit():
			intangible += 1
		_tick()
	assert_eq(intangible, _tuning.air_tech_invuln_ticks, "the tech tick and its intangible ticks")
	assert_eq(defender.state, State.FLYING, "free in the air")
	assert_gt(defender.position.y, start_y + 2.0)


func test_one_air_tech_per_knockback() -> void:
	_start()
	_land_heavy()
	_fly_to(_tuning.air_tech_first_tick)
	_fighter(DEFENDER).escapes.air_tech_used = true
	_tap(DEFENDER, DASH)
	assert_eq(_events_of(Event.AIR_TECH).size(), 0)


## Smash, the attacker chases with chase_vertical, the defender techs with tech_vertical at
## the window start. Returns [tech event, attacker free tick, defender free tick].
func _chase_and_tech(chase_vertical: int, tech_vertical: int) -> Array:
	_start()
	_fighter(ATTACKER).ki = 100 * UNIT
	_land_heavy()
	_vertical[ATTACKER] = chase_vertical
	_tap(ATTACKER, DASH)
	_vertical[ATTACKER] = 0
	assert_eq(_events_of(Event.CHASE).size(), 1, "the chase starts")
	assert_eq(_fighter(ATTACKER).escapes.chasing, DEFENDER)
	_fly_to(_tuning.air_tech_first_tick)
	_vertical[DEFENDER] = tech_vertical
	_tap(DEFENDER, DASH)
	_vertical[DEFENDER] = 0
	var techs := _events_of(Event.AIR_TECH)
	var free := [-1, -1]
	for tick in 120:
		for index in 2:
			if free[index] < 0 and _fighter(index).state in [State.IDLE, State.MOVING, State.FLYING, State.FALLING]:
				free[index] = tick
		_tick()
	return [techs[0] if not techs.is_empty() else {}, free[0], free[1]]


func test_a_chase_the_right_way_catches_the_tech() -> void:
	var result := _chase_and_tech(1, 1)
	var tech: Dictionary = result[0]
	assert_true(tech.caught, "the chaser read the tech")
	assert_eq(tech.target, ATTACKER)
	assert_eq(_events_of(Event.HIT).size(), 1, "only the smash so far")


func test_a_chase_the_wrong_way_gives_the_defender_8_ticks() -> void:
	var result := _chase_and_tech(-1, 1)
	var tech: Dictionary = result[0]
	assert_false(tech.caught)
	assert_eq(result[1] - result[2], _tuning.chase_miss_advantage_ticks, "defender acts 8 ticks first")


func test_a_caught_tech_keeps_the_defender_in_hitstun_for_the_follow_up() -> void:
	_start()
	_fighter(ATTACKER).ki = 100 * UNIT
	_land_heavy()
	_tap(ATTACKER, DASH)
	_fly_to(_tuning.air_tech_first_tick)
	_tap(DEFENDER, DASH)
	var defender := _fighter(DEFENDER)
	assert_eq(defender.state, State.HITSTUN)
	assert_gte(defender.stun_ticks, defender.state_ticks + _tuning.air_tech_caught_ticks - 1)


func test_a_chase_needs_a_knockback_hit_in_the_last_20_ticks() -> void:
	_start()
	_fighter(ATTACKER).ki = 100 * UNIT
	_land_heavy()
	_tick(_tuning.chase_window_ticks)
	_tap(ATTACKER, DASH)
	assert_eq(_events_of(Event.CHASE).size(), 0, "too late to chase")


func test_a_chase_costs_its_ki() -> void:
	_start()
	_fighter(ATTACKER).ki = 100 * UNIT
	_land_heavy()
	var before := _fighter(ATTACKER).ki
	_tap(ATTACKER, DASH)
	assert_eq(_events_of(Event.CHASE).size(), 1)
	assert_lte(_fighter(ATTACKER).ki, before - _tuning.chase_ki_cost * UNIT + 2 * _sim.meter_tuning.ki_passive_per_second)


# Knockdown: tech roll and wakeups

func _knock_down() -> void:
	_land_heavy(-1)
	for _i in 120:
		if _fighter(DEFENDER).state == State.KNOCKDOWN:
			return
		_tick()
	assert_eq(_fighter(DEFENDER).state, State.KNOCKDOWN, "knocked down")


func test_a_tech_roll_within_10_ticks_of_landing_rolls_the_held_way() -> void:
	# late: the tick after landing the press comes on (1 = the very next tick).
	for late in [1, _tuning.tech_roll_window_ticks, _tuning.tech_roll_window_ticks + 1]:
		_start()
		_knock_down()
		assert_eq(_fighter(DEFENDER).state_ticks, 1, "just landed")
		_tick(late - 1)
		var at := _fighter(DEFENDER).position
		_vertical[DEFENDER] = 1
		_move[DEFENDER] = Vector2(1, 0)
		_tick()
		_vertical[DEFENDER] = 0
		_move[DEFENDER] = Vector2.ZERO
		var rolled := _events_of(Event.TECH_ROLL).size() == 1
		assert_eq(rolled, late <= _tuning.tech_roll_window_ticks, "roll on tick %d after landing" % late)
		if rolled:
			_tick(_tuning.tech_roll_ticks)
			var travel := _fighter(DEFENDER).position - at
			travel.y = 0.0
			assert_almost_eq(travel.length(), _tuning.tech_roll_distance, 0.2, "rolls its distance")
			assert_eq(_fighter(DEFENDER).state, State.IDLE)


func test_a_tech_roll_is_intangible_for_6_ticks_then_vulnerable() -> void:
	_start()
	_knock_down()
	_vertical[DEFENDER] = 1
	_tick()
	_vertical[DEFENDER] = 0
	var defender := _fighter(DEFENDER)
	assert_eq(defender.escapes.kind, Kind.TECH_ROLL)
	var intangible := 0
	while defender.state == State.ESCAPING:
		if not defender.can_be_hit():
			intangible += 1
		_tick()
	assert_eq(intangible, _tuning.wakeup_invuln_ticks)


func test_a_neutral_wakeup_stands_after_40_ticks_intangible_for_6() -> void:
	_start()
	_knock_down()
	var defender := _fighter(DEFENDER)
	var down := 0
	while defender.state == State.KNOCKDOWN:
		down += 1
		_tick()
	assert_eq(down, _sim.hit_tuning.knockdown_ticks, "lies for the knockdown tick count")
	var wake := _events_of(Event.WAKEUP)
	assert_eq(wake.size(), 1)
	assert_false(wake[0].delayed)
	var intangible := 0
	for _i in 10:
		if not defender.can_be_hit():
			intangible += 1
		_tick()
	assert_eq(intangible, _tuning.wakeup_invuln_ticks, "the wakeup tick and the ones after it")


func test_holding_descend_delays_the_wakeup_to_70_ticks() -> void:
	_start()
	_knock_down()
	_vertical[DEFENDER] = -1
	var defender := _fighter(DEFENDER)
	var down := 0
	while defender.state == State.KNOCKDOWN and down < 200:
		down += 1
		_tick()
	_vertical[DEFENDER] = 0
	assert_eq(down, _tuning.delayed_wakeup_ticks, "lies for the delayed tick count")
	assert_true(_events_of(Event.WAKEUP)[0].delayed)


# Determinism and rollback

func test_snapshot_and_restore_mid_escape_replay_the_same_states() -> void:
	_start()
	_give_burst(1)
	_land_light()
	_tap(DEFENDER, BREAKER)
	var saved := _sim.snapshot()
	var previous := _previous.duplicate()
	_tick(30)
	var expected := _sim.state_hash()
	_sim.restore(saved)
	_previous = previous
	_tick(30)
	assert_eq(_sim.state_hash(), expected)


func test_the_state_hash_covers_the_escape_state() -> void:
	_start()
	var before := _sim.state_hash()
	_fighter(DEFENDER).escapes.breaker_cooldown = 5
	assert_ne(_sim.state_hash(), before)
	_fighter(DEFENDER).escapes.breaker_cooldown = 0
	_fighter(ATTACKER).escapes.chase_window = 3
	assert_ne(_sim.state_hash(), before)


# Perfect-block polish (S3)

## Fighter 1 presses block offset ticks before fighter 0's light lands and holds it; returns the contact type.
func _light_against_held_press(offset: int) -> int:
	_start()
	var light: MoveData = _fighter(ATTACKER).stats.move_set.light_string[0]
	var hit_tick := light.startup_ticks
	for tick in hit_tick + 3:
		if tick == 0:
			_held[ATTACKER] |= LIGHT
		if tick == hit_tick - offset:
			_held[DEFENDER] |= FighterInput.Action.BLOCK
		_tick()
		_held[ATTACKER] &= ~LIGHT
		for event in _sim.events:
			if event.type in [Event.PERFECT_BLOCK, Event.BLOCK, Event.HIT]:
				return event.type
	return -1


func test_an_early_held_press_from_the_attack_start_only_blocks() -> void:
	var light: MoveData = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set.light_string[0]
	assert_eq(_light_against_held_press(light.startup_ticks), Event.BLOCK,
		"guard raised on the attacker's press tick: a plain block")


func test_a_fresh_held_press_inside_6_ticks_still_perfect_blocks() -> void:
	for offset in 6:
		assert_eq(_light_against_held_press(offset), Event.PERFECT_BLOCK, "press %d ticks before" % offset)


func test_a_perfect_block_slows_the_view_to_0_8_for_6_ticks_and_never_the_sim() -> void:
	var slow := EscapeVfx.ViewSlow.new(CombatSim.DEFAULT_ESCAPE_TUNING as EscapeTuning)
	assert_eq(slow.time_scale(), 1.0)
	var perfect: Array[Dictionary] = [{"type": Event.PERFECT_BLOCK}]
	var none: Array[Dictionary] = []
	slow.react(perfect)
	var scales: Array[float] = [slow.time_scale()]
	for _i in 7:
		slow.react(none)
		scales.append(slow.time_scale())
	assert_eq(scales, [0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 1.0, 1.0] as Array[float])
	slow.enabled = false
	slow.react(perfect)
	assert_eq(slow.time_scale(), 1.0, "off (netplay) means no slow")
