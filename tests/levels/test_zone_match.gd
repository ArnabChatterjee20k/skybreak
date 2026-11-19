extends GutTest

const SCENE := preload("res://game/levels/zone_match.tscn")


func _match(config: Dictionary) -> ZoneMatch:
	var zone_match: ZoneMatch = SCENE.instantiate()
	if not config.is_empty():
		zone_match.configure(config)
	add_child_autofree(zone_match)
	zone_match.set_physics_process(false)
	zone_match.set_process(false)
	return zone_match


func test_the_default_is_kael_against_ai_vexa_in_heartbloom() -> void:
	var zone_match := _match({})
	assert_eq(zone_match.zone_id, &"heartbloom_gardens")
	assert_eq(zone_match.sim.fighters.size(), 2)
	assert_eq(zone_match.fighter_views[0].character_id, &"kael")
	assert_eq(zone_match.fighter_views[1].character_id, &"vexa")
	assert_null(zone_match.drivers[0], "the player is human")
	assert_not_null(zone_match.drivers[1], "Vexa is AI")
	assert_eq(zone_match.config.fighters[1].ai_level, 3)
	assert_eq(zone_match.player, 0)
	assert_eq(zone_match.sim.zone, &"heartbloom_gardens")


func test_configure_builds_the_requested_fighters_teams_and_ai() -> void:
	var zone_match := _match({
		"zone": &"stormfall_city",
		"fighters": [
			{"character": &"vexa", "team": 0, "is_ai": true, "ai_level": 1},
			{"character": &"kael", "team": 0, "is_ai": false, "ai_level": 0},
			{"character": &"kael", "team": 1, "is_ai": true, "ai_level": 5},
			{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 2},
		],
		"rounds": 5,
		"mode": &"team",
	})
	assert_eq(zone_match.sim.fighters.size(), 4)
	assert_eq(zone_match.teams, [0, 0, 1, 1] as Array[int])
	var ids: Array = zone_match.fighter_views.map(func(v: FighterView) -> StringName: return v.character_id)
	assert_eq(ids, [&"vexa", &"kael", &"kael", &"vexa"])
	assert_not_null(zone_match.drivers[0])
	assert_null(zone_match.drivers[1])
	assert_eq(zone_match.player, 1, "the camera follows the human")
	assert_eq(zone_match.config.rounds, 5)
	assert_eq(zone_match.match_hud.names.size(), 4)
	for i in 4:
		var target := zone_match.sim.fighters[i].lock_on_target
		assert_ne(zone_match.teams[target], zone_match.teams[i], "fighter %d locks onto a rival" % i)
	assert_eq(zone_match.sim.fighters[2].stats, Roster.character(&"kael").stats)


func test_fighters_spawn_standing_on_the_zone_ground() -> void:
	for zone_id in [&"heartbloom_gardens", &"ember_rift"]:
		var zone_match := _match({"zone": zone_id})
		for fighter in zone_match.sim.fighters:
			assert_eq(fighter.state, FighterState.State.IDLE, "%s: standing" % zone_id)
			var floor_y := zone_match.world.ground_height_at(fighter.position.x, fighter.position.z)
			assert_almost_eq(fighter.position.y, floor_y + zone_match.sim.tuning.ground_height, 0.05)
		zone_match.free()


func test_the_arena_box_and_ground_follow_the_zone() -> void:
	var zone_match := _match({"zone": &"verdant_falls"})
	var data := zone_match.world.zone(&"verdant_falls")
	assert_eq(zone_match.sim.arena_centre, data.centre)
	assert_eq(zone_match.sim.tuning.arena_half_size, ZoneMatch.ARENAS[&"verdant_falls"].x)
	assert_ne(zone_match.sim.tuning, CombatSim.new().tuning, "the shared tuning is not changed")
	assert_true(zone_match.sim.ground_height.is_valid())


func test_a_bot_fight_runs_and_stays_on_or_above_the_ground() -> void:
	var zone_match := _match({"fighters": [
		{"character": &"kael", "team": 0, "is_ai": true, "ai_level": 3},
		{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 3},
	]})
	zone_match.match_flow.enabled = false
	for t in 600:
		zone_match.step_tick()
		for fighter in zone_match.sim.fighters:
			assert_true(fighter.position.y >= fighter.stand_height - 0.001)
	zone_match.present_frame(1.0, 1.0 / 60.0)
	assert_true(zone_match.fighter_views[0].position.is_finite())


func test_the_ambience_stays_on_the_zone() -> void:
	var zone_match := _match({"zone": &"frozen_peaks"})
	assert_eq(zone_match.match_audio.default_zone, &"frozen_peaks")
	assert_null(zone_match.match_audio.world, "no position-based ambience switching")


func test_rounds_get_cues_music_zone_and_spawn_points() -> void:
	var zone_match := _match({})
	assert_true(zone_match.match_cues.is_inside_tree(), "round cues wired")
	assert_eq(zone_match.match_cues.zone, zone_match.zone_id, "the zone's battle theme")
	assert_eq(zone_match.match_flow.spawn_points, zone_match.spawn_positions(), "rounds restart on the zone spawns")
