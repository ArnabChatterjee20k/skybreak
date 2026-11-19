extends GutTest

const LIGHT := FighterInput.Action.LIGHT
const BLOCK := FighterInput.Action.BLOCK


func test_action_held_on_first_tick_counts_as_pressed() -> void:
	var input := FighterInput.from_held(LIGHT, FighterInput.new())
	assert_true(input.is_held(LIGHT))
	assert_true(input.is_pressed(LIGHT))
	assert_false(input.is_released(LIGHT))


func test_action_held_over_two_ticks_is_pressed_only_once() -> void:
	var first := FighterInput.from_held(LIGHT, FighterInput.new())
	var second := FighterInput.from_held(LIGHT, first)
	assert_true(second.is_held(LIGHT))
	assert_false(second.is_pressed(LIGHT))


func test_letting_go_counts_as_released() -> void:
	var first := FighterInput.from_held(LIGHT | BLOCK, FighterInput.new())
	var second := FighterInput.from_held(BLOCK, first)
	assert_true(second.is_released(LIGHT))
	assert_false(second.is_released(BLOCK))
	assert_false(second.is_held(LIGHT))
