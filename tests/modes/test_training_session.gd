extends GutTest
## Training room rules: refills, KO protection, reset, weapon spawner, input display.

const Bench := preload("res://tests/modes/training_bench.gd")
const State := FighterState.State
const UNIT := FighterState.METER_UNIT
const LIGHT := FighterInput.Action.LIGHT
const DASH := FighterInput.Action.DASH

var _bench: Bench


func before_each() -> void:
	_bench = Bench.new()


func test_reset_puts_the_pair_at_the_centre_inside_light_range() -> void:
	_bench.move = Vector2(1, 0)
	_bench.tick(60)
	_bench.session.reset_positions()
	var gap := _bench.player().position.distance_to(_bench.dummy().position)
	assert_almost_eq(gap, TrainingSession.RESET_GAP, 0.001)
	assert_eq(_bench.player().state, State.IDLE)
	assert_eq(_bench.player().lock_on_target, 1)
	assert_eq(_bench.dummy().lock_on_target, 0)


func test_infinite_meters_keep_ki_full_after_dashing() -> void:
	# A rush dash costs ki (a dodge is free).
	_bench.move = Vector2(0, 1)
	_bench.tap(DASH)
	_bench.tick(3)
	assert_eq(_bench.player().ki, _bench.sim.meter_tuning.ki_max * UNIT)


func test_without_infinite_meters_dashing_spends_ki() -> void:
	_bench.session.infinite_meters = false
	# A rush dash costs ki (a dodge is free).
	_bench.move = Vector2(0, 1)
	_bench.tap(DASH)
	assert_lt(_bench.player().ki, _bench.sim.meter_tuning.ki_max * UNIT)


func test_infinite_health_refills_once_the_combo_ends() -> void:
	_bench.tap(LIGHT)
	_bench.tick(6)
	var hurt := _bench.dummy().health
	assert_lt(hurt, _bench.dummy().stats.max_health * UNIT, "damage shows during the combo")
	_bench.tick(60)
	assert_eq(_bench.dummy().health, _bench.dummy().stats.max_health * UNIT)


func test_without_infinite_health_damage_stays() -> void:
	_bench.session.infinite_health = false
	_bench.tap(LIGHT)
	_bench.tick(60)
	assert_eq(_bench.dummy().health, (10_000 - 300) * UNIT)


func test_a_knockout_resets_the_room_instead_of_ending_it() -> void:
	_bench.session.infinite_health = false
	_bench.dummy().health = 1 * UNIT
	_bench.tap(LIGHT)
	_bench.tick(10)
	assert_false(_bench.sim.round_over)
	assert_eq(_bench.dummy().health, _bench.dummy().stats.max_health * UNIT)


func test_spawned_weapon_lands_in_reach_and_can_be_picked_up() -> void:
	var pickup := _bench.session.spawn_weapon(Weapon.Kind.STORM_BLADE)
	assert_eq(_bench.sim.pickup_in_reach(0), _bench.sim.pickups.find(pickup))
	_bench.tap(FighterInput.Action.PICKUP)
	_bench.tick(10)
	assert_eq(_bench.player().held_weapon(), Weapon.Kind.STORM_BLADE)


func test_spawned_ranged_weapon_comes_loaded() -> void:
	var pickup := _bench.session.spawn_weapon(Weapon.Kind.ARC_REVOLVER)
	assert_eq(pickup.ammo, Weapon.RANGED_STATS[Weapon.Kind.ARC_REVOLVER].ammo)


func test_input_display_merges_held_ticks() -> void:
	_bench.move = Vector2(0, 1)
	_bench.tick(5)
	_bench.move = Vector2.ZERO
	_bench.held = LIGHT
	_bench.tick(2)
	var rows := _bench.session.input_history.rows
	assert_eq(rows[0].text, "L")
	assert_eq(rows[0].ticks, 2)
	assert_eq(rows[1].text, "↑")
	assert_eq(rows[1].ticks, 5)
