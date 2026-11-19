extends GutTest

const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const CHARGE := FighterInput.Action.CHARGE
const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK
const FORWARD := Vector2(0, 1)
const BACK := Vector2(0, -1)
const RIGHT := Vector2(1, 0)
const LEFT := Vector2(-1, 0)
const Phase := FighterState.AttackPhase
const EPSILON := 0.0001

var _sim: CombatSim
var _moves: MoveSet
var _previous: Array[FighterInput] = []


## Fighter 0 on the floor at the origin, fighter 1 six metres ahead (-Z), both locked on.
func _start(target := Vector3(0, 0, -6), locked := true) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(target)
	if locked:
		_sim.lock_everyone_onto_nearest()
	_moves = _fighter().stats.move_set
	_previous = [FighterInput.new(), FighterInput.new()]


## Runs ticks with fighter 0 holding these controls; fighter 1 stands still.
func _drive(ticks: int, held: int = 0, move: Vector2 = Vector2.ZERO, vertical: int = 0,
		view_yaw: float = 0.0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]),
			FighterInput.from_held(0, _previous[1]),
		]
		inputs[0].move = move
		inputs[0].vertical = vertical
		inputs[0].view_yaw = view_yaw
		_sim.tick(inputs)
		_previous = inputs


func _fighter() -> FighterState:
	return _sim.fighters[0]


## Ticks with neutral input until fighter 0 stops attacking; returns [move id, phase] per tick.
func _record_until_free(first: Array) -> Array:
	var timeline: Array = [first]
	while _fighter().state == FighterState.State.ATTACKING and timeline.size() < 300:
		_drive(1)
		timeline.append([_fighter().move_id(), _fighter().attack_phase()])
	return timeline


func _now() -> Array:
	return [_fighter().move_id(), _fighter().attack_phase()]


func _assert_frame_data(move: MoveData, timeline: Array) -> void:
	var counts := {Phase.STARTUP: 0, Phase.ACTIVE: 0, Phase.RECOVERY: 0}
	for entry: Array in timeline:
		if entry[0] == move.id and counts.has(entry[1]):
			counts[entry[1]] += 1
	assert_eq(counts[Phase.STARTUP], move.startup_ticks, "%s startup" % move.id)
	assert_eq(counts[Phase.ACTIVE], move.active_ticks, "%s active" % move.id)
	assert_eq(counts[Phase.RECOVERY], move.recovery_ticks, "%s recovery" % move.id)


## Presses heavy for one tick with this direction, then lets go.
func _heavy(move := Vector2.ZERO, vertical := 0) -> void:
	_drive(1, HEAVY, move, vertical)


# Frame data

func test_every_heavy_goes_through_startup_active_and_recovery_with_its_tick_counts() -> void:
	var cases := [
		["smash", Vector2.ZERO, 0], ["breaker", FORWARD, 0], ["launcher", BACK, 0],
		["rising", Vector2.ZERO, 1], ["spike", Vector2.ZERO, -1], ["sweep", RIGHT, 0],
	]
	for case: Array in cases:
		_start()
		var move := _moves.get(case[0]) as MoveData
		_heavy(case[1], case[2])
		var timeline := _record_until_free(_now())
		_assert_frame_data(move, timeline)
		assert_eq(timeline.size(), move.total_ticks() + 1, "free right after recovery")
		assert_eq(_fighter().state, FighterState.State.IDLE)


func test_every_light_goes_through_startup_active_and_recovery_with_its_tick_counts() -> void:
	for number in range(1, _light_count() + 1):
		_start()
		var timeline := _play_string_to(number)
		_assert_frame_data(_moves.light_string[number - 1], timeline)


func test_every_charged_smash_level_goes_through_its_tick_counts() -> void:
	var thresholds := _moves.smash.charge_level_ticks
	for level in range(1, thresholds.size() + 1):
		_start()
		_drive(thresholds[level - 1], HEAVY)
		if level < thresholds.size():
			_drive(1)
		var timeline := _record_until_free(_now())
		_assert_frame_data(_moves.charged_smash[level - 1], timeline)


func test_push_block_goes_through_its_tick_counts() -> void:
	_start()
	_drive(1, BLOCK)
	_drive(1, BLOCK | HEAVY)
	assert_eq(_fighter().move_id(), _moves.push_block.id)
	_assert_frame_data(_moves.push_block, _record_until_free(_now()))


func test_the_phase_tick_counts_from_the_start_of_each_phase() -> void:
	_start()
	_heavy()
	assert_eq(_fighter().phase_tick(), 0)
	_drive(_moves.smash.startup_ticks)
	assert_eq(_fighter().attack_phase(), Phase.ACTIVE)
	assert_eq(_fighter().phase_tick(), 0)
	_drive(1)
	assert_eq(_fighter().phase_tick(), 1)


# Directional heavies

func test_each_heavy_direction_picks_its_move_when_locked_on() -> void:
	var cases := [
		[Vector2.ZERO, 0, "smash"], [FORWARD, 0, "breaker"], [BACK, 0, "launcher"],
		[RIGHT, 0, "sweep"], [LEFT, 0, "sweep"], [Vector2.ZERO, 1, "rising"],
		[Vector2.ZERO, -1, "spike"], [FORWARD, 1, "rising"], [BACK, -1, "spike"],
	]
	for case: Array in cases:
		_start()
		_heavy(case[0], case[1])
		assert_eq(_fighter().move_id(), StringName(case[2]), "move %s vertical %d" % [case[0], case[1]])


func test_heavy_direction_is_relative_to_the_target_not_the_camera() -> void:
	_start(Vector3(6, 0, 0))
	# Camera yaw -90 degrees turns forward input toward +X, where the target is.
	_drive(1, HEAVY, FORWARD, 0, -PI / 2)
	assert_eq(_fighter().move_id(), &"breaker")
	_start(Vector3(6, 0, 0))
	_drive(1, HEAVY, FORWARD)
	assert_eq(_fighter().move_id(), &"sweep", "forward on camera is sideways to the target")


func test_heavy_direction_is_relative_to_the_facing_when_unlocked() -> void:
	_start(Vector3(0, 0, -60), false)
	_heavy(FORWARD)
	assert_eq(_fighter().move_id(), &"breaker")
	_start(Vector3(0, 0, -60), false)
	_heavy(BACK)
	assert_eq(_fighter().move_id(), &"launcher")


func test_heavy_while_blocking_is_a_push_block() -> void:
	_start()
	_drive(1, BLOCK, FORWARD)
	_drive(1, BLOCK | HEAVY, FORWARD)
	assert_eq(_fighter().move_id(), &"push_block")


func test_a_light_press_starts_the_first_light() -> void:
	_start()
	_drive(1, LIGHT)
	assert_eq(_fighter().state, FighterState.State.ATTACKING)
	assert_eq(_fighter().move_id(), _moves.light_string[0].id)
	assert_eq(_fighter().string_index, 1)


# Charged smash

func test_a_tapped_heavy_is_a_plain_smash() -> void:
	_start()
	var timeline: Array = []
	for _tick in _moves.smash.charge_level_ticks[0] - 1:
		_drive(1, HEAVY)
		timeline.append(_now())
	_drive(1)
	assert_eq(_fighter().move_id(), &"smash")
	assert_eq(_fighter().charge_level, 0)
	timeline.append_array(_record_until_free(_now()))
	_assert_frame_data(_moves.smash, timeline)


func test_holding_heavy_reaches_each_charge_level_at_its_threshold() -> void:
	_start()
	var thresholds := _moves.smash.charge_level_ticks
	_drive(thresholds[0] - 1, HEAVY)
	assert_eq(_fighter().attack_phase(), Phase.STARTUP, "still a smash one tick before level 1")
	_drive(1, HEAVY)
	assert_eq(_fighter().attack_phase(), Phase.HOLD)
	assert_eq(_fighter().charge_level, 1)
	_drive(thresholds[1] - thresholds[0] - 1, HEAVY)
	assert_eq(_fighter().charge_level, 1)
	_drive(1, HEAVY)
	assert_eq(_fighter().charge_level, 2)


func test_releasing_heavy_performs_the_charged_smash_at_the_reached_level() -> void:
	_start()
	_drive(_moves.smash.charge_level_ticks[1], HEAVY)
	_drive(1)
	assert_eq(_fighter().move_id(), &"charged_smash_2")
	assert_eq(_fighter().charge_level, 2)
	assert_eq(_fighter().attack_phase(), Phase.STARTUP)


func test_reaching_the_top_level_performs_it_without_releasing() -> void:
	_start()
	_drive(_moves.smash.charge_level_ticks[2], HEAVY)
	assert_eq(_fighter().move_id(), &"charged_smash_3")
	assert_eq(_fighter().charge_level, 3)


func test_a_heavy_pressed_again_after_letting_go_does_not_resume_the_charge() -> void:
	_start()
	_drive(5, HEAVY)
	_drive(1)
	_drive(20, HEAVY)
	assert_eq(_fighter().move_id(), &"smash")
	assert_ne(_fighter().attack_phase(), Phase.HOLD)


func test_the_level_3_charged_smash_is_armored_through_startup_and_active() -> void:
	_start()
	_drive(_moves.smash.charge_level_ticks[2], HEAVY)
	var move := _moves.charged_smash[2]
	for _tick in move.recovery_start_tick():
		assert_true(_fighter().is_armored(), "armored at move tick %d" % _fighter().move_tick)
		_drive(1)
	assert_false(_fighter().is_armored(), "no armor in recovery")


func test_lower_charge_levels_have_no_armor() -> void:
	_start()
	_drive(_moves.smash.charge_level_ticks[1], HEAVY)
	_drive(1)
	for _tick in _moves.charged_smash[1].total_ticks() - 1:
		assert_false(_fighter().is_armored())
		_drive(1)


func test_holding_a_charge_keeps_the_fighter_in_place() -> void:
	_start()
	_drive(_moves.smash.charge_level_ticks[0], HEAVY)
	assert_eq(_fighter().attack_phase(), Phase.HOLD)
	var held_at := _fighter().position
	_drive(10, HEAVY)
	assert_eq(_fighter().position, held_at)


# Invincibility

func test_rising_is_upper_body_invincible_on_frames_4_to_9() -> void:
	_start()
	_heavy(Vector2.ZERO, 1)
	for move_tick in _moves.rising.total_ticks():
		var expected := move_tick >= 3 and move_tick <= 8
		assert_eq(_fighter().is_invincible_to(true), expected, "upper body at tick %d" % move_tick)
		assert_false(_fighter().is_invincible_to(false), "lower body at tick %d" % move_tick)
		_drive(1)


# Charging and movement

func test_an_attack_press_cancels_charging_and_attacks_on_the_same_tick() -> void:
	_start()
	_drive(10, CHARGE)
	_drive(1, CHARGE | LIGHT)
	assert_eq(_fighter().move_id(), &"light_1")
	assert_eq(_fighter().move_tick, 0)
	_start()
	_drive(10, CHARGE)
	_drive(1, CHARGE | HEAVY)
	assert_eq(_fighter().move_id(), &"smash")


func test_movement_is_locked_during_an_attack_except_its_step() -> void:
	_start()
	_drive(1, HEAVY, FORWARD)
	var move := _moves.breaker
	_drive(move.total_ticks() - 2, 0, RIGHT)
	assert_eq(_fighter().state, FighterState.State.ATTACKING)
	assert_almost_eq(_fighter().position.z, -move.step_distance, EPSILON, "stepped toward the target")
	assert_almost_eq(_fighter().position.x, 0.0, EPSILON, "strafe input did nothing")


func test_the_step_is_spread_over_startup_and_stops_at_active() -> void:
	_start()
	_heavy()
	_drive(_moves.smash.startup_ticks - 1)
	var after_startup := _fighter().position
	assert_almost_eq(after_startup.z, -_moves.smash.step_distance, EPSILON)
	_drive(5)
	assert_eq(_fighter().position, after_startup)


func test_attacking_in_flight_hovers_and_returns_to_flight() -> void:
	_start(Vector3(0, 40, -6))
	_fighter().position.y = 40.0
	_fighter().enter_state(FighterState.State.FLYING)
	_drive(1, LIGHT, Vector2.ZERO, -1)
	assert_eq(_fighter().state, FighterState.State.ATTACKING)
	_drive(_moves.light_string[0].total_ticks() - 1, 0, Vector2.ZERO, -1)
	assert_eq(_fighter().position.y, 40.0, "descend input ignored while attacking")
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.FLYING)


func test_ascend_during_a_ground_attack_does_not_take_off() -> void:
	_start()
	_drive(1, LIGHT)
	_drive(5, 0, Vector2.ZERO, 1)
	assert_eq(_fighter().state, FighterState.State.ATTACKING)
	assert_eq(_fighter().position.y, _sim.tuning.ground_height)


func test_a_dash_cannot_start_during_an_attack() -> void:
	_start()
	_heavy()
	_drive(1, DASH, RIGHT)
	assert_eq(_fighter().state, FighterState.State.ATTACKING)


func test_an_attack_keeps_its_facing_while_the_target_moves() -> void:
	_start()
	_heavy()
	var facing := _fighter().facing_yaw
	_sim.fighters[1].position = Vector3(6, 1, 0)
	_drive(5)
	assert_eq(_fighter().facing_yaw, facing)


# Input buffer

func test_a_light_pressed_late_in_a_heavy_comes_out_on_the_tick_it_ends() -> void:
	_start()
	_heavy()
	var total := _moves.smash.total_ticks()
	_drive(total - 4)
	_drive(1, LIGHT)
	_drive(2)
	assert_eq(_fighter().move_id(), &"smash", "still in the smash's last tick")
	_drive(1)
	assert_eq(_fighter().move_id(), &"light_1", "came out on the first free tick")
	assert_eq(_fighter().move_tick, 0)


func test_a_light_pressed_too_long_before_a_heavy_ends_is_lost() -> void:
	_start()
	_heavy()
	_drive(_moves.smash.total_ticks() - CombatSim.INPUT_BUFFER_TICKS - 2)
	_drive(1, LIGHT)
	_drive(CombatSim.INPUT_BUFFER_TICKS + 2)
	assert_eq(_fighter().state, FighterState.State.IDLE)


func test_a_heavy_pressed_during_a_vanish_step_comes_out_when_it_ends() -> void:
	_start()
	_drive(1, DASH | FighterInput.Action.BLOCK)
	_drive(_sim.tuning.vanish_step_ticks - 3)
	_heavy()
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.VANISHING)
	_drive(1)
	assert_eq(_fighter().move_id(), &"smash")


# Hitboxes

func test_there_are_no_hitboxes_outside_the_active_phase() -> void:
	_start()
	_heavy()
	assert_true(_fighter().active_hitboxes().is_empty(), "none in startup")
	_drive(_moves.smash.startup_ticks)
	assert_eq(_fighter().active_hitboxes().size(), 1, "one in active")
	_drive(_moves.smash.active_ticks)
	assert_true(_fighter().active_hitboxes().is_empty(), "none in recovery")


func test_world_space_hitboxes_follow_the_facing() -> void:
	for target: Vector3 in [Vector3(0, 0, -6), Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6)]:
		_start(target)
		_drive(1, LIGHT)
		_drive(_moves.light_string[0].startup_ticks)
		var light := _moves.light_string[0]
		var box: Dictionary = _fighter().active_hitboxes()[0]
		var to_target := (target - Vector3(0, target.y, 0)).normalized()
		var local := light.hitbox_offsets[0]
		var expected := _fighter().position + to_target * -local.z + Vector3.UP * local.y
		assert_almost_eq((box.start as Vector3).distance_to(expected), 0.0, EPSILON, "towards %s" % target)
		assert_eq(box.start, box.end, "a sphere")
		assert_eq(box.radius, light.hitbox_radii[0])


func test_capsule_hitboxes_turn_with_the_facing() -> void:
	_start(Vector3(6, 0, 0))
	_drive(1, HEAVY, BACK, 0, -PI / 2)
	assert_eq(_fighter().move_id(), &"launcher")
	_drive(_moves.launcher.startup_ticks)
	var box: Dictionary = _fighter().active_hitboxes()[0]
	var axis := (box.end as Vector3) - (box.start as Vector3)
	assert_almost_eq(axis.normalized().dot(Vector3.UP), 1.0, EPSILON, "vertical capsule stays vertical")
	assert_almost_eq(axis.length(), _moves.launcher.hitbox_lengths[0], EPSILON)
	var centre := ((box.start as Vector3) + (box.end as Vector3)) * 0.5
	assert_gt(centre.x, _fighter().position.x, "in front, toward the target at +X")


func test_hitboxes_move_per_active_tick() -> void:
	_start()
	_heavy(Vector2.ZERO, -1)
	_drive(_moves.spike.startup_ticks)
	var first: Vector3 = _fighter().active_hitboxes()[0].start
	_drive(1)
	var second: Vector3 = _fighter().active_hitboxes()[0].start
	assert_lt(second.y, first.y, "spike's hitbox comes down")


func _light_count() -> int:
	return _moves.light_string.size()


## Presses light at each window opening until light number is out, then lets it play out.
## Returns [move id, phase] per tick from the first press.
func _play_string_to(number: int) -> Array:
	_drive(1, LIGHT)
	var timeline: Array = [_now()]
	while _fighter().state == FighterState.State.ATTACKING and timeline.size() < 300:
		var fighter := _fighter()
		var press := fighter.string_index < number \
			and fighter.move_tick + 1 == fighter.move.string_window_start_tick
		_drive(1, LIGHT if press else 0)
		timeline.append(_now())
	return timeline
