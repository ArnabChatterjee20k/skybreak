extends GutTest

const CALM := MusicIntensity.Level.CALM
const COMBAT := MusicIntensity.Level.COMBAT
const CLIMAX := MusicIntensity.Level.CLIMAX
const FAR := 40.0
const NEAR := 5.0

var _music: MusicIntensity


func before_each() -> void:
	_music = MusicIntensity.new()


## Runs ticks with the same readings; returns the last level.
func _run(ticks: int, distance: float, health: float = 1.0, combo: int = 0, final_round: bool = false) -> int:
	var level := CALM
	for _i in ticks:
		level = _music.step(distance, false, health, combo, final_round)
	return level


func test_it_starts_calm_while_fighters_are_apart() -> void:
	assert_eq(_run(60, FAR), CALM)


func test_closing_within_fifteen_metres_raises_combat_at_once() -> void:
	_run(60, FAR)
	assert_eq(_music.step(14.0, false, 1.0, 0, false), COMBAT)


func test_a_hit_raises_combat_even_from_far_away() -> void:
	_run(60, FAR)
	assert_eq(_music.step(FAR, true, 1.0, 0, false), COMBAT)


func test_combat_holds_between_the_enter_and_exit_distances() -> void:
	_run(10, NEAR)
	assert_eq(_run(MusicIntensity.CALM_AFTER_TICKS * 3, 18.0), COMBAT, "18 m is inside the hysteresis band")


func test_combat_drops_to_calm_only_when_far_and_quiet() -> void:
	_music.step(NEAR, true, 1.0, 0, false)
	assert_eq(_run(MusicIntensity.CALM_AFTER_TICKS - 10, FAR), COMBAT, "not quiet long enough yet")
	assert_eq(_run(MusicIntensity.MIN_HOLD_TICKS + 20, FAR), CALM)


func test_distance_jitter_around_the_threshold_does_not_flap() -> void:
	var changes := 0
	var last := _music.level
	for i in 3000:
		var distance := 14.5 if i % 7 < 3 else 16.0 + float(i % 5)
		var level := _music.step(distance, false, 1.0, 0, false)
		if level != last:
			changes += 1
			last = level
	assert_eq(changes, 1, "one rise to combat, then it stays")


func test_rapid_hits_at_range_never_flap() -> void:
	var changes := 0
	var last := _music.level
	for i in 3000:
		var level := _music.step(30.0, i % 150 == 0, 1.0, 0, false)
		if level != last:
			changes += 1
			last = level
	assert_eq(changes, 1)


func test_any_fighter_under_a_quarter_health_raises_the_climax() -> void:
	assert_eq(_run(1, FAR, 0.24), CLIMAX)


func test_low_health_climax_survives_grey_health_regen_inside_the_band() -> void:
	_run(1, FAR, 0.2)
	assert_eq(_run(MusicIntensity.MIN_HOLD_TICKS * 3, FAR, 0.30), CLIMAX, "0.30 is under the exit ratio")
	assert_eq(_run(MusicIntensity.MIN_HOLD_TICKS + 1, FAR, 0.5), CALM)


func test_the_final_round_is_always_climax() -> void:
	assert_eq(_run(1, FAR, 1.0, 0, true), CLIMAX)
	assert_eq(_run(600, FAR, 1.0, 0, true), CLIMAX)


func test_a_long_combo_raises_the_climax_for_a_while() -> void:
	_run(1, NEAR, 1.0, MusicIntensity.LONG_COMBO_HITS)
	assert_eq(_run(MusicIntensity.COMBO_CLIMAX_TICKS - 5, NEAR), CLIMAX)
	assert_eq(_run(MusicIntensity.MIN_HOLD_TICKS + 10, NEAR), COMBAT)


func test_a_level_holds_at_least_the_minimum_time_before_dropping() -> void:
	_run(1, FAR, 0.1)
	assert_eq(_run(MusicIntensity.MIN_HOLD_TICKS - 2, FAR, 1.0), CLIMAX)


func test_it_reads_distance_and_hits_from_the_sim() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -40))
	assert_eq(_music.observe(sim), CALM)
	sim.fighters[1].position = Vector3(0, 0, -6)
	assert_eq(_music.observe(sim), COMBAT)


func test_it_reads_low_health_from_the_sim() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -40))
	sim.fighters[1].health = sim.fighters[1].stats.max_health * FighterState.METER_UNIT / 5
	assert_eq(_music.observe(sim), CLIMAX)


func test_a_hit_event_from_the_sim_counts_as_a_hit() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -40))
	sim.events = [{"type": CombatSim.EventType.HIT}]
	assert_eq(_music.observe(sim), COMBAT)
