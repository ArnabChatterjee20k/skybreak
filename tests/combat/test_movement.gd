extends GutTest

const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK
const LOCK := FighterInput.Action.LOCK_TOGGLE
const FORWARD := Vector2(0, 1)
const BACK := Vector2(0, -1)
const RIGHT := Vector2(1, 0)
const EPSILON := 0.001

var _sim: CombatSim
var _tuning: MovementTuning
var _previous: Array[FighterInput] = []
## False holds fighter 0's camera at yaw 0 in _drive_locked, as a camera that has not turned yet.
var _camera_follows := true


## Starts a sim with one fighter per position; fighter 0 is the one under test.
func _start(positions: Array) -> void:
	_sim = CombatSim.new()
	_tuning = _sim.tuning
	_previous = []
	_camera_follows = true
	for start_position in positions:
		_sim.add_fighter(start_position)
		_previous.append(FighterInput.new())


## Runs ticks with fighter 0 holding these controls; the others stand still.
func _drive(ticks: int, held: int = 0, move: Vector2 = Vector2.ZERO, vertical: int = 0,
		view_yaw: float = 0.0, target_switch: int = 0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		for j in _sim.fighters.size():
			var input := FighterInput.from_held(held if j == 0 else 0, _previous[j])
			if j == 0:
				input.move = move
				input.vertical = vertical
				input.view_yaw = view_yaw
				input.target_switch = target_switch
			inputs.append(input)
		_sim.tick(inputs)
		_previous = inputs


func _fighter() -> FighterState:
	return _sim.fighters[0]


func _planar_speed(fighter: FighterState) -> float:
	return Vector2(fighter.velocity.x, fighter.velocity.z).length()


# Ground

func test_a_fighter_starting_on_the_floor_stands_idle() -> void:
	_start([Vector3.ZERO])
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.IDLE)
	assert_true(_fighter().is_grounded())
	assert_almost_eq(_fighter().position.y, _tuning.ground_height, EPSILON)


func test_holding_forward_runs_on_the_ground_up_to_ground_speed() -> void:
	_start([Vector3.ZERO])
	_drive(120, 0, FORWARD)
	assert_eq(_fighter().state, FighterState.State.MOVING)
	assert_almost_eq(_planar_speed(_fighter()), _tuning.ground_speed, EPSILON)
	assert_almost_eq(_fighter().position.y, _tuning.ground_height, EPSILON)
	assert_lt(_fighter().position.z, 0.0, "forward at yaw 0 is -Z")


func test_letting_go_on_the_ground_slows_to_idle() -> void:
	_start([Vector3.ZERO])
	_drive(120, 0, FORWARD)
	_drive(120)
	assert_eq(_fighter().state, FighterState.State.IDLE)
	assert_eq(_fighter().velocity, Vector3.ZERO)


func test_move_is_relative_to_the_camera_yaw() -> void:
	_start([Vector3.ZERO])
	_drive(1, 0, FORWARD, 0, PI / 2)
	var camera_forward := Basis(Vector3.UP, PI / 2) * Vector3.FORWARD
	assert_lt(_fighter().velocity.normalized().distance_to(camera_forward), EPSILON)


func test_ascend_on_the_ground_jumps_into_flight() -> void:
	_start([Vector3.ZERO])
	_drive(1, 0, Vector2.ZERO, 1)
	assert_eq(_fighter().state, FighterState.State.FLYING)
	assert_gt(_fighter().position.y, _tuning.ground_height)


# Flight

func test_a_fighter_starting_above_the_floor_hovers_in_flight() -> void:
	_start([Vector3(0, 20, 0)])
	_drive(60)
	assert_eq(_fighter().state, FighterState.State.FLYING)
	assert_almost_eq(_fighter().position.y, 20.0, EPSILON)


func test_holding_ascend_in_flight_climbs_at_ascend_speed() -> void:
	_start([Vector3(0, 50, 0)])
	_drive(120, 0, Vector2.ZERO, 1)
	assert_almost_eq(_fighter().velocity.y, _tuning.ascend_speed, EPSILON)


func test_holding_descend_in_flight_sinks_at_descend_speed() -> void:
	_start([Vector3(0, 150, 0)])
	_drive(120, 0, Vector2.ZERO, -1)
	assert_almost_eq(_fighter().velocity.y, -_tuning.descend_speed, EPSILON)


func test_flying_forward_reaches_fly_speed_without_losing_height() -> void:
	_start([Vector3(0, 50, 0)])
	_drive(180, 0, FORWARD)
	assert_almost_eq(_planar_speed(_fighter()), _tuning.fly_speed, EPSILON)
	assert_almost_eq(_fighter().position.y, 50.0, EPSILON)


func test_descending_onto_the_floor_lands() -> void:
	_start([Vector3(0, 5, 0)])
	_drive(120, 0, Vector2.ZERO, -1)
	assert_true(_fighter().is_grounded())
	assert_almost_eq(_fighter().position.y, _tuning.ground_height, EPSILON)


# Falling

func test_a_falling_fighter_accelerates_downward_under_gravity() -> void:
	_start([Vector3(0, 100, 0)])
	_fighter().enter_state(FighterState.State.FALLING)
	_drive(1)
	assert_almost_eq(_fighter().velocity.y, -_tuning.gravity * CombatSim.TICK_SECONDS, EPSILON)


func test_a_falling_fighter_lands_on_the_floor() -> void:
	_start([Vector3(0, 30, 0)])
	_fighter().enter_state(FighterState.State.FALLING)
	_drive(600)
	assert_true(_fighter().is_grounded())
	assert_almost_eq(_fighter().position.y, _tuning.ground_height, EPSILON)


func test_ascend_while_falling_takes_back_flight() -> void:
	_start([Vector3(0, 100, 0)])
	_fighter().enter_state(FighterState.State.FALLING)
	_drive(1, 0, Vector2.ZERO, 1)
	assert_eq(_fighter().state, FighterState.State.FLYING)


# Dash

func test_tapping_dash_dodges_the_directional_distance_and_lasts_its_frames() -> void:
	_start([Vector3.ZERO])
	var dodge := _sim.dodge_tuning
	var total := dodge.directional_startup_ticks + dodge.directional_invuln_ticks + dodge.directional_recovery_ticks
	_drive(1, DASH, RIGHT)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.DODGE)
	_drive(total - 1)
	assert_eq(_fighter().state, FighterState.State.DASHING, "the dodge lasts its frames")
	assert_almost_eq(_fighter().position.x, dodge.directional_distance, EPSILON)
	_drive(1)
	assert_ne(_fighter().state, FighterState.State.DASHING)


func test_holding_dash_turns_the_step_into_a_sustained_dash() -> void:
	_start([Vector3(0, 50, 0)])
	_drive(_tuning.dash_step_ticks + 5, DASH, RIGHT)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.SUSTAINED)
	assert_almost_eq(_fighter().velocity.length(), _tuning.sustained_dash_speed, EPSILON)


func test_releasing_a_sustained_dash_returns_to_flight() -> void:
	_start([Vector3(0, 50, 0)])
	# Held past the dodge's last frame: a dash grown out of a dodge keeps its frames.
	_drive(40, DASH, RIGHT)
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.FLYING)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.NONE)


func test_a_sustained_dash_steers_with_the_move_input() -> void:
	_start([Vector3(0, 50, 0)])
	_drive(_tuning.dash_step_ticks + 1, DASH, RIGHT)
	_drive(1, DASH, FORWARD)
	assert_lt(_fighter().dash_direction.distance_to(Vector3.FORWARD), EPSILON)


func test_dashing_toward_the_lock_on_target_rushes_and_stops_in_front_of_it() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -60)])
	_drive(1, LOCK)
	assert_eq(_fighter().lock_on_target, 1)
	_drive(1)
	_drive(1, DASH, FORWARD)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.RUSH)
	var ticks := 0
	while _fighter().state == FighterState.State.DASHING and ticks <= _tuning.rush_max_ticks:
		_drive(1)
		ticks += 1
	assert_ne(_fighter().state, FighterState.State.DASHING, "the rush ends")
	var distance := _fighter().position.distance_to(_sim.fighters[1].position)
	assert_almost_eq(distance, _tuning.rush_stop_distance, 0.05)
	assert_eq(_fighter().velocity, Vector3.ZERO, "stops dead, ready for a follow-up")


func test_a_neutral_dash_tap_while_locked_on_is_a_spot_dodge() -> void:
	_start([Vector3.ZERO, Vector3(30, 0, 0)])
	_drive(1, LOCK)
	_drive(1)
	_drive(1, DASH)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.DODGE)
	assert_eq(_fighter().dodge.kind, FighterDodge.Kind.SPOT)


func test_dashing_away_from_the_lock_on_target_is_a_directional_dodge() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -60)])
	_drive(1, LOCK)
	_drive(1)
	_drive(1, DASH, BACK)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.DODGE)
	assert_eq(_fighter().dodge.kind, FighterDodge.Kind.DIRECTIONAL)


func test_dashing_without_a_lock_on_is_never_a_rush() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -60)])
	_drive(1, DASH, FORWARD)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.DODGE)


# Vanish step

func test_a_vanish_step_teleports_the_vanish_distance_and_waits_out_its_ticks() -> void:
	_start([Vector3.ZERO])
	_drive(1, DASH | BLOCK, RIGHT)
	assert_eq(_fighter().state, FighterState.State.VANISHING)
	assert_almost_eq(_fighter().position.x, _tuning.vanish_step_distance, EPSILON)
	assert_eq(_fighter().velocity, Vector3.ZERO)
	_drive(_tuning.vanish_step_ticks - 1)
	assert_eq(_fighter().state, FighterState.State.VANISHING)
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.IDLE)


func test_an_unlocked_neutral_vanish_step_goes_straight_back() -> void:
	_start([Vector3.ZERO])
	_drive(1, DASH | BLOCK)
	assert_almost_eq(_fighter().position.z, _tuning.vanish_step_distance, EPSILON, "yaw 0 faces -Z")


# Arena bounds

func test_fighters_cannot_fly_past_the_arena_walls() -> void:
	var half := CombatSim.new().tuning.arena_half_size
	_start([Vector3(half - 1, 50, 0)])
	_drive(120, 0, RIGHT)
	assert_almost_eq(_fighter().position.x, half, EPSILON)
	assert_eq(_fighter().velocity.x, 0.0)


func test_fighters_cannot_fly_above_the_ceiling() -> void:
	var ceiling := CombatSim.new().tuning.arena_ceiling
	_start([Vector3(0, ceiling - 1, 0)])
	_drive(120, 0, Vector2.ZERO, 1)
	assert_almost_eq(_fighter().position.y, ceiling, EPSILON)
	assert_eq(_fighter().velocity.y, 0.0)


func test_a_vanish_step_cannot_teleport_out_of_the_arena() -> void:
	var half := CombatSim.new().tuning.arena_half_size
	_start([Vector3(0, 0, -(half - 1))])
	_drive(1, DASH | BLOCK, FORWARD)
	assert_almost_eq(_fighter().position.z, -half, EPSILON)


# Lock-on and facing

func test_lock_toggle_locks_onto_the_nearest_opponent_then_unlocks() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -50), Vector3(0, 0, 10)])
	_drive(1, LOCK)
	assert_eq(_fighter().lock_on_target, 2)
	_drive(1)
	_drive(1, LOCK)
	assert_eq(_fighter().lock_on_target, -1)


func test_a_match_can_start_with_every_fighter_locked_onto_the_nearest_opponent() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -20)])
	_sim.lock_everyone_onto_nearest()
	assert_eq(_sim.fighters[0].lock_on_target, 1)
	assert_eq(_sim.fighters[1].lock_on_target, 0)


func test_target_switch_without_a_lock_does_nothing() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -50)])
	_drive(1, 0, Vector2.ZERO, 0, 0.0, 1)
	assert_eq(_fighter().lock_on_target, -1)


func test_target_switch_moves_the_lock_to_the_next_opponent() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -50), Vector3(0, 0, 10)])
	_drive(1, LOCK)
	_drive(1, 0, Vector2.ZERO, 0, 0.0, 1)
	assert_eq(_fighter().lock_on_target, 1, "wraps past the fighter itself")


func test_a_locked_on_fighter_faces_its_target() -> void:
	_start([Vector3.ZERO, Vector3(10, 0, 0)])
	_drive(1, LOCK)
	var facing := Basis(Vector3.UP, _fighter().facing_yaw) * Vector3.FORWARD
	assert_lt(facing.distance_to(Vector3.RIGHT), EPSILON)


func test_a_custom_movement_tuning_changes_the_feel() -> void:
	var tuning := MovementTuning.new()
	tuning.ground_speed = 3.0
	_sim = CombatSim.new(0, tuning)
	_tuning = tuning
	_sim.add_fighter(Vector3.ZERO)
	_previous = [FighterInput.new()]
	_drive(120, 0, FORWARD)
	assert_almost_eq(_planar_speed(_fighter()), 3.0, EPSILON)


# Playtest #1 regressions (T-D01b)

## Starts two hovering fighters 12 m apart, locked onto each other, as in the playtest.
func _start_locked_pair(height: float = 10.0) -> void:
	_start([Vector3(0, height, 6), Vector3(0, height, -6)])
	_sim.lock_everyone_onto_nearest()


## Heading from fighter 0 to its target, as a camera on the lock line sees it.
func _lock_yaw() -> float:
	var to_target := _sim.fighters[1].position - _fighter().position
	return atan2(-to_target.x, -to_target.z)


## Runs ticks with fighter 0's camera yawed camera_yaw_offset off the lock
## line, as the playtest camera was; fighter 1 holds target_vertical.
func _drive_locked(ticks: int, held: int, move: Vector2, camera_yaw_offset: float = 0.0,
		target_vertical: int = 0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		var input := FighterInput.from_held(held, _previous[0])
		input.move = move
		input.view_yaw = (_lock_yaw() if _camera_follows else 0.0) + camera_yaw_offset
		inputs.append(input)
		var other := FighterInput.from_held(0, _previous[1])
		other.vertical = target_vertical
		inputs.append(other)
		_sim.tick(inputs)
		_previous = inputs


func _gap() -> float:
	return _fighter().position.distance_to(_sim.fighters[1].position)


func _height_gap() -> float:
	return _fighter().position.y - _sim.fighters[1].position.y


func test_locked_strafing_orbits_the_target_at_the_strafe_start_radius() -> void:
	# Playtest: 12 -> 22.7 m in 5 s with the camera slightly off the lock line.
	_start_locked_pair()
	var widest := 0.0
	for _i in 300:
		_drive_locked(1, 0, RIGHT, -0.05)
		widest = maxf(widest, absf(_gap() - 12.0))
	assert_lt(widest, 0.01, "gap after 5 s: %.2f m (drifted up to %.2f m)" % [_gap(), widest])
	assert_almost_eq(_height_gap(), 0.0, EPSILON)


func test_locked_strafing_keeps_the_radius_even_with_the_camera_on_the_lock_line() -> void:
	_start_locked_pair()
	_drive_locked(300, 0, -RIGHT)
	assert_almost_eq(_gap(), 12.0, 0.01, "gap after 5 s: %.2f m" % _gap())


func test_locked_strafing_on_the_ground_orbits_too() -> void:
	_start([Vector3(0, 0, 6), Vector3(0, 0, -6)])
	_sim.lock_everyone_onto_nearest()
	_drive_locked(180, 0, RIGHT, 0.3)
	assert_almost_eq(_gap(), 12.0, 0.01, "gap after 3 s: %.2f m" % _gap())


func test_forward_and_back_while_locked_change_the_orbit_radius() -> void:
	_start_locked_pair()
	_drive_locked(20, 0, Vector2(1, 1).normalized())
	assert_lt(_gap(), 12.0 - 1.0, "W+D closes in")
	_drive_locked(60, 0, RIGHT)
	var settled := _gap()
	_drive_locked(60, 0, RIGHT)
	assert_almost_eq(_gap(), settled, 0.01, "once the approach momentum is gone, a strafe holds the radius")
	_drive_locked(60, 0, BACK)
	assert_gt(_gap(), settled + 5.0, "S backs off")


func test_a_locked_dash_away_goes_straight_back_along_the_line_from_the_target() -> void:
	# Playtest: a 1.8 s sustained dash-away drifted 22 m sideways.
	_start_locked_pair()
	_drive_locked(108, DASH, BACK, 0.1)
	var away := _fighter().position - _sim.fighters[1].position
	var sideways := Vector2(away.x, 0.0).length()
	assert_gt(away.z, 90.0, "it went back")
	assert_lt(sideways, 0.01, "sideways drift %.1f m over %.0f m" % [sideways, away.z])


func test_a_locked_back_dodge_goes_straight_back() -> void:
	_start_locked_pair()
	_drive_locked(1, DASH, BACK, 0.4)
	_drive_locked(20, 0, Vector2.ZERO, 0.4)
	assert_almost_eq(_fighter().position.x, 0.0, EPSILON)
	assert_almost_eq(_gap(), 12.0 + _sim.dodge_tuning.directional_distance, 0.01)


func test_a_locked_sidestep_curves_around_the_target_by_its_arc() -> void:
	_start_locked_pair()
	_drive_locked(1, DASH, RIGHT)
	_drive_locked(20, 0, Vector2.ZERO)
	assert_almost_eq(_gap(), 12.0, 0.01)
	var offset := _fighter().position - _sim.fighters[1].position
	var turned := rad_to_deg(Vector2(offset.z, offset.x).angle())
	assert_almost_eq(absf(turned), _sim.dodge_tuning.sidestep_arc_degrees, 0.5, "past the orbit cap")


func test_the_rush_brakes_over_rush_brake_ticks_instead_of_stopping_dead() -> void:
	# Playtest: 80 -> 0 m/s in one tick.
	_start([Vector3(0, 10, 0), Vector3(0, 10, -60)])
	_sim.lock_everyone_onto_nearest()
	_drive(1, DASH, FORWARD)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.RUSH)
	var speeds: Array[float] = [_fighter().velocity.length()]
	while _fighter().state == FighterState.State.DASHING and speeds.size() <= _tuning.rush_max_ticks:
		_drive(1)
		speeds.append(_fighter().velocity.length())
	var biggest_drop := 0.0
	var braking := 0
	for i in range(1, speeds.size()):
		biggest_drop = maxf(biggest_drop, speeds[i - 1] - speeds[i])
		if speeds[i] > 0.0 and speeds[i] < _tuning.rush_speed - EPSILON:
			braking += 1
	var even_drop := _tuning.rush_speed / _tuning.rush_brake_ticks
	assert_lt(biggest_drop, even_drop * 1.5, "biggest one-tick drop %.1f m/s" % biggest_drop)
	assert_between(braking, _tuning.rush_brake_ticks - 2, _tuning.rush_brake_ticks + 2,
		"braking ticks: %d" % braking)
	assert_almost_eq(_gap(), _tuning.rush_stop_distance, 0.05, "still arrives at the stop distance")
	assert_eq(_fighter().velocity, Vector3.ZERO)


func test_a_locked_sideways_vanish_keeps_the_distance_and_height_to_the_target() -> void:
	# Playtest: two side vanishes before the camera turned took the gap 12 -> 17 m,
	# and the height fell 0.8 m behind a target that was still climbing.
	_start_locked_pair()
	_camera_follows = false
	_drive_locked(1, DASH | BLOCK, RIGHT, 0.0, 1)
	_drive_locked(5, 0, Vector2.ZERO, 0.0, 1)
	_drive_locked(_tuning.vanish_step_ticks - 6, 0, Vector2.ZERO)
	assert_eq(_fighter().state, FighterState.State.VANISHING)
	var first := "after one: gap %.2f m, height %.2f m" % [_gap(), _height_gap()]
	assert_almost_eq(_height_gap(), 0.0, 0.01, first)
	_drive_locked(60, 0, Vector2.ZERO)
	_drive_locked(1, DASH | BLOCK, RIGHT)
	_drive_locked(_tuning.vanish_step_ticks - 1, 0, Vector2.ZERO)
	assert_almost_eq(_gap(), 12.0, 0.01, "%s; after two: gap %.2f m" % [first, _gap()])


func test_a_locked_neutral_vanish_keeps_the_offset_to_the_target() -> void:
	_start_locked_pair()
	var offset := _fighter().position - _sim.fighters[1].position
	_drive_locked(1, DASH | BLOCK, Vector2.ZERO, 0.0, 1)
	_drive_locked(_tuning.vanish_step_ticks - 1, 0, Vector2.ZERO, 0.0, 1)
	var now := _fighter().position - _sim.fighters[1].position
	assert_lt(now.distance_to(offset), 0.01)


func test_a_locked_vanish_toward_or_away_changes_the_distance_by_the_vanish_distance() -> void:
	_start_locked_pair()
	_drive_locked(1, DASH | BLOCK, FORWARD)
	assert_almost_eq(_gap(), 12.0 - _tuning.vanish_step_distance, 0.01)
	_start_locked_pair()
	_drive_locked(1, DASH | BLOCK, BACK, 0.5)
	assert_almost_eq(_gap(), 12.0 + _tuning.vanish_step_distance, 0.01)


func test_holding_block_then_pressing_dash_vanishes() -> void:
	_start([Vector3(0, 10, 0)])
	_drive(20, BLOCK)
	assert_eq(_fighter().state, FighterState.State.BLOCKING)
	_drive(1, BLOCK | DASH, RIGHT)
	assert_eq(_fighter().state, FighterState.State.VANISHING)


func test_holding_dash_then_pressing_block_vanishes() -> void:
	_start([Vector3(0, 10, 0)])
	_drive(20, DASH, RIGHT)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.SUSTAINED)
	_drive(1, DASH | BLOCK, RIGHT)
	assert_eq(_fighter().state, FighterState.State.VANISHING)


## Vertical speed each tick after letting go, until it settles at 0 (or max_ticks).
func _vertical_speeds_after_release(max_ticks: int) -> Array[float]:
	var speeds: Array[float] = [_fighter().velocity.y]
	while speeds.size() <= max_ticks and _fighter().velocity.y != 0.0:
		_drive(1)
		speeds.append(_fighter().velocity.y)
	return speeds


func test_releasing_ascend_eases_the_climb_out_instead_of_stopping_dead() -> void:
	_start([Vector3(0, 50, 0)])
	_drive(60, 0, Vector2.ZERO, 1)
	var speeds := _vertical_speeds_after_release(120)
	var first_drop := speeds[0] - speeds[1]
	var last_drop := speeds[speeds.size() - 2] - speeds[speeds.size() - 1]
	assert_lt(last_drop, first_drop * 0.5, "drops %s" % str(speeds))
	assert_lte(speeds.size() - 1, _tuning.climb_ease_out_ticks + 1, "settles in %d ticks" % (speeds.size() - 1))
	assert_almost_eq(speeds[speeds.size() - 1], 0.0, EPSILON)


func test_releasing_descend_eases_the_dive_out() -> void:
	_start([Vector3(0, 150, 0)])
	_drive(60, 0, Vector2.ZERO, -1)
	var speeds := _vertical_speeds_after_release(120)
	var first_drop := speeds[1] - speeds[0]
	var last_drop := speeds[speeds.size() - 1] - speeds[speeds.size() - 2]
	assert_lt(last_drop, first_drop * 0.5, "drops %s" % str(speeds))
	assert_almost_eq(speeds[speeds.size() - 1], 0.0, EPSILON)
