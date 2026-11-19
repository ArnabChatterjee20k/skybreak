extends GutTest
## Every training dummy behaviour, driven through a real CombatSim.

const Bench := preload("res://tests/modes/training_bench.gd")
const Mode := TrainingDummy.Mode
const State := FighterState.State
const Event := CombatSim.EventType
const LIGHT := FighterInput.Action.LIGHT
const GRAB := FighterInput.Action.GRAB

var _bench: Bench


func before_each() -> void:
	_bench = Bench.new()


func _mode(mode: Mode) -> void:
	_bench.session.set_dummy_mode(mode)


## Taps light every period ticks for count presses (single jabs, no string);
## with reset, from the reset positions each time (jabs push the dummy back).
func _jab(count: int, period := 40, reset := false) -> void:
	for _i in count:
		if reset:
			_bench.session.reset_positions()
			_bench.tick(10)
		_bench.tap(LIGHT)
		_bench.tick(period - 1)


func test_stand_dummy_takes_every_jab() -> void:
	_mode(Mode.STAND)
	_jab(3)
	assert_eq(_bench.events_of(Event.HIT).size(), 3)
	assert_eq(_bench.events_of(Event.BLOCK).size(), 0)


func test_crouch_dummy_holds_descend_and_stays_on_the_floor() -> void:
	_mode(Mode.CROUCH)
	var input := _bench.session.dummy.input_for(_bench.sim, 1, 0)
	assert_eq(input.vertical, -1)
	_bench.tick(30)
	assert_almost_eq(_bench.dummy().position.y, _bench.sim.tuning.ground_height, 0.001)


func test_jump_dummy_leaves_the_floor_and_comes_back_down() -> void:
	_mode(Mode.JUMP)
	var peak := 0.0
	var landed_after_peak := false
	for _i in 180:
		_bench.tick()
		peak = maxf(peak, _bench.dummy().position.y)
		if peak > 2.0 and _bench.dummy().state == State.IDLE:
			landed_after_peak = true
	assert_gt(peak, 2.0, "it jumps")
	assert_true(landed_after_peak, "it lands again")


func test_fly_dummy_hovers_at_its_height() -> void:
	_mode(Mode.FLY)
	_bench.tick(240)
	var height := _bench.dummy().position.y - _bench.sim.tuning.ground_height
	assert_eq(_bench.dummy().state, State.FLYING)
	assert_between(height, TrainingDummy.FLY_HEIGHT - 0.5, TrainingDummy.FLY_HEIGHT + 3.0)


func test_block_all_dummy_blocks_every_jab() -> void:
	_mode(Mode.BLOCK_ALL)
	_bench.tick(2)
	_jab(3)
	assert_eq(_bench.events_of(Event.BLOCK).size(), 3)
	assert_eq(_bench.events_of(Event.HIT).size(), 0)


func test_block_after_first_hit_dummy_takes_one_then_blocks() -> void:
	_mode(Mode.BLOCK_AFTER_FIRST_HIT)
	_jab(3, 30)
	assert_eq(_bench.events_of(Event.HIT).size(), 1, "the first jab lands")
	assert_eq(_bench.events_of(Event.BLOCK).size(), 2, "the rest are blocked")
	# Once the pressure stops, it drops its guard and the next jab lands again.
	_bench.tick(TrainingDummy.GUARD_HOLD_TICKS + 30)
	_jab(1)
	assert_eq(_bench.events_of(Event.HIT).size(), 2)


func test_random_block_dummy_blocks_some_jabs_and_takes_others() -> void:
	_mode(Mode.RANDOM_BLOCK)
	_jab(24, 60, true)
	var hits := _bench.events_of(Event.HIT).size()
	var blocks := _bench.events_of(Event.BLOCK).size()
	assert_eq(_bench.events_of(Event.PERFECT_BLOCK).size(), 0, "plain blocks, not perfect-block taps")
	assert_eq(hits + blocks, 24, "every jab connects one way or the other")
	assert_gt(hits, 3)
	assert_gt(blocks, 3)


func test_random_block_is_repeatable_with_the_same_seed() -> void:
	_mode(Mode.RANDOM_BLOCK)
	_jab(12, 60, true)
	var first := _bench.events_of(Event.BLOCK).size()
	before_each()
	_mode(Mode.RANDOM_BLOCK)
	_jab(12, 60, true)
	assert_eq(_bench.events_of(Event.BLOCK).size(), first)


func test_perfect_block_dummy_perfect_blocks_jabs_and_heavies() -> void:
	_mode(Mode.PERFECT_BLOCK)
	_jab(3, 60)
	_bench.tap(FighterInput.Action.HEAVY)
	_bench.tick(80)
	assert_eq(_bench.events_of(Event.PERFECT_BLOCK).size(), 4)
	assert_eq(_bench.events_of(Event.HIT).size(), 0)


func test_perfect_block_dummy_never_falls_into_the_lockout() -> void:
	_mode(Mode.PERFECT_BLOCK)
	for _i in 6:
		_bench.tap(LIGHT)
		_bench.tick(29)
		assert_eq(_bench.dummy().perfect_block_lockout, 0)


func test_tech_dummy_breaks_every_grab() -> void:
	_mode(Mode.TECH)
	for _i in 3:
		_bench.session.reset_positions()
		_bench.tap(GRAB)
		_bench.tick(60)
	assert_eq(_bench.events_of(Event.GRAB).size(), 3)
	assert_eq(_bench.events_of(Event.GRAB_TECH).size(), 3)
	assert_eq(_bench.events_of(Event.THROW).size(), 0)


func test_without_tech_the_grab_throws() -> void:
	_mode(Mode.STAND)
	_bench.tap(GRAB)
	_bench.tick(60)
	assert_eq(_bench.events_of(Event.THROW).size(), 1)


func test_playback_dummy_repeats_the_recorded_loop() -> void:
	_bench.session.toggle_recording()
	# While recording the player's controls drive the dummy: a jab at the player.
	_bench.tick(5)
	_bench.tap(LIGHT)
	_bench.tick(34)
	_bench.session.toggle_recording()
	assert_eq(_bench.session.input_loop.length(), 40)
	assert_eq(_bench.events_of(Event.HIT).size(), 1, "the dummy's recorded jab hit the player")
	assert_eq(_bench.events_of(Event.HIT)[0].attacker, 1)
	_bench.session.reset_positions()
	_bench.session.toggle_playback()
	assert_eq(_bench.session.dummy.mode, Mode.PLAYBACK)
	_bench.tick(40 * 3)
	var dummy_hits := _bench.events_of(Event.HIT).filter(func(e: Dictionary) -> bool: return e.attacker == 1)
	assert_eq(dummy_hits.size(), 4, "one recorded jab plus three loops of playback")


func test_recording_stops_by_itself_after_ten_seconds() -> void:
	_bench.session.toggle_recording()
	_bench.tick(InputLoop.MAX_TICKS + 30)
	assert_false(_bench.session.input_loop.recording)
	assert_eq(_bench.session.input_loop.length(), InputLoop.MAX_TICKS)
