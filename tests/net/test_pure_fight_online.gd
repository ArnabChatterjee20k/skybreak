extends GutTest
## Online Pure Fight: two peers over a lossy, jittery loopback with their own inputs stay in
## sync through rollbacks, and every Pure Fight input survives the wire codec.

const SEED := 33
const TICK_MS := 1000.0 / 60.0

var _now := [0.0]


func _clock() -> float:
	return _now[0]


func _peers(rtt: float, jitter: float, loss: float) -> Array[RollbackSession]:
	var ends := LoopbackTransport.pair(_clock, rtt, jitter, loss, SEED)
	var legends: Array[StringName] = [&"kael", &"brann"]
	var out: Array[RollbackSession] = []
	for peer in 2:
		out.append(PureFightNet.new_session(PureFightNet.new_sim(SEED, legends), ends[peer], peer, 2, _clock))
	return out


func test_two_peers_stay_in_sync_through_rollbacks() -> void:
	var peers := _peers(120.0, 20.0, 0.05)
	var desyncs: Array = []
	for peer in peers:
		peer.desynced.connect(func(f: int, a: int, b: int) -> void: desyncs.append([f, a, b]))
	# Each peer's own AI makes its inputs, as a human would: unpredictable for the other side.
	var ais: Array[PureFightAI] = []
	for peer in 2:
		var ai := PureFightAI.new()
		ai.setup(peer, 4, 100 + peer)
		ai.explore = 0.4
		ais.append(ai)
	for t in 2400:
		_now[0] += TICK_MS
		for peer in 2:
			peers[peer].advance(ais[peer].next_input(peers[peer].sim as PureFightSim))
	for end in peers:
		var link := end.transport as LoopbackTransport
		link.latency_ms = 0.0
		link.jitter_ms = 0.0
		link.loss = 0.0
	for i in 120:
		_now[0] += TICK_MS
		for peer in 2:
			if peers[peer].frame <= peers[1 - peer].frame:
				peers[peer].advance(FighterInput.new())
			else:
				peers[peer].poll()
	assert_eq(desyncs, [], "no desync")
	assert_gt(peers[0].rollbacks + peers[1].rollbacks, 0, "the link forced rollbacks")
	assert_gt(peers[0].hashes_compared, 10, "hashes were compared")
	var a := peers[0].sim as PureFightSim
	var b := peers[1].sim as PureFightSim
	if a.current_tick == b.current_tick:
		assert_eq(a.state_hash(), b.state_hash(), "same state")


func test_every_pure_fight_input_survives_the_codec() -> void:
	var A := FighterInput.Action
	for action in [A.LIGHT, A.SPECIAL_1, A.HEAVY, A.GRAB, A.SPECIAL_2, A.ULTIMATE, A.DASH, A.BLOCK]:
		for move in [Vector2(1, 0), Vector2(-1, -1), Vector2(0, 1), Vector2(1, 1)]:
			var input := FighterInput.from_held(action, FighterInput.new())
			input.move = move.normalized() if move.length() > 1.0 else move
			var back := InputCodec.decode(InputCodec.encode(input))
			assert_eq(back.held_actions, input.held_actions)
			assert_eq(back.pressed_actions, input.pressed_actions)
			assert_eq(signf(back.move.x), signf(input.move.x))
			assert_eq(signf(back.move.y), signf(input.move.y))
			assert_eq(absf(back.move.x) > 0.4, absf(input.move.x) > 0.4, "direction threshold kept")
