extends GutTest
## Duo match setup: the config both peers launch, teams, peers and AI drivers.

const SETUP := {"host_legend": &"lyra", "guest_legend": &"brann", "zone": &"ember_rift",
	"ai_count": 2, "ai_level": 4, "lives": 3, "minutes": 3}


func test_the_config_seats_both_humans_on_one_team_against_the_ai() -> void:
	var config := DuoMatch.build_config(SETUP, 77)
	assert_eq(config.mode, MatchRules.MODE_DUO)
	assert_eq(config.zone, &"ember_rift")
	assert_eq(config.seed, 77)
	assert_eq(config.lives, 3)
	assert_eq(config.minutes, 3)
	var fighters: Array = config.fighters
	assert_eq(fighters.size(), 4)
	assert_eq(fighters[0].character, &"lyra")
	assert_eq(fighters[1].character, &"brann")
	assert_eq(DuoMatch.teams_of(config), [0, 0, 1, 1] as Array[int])
	assert_false(fighters[0].is_ai)
	assert_true(fighters[2].is_ai)
	assert_eq(fighters[2].ai_level, 4)
	assert_eq(MatchRules.problems(config), PackedStringArray())


func test_both_peers_build_the_same_config_from_the_seed() -> void:
	assert_eq(DuoMatch.build_config(SETUP, 1234), DuoMatch.build_config(SETUP, 1234))


func test_ai_count_is_clamped() -> void:
	var many := SETUP.duplicate()
	many.ai_count = 9
	assert_eq((DuoMatch.build_config(many, 1).fighters as Array).size(), 2 + DuoMatch.MAX_AI)


func test_peers_own_the_human_slots_and_bots_drive_the_rest() -> void:
	var config := DuoMatch.build_config(SETUP, 5)
	assert_eq(DuoMatch.fighter_peers(4), [0, 1, -1, -1] as Array[int])
	var bots := DuoMatch.new_bots(config)
	assert_null(bots[0])
	assert_null(bots[1])
	assert_true(bots[2] is AIDriver)


func test_the_flat_sim_puts_fighters_on_their_teams() -> void:
	var sim := DuoMatch.new_sim(DuoMatch.build_config(SETUP, 5))
	assert_eq(sim.fighters.size(), 4)
	assert_eq(sim.fighters[0].team, 0)
	assert_eq(sim.fighters[1].team, 0)
	assert_eq(sim.fighters[3].team, 1)
	for i in 2:
		assert_gte(sim.fighters[i].lock_on_target, 2, "humans lock onto the AI")
