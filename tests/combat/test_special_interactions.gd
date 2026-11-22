extends GutTest
## Specials (T-SP1) against escapes (T-DEF3), dodge (T-DEF2) and ki (T-KI1).

const SP1 := FighterInput.Action.SPECIAL_1
const LIGHT := FighterInput.Action.LIGHT
const DASH := FighterInput.Action.DASH
const BREAKER := FighterInput.Action.BREAKER
const State := FighterState.State
const Event := CombatSim.EventType
const Kind := FighterEscapes.Kind
const UNIT := FighterState.METER_UNIT
const KAEL := preload("res://game/combat/moves/kael/kael_fighter_stats.tres")
const DUMMY := preload("res://game/combat/default_fighter_stats.tres")

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _log: Array[Dictionary] = []


func _start(gap: float, first: FighterStats = KAEL, second: FighterStats = DUMMY) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO, first)
	_sim.add_fighter(Vector3(0, 0, -gap), second)
	_sim.lock_everyone_onto_nearest()
	for fighter in _sim.fighters:
		fighter.ki = 100 * UNIT
	_previous = [FighterInput.new(), FighterInput.new()]
	_log = []


func _tick(held0: int = 0, held1: int = 0, move0 := Vector2.ZERO, vertical0 := 0) -> void:
	var a := FighterInput.from_held(held0, _previous[0])
	a.move = move0
	a.vertical = vertical0
	var b := FighterInput.from_held(held1, _previous[1])
	var inputs: Array[FighterInput] = [a, b]
	_sim.tick(inputs)
	_previous = inputs
	_log.append_array(_sim.events)


func _count(type: Event) -> int:
	var found := 0
	for event in _log:
		if event.type == type:
			found += 1
	return found


func _kael() -> FighterState:
	return _sim.fighters[0]


func _other() -> FighterState:
	return _sim.fighters[1]


## Fighter 1 lands a light on Kael; ticks to Kael's first unfrozen hitstun tick.
func _kael_is_hit() -> void:
	_tick(0, LIGHT)
	for _i in 20:
		if _kael().state == State.HITSTUN:
			break
		_tick()
	assert_eq(_kael().state, State.HITSTUN, "the light lands")
	while _kael().hitstop_ticks > 0:
		_tick()


func test_a_special_cannot_start_in_hitstun_or_in_the_breaker_pose() -> void:
	_start(2.0)
	_kael().burst = _sim.meter_tuning.burst_stock_size * UNIT
	_kael_is_hit()
	_tick(SP1)
	assert_eq(_count(Event.SPECIAL_START), 0, "no special out of hitstun")
	_tick()
	_tick(BREAKER)
	assert_eq(_kael().escapes.kind, Kind.BREAKER, "the breaker fires")
	_tick(SP1)
	assert_eq(_kael().state, State.ESCAPING)
	assert_eq(_count(Event.SPECIAL_START), 0, "no special out of the breaker pose")


func test_a_special_cannot_start_during_a_dodge() -> void:
	_start(6.0)
	_tick(DASH, 0, Vector2(1, 0))
	assert_true(_kael().dodge.is_dodging(), "a sidestep dodge")
	_tick(SP1)
	while _kael().dodge.is_dodging() and _kael().state == State.DASHING:
		assert_eq(_count(Event.SPECIAL_START), 0, "no special inside the dodge's frames")
		_tick()


func test_starting_a_special_ends_wakeup_intangibility() -> void:
	_start(7.0)
	_kael().escapes.intangible_ticks = _sim.escape_tuning.wakeup_invuln_ticks
	_tick(SP1)
	assert_eq(_count(Event.SPECIAL_START), 1, "Comet Drive starts")
	assert_eq(_kael().escapes.intangible_ticks, 0, "attacking ends the escape's intangibility")


func test_a_breaker_blows_away_a_special_user_and_ends_the_special() -> void:
	_start(7.0)
	_other().burst = _sim.meter_tuning.burst_stock_size * UNIT
	_tick(SP1)
	for _i in 60:
		if _other().state == State.HITSTUN:
			break
		_tick()
	assert_eq(_other().state, State.HITSTUN, "Comet Drive lands")
	while _other().hitstop_ticks > 0:
		_tick()
	_tick(0, BREAKER)
	_tick()
	assert_eq(_kael().escapes.kind, Kind.BLOWN_AWAY, "Kael is blown away")
	assert_null(SpecialRules.current(_kael()), "the special is over")


func test_a_special_that_hits_can_only_chase_inside_its_vanish_cancel_window() -> void:
	_start(7.0)
	_tick(SP1)
	for _i in 60:
		if _kael().contact_hit:
			break
		_tick()
	assert_true(_kael().contact_hit, "Comet Drive connects")
	assert_eq(_kael().escapes.chase_target, 1, "its blowback opens the chase window")
	while _kael().hitstop_ticks > 0:
		_tick()
	var in_window := _sim.can_cancel_into(0, MoveData.CancelLevel.VANISH)
	gut.p("Comet Drive tick %d, vanish window open: %s, chase window %d" % [_kael().move_tick, in_window,
		_kael().escapes.chase_window])
	_tick(DASH)
	assert_eq(_count(Event.CHASE), 1 if in_window else 0,
		"GAME_DESIGN §6: on hit a special cancels only into Vanish or Ultimate; the chase is Vanish-level")


func test_specials_fire_no_beams_of_their_own_so_the_ki_beam_api_stays_the_only_beam() -> void:
	for legend in [&"kael", &"vexa"]:
		var kit := SpecialRules.kit_of(_fighter_of(legend))
		assert_not_null(kit, "%s has a kit" % legend)
		if kit != null:
			assert_null(kit.ultimate, "%s's key 4 stays the KiRules beam ultimate (KiBeam)" % legend)


func _fighter_of(legend: StringName) -> FighterState:
	var sim := CombatSim.new()
	return sim.add_fighter(Vector3.ZERO, Roster.character(legend).stats)


func test_a_special_past_its_cancel_window_cannot_chase() -> void:
	_start(7.0)
	_tick(SP1)
	for _i in 60:
		if _kael().contact_hit:
			break
		_tick()
	assert_true(_kael().contact_hit, "Comet Drive connects")
	while _kael().hitstop_ticks > 0 or (_sim.can_cancel_into(0, MoveData.CancelLevel.VANISH) \
			and _kael().escapes.chase_window > 0):
		_tick()
	if _kael().escapes.chase_window <= 0 or _kael().state != State.ATTACKING or _other().state != State.HITSTUN:
		pending("the chase window closes with the cancel window for Comet Drive")
		return
	_tick(DASH)
	assert_eq(_count(Event.CHASE), 0, "no chase cancel outside the special's Vanish window")
	assert_eq(_kael().state, State.ATTACKING, "the special plays out")
