extends GutTest
## Frame advantage maths against hand-computed MoveData values, and the live
## measurement in the sim agreeing with it.

const Bench := preload("res://tests/modes/training_bench.gd")
const KAEL_MOVES := "res://game/combat/moves/kael/"
const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY


func _move(file: String) -> MoveData:
	return load(KAEL_MOVES + file + ".tres") as MoveData


func test_light_1_is_minus_2_on_block_and_plus_5_on_hit() -> void:
	# Blockstun 9 + 1 - (active 2 + recovery 10) = -2; hitstun 16 + 1 - 12 = +5.
	assert_eq(FrameMeter.on_block(_move("light_1")), -2)
	assert_eq(FrameMeter.on_hit(_move("light_1")), 5)


func test_light_string_advantages_match_hand_maths() -> void:
	# light_2: 10 + 1 - 13 / 17 + 1 - 13; light_3: 12 + 1 - 16 / 18 + 1 - 16; light_4: 14 + 1 - 21 / 30 + 1 - 21.
	assert_eq(FrameMeter.on_block(_move("light_2")), -2)
	assert_eq(FrameMeter.on_hit(_move("light_2")), 5)
	assert_eq(FrameMeter.on_block(_move("light_3")), -3)
	assert_eq(FrameMeter.on_hit(_move("light_3")), 3)
	assert_eq(FrameMeter.on_block(_move("light_4")), -6)
	assert_eq(FrameMeter.on_hit(_move("light_4")), 10)


func test_heavy_block_advantages_match_the_design_table() -> void:
	# GAME_DESIGN §5.3: Smash -8, Breaker -4, Launcher -10, Rising -14, Spike -10, Sweep -6.
	assert_eq(FrameMeter.on_block(_move("smash")), -8)
	assert_eq(FrameMeter.on_block(_move("breaker")), -4)
	assert_eq(FrameMeter.on_block(_move("launcher")), -10)
	assert_eq(FrameMeter.on_block(_move("rising")), -14)
	assert_eq(FrameMeter.on_block(_move("spike")), -10)
	assert_eq(FrameMeter.on_block(_move("sweep")), -6)


func test_smash_is_plus_15_on_hit() -> void:
	# Hitstun 40 + 1 - (active 4 + recovery 22).
	assert_eq(FrameMeter.on_hit(_move("smash")), 15)


func test_texts_sign_advantage_and_name_special_cases() -> void:
	assert_eq(FrameMeter.on_hit_text(_move("light_1")), "+5")
	assert_eq(FrameMeter.on_block_text(_move("light_1")), "-2")
	assert_eq(FrameMeter.on_hit_text(_move("spike")), "KD")
	assert_eq(FrameMeter.on_block_text(_move("grab")), "unblockable")
	assert_eq(FrameMeter.on_hit_text(_move("grab")), "throw")
	assert_eq(FrameMeter.signed(0), "0")


func _measure(mode: TrainingDummy.Mode, action: int) -> FrameMeter:
	var bench := Bench.new()
	bench.session.set_dummy_mode(mode)
	bench.tick(2)
	bench.tap(action)
	bench.tick(90)
	return bench.session.frame_meter


func test_measured_light_1_on_block_matches_the_maths() -> void:
	var meter := _measure(TrainingDummy.Mode.BLOCK_ALL, LIGHT)
	assert_true(meter.has_measurement)
	assert_eq(meter.measured_kind, "block")
	assert_eq(meter.measured_advantage, FrameMeter.on_block(_move("light_1")))


func test_measured_light_1_on_hit_matches_the_maths() -> void:
	var meter := _measure(TrainingDummy.Mode.STAND, LIGHT)
	assert_true(meter.has_measurement)
	assert_eq(meter.measured_kind, "hit")
	assert_eq(meter.measured_advantage, FrameMeter.on_hit(_move("light_1")))
	assert_eq(meter.last_damage, 300)


func test_measured_smash_on_block_matches_the_maths() -> void:
	var meter := _measure(TrainingDummy.Mode.BLOCK_ALL, HEAVY)
	assert_eq(meter.last_move.id, &"smash")
	assert_eq(meter.measured_advantage, -8)


func test_combo_counter_keeps_hits_and_damage_after_the_combo() -> void:
	var bench := Bench.new()
	bench.light_string(4)
	bench.tick(120)
	var meter := bench.session.frame_meter
	assert_eq(meter.combo_hits, 4)
	# 300 + 320 * 92% + 350 * 84% + 450 * 76%, each rounded down.
	assert_eq(meter.combo_damage, 300 + 294 + 294 + 342)


func test_a_new_move_clears_the_last_hits_damage() -> void:
	var bench := Bench.new()
	bench.tap(LIGHT)
	bench.tick(40)
	assert_eq(bench.session.frame_meter.last_damage, 300)
	bench.session.set_dummy_mode(TrainingDummy.Mode.BLOCK_ALL)
	bench.session.reset_positions()
	bench.tick(2)
	bench.tap(HEAVY)
	bench.tick(60)
	assert_eq(bench.session.frame_meter.last_move.id, &"smash")
	assert_eq(bench.session.frame_meter.last_damage, 0, "a blocked smash deals nothing")
