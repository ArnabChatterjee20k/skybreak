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


## Starts a sim with one fighter per position; fighter 0 is the one under test.
func _start(positions: Array) -> void:
	_sim = CombatSim.new()
	_tuning = _sim.tuning
	_previous = []
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

func test_tapping_dash_steps_exactly_the_dash_step_distance() -> void:
	_start([Vector3.ZERO])
	_drive(1, DASH, RIGHT)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.STEP)
	_drive(_tuning.dash_step_ticks - 1)
	assert_eq(_fighter().state, FighterState.State.DASHING, "step lasts dash_step_ticks")
	assert_almost_eq(_fighter().position.x, _tuning.dash_step_distance, EPSILON)
	_drive(1)
	assert_ne(_fighter().state, FighterState.State.DASHING)


func test_holding_dash_turns_the_step_into_a_sustained_dash() -> void:
	_start([Vector3(0, 50, 0)])
	_drive(_tuning.dash_step_ticks + 5, DASH, RIGHT)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.SUSTAINED)
	assert_almost_eq(_fighter().velocity.length(), _tuning.sustained_dash_speed, EPSILON)


func test_releasing_a_sustained_dash_returns_to_flight() -> void:
	_start([Vector3(0, 50, 0)])
	_drive(_tuning.dash_step_ticks + 5, DASH, RIGHT)
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


func test_a_neutral_dash_while_locked_on_rushes_the_target() -> void:
	_start([Vector3.ZERO, Vector3(30, 0, 0)])
	_drive(1, LOCK)
	_drive(1)
	_drive(1, DASH)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.RUSH)


func test_dashing_away_from_the_lock_on_target_is_a_plain_step() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -60)])
	_drive(1, LOCK)
	_drive(1)
	_drive(1, DASH, BACK)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.STEP)


func test_dashing_without_a_lock_on_is_never_a_rush() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -60)])
	_drive(1, DASH, FORWARD)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.STEP)


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


func test_a_neutral_vanish_step_goes_straight_back() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -60)])
	_drive(1, LOCK)
	_drive(1)
	_drive(1, DASH | BLOCK)
	assert_almost_eq(_fighter().position.z, _tuning.vanish_step_distance, EPSILON)


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
