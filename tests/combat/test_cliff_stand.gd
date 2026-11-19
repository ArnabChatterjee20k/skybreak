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
