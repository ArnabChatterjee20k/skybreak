extends GutTest
## Without injected terrain the sim must move exactly as recorded (golden re-recorded in T-D30c for the measured pushboxes).

var _golden: Dictionary
var _actual: Dictionary


func before_all() -> void:
	_golden = JSON.parse_string(FileAccess.get_file_as_string(FlatFloorSequences.GOLDEN_PATH))
	_actual = FlatFloorSequences.record()


func test_the_scripted_4_fighter_free_for_all_matches_the_pre_terrain_golden_every_tick() -> void:
	_assert_same_sequence("free_for_all", FlatFloorSequences.FREE_FOR_ALL_TICKS)


func test_the_3600_tick_bot_match_matches_the_pre_terrain_golden_every_tick() -> void:
	_assert_same_sequence("bot_match", FlatFloorSequences.BOT_MATCH_TICKS)


func _assert_same_sequence(name: String, ticks: int) -> void:
	var golden: Array = _golden[name]
	var actual: Array = _actual[name]
	assert_eq(golden.size(), ticks, "golden %s has every tick" % name)
	assert_eq(actual.size(), ticks, "%s ran every tick" % name)
	var first_difference := -1
	for i in mini(golden.size(), actual.size()):
		if golden[i] != actual[i]:
			first_difference = i
			break
	assert_eq(first_difference, -1, "%s first differs at tick index %d" % [name, first_difference])


func test_on_the_flat_floor_a_spawn_a_hair_above_standing_height_flies() -> void:
	var sim := CombatSim.new(1)
	sim.add_fighter(Vector3(0, sim.tuning.ground_height + 0.0005, 6))
	assert_eq(sim.fighters[0].state, FighterState.State.FLYING)


func test_on_the_flat_floor_a_grounded_fighter_held_high_snaps_down_instead_of_falling() -> void:
	var sim := CombatSim.new(1)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	sim.fighters[0].position.y = sim.tuning.ground_height + 2.0
	sim.tick([FighterInput.new(), FighterInput.new()] as Array[FighterInput])
	assert_eq(sim.fighters[0].position.y, sim.tuning.ground_height)
	assert_eq(sim.fighters[0].state, FighterState.State.IDLE)
