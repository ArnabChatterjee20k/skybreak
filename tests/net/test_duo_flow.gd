extends GutTest
## Duo rules (GAME_DESIGN §8.2): shared team lives, respawns, the losing team, time-out.

const SETUP := {"ai_count": 1, "lives": 2, "minutes": 3}

var sim: CombatSim
var flow: DuoFlow


func before_each() -> void:
	var config := DuoMatch.build_config(SETUP, 3)
	sim = DuoMatch.new_sim(config)
	flow = DuoMatch.new_flow(config)
	flow.spawn_points.assign(sim.spawn_points)
	flow._enter(MatchFlow.Phase.FIGHT)


func _tick(count := 1) -> void:
	for i in count:
		var inputs: Array[FighterInput] = []
		for f in sim.fighters:
			inputs.append(FighterInput.new())
		sim.tick(inputs)
		flow.after_tick(sim)


func _knock_out(index: int) -> void:
	sim.fighters[index].health = 0
	_tick()


func test_the_teams_start_with_their_life_pools() -> void:
	assert_eq(flow.lives, PackedInt32Array([2, DuoFlow.AI_LIVES_EACH]))
	assert_eq(flow.teams, PackedInt32Array([0, 0, 1]))
	assert_eq(flow.seconds_left(), 180)


func test_a_knocked_out_human_spends_a_shared_life_and_comes_back() -> void:
	_knock_out(0)
	assert_eq(flow.lives[DuoFlow.HUMAN_TEAM], 1)
	assert_true(sim.fighters[0].is_knocked_out())
	_tick(DuoFlow.RESPAWN_TICKS)
	assert_false(sim.fighters[0].is_knocked_out(), "back after the respawn time")
	assert_eq(sim.fighters[0].health, sim.fighters[0].stats.max_health * FighterState.METER_UNIT)
	assert_eq(flow.phase, MatchFlow.Phase.FIGHT)


func test_both_humans_down_with_lives_left_keeps_the_match_going() -> void:
	sim.fighters[0].health = 0
	sim.fighters[1].health = 0
	_tick()
	assert_false(sim.round_over, "a respawn is coming, so the round goes on")
	assert_eq(flow.phase, MatchFlow.Phase.FIGHT)
	assert_eq(flow.lives[DuoFlow.HUMAN_TEAM], 0)
	_tick(DuoFlow.RESPAWN_TICKS)
	assert_false(sim.fighters[0].is_knocked_out())
	assert_false(sim.fighters[1].is_knocked_out())


func test_a_team_down_with_no_lives_left_loses() -> void:
	flow.lives[DuoFlow.HUMAN_TEAM] = 0
	sim.fighters[0].health = 0
	sim.fighters[1].health = 0
	_tick()
	assert_eq(flow.phase, MatchFlow.Phase.KO)
	assert_eq(flow.winning_team, DuoFlow.AI_TEAM)
	assert_eq(flow.banner([]).subtitle, "THE AI WINS")
	_tick(MatchFlow.KO_TICKS)
	assert_eq(flow.phase, MatchFlow.Phase.MATCH_OVER)


func test_beating_the_ai_team_wins_for_the_duo() -> void:
	flow.lives[DuoFlow.AI_TEAM] = 0
	_knock_out(2)
	assert_eq(flow.winning_team, DuoFlow.HUMAN_TEAM)
	assert_eq(flow.last_winner, 0)


func test_on_time_the_team_with_more_lives_wins() -> void:
	flow.timer_ticks = 1
	flow.lives[DuoFlow.AI_TEAM] = 0
	_tick()
	assert_true(flow.timed_out)
	assert_eq(flow.winning_team, DuoFlow.HUMAN_TEAM)


func test_online_play_never_slows_time() -> void:
	_knock_out(0)
	assert_eq(flow.time_scale(), 1.0)


func test_the_rules_hash_follows_their_state() -> void:
	var before := flow.state_hash()
	_knock_out(0)
	assert_ne(flow.state_hash(), before)



func test_teammates_never_hit_each_other() -> void:
	# The sim skips same-team hits (tests/combat/test_knockout.gd); Duo puts both humans on team 0.
	sim.fighters[1].position = sim.fighters[0].position + Vector3(0, 0, -1.5)
	sim.fighters[0].lock_on_target = 1
	var hits := 0
	var previous := FighterInput.new()
	for i in 40:
		var light := FighterInput.from_held(FighterInput.Action.LIGHT if i % 6 < 3 else 0, previous)
		previous = light
		sim.tick([light, FighterInput.new(), FighterInput.new()] as Array[FighterInput])
		hits += sim.events.filter(func(e: Dictionary) -> bool: return e.get("target", -1) == 1).size()
	assert_eq(hits, 0)
	assert_eq(sim.fighters[1].health, sim.fighters[1].stats.max_health * FighterState.METER_UNIT)
