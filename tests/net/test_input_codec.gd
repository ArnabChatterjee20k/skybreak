extends GutTest

const NetScript := preload("res://tests/net/net_script.gd")


func test_a_neutral_input_takes_eight_bytes() -> void:
	assert_eq(InputCodec.neutral().size(), 8)


func test_a_full_input_takes_at_most_eighteen_bytes() -> void:
	var input := FighterInput.new()
	input.held_actions = 0x3FFFF
	input.pressed_actions = 0x3FFFF
	input.released_actions = 1
	input.camera_offset = Vector2(1, -1)
	assert_eq(InputCodec.encode(input).size(), 18)


func test_decoding_round_trips_every_field_within_quantisation() -> void:
	var input := FighterInput.new()
	input.held_actions = FighterInput.Action.DASH | FighterInput.Action.THROW
	input.pressed_actions = FighterInput.Action.THROW
	input.released_actions = FighterInput.Action.LIGHT
	input.move = Vector2(0.6, -0.8)
	input.vertical = -1
	input.view_yaw = -2.5
	input.camera_offset = Vector2(0.3, -0.2)
	input.target_switch = 1
	var decoded := InputCodec.decode(InputCodec.encode(input))
	assert_eq(decoded.held_actions, input.held_actions)
	assert_eq(decoded.pressed_actions, input.pressed_actions)
	assert_eq(decoded.released_actions, input.released_actions)
	assert_almost_eq(decoded.move, input.move, Vector2(0.01, 0.01))
	assert_lte(decoded.move.length(), 1.0)
	assert_eq(decoded.vertical, -1)
	assert_eq(decoded.target_switch, 1)
	assert_almost_eq(wrapf(decoded.view_yaw - input.view_yaw, -PI, PI), 0.0, 0.0002)
	assert_almost_eq(decoded.camera_offset, input.camera_offset, Vector2(0.0002, 0.0002))


func test_re_encoding_a_decoded_input_gives_the_same_bytes() -> void:
	var script := NetScript.new(5)
	for i in 500:
		var bytes := InputCodec.encode(script.next_input())
		assert_eq(InputCodec.encode(InputCodec.decode(bytes)), bytes)


func test_a_prediction_keeps_holds_and_drops_presses() -> void:
	var input := FighterInput.new()
	input.held_actions = FighterInput.Action.BLOCK
	input.pressed_actions = FighterInput.Action.BLOCK
	input.move = Vector2(0, 1)
	var predicted := InputCodec.decode(InputCodec.predict_from(InputCodec.encode(input)))
	assert_eq(predicted.held_actions, FighterInput.Action.BLOCK)
	assert_eq(predicted.pressed_actions, 0)
	assert_eq(predicted.move, Vector2(0, 1))
