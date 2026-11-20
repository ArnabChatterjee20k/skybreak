extends GutTest
## Rollback through the escape tools (T-DEF3): re-simulating from a snapshot taken
## mid-breaker, mid-air-tech, mid-chase or mid-roll gives the same hash on every tick.

const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const DASH := FighterInput.Action.DASH
const BREAKER := FighterInput.Action.BREAKER
const State := FighterState.State
const Kind := FighterEscapes.Kind
const UNIT := FighterState.METER_UNIT
const ATTACKER := 0
const DEFENDER := 1
## Frames a rollback rewinds and re-simulates, at every recorded tick.
const ROLLBACK := 8

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _held: Array[int] = []
var _move: Array[Vector2] = []
var _vertical: Array[int] = []
var _recording := false
var _base: SimSnapshot
var _inputs: Array = []
var _hashes: Array[int] = []
var _snaps: Array[SimSnapshot] = []


func _new_sim() -> CombatSim:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -2))
	sim.lock_everyone_onto_nearest()
	return sim


func _start() -> void:
	_sim = _new_sim()
	_previous = [FighterInput.new(), FighterInput.new()]
	_held = [0, 0]
	_move = [Vector2.ZERO, Vector2.ZERO]
	_vertical = [0, 0]
	_recording = false
	_inputs = []
	_hashes = []
	_snaps = []
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
		if _recording:
			_inputs.append(inputs)
			_hashes.append(_sim.state_hash())
			_snaps.append(_sim.snapshot())


func _tap(index: int, action: int, vertical := 0) -> void:
	_held[index] |= action
	_vertical[index] = vertical
	_tick()
	_held[index] &= ~action
	_vertical[index] = 0


func _fighter(index: int) -> FighterState:
	return _sim.fighters[index]


## Snapshot here; every later tick is recorded for _assert_rollback_matches().
func _mark() -> void:
	_base = _sim.snapshot()
	_recording = true


func _until(index: int, state: State, limit := 120) -> void:
	for _i in limit:
		if _fighter(index).state == state:
			return
		_tick()


func _land_heavy(vertical := 0) -> void:
	_tap(ATTACKER, HEAVY, vertical)
	_until(DEFENDER, State.HITSTUN, 30)
	assert_eq(_fighter(DEFENDER).state, State.HITSTUN, "the heavy lands")
	while _fighter(DEFENDER).hitstop_ticks > 0:
		_tick()


func _fly_to(tick: int) -> void:
	while _fighter(DEFENDER).state == State.HITSTUN and _fighter(DEFENDER).state_ticks < tick:
		_tick()


## Replays from the mark, rewinds ROLLBACK frames at every tick, and restores into a
## fresh sim: all three must give the recorded hash on every tick.
func _assert_rollback_matches(label: String) -> void:
	_recording = false
	assert_gt(_hashes.size(), ROLLBACK, "%s: recorded enough ticks" % label)
	var straight := _first_mismatch(_sim, _base, 0)
	assert_eq(straight, -1, "%s: replay from the mark drifts at tick %d" % [label, straight])
	var rewinds := 0
	for t in range(ROLLBACK, _hashes.size()):
		var from := t - ROLLBACK
		_sim.restore(_snaps[from])
		assert_eq(_sim.state_hash(), _hashes[from], "%s: restore at tick %d" % [label, from])
		for k in range(from + 1, t + 1):
			_sim.tick(_inputs[k])
		if _sim.state_hash() != _hashes[t]:
			rewinds += 1
	assert_eq(rewinds, 0, "%s: rollbacks of %d frames that re-simulate differently" % [label, ROLLBACK])
	var fresh := _first_mismatch(_new_sim(), _base, 0)
	assert_eq(fresh, -1, "%s: a fresh sim restored at the mark drifts at tick %d" % [label, fresh])


## Restores saved into sim, feeds the recorded inputs; the first tick whose hash differs, or -1.
func _first_mismatch(sim: CombatSim, saved: SimSnapshot, from: int) -> int:
	sim.restore(saved)
	for t in range(from, _hashes.size()):
		sim.tick(_inputs[t])
		if sim.state_hash() != _hashes[t]:
			return t
	return -1


func test_rollback_mid_combo_breaker_and_blow_out_re_simulates_identically() -> void:
	_start()
	_fighter(DEFENDER).burst = 2 * _sim.meter_tuning.burst_stock_size * UNIT
	_tap(ATTACKER, LIGHT)
	_until(DEFENDER, State.HITSTUN, 20)
	while _fighter(DEFENDER).hitstop_ticks > 0:
		_tick()
	_tap(DEFENDER, BREAKER)
	assert_eq(_fighter(DEFENDER).escapes.kind, Kind.BREAKER, "the breaker fires")
	_tick(2)
	_mark()
	assert_gt(_fighter(DEFENDER).hitstop_ticks, 0, "marked inside the breaker freeze")
	_tick(10)
	assert_eq(_fighter(ATTACKER).escapes.kind, Kind.BLOWN_AWAY, "recording through the blow-out")
	_tick(30)
	_tap(ATTACKER, LIGHT)
	_tick(10)
	_assert_rollback_matches("breaker")


func test_rollback_mid_air_tech_re_simulates_identically() -> void:
	_start()
	_land_heavy()
	_fly_to(_sim.escape_tuning.air_tech_first_tick)
	_tap(DEFENDER, DASH, 1)
	assert_eq(_fighter(DEFENDER).escapes.kind, Kind.AIR_TECH, "the air tech fires")
	_tick(3)
	_mark()
	assert_eq(_fighter(DEFENDER).state, State.ESCAPING, "marked mid-tech")
	_tick(30)
	_tap(DEFENDER, LIGHT)
	_tick(15)
	_assert_rollback_matches("air tech")


func test_rollback_mid_chase_and_caught_tech_re_simulates_identically() -> void:
	_start()
	_fighter(ATTACKER).ki = 100 * UNIT
	_land_heavy()
	_tap(ATTACKER, DASH, 1)
	assert_eq(_fighter(ATTACKER).escapes.chasing, DEFENDER, "the chase starts")
	_tick(2)
	_mark()
	_fly_to(_sim.escape_tuning.air_tech_first_tick)
	_tap(DEFENDER, DASH, 1)
	_tick(40)
	_assert_rollback_matches("chase")


func test_rollback_mid_tech_roll_re_simulates_identically() -> void:
	_start()
	_land_heavy(-1)
	_until(DEFENDER, State.KNOCKDOWN)
	assert_eq(_fighter(DEFENDER).state, State.KNOCKDOWN, "knocked down")
	_move[DEFENDER] = Vector2(1, 0)
	_tap(DEFENDER, 0, 1)
	_move[DEFENDER] = Vector2.ZERO
	assert_eq(_fighter(DEFENDER).escapes.kind, Kind.TECH_ROLL, "the roll fires")
	_tick(4)
	_mark()
	_tick(40)
	_assert_rollback_matches("tech roll")
