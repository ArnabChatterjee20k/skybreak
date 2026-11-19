extends GutTest
## T-127: MatchFlow phases drive the UI cues and the MusicDirector.


class FakeDirector:
	var played: Array[StringName] = []

	func play(cue: StringName, _at: Variant = null, _params: Dictionary = {}) -> Node:
		played.append(cue)
		return null


class FakeMusic:
	var calls: Array[String] = []
	var observed := 0
	var final_round_seen := false

	func start_battle(zone: StringName) -> void:
		calls.append("start_battle:%s" % zone)

	func round_started() -> void:
		calls.append("round_started")

	func round_ended(match_over: bool, player_won: bool) -> void:
		calls.append("round_ended:%s:%s" % [match_over, player_won])

	func observe_sim(_sim: CombatSim, final_round: bool = false) -> void:
		observed += 1
		final_round_seen = final_round_seen or final_round


var _director: FakeDirector
var _music: FakeMusic
var _cues: MatchCues
var _flow: MatchFlow
var _sim: CombatSim


func before_each() -> void:
	_director = FakeDirector.new()
	_music = FakeMusic.new()
	_cues = MatchCues.new()
	_cues.director = _director
	_cues.music = _music
	_cues.zone = &"heartbloom_gardens"
	add_child_autofree(_cues)
	_flow = MatchFlow.new()
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3(0, 1, 0))
	_sim.add_fighter(Vector3(4, 1, 0))


func _run(ticks: int) -> void:
	for i in ticks:
		_flow.step(_sim)
		_cues.after_tick(_flow, _sim)


func _knock_out(index: int) -> void:
	_sim.apply_damage(index, 1 - index, _sim.fighters[index].stats.max_health)


func test_intro_starts_the_zone_theme_and_counts_down_into_fight() -> void:
	_cues.after_tick(_flow, _sim)  # first tick: intro of round 1
	assert_eq(_music.calls, ["start_battle:heartbloom_gardens"])
	_run(MatchFlow.INTRO_TICKS)
	assert_eq(_director.played, [&"round_count_3", &"round_count_2", &"round_count_1", &"round_fight"])


func test_music_follows_the_fight_only_while_fighting() -> void:
	_run(MatchFlow.INTRO_TICKS - 1)
	assert_eq(_music.observed, 0, "silent intensity during the intro")
	_run(61)  # the step into FIGHT, then 60 fight ticks
	assert_eq(_music.observed, 61)


func test_ko_plays_round_end_and_the_stinger_then_round_two_resets_the_music() -> void:
	_run(MatchFlow.INTRO_TICKS)
	_knock_out(1)
	_run(1)
	assert_has(_director.played, &"round_end")
	assert_has(_music.calls, "round_ended:false:true", "player won the round, match not over")
	_run(MatchFlow.KO_TICKS)
	assert_has(_music.calls, "round_started")
	_run(MatchFlow.INTRO_ROUND_TICKS + 1)
	assert_eq(_director.played.count(&"round_count_3"), 2, "the count again for round 2")


func _play_round(loser: int) -> void:
	_run(MatchFlow.INTRO_TICKS + 30)
	_knock_out(loser)
	_run(1)


func test_one_all_is_match_point_and_the_win_plays_the_victory_stinger_and_cue() -> void:
	_play_round(0)  # opponent takes round 1
	_run(MatchFlow.KO_TICKS)
	_play_round(1)  # player takes round 2: 1-1
	assert_false(_music.final_round_seen, "not match point before 1-1")
	_run(MatchFlow.KO_TICKS)
	_play_round(1)  # round 3 decides it
	assert_true(_music.final_round_seen, "1-1: the music asks for its climax")
	assert_has(_music.calls, "round_ended:true:true", "match over, player won")
	_run(MatchFlow.KO_TICKS)
	assert_eq(_flow.phase, MatchFlow.Phase.MATCH_OVER)
	assert_has(_director.played, &"victory")


func test_disabled_flow_is_silent() -> void:
	_flow.enabled = false
	_run(300)
	assert_eq(_director.played, [] as Array[StringName])
	assert_eq(_music.calls, [] as Array[String])
