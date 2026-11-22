extends GutTest
## Two Duo peers over the loopback transport at 150 ms RTT, 20 ms jitter and 2% loss,
## each a full RollbackSession with the Duo rules and AI drivers, the local human on
## each side played by its own AI. Plus a forced rollback burst. No desync allowed.

const RTT_MS := 150.0
const JITTER_MS := 20.0
const LOSS := 0.02
const TICKS := 3600
const BURST_AT := 1500
## Ticks with every packet lost both ways: the burst forces deep rollbacks after it.
const BURST_TICKS := 7
const SETUP := {"host_legend": &"kael", "guest_legend": &"vexa", "zone": &"heartbloom_gardens",
	"ai_count": 2, "ai_level": 3, "lives": 6, "minutes": 3}

var now_ms := 0.0


func _clock() -> float:
	return now_ms


func _peer(config: Dictionary, transport: LoopbackTransport, peer: int) -> Array:
	var sim := DuoMatch.new_sim(config)
	var session := RollbackSession.new(sim, transport, peer, DuoMatch.HUMAN_PEERS,
		DuoMatch.fighter_peers(sim.fighters.size()), DuoMatch.new_bots(config), DuoMatch.INPUT_DELAY, _clock)
	var flow := DuoMatch.new_flow(config)
	flow.spawn_points.assign(sim.spawn_points)
	session.rules = flow
	var pilot := AIDriver.new()
	pilot.setup(peer, 4)
	return [session, pilot]


func test_two_peers_stay_in_sync_through_lag_jitter_loss_and_a_rollback_burst() -> void:
	var config := DuoMatch.build_config(SETUP, 90210)
	var ends := LoopbackTransport.pair(_clock, RTT_MS, JITTER_MS, LOSS, 31)
	var a := _peer(config, ends[0], 0)
	var b := _peer(config, ends[1], 1)
	var host: RollbackSession = a[0]
	var guest: RollbackSession = b[0]
	var host_hashes := {}
	var guest_hashes := {}
	host.hash_checked.connect(func(frame: int, value: int) -> void: host_hashes[frame] = value)
	guest.hash_checked.connect(func(frame: int, value: int) -> void: guest_hashes[frame] = value)
	var deepest_after_burst := 0
	for tick in TICKS:
		var burst := tick >= BURST_AT and tick < BURST_AT + BURST_TICKS
		ends[0].loss = 1.0 if burst else LOSS
		ends[1].loss = 1.0 if burst else LOSS
		now_ms += 1000.0 / CombatSim.TICKS_PER_SECOND
		host.advance((a[1] as AIDriver).next_input(host.sim))
		guest.advance((b[1] as AIDriver).next_input(guest.sim))
		if tick == BURST_AT + 40:
			deepest_after_burst = maxi(host.max_rollback_depth, guest.max_rollback_depth)
	assert_eq(host.desync_frame, -1, "host saw no desync")
	assert_eq(guest.desync_frame, -1, "guest saw no desync")
	assert_gt(host.hashes_compared, 60, "state hashes were compared over the network")
	assert_gt(guest.hashes_compared, 60)
	var common := 0
	for frame: int in host_hashes:
		if guest_hashes.has(frame):
			common += 1
			assert_eq(host_hashes[frame], guest_hashes[frame], "hash at tick %d" % frame)
	assert_gt(common, 100, "both peers confirmed the same ticks")
	assert_gt(host.frame, TICKS * 0.85, "the lag never froze the match")
	assert_gt(host.rollbacks, 100, "late inputs were rolled back")
	assert_gte(deepest_after_burst, 6, "the burst forced deep rollbacks")
	assert_lte(host.max_rollback_depth, RollbackSession.MAX_ROLLBACK)
	gut.p("host: frame %d rollbacks %d (max %d) stalls %d skips %d compared %d rtt %.0f ms; dropped %d/%d" % [
		host.frame, host.rollbacks, host.max_rollback_depth, host.stalls, host.sync_skips,
		host.hashes_compared, host.rtt_ms, ends[0].dropped_packets, ends[0].sent_packets])
	gut.p("guest: frame %d rollbacks %d (max %d) stalls %d compared %d" % [
		guest.frame, guest.rollbacks, guest.max_rollback_depth, guest.stalls, guest.hashes_compared])


func test_the_ai_drivers_roll_back_exactly() -> void:
	# Re-simulating from a snapshot with the AI drivers restored gives the same hashes.
	var config := DuoMatch.build_config(SETUP, 4)
	var sim := DuoMatch.new_sim(config)
	var bots := DuoMatch.new_bots(config)
	var flow := DuoMatch.new_flow(config)
	var step := func() -> void:
		var inputs: Array[FighterInput] = []
		for i in sim.fighters.size():
			inputs.append(bots[i].next_input(sim) if bots[i] else FighterInput.new())
		sim.tick(inputs)
		flow.after_tick(sim)
	for i in 300:
		step.call()
	var saved := sim.snapshot()
	var saved_bots: Array = bots.map(func(bot: Variant) -> Variant: return SimSnapshot.capture(bot) if bot else null)
	var saved_flow := SimSnapshot.capture(flow)
	var first: Array[int] = []
	for i in 120:
		step.call()
		first.append(hash([sim.state_hash(), flow.state_hash()]))
	sim.restore(saved)
	for i in bots.size():
		if bots[i]:
			(saved_bots[i] as SimSnapshot).restore_into(bots[i])
	saved_flow.restore_into(flow)
	for i in 120:
		step.call()
		assert_eq(hash([sim.state_hash(), flow.state_hash()]), first[i], "tick %d after the rewind" % i)
		if hash([sim.state_hash(), flow.state_hash()]) != first[i]:
			return


func test_a_silent_partner_gets_about_ten_packets_a_second_instead_of_sixty() -> void:
	var config := DuoMatch.build_config(SETUP, 8)
	var ends := LoopbackTransport.pair(_clock, 40.0, 0.0, 0.0, 5)
	var a := _peer(config, ends[0], 0)
	var b := _peer(config, ends[1], 1)
	var host: RollbackSession = a[0]
	var guest: RollbackSession = b[0]
	for tick in 120:
		now_ms += 1000.0 / CombatSim.TICKS_PER_SECOND
		host.advance(FighterInput.new())
		guest.advance(FighterInput.new())
	var before := ends[0].sent_packets
	# The guest freezes (hidden tab): the host stalls and keeps sending, but slowly.
	for tick in 60:
		now_ms += 1000.0 / CombatSim.TICKS_PER_SECOND
		host.advance(FighterInput.new())
	var sent := ends[0].sent_packets - before
	assert_between(sent, 8, 30, "about 10 packets a second once the partner is quiet (sent %d)" % sent)
	for tick in 120:
		now_ms += 1000.0 / CombatSim.TICKS_PER_SECOND
		host.advance(FighterInput.new())
		guest.advance(FighterInput.new())
	assert_eq(host.desync_frame, -1)
	assert_gt(host.frame, 200, "the match goes on once the partner is back")
