extends GutTest

var heightmap: TerrainHeightmap
var islands: IslandField


func before_all() -> void:
	heightmap = load(WorldMap.HEIGHTMAP_PATH)
	islands = IslandField.heartbloom()


func _heartbloom() -> ZoneGround:
	return ZoneGround.bake(heightmap, islands, Vector2(0, 10), 290.0)


func test_two_bakes_of_a_zone_give_the_same_checksum() -> void:
	assert_eq(_heartbloom().checksum(), _heartbloom().checksum())


func test_samples_repeat_exactly_and_are_whole_centimetres() -> void:
	var ground := _heartbloom()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 200:
		var x := rng.randf_range(-280, 280)
		var z := rng.randf_range(-270, 290)
		var h := ground.height_at(x, z, 400.0)
		assert_eq(h, ground.height_at(x, z, 400.0))
		assert_almost_eq(h * 100.0, roundf(h * 100.0), 0.001, "quantised to cm")


func test_terrain_samples_match_the_drawn_lod_0_triangles_within_two_centimetres() -> void:
	var ground := ZoneGround.bake(heightmap, null, Vector2(650, 500), 300.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		var x := rng.randf_range(360, 940)
		var z := rng.randf_range(210, 790)
		assert_almost_eq(ground.height_at(x, z, INF), _drawn_terrain(x, z), 0.02, "within the cm grid")


## The terrain as TerrainGrid draws it at LOD 0: cell (i, j) split into a b c and b d c.
func _drawn_terrain(x: float, z: float) -> float:
	var gx := (x - heightmap.origin.x) / heightmap.cell_size
	var gz := (z - heightmap.origin.y) / heightmap.cell_size
	var i := floori(gx)
	var j := floori(gz)
	var u := gx - i
	var v := gz - j
	var a := heightmap.height_at_sample(i, j)
	var b := heightmap.height_at_sample(i + 1, j)
	var c := heightmap.height_at_sample(i, j + 1)
	var d := heightmap.height_at_sample(i + 1, j + 1)
	if u + v <= 1.0:
		return a + u * (b - a) + v * (c - a)
	return d + (1.0 - u) * (c - d) + (1.0 - v) * (b - d)


func test_island_tops_are_the_floor_from_above_and_terrain_from_below() -> void:
	var ground := _heartbloom()
	var top := islands.surface_at(0, 0)
	assert_almost_eq(ground.height_at(0, 0, 400.0), top, 0.02, "on Heart Isle")
	assert_almost_eq(ground.height_at(0, 0, top - 20.0), heightmap.ground_height_at(0, 0), 0.02, "under the island")


func test_past_an_island_rim_the_floor_drops_to_the_terrain() -> void:
	var ground := _heartbloom()
	var gap := Vector2(-75, 60)
	assert_eq(islands.island_at(gap.x, gap.y), -1, "a gap between islands")
	assert_almost_eq(ground.height_at(gap.x, gap.y, 400.0), heightmap.ground_height_at(gap.x, gap.y), 0.02)


func test_a_fighter_falls_onto_an_island_and_stands_there() -> void:
	var ground := _heartbloom()
	var sim := CombatSim.new()
	sim.ground_height = ground.height_at
	sim.tuning = sim.tuning.duplicate()
	sim.tuning.arena_ceiling = 400.0
	sim.arena_centre = Vector2(0, 10)
	var top := islands.surface_at(140, -96)
	var fighter := sim.add_fighter(Vector3(140, top + 6.0, -96))
	fighter.enter_state(FighterState.State.FALLING)
	var idle: Array[FighterInput] = [FighterInput.new()]
	for i in 120:
		sim.tick(idle)
	assert_eq(fighter.state, FighterState.State.IDLE, "landed")
	assert_almost_eq(fighter.position.y, top + sim.tuning.ground_height, 0.05, "on Picnic Meadow")
	assert_almost_eq(fighter.stand_height, fighter.position.y, 0.001)


func test_walking_off_an_island_rim_falls_and_ascend_flies() -> void:
	var ground := _heartbloom()
	var sim := CombatSim.new()
	sim.ground_height = ground.height_at
	sim.tuning = sim.tuning.duplicate()
	sim.tuning.arena_ceiling = 400.0
	sim.arena_centre = Vector2(0, 10)
	var i := islands.index_of("East Petal")
	var c := islands.centres[i]
	var start := Vector3(c.x, 0, c.y)
	start.y = ground.height_at(start.x, start.z, INF) + sim.tuning.ground_height
	var fighter := sim.add_fighter(start)
	assert_eq(fighter.state, FighterState.State.IDLE)
	var walk := FighterInput.new()
	walk.move = Vector2(1, 0)
	var walking: Array[FighterInput] = [walk]
	var fell := false
	for t in 240:
		sim.tick(walking)
		if fighter.state == FighterState.State.FALLING:
			fell = true
			break
	assert_true(fell, "walked off the rim")
	assert_gt(islands.rim_fraction(i, fighter.position.x, fighter.position.z), 0.95)
	var climb := FighterInput.new()
	climb.vertical = 1
	var climbing: Array[FighterInput] = [climb]
	sim.tick(climbing)
	assert_eq(fighter.state, FighterState.State.FLYING, "flies after falling off")


func test_without_a_zone_ground_the_floor_stays_flat() -> void:
	var sim := CombatSim.new()
	var fighter := sim.add_fighter(Vector3(100, 0, 100))
	assert_eq(fighter.position.y, sim.tuning.ground_height)
	assert_eq(fighter.stand_height, sim.tuning.ground_height)


func _bot_fight_hash(ground: ZoneGround) -> int:
	var sim := CombatSim.new()
	sim.ground_height = ground.height_at
	sim.tuning = sim.tuning.duplicate()
	sim.tuning.arena_ceiling = 400.0
	sim.arena_centre = Vector2(0, 10)
	sim.rng.seed = 99
	sim.pickups_enabled = true
	for x in [120.0, 160.0]:
		sim.add_fighter(Vector3(x, ground.height_at(x, -96, INF) + 1.0, -96))
	sim.lock_everyone_onto_nearest()
	var bots := [WeaponBot.new(0, 1), WeaponBot.new(1, 2)]
	var states := []
	for t in 1200:
		var inputs: Array[FighterInput] = [bots[0].next_input(sim), bots[1].next_input(sim)]
		sim.tick(inputs)
		for fighter in sim.fighters:
			states.append(fighter.position)
	return hash(states)


func test_a_bot_fight_on_the_islands_repeats_exactly() -> void:
	assert_eq(_bot_fight_hash(_heartbloom()), _bot_fight_hash(_heartbloom()))
