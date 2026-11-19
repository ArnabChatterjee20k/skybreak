extends GutTest

const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const State := FighterState.State
const Knockback := MoveData.KnockbackType
const EPSILON := 0.0001

var _sim: CombatSim
var _moves: MoveSet
var _previous: Array[FighterInput] = []


## Fighter 0 on the floor at the origin, the target two metres ahead (-Z); both locked on.
func _start(target := Vector3(0, 0, -2), attacker := Vector3.ZERO, stats: FighterStats = null) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(attacker, stats)
	_sim.add_fighter(target)
	_sim.lock_everyone_onto_nearest()
	_moves = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
	_previous = [FighterInput.new(), FighterInput.new()]


func _tick(ticks := 1, held := 0, move := Vector2.ZERO, vertical := 0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]), FighterInput.from_held(0, _previous[1]),
		]
		inputs[0].move = move
		inputs[0].vertical = vertical
		_sim.tick(inputs)
		_previous = inputs


## Presses a heavy for one tick (so it does not charge), then ticks until it lands and its hitstop ends.
func _land_heavy(move := Vector2.ZERO, vertical := 0) -> void:
	_tick(1, HEAVY, move, vertical)
	for _i in 30:
		_tick()
		if not _sim.events.is_empty():
			break
	assert_eq(_sim.events.size(), 1, "the heavy lands")
	_tick(_sim.events[0].hitstop)


func _target() -> FighterState:
	return _sim.fighters[1]


## Ticks until the target leaves HITSTUN; returns its velocity on every tick it was still in it.
func _fly_out_hitstun() -> Array[Vector3]:
	var velocities: Array[Vector3] = []
	while _target().state == State.HITSTUN and velocities.size() < 200:
		velocities.append(_target().velocity)
		_tick()
	return velocities


func test_blowback_sends_the_target_far_along_the_aim_and_air_friction_slows_it() -> void:
	_start()
	_land_heavy()
	assert_eq(_target().knockback_type, Knockback.BLOWBACK)
	var smash := _moves.smash
	assert_true(_target().velocity.is_equal_approx(smash.knockback), "attacker faces -Z, so the vector is unchanged")
	var start := _target().position
	var velocities := _fly_out_hitstun()
	for i in range(1, velocities.size()):
		assert_almost_eq(velocities[i - 1].length() - velocities[i].length(),
			_sim.hit_tuning.knockback_drag / CombatSim.TICKS_PER_SECOND, EPSILON, "drag on tick %d" % i)
	assert_gt(start.z - _target().position.z, 10.0, "sent more than 10 m away")
	assert_eq(_target().state, State.FLYING, "recovers in the air")


func test_a_wall_splat_hit_flies_like_blowback_for_now() -> void:
	var splat := _moves.smash.duplicate() as MoveData
	splat.charge_level_ticks = PackedInt32Array()
	splat.knockback_type = Knockback.WALL_SPLAT
	var stats := FighterStats.new()
	stats.move_set = MoveSet.new()
	stats.move_set.smash = splat
	var paths: Array = []
	for custom in [null, stats]:
		_start(Vector3(0, 0, -2), Vector3.ZERO, custom)
		_land_heavy()
		paths.append(_fly_out_hitstun())
	assert_eq(paths[1], paths[0])


func test_launch_sends_the_target_straight_up_then_juggle_gravity_pulls_it_down() -> void:
	_start()
	_land_heavy(Vector2(0, -1))
	assert_eq(_target().knockback_type, Knockback.LAUNCH)
	assert_gt(_target().velocity.y, 20.0)
	var floor_height := _sim.tuning.ground_height
	var velocities := _fly_out_hitstun()
	for i in range(1, velocities.size()):
		assert_almost_eq(velocities[i - 1].y - velocities[i].y,
			_sim.hit_tuning.juggle_gravity / CombatSim.TICKS_PER_SECOND, EPSILON)
	assert_eq(_target().state, State.FLYING, "a juggled fighter recovers in flight")
	assert_gt(_target().position.y, floor_height + 5.0)


func test_launch_stays_vertical_even_when_aimed_at_a_target_above() -> void:
	_start(Vector3(0, 1.5, -2))
	_land_heavy(Vector2(0, -1))
	assert_gt(_target().velocity.y, 20.0)
	assert_almost_eq(_target().velocity.z, _moves.launcher.knockback.z, EPSILON)


func test_blowback_follows_the_aim_pitch() -> void:
	var smash := _moves.smash.duplicate() as MoveData
	smash.charge_level_ticks = PackedInt32Array()
	smash.knockback = Vector3(0, 0, -30)
	smash.step_distance = 0.0
	var stats := FighterStats.new()
	stats.move_set = MoveSet.new()
	stats.move_set.smash = smash
	_start(Vector3(0, 21.5, -1.5), Vector3(0, 20, 0), stats)
	_land_heavy()
	var velocity := _target().velocity
	assert_almost_eq(velocity.y, -velocity.z, 0.001, "45 degrees up toward the target")
	assert_almost_eq(velocity.length(), 30.0, 0.001)


func test_spike_slams_down_bounces_once_then_knocks_down() -> void:
	_start()
	_land_heavy(Vector2.ZERO, -1)
	assert_eq(_target().knockback_type, Knockback.SPIKE)
	assert_lt(_target().velocity.y, -20.0)
	_tick()
	assert_true(_target().spike_bounced, "bounces at once off the floor")
	assert_almost_eq(_target().velocity.y, _sim.hit_tuning.spike_bounce_speed, EPSILON)
	var peak := 0.0
	while _target().state == State.HITSTUN:
		peak = maxf(peak, _target().position.y)
		_tick()
	assert_gt(peak, _sim.tuning.ground_height + 0.5, "the bounce leaves the floor")
	assert_eq(_target().state, State.KNOCKDOWN)
	assert_eq(_target().position.y, _sim.tuning.ground_height)
	assert_eq(_target().combo_hits, 0, "the combo is over")


func test_a_new_spike_after_a_bounce_bounces_again() -> void:
	_start()
	_target().enter_state(State.HITSTUN)
	_target().stun_ticks = 60
	# Left over from an earlier spike in the combo.
	_target().spike_bounced = true
	_land_heavy(Vector2.ZERO, -1)
	assert_false(_target().spike_bounced)
	_tick()
	assert_true(_target().spike_bounced)
	assert_eq(_target().state, State.HITSTUN, "bounced, not knocked down")


func test_a_knocked_down_fighter_cannot_be_hit_and_stands_up_after_40_ticks() -> void:
	_start()
	_target().enter_state(State.KNOCKDOWN)
	_target().stun_ticks = _sim.hit_tuning.knockdown_ticks
	_tick(1, LIGHT)
	for _i in 20:
		_tick()
		assert_eq(_sim.events, [] as Array[Dictionary], "hits pass through")
	_tick(_sim.hit_tuning.knockdown_ticks - 21)
	assert_eq(_target().state, State.KNOCKDOWN, "down on its last tick")
	_tick()
	assert_eq(_target().state, State.IDLE)


func test_an_airborne_spike_too_high_to_reach_the_floor_recovers_in_flight() -> void:
	_start(Vector3(0, 80, -2), Vector3(0, 80, 0))
	_land_heavy(Vector2.ZERO, -1)
	_fly_out_hitstun()
	assert_eq(_target().state, State.FLYING)
	assert_false(_target().spike_bounced)


func test_sweep_pushes_the_target_to_the_side_the_attacker_pressed() -> void:
	for side in [1, -1]:
		_start()
		_land_heavy(Vector2(side, 0))
		assert_eq(_target().knockback_type, Knockback.SWEEP)
		var velocity := _target().velocity
		assert_almost_eq(velocity.x, side * 8.0, EPSILON, "sideways at the knockback speed")
		assert_almost_eq(velocity.z, 0.0, EPSILON)


func test_a_light_on_a_flying_target_stuns_it_in_the_air_then_it_flies_again() -> void:
	_start(Vector3(0, 10, -2), Vector3(0, 10, 0))
	_tick(1, LIGHT)
	for _i in 10:
		_tick()
	assert_eq(_target().state, State.HITSTUN)
	assert_eq(_target().combo_hits, 1)
	_fly_out_hitstun()
	assert_eq(_target().state, State.FLYING)
	assert_almost_eq(_target().position.y, 10.0, 0.01, "no gravity on a light juggle")


func test_a_launched_target_can_be_juggled_into_a_longer_combo() -> void:
	_start()
	_land_heavy(Vector2(0, -1))
	# Near the top of its flight, put the attacker beside it (as a rush would) and hit it again.
	_tick(28)
	assert_eq(_target().state, State.HITSTUN)
	_sim.fighters[0].position = _target().position + Vector3(0, 0.7, 1.6)
	_sim.fighters[0].enter_state(State.FLYING)
	_tick(1, LIGHT)
	for _i in 10:
		_tick()
		if not _sim.events.is_empty():
			break
	assert_eq(_target().state, State.HITSTUN)
	assert_eq(_target().combo_hits, 2)
