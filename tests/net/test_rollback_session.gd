extends GutTest
## Two Duo peers over a lossy loopback: same seed, own scripted inputs, AI on both.

const NetScript := preload("res://tests/net/net_script.gd")
const SEED := 21
const TICKS := 3600
const TICK_MS := 1000.0 / 60.0

var _now := [0.0]


func _clock() -> float:
	return _now[0]


func _make_peers(rtt_ms: float, jitter_ms: float, loss: float, delay: int = 2) -> Array[RollbackSession]:
	var ends := LoopbackTransport.pair(_clock, rtt_ms, jitter_ms, loss, SEED)
	var peers: Array[RollbackSession] = []
	for peer in 2:
		var sim := DuoMatch.new_sim(SEED, 2)
		peers.append(RollbackSession.new(sim, ends[peer], peer, 2, DuoMatch.fighter_peers(sim),
			DuoMatch.new_bots(sim, SEED), delay, _clock))
		peers[peer].rules = DuoMatch.new()
	return peers


func _run(peers: Array[RollbackSession], ticks: int, scripts: Array = [], late_start: int = 0) -> void:
	for t in ticks:
		_now[0] += TICK_MS
		for peer in peers.size():
			if peer == 1 and t < late_start:
				continue
			var input: FighterInput = scripts[peer].next_input() if scripts else FighterInput.new()
			peers[peer].advance(input)


## Ends the run with a perfect link until both peers sit on the same fully confirmed frame.
func _settle(peers: Array[RollbackSession]) -> void:
	for peer in peers:
		var end := peer.transport as LoopbackTransport
		end.latency_ms = 0.0
		end.jitter_ms = 0.0
		end.loss = 0.0
	_now[0] += 1000.0
	_run(peers, 30)
	for i in 60:
		var behind := peers[0] if peers[0].frame < peers[1].frame else peers[1]
		if peers[0].frame == peers[1].frame:
			break
		_now[0] += TICK_MS
		behind.advance(FighterInput.new())
	for i in 3:
		_now[0] += TICK_MS
		peers[0].poll()
		peers[1].poll()
		peers[0]._send()
		peers[1]._send()


func _check_link(rtt_ms: float, jitter_ms: float, loss: float) -> void:
	var peers := _make_peers(rtt_ms, jitter_ms, loss)
	_run(peers, TICKS, [NetScript.new(101), NetScript.new(202)])
	var rtt_estimates := [peers[0].rtt_ms, peers[1].rtt_ms]
	_settle(peers)
	for peer in peers:
		gut.p("rtt %d ms: peer %d frame %d, rollbacks %d (%.1f/s, avg depth %.1f, max %d), stalls %d, sync skips %d, hashes compared %d, rtt est %.0f ms" % [
			rtt_ms, peer.local_peer, peer.frame, peer.rollbacks, peer.rollbacks / (TICKS / 60.0),
			peer.rollback_frames / maxf(peer.rollbacks, 1.0), peer.max_rollback_depth,
			peer.stalls, peer.sync_skips, peer.hashes_compared, rtt_estimates[peer.local_peer]])
		assert_eq(peer.desync_frame, -1, "no desync")
		assert_gt(peer.hashes_compared, 50, "hashes were exchanged")
		assert_lte(peer.max_rollback_depth, RollbackSession.MAX_ROLLBACK)
		assert_lte(peer.rollbacks / (TICKS / 60.0), 30.0, "rollbacks per second stay bounded")
		assert_gt(peer.frame, int(TICKS * 0.9), "the match kept running")
	assert_eq(peers[0].frame, peers[1].frame, "both peers on the same frame")
	assert_gte(peers[0].confirmed_frame(), peers[0].frame - 1, "every input confirmed")
	assert_eq(peers[0].sim.state_hash(), peers[1].sim.state_hash(), "same final state")
	assert_eq(peers[0].rules.ko_ticks, peers[1].rules.ko_ticks)


func test_peers_agree_at_0_ms_rtt() -> void:
	_check_link(0.0, 10.0, 0.02)


func test_peers_agree_at_60_ms_rtt() -> void:
	_check_link(60.0, 10.0, 0.02)


func test_peers_agree_at_120_ms_rtt() -> void:
	_check_link(120.0, 10.0, 0.02)


func test_peers_agree_at_200_ms_rtt() -> void:
	_check_link(200.0, 10.0, 0.02)


func test_a_wrong_prediction_rolls_back() -> void:
	var peers := _make_peers(120.0, 0.0, 0.0)
	_run(peers, 600, [NetScript.new(1), NetScript.new(2)])
	assert_gt(peers[0].rollbacks, 0)
	assert_gt(peers[1].rollbacks, 0)


func test_the_peer_that_runs_ahead_slows_down() -> void:
	var peers := _make_peers(60.0, 0.0, 0.0)
	_run(peers, 900, [NetScript.new(1), NetScript.new(2)], 6)
	assert_gt(peers[0].sync_skips, 0, "the early peer skipped ticks")
	assert_lte(absi(peers[0].frame - peers[1].frame), 2)


func test_a_desync_is_reported() -> void:
	var peers := _make_peers(60.0, 0.0, 0.0)
	_run(peers, 120, [NetScript.new(1), NetScript.new(2)])
	peers[1].sim.fighters[3].health -= 1
	watch_signals(peers[0])
	_run(peers, 300, [NetScript.new(3), NetScript.new(4)])
	assert_signal_emitted(peers[0], "desynced")
	assert_gte(peers[0].desync_frame, 120, "found at the corrupted frame or later")


func test_a_peer_that_hears_nothing_stalls_within_the_rollback_window() -> void:
	var peers := _make_peers(0.0, 0.0, 1.0)
	_run(peers, 60, [NetScript.new(1), NetScript.new(2)])
	assert_eq(peers[0].frame, RollbackSession.MAX_ROLLBACK + peers[0].input_delay)
	assert_gt(peers[0].stalls, 0)


func test_re_simulating_8_frames_for_4_fighters_takes_at_most_4_ms() -> void:
	var sim := DuoMatch.new_sim(SEED, 2)
	var bots := DuoMatch.new_bots(sim, SEED)
	var session := RollbackSession.new(sim, null, 0, 1, DuoMatch.fighter_peers(sim), bots, 0, _clock)
	session.fighter_peers = [0, 0, -1, -1]
	var script := NetScript.new(9)
	for i in 600:
		sim.tick([script.next_input(), script.next_input(), bots[2].next_input(sim), bots[3].next_input(sim)] as Array[FighterInput])
	# Worst case: restore, then 8 ticks each with bot inputs and a fresh snapshot.
	var timings: Array[float] = []
	for trial in 41:
		var saved := sim.snapshot()
		var saved_bots := [SimSnapshot.capture(bots[2]), SimSnapshot.capture(bots[3])]
		var start := Time.get_ticks_usec()
		sim.restore(saved)
		saved_bots[0].restore_into(bots[2])
		saved_bots[1].restore_into(bots[3])
		for f in RollbackSession.MAX_ROLLBACK:
			sim.snapshot()
			SimSnapshot.capture(bots[2])
			SimSnapshot.capture(bots[3])
			sim.tick([script.next_input(), script.next_input(), bots[2].next_input(sim), bots[3].next_input(sim)] as Array[FighterInput])
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
	timings.sort()
	var median := timings[timings.size() / 2]
	gut.p("8-frame rollback, 4 fighters: median %.2f ms, max %.2f ms" % [median, timings[-1]])
	assert_lte(median, 4.0)
