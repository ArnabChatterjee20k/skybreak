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


func test_terrain_samples_match_the_heightmap_within_a_few_centimetres() -> void:
	var ground := ZoneGround.bake(heightmap, null, Vector2(650, 500), 300.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 100:
		var x := rng.randf_range(360, 940)
		var z := rng.randf_range(210, 790)
		assert_almost_eq(ground.height_at(x, z, INF), heightmap.ground_height_at(x, z), 0.05)


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


func test_the_floor_ends_at_every_visible_island_rim() -> void:
	# Issue #107: rim cells used the nearest corner, so the floor reached up to 1.4 m past
	# the drawn outline and fighters stood on air, 286 m above the visible ground.
	var ground := _heartbloom()
	for i in islands.size():
		var c := islands.centres[i]
		for step in 72:
			var angle := TAU * step / 72.0
			var rim := islands.rim_radius(i, angle)
			var out := c + Vector2(cos(angle), sin(angle)) * (rim + 0.1)
			var inside := c + Vector2(cos(angle), sin(angle)) * (rim - ZoneGround.RIM_INSET - 0.2)
			var terrain := heightmap.ground_height_at(out.x, out.y)
			assert_almost_eq(ground.height_at(out.x, out.y, 400.0), terrain, 0.05,
				"%s, 10 cm past the rim at %d deg" % [islands.names[i], step * 5])
			assert_almost_eq(ground.height_at(inside.x, inside.y, 400.0), islands.surface_at(inside.x, inside.y),
				0.03, "%s, just inside the rim at %d deg" % [islands.names[i], step * 5])


func test_the_lyra_landing_spot_of_issue_107_is_past_the_floor() -> void:
	var ground := _heartbloom()
	var spot := Vector2(150.8341, -152.6504)
	assert_eq(islands.island_at(spot.x, spot.y), -1, "outside Picnic Meadow's outline")
	assert_lt(ground.height_at(spot.x, spot.y, 272.0), 0.0, "no island floor there")


func _island_sim(ground: ZoneGround) -> CombatSim:
	var sim := CombatSim.new()
	sim.ground_height = ground.height_at
	sim.tuning = sim.tuning.duplicate()
	sim.tuning.arena_ceiling = 400.0
	sim.arena_centre = Vector2(0, 10)
	return sim


func test_a_fall_at_full_speed_stops_on_an_island_top() -> void:
	# Issue #107: 50 m/s is 0.83 m a tick, more than the 0.5 m step-up, so a fall used to
	# pass the top and drop 280 m through the island.
	var ground := _heartbloom()
	var sim := _island_sim(ground)
	var top := islands.surface_at(120, -96)
	var stand := top + sim.tuning.ground_height
	for start in [0.1, 0.3, 0.5, 0.7]:
		var fighter := sim.add_fighter(Vector3(120, stand + start, -96))
		fighter.enter_state(FighterState.State.FALLING)
		fighter.velocity = Vector3.DOWN * sim.tuning.max_fall_speed
	var idle: Array[FighterInput] = [FighterInput.new(), FighterInput.new(), FighterInput.new(), FighterInput.new()]
	for t in 30:
		sim.tick(idle)
	for fighter in sim.fighters:
		assert_eq(fighter.state, FighterState.State.IDLE, "landed")
		assert_almost_eq(fighter.position.y, stand, 0.05, "on Picnic Meadow, not under it")


func test_a_vanish_following_a_lower_anchor_stays_on_the_island() -> void:
	# Issue #107 (seed 2612): a vanished fighter copies its anchor's height and sank 0.7 m
	# under the top, then fell through the island.
	var ground := _heartbloom()
	var sim := _island_sim(ground)
	var top := islands.surface_at(120, -96)
	var stand := top + sim.tuning.ground_height
	var anchor := sim.add_fighter(Vector3(120, stand, -96))
	var vanished := sim.add_fighter(Vector3(120, stand, -92))
	vanished.enter_state(FighterState.State.VANISHING)
	vanished.vanish_anchor = 0
	vanished.vanish_offset = Vector3(0, -0.7, 4)
	var idle: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	for t in 40:
		sim.tick(idle)
	assert_almost_eq(vanished.position.y, islands.surface_at(vanished.position.x, vanished.position.z) \
		+ sim.tuning.ground_height, 0.05, "on the island top")
	assert_gt(anchor.position.y, top, "anchor still on top")


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
