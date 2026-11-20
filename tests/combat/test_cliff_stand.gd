extends GutTest
## QA-12c: a fighter on the floor walks up slopes but stops at a cliff face
## instead of standing on it.

const RIGHT := Vector2(1.0, 0.0)

var _sim: CombatSim


## Flat at 0 for x < 2, then a face rising 4 m per metre (about 76 degrees) to 40 m.
static func _cliff(x: float, _z: float, _y: float) -> float:
	return clampf((x - 2.0) * 4.0, 0.0, 40.0)


## A 30 degree slope rising toward +x.
static func _slope(x: float, _z: float, _y: float) -> float:
	return maxf(x, 0.0) * 0.57735


func _start(ground: Callable) -> FighterState:
	_sim = CombatSim.new(3)
	_sim.ground_height = ground
	var fighter := _sim.add_fighter(Vector3(0.0, _sim.tuning.ground_height, 0.0))
	_sim.settle(fighter)
	return fighter


func _walk(direction: Vector2, ticks: int, check: Callable = Callable()) -> void:
	for _i in ticks:
		var input := FighterInput.new()
		input.move = direction
		_sim.tick([input])
		if check.is_valid():
			check.call()


func test_a_fighter_walking_into_a_cliff_stops_at_its_foot() -> void:
	var fighter := _start(_cliff)
	_walk(RIGHT, 120)
	assert_true(fighter.is_grounded(), "still on the floor, %s" % FighterState.State.keys()[fighter.state])
	assert_lt(fighter.position.y, _sim.tuning.ground_height + 0.3, "not up the face: y %.2f" % fighter.position.y)
	assert_lt(fighter.position.x, 2.2, "stopped at the foot: x %.2f" % fighter.position.x)


func test_the_stand_height_never_jumps_up_a_cliff_in_one_tick() -> void:
	var fighter := _start(_cliff)
	var last := [fighter.stand_height]
	var worst := [0.0]
	_walk(RIGHT, 120, func() -> void:
		worst[0] = maxf(worst[0], fighter.stand_height - last[0])
		last[0] = fighter.stand_height)
	assert_lt(worst[0], 0.35, "largest rise per tick %.2f m" % worst[0])


func test_a_fighter_still_walks_up_a_30_degree_slope() -> void:
	var fighter := _start(_slope)
	_walk(RIGHT, 60)
	assert_gt(fighter.position.x, 5.0, "walked up the slope: x %.2f" % fighter.position.x)
	assert_almost_eq(fighter.position.y, _sim.tuning.ground_height + fighter.position.x * 0.57735, 0.05)


func test_a_fighter_flying_up_a_cliff_is_not_stopped() -> void:
	var fighter := _start(_cliff)
	for _i in 30:
		var input := FighterInput.new()
		input.vertical = 1
		input.move = RIGHT
		_sim.tick([input])
	assert_gt(fighter.position.x, 2.5, "flew over the foot of the cliff: x %.2f" % fighter.position.x)


func test_the_flat_floor_has_no_cliff_rule() -> void:
	var fighter := _start(Callable())
	_walk(RIGHT, 30)
	assert_eq(fighter.position.y, _sim.tuning.ground_height)
	assert_gt(fighter.position.x, 4.0)


func test_walking_across_a_cliff_at_an_angle_does_not_climb_it() -> void:
	# Across the 76 degree face at about 24 degrees the path rises only 1.6 per metre.
	var fighter := _start(_cliff)
	_walk(Vector2(0.4, 0.92), 240)
	assert_lt(fighter.position.y, _sim.tuning.ground_height + 0.3, "not up the face: y %.2f" % fighter.position.y)


func test_creeping_into_a_cliff_in_tiny_steps_does_not_climb_it() -> void:
	var fighter := _start(_cliff)
	_walk(RIGHT, 120)
	for _i in 60:
		_walk(RIGHT, 1)
		_walk(Vector2.ZERO, 6)
	assert_lt(fighter.position.y, _sim.tuning.ground_height + 0.3, "not up the face: y %.2f" % fighter.position.y)


func test_the_leading_foot_stops_short_of_the_cliff_face() -> void:
	var fighter := _start(_cliff)
	_walk(RIGHT, 120)
	assert_lt(fighter.position.x, 1.8, "a foot's reach before the face at x 2: x %.2f" % fighter.position.x)
	assert_gt(fighter.position.x, 1.4, "but close to it: x %.2f" % fighter.position.x)


## Puts the fighter in a tech roll of ticks ticks with velocity.
func _roll(fighter: FighterState, velocity: Vector3, ticks: int) -> void:
	fighter.enter_state(FighterState.State.ESCAPING)
	fighter.escapes.kind = FighterEscapes.Kind.TECH_ROLL
	fighter.stun_ticks = ticks
	fighter.velocity = velocity


func test_a_tech_roll_down_a_slope_follows_the_ground() -> void:
	var fighter := _start(_slope)
	fighter.position.x = 8.0
	_sim.settle(fighter)
	_roll(fighter, Vector3(-11.7, 0.0, 0.0), 18)
	var worst := 0.0
	for _i in 17:
		_walk(Vector2.ZERO, 1)
		assert_eq(fighter.state, FighterState.State.ESCAPING, "still rolling, not falling")
		assert_gte(fighter.position.y, fighter.stand_height, "never under the ground")
		worst = maxf(worst, fighter.position.y - fighter.stand_height)
	assert_lt(fighter.position.x, 5.0, "rolled downhill: x %.2f" % fighter.position.x)
	# Like walking: snapped each tick, at most one tick's descent above the slope.
	assert_lt(worst, 0.15, "worst gap %.3f m" % worst)


func test_a_tech_roll_into_a_cliff_stops_at_its_foot() -> void:
	var fighter := _start(_cliff)
	_roll(fighter, Vector3(11.7, 0.0, 0.0), 18)
	_walk(Vector2.ZERO, 18)
	assert_lt(fighter.position.y, _sim.tuning.ground_height + 0.3, "not up the face: y %.2f" % fighter.position.y)
	assert_lt(fighter.position.x, 2.0, "x %.2f" % fighter.position.x)


func test_a_fighter_landing_on_a_cliff_face_slides_down_to_its_foot() -> void:
	var fighter := _start(_cliff)
	fighter.position = Vector3(3.0, _cliff(3.0, 0.0, 0.0) + _sim.tuning.ground_height + 0.5, 0.0)
	fighter.enter_state(FighterState.State.FALLING)
	_walk(RIGHT, 120)
	assert_lt(fighter.position.x, 2.05, "slid off the face: x %.2f" % fighter.position.x)
	assert_lt(fighter.position.y, _sim.tuning.ground_height + 0.3, "at the foot: y %.2f" % fighter.position.y)
