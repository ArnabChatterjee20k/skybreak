extends GutTest
## Escape tools (T-DEF3) against dodge (T-DEF2) and ki beams and clashes (T-KI1).

const A := FighterInput.Action
const State := FighterState.State
const Event := CombatSim.EventType
const Kind := FighterEscapes.Kind
const UNIT := FighterState.METER_UNIT

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _held: Array[int] = []
var _move: Array[Vector2] = []
var _vertical: Array[int] = []
var _log: Array[Dictionary] = []


func _start(positions: Array[Vector3]) -> void:
	_sim = CombatSim.new(7)
	for at in positions:
		_sim.add_fighter(at)
	_sim.lock_everyone_onto_nearest()
	_previous = []
	_held = []
	_move = []
	_vertical = []
	for _i in positions.size():
		_previous.append(FighterInput.new())
		_held.append(0)
		_move.append(Vector2.ZERO)
		_vertical.append(0)
	_log = []
	_tick(10)


func _tick(ticks := 1) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		for index in _sim.fighters.size():
			var input := FighterInput.from_held(_held[index], _previous[index])
			input.move = _move[index]
			input.vertical = _vertical[index]
			inputs.append(input)
		_sim.tick(inputs)
		_previous = inputs
		_log.append_array(_sim.events)


func _tap(index: int, action: int, vertical := 0) -> void:
	_held[index] |= action
	_vertical[index] = vertical
	_tick()
	_held[index] &= ~action
	_vertical[index] = 0


func _count(type: Event) -> int:
	var found := 0
	for event in _log:
		if event.type == type:
			found += 1
	return found


func _until(index: int, state: State, limit := 60) -> void:
	for _i in limit:
		if _sim.fighters[index].state == state:
			return
		_tick()


func _unfreeze(index: int) -> void:
	while _sim.fighters[index].hitstop_ticks > 0:
		_tick()


# Dodge

func test_a_dash_tap_in_hitstun_outside_the_tech_window_never_starts_a_dodge() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -2)])
	_tap(0, A.LIGHT)
	_until(1, State.HITSTUN, 20)
	_unfreeze(1)
	_move[1] = Vector2(1, 0)
	_tap(1, A.DASH)
	assert_eq(_sim.fighters[1].state, State.HITSTUN, "still in hitstun")
	assert_eq(_count(Event.DODGE), 0, "no dodge out of hitstun")
	assert_eq(_count(Event.AIR_TECH), 0, "a light has no knockback to tech")


func test_a_dash_tap_during_an_air_tech_does_not_dodge_until_the_tech_ends() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -2)])
	_tap(0, A.HEAVY)
	_until(1, State.HITSTUN, 30)
	_unfreeze(1)
	var tuning := _sim.escape_tuning
	while _sim.fighters[1].state_ticks < tuning.air_tech_first_tick:
		_tick()
	_tap(1, A.DASH, 1)
	assert_eq(_sim.fighters[1].escapes.kind, Kind.AIR_TECH, "the air tech fires")
	_move[1] = Vector2(1, 0)
	_tap(1, A.DASH)
	_move[1] = Vector2.ZERO
	assert_eq(_sim.fighters[1].state, State.ESCAPING, "the tech runs its course")
	assert_eq(_count(Event.DODGE), 0, "no dodge out of an air tech")


func test_an_air_tech_spends_no_air_dodge_because_the_hit_refreshed_them() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -2)])
	_tap(0, A.HEAVY)
	_until(1, State.HITSTUN, 30)
	_unfreeze(1)
	while _sim.fighters[1].state_ticks < _sim.escape_tuning.air_tech_first_tick:
		_tick()
	_tap(1, A.DASH, 1)
	assert_eq(_sim.fighters[1].escapes.kind, Kind.AIR_TECH)
	assert_eq(_sim.fighters[1].dodge.air_left, _sim.dodge_tuning.air_dodges,
		"GAME_DESIGN §5.5: being hit refreshes air dodges; the tech is not one of them")


func test_the_breaker_is_intangible_to_a_dodge_punish_grab() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -2)])
	var defender := _sim.fighters[1]
	defender.burst = _sim.meter_tuning.burst_stock_size * UNIT
	_tap(0, A.LIGHT)
	_until(1, State.HITSTUN, 20)
	_unfreeze(1)
	_tap(1, A.BREAKER)
	assert_eq(defender.escapes.kind, Kind.BREAKER, "the breaker fires")
	assert_false(defender.can_be_hit(), "intangible through the burst")
	assert_false(DodgeRules.in_recovery(defender), "a breaker is no dodge recovery to punish")


# Ki beams and clashes

func test_a_breaker_blows_away_a_beams_owner_and_the_beam_ends() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -3.5)])
	var owner := _sim.fighters[0]
	var defender := _sim.fighters[1]
	owner.ki = 100 * UNIT
	defender.burst = _sim.meter_tuning.burst_stock_size * UNIT
	_tap(0, A.SPECIAL_1)
	for _i in 60:
		if defender.state == State.HITSTUN:
			break
		_tick()
	assert_eq(defender.state, State.HITSTUN, "the beam lands")
	_unfreeze(1)
	assert_eq(_sim.beams.size(), 1, "the beam is still firing")
	_tap(1, A.BREAKER)
	_tick(2)
	assert_eq(owner.escapes.kind, Kind.BLOWN_AWAY, "the beam's owner is blown away")
	assert_eq(_sim.beams.size(), 0, "the owner left the move: its beam ended")
	assert_gt(_count(Event.BEAM_END), 0)
	assert_false(defender.can_be_hit(), "and the breaker is intangible to anything still flying")


func test_a_beam_passes_through_an_intangible_breaker() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -2)])
	var defender := _sim.fighters[1]
	defender.burst = _sim.meter_tuning.burst_stock_size * UNIT
	defender.escapes.intangible_ticks = 30
	assert_false(defender.can_be_hit(), "KiRules beam contacts skip fighters that cannot be hit")


func test_a_beam_clash_locks_out_breakers() -> void:
	# Fighters 0 and 1 clash; fighter 2, beside fighter 1, bursts out of hitstun.
	_start([Vector3.ZERO, Vector3(0, 0, -24), Vector3(3, 0, -24)])
	for fighter in _sim.fighters:
		fighter.ki = 100 * UNIT
	_sim.fighters[0].lock_on_target = 1
	_sim.fighters[1].lock_on_target = 0
	_sim.fighters[2].lock_on_target = 1
	_held[0] = A.SPECIAL_1
	_held[1] = A.SPECIAL_1
	_tick()
	_held[0] = 0
	_held[1] = 0
	for _i in 60:
		if not _sim.beam_clashes.is_empty():
			break
		_tick()
	assert_false(_sim.beam_clashes.is_empty(), "the beams clashed")
	if _sim.beam_clashes.is_empty():
		return
	var third := _sim.fighters[2]
	third.burst = _sim.meter_tuning.burst_stock_size * UNIT
	_sim._enter_stun(third, State.HITSTUN, 40)
	_tap(2, A.BREAKER)
	assert_eq(_count(Event.COMBO_BREAKER), 1, "the third fighter's breaker fires")
	assert_eq(_sim.fighters[1].state, State.ATTACKING, "the clashing fighter is not blown away")
	assert_true(KiRules.in_clash(_sim, 1), "the clash goes on")
	# A clashing fighter itself never qualifies for a breaker.
	var clasher := _sim.fighters[0]
	clasher.burst = _sim.meter_tuning.burst_stock_size * UNIT
	clasher.state = State.HITSTUN
	assert_false(EscapeRules.can_break(_sim, clasher), "no breaker while locked in a clash")
