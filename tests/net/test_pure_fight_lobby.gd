extends GutTest
## Pure Fight online through the Duo lobby: the host's game choice reaches the guest, Start
## hands both peers the same Pure Fight config, and a PureFightMatch over an open DuoLink
## plays a rollback match against a remote peer without desyncing.


class FakeRtc:
	extends WebRtcTransport
	var other: FakeRtc
	var control_inbox: Array[PackedByteArray] = []
	var data_inbox: Array[PackedByteArray] = []
	var open := true

	func is_open() -> bool:
		return open

	func send_control(bytes: PackedByteArray) -> void:
		if open and other.open:
			other.control_inbox.append(bytes)

	func send(bytes: PackedByteArray) -> void:
		if open and other.open:
			other.data_inbox.append(bytes)

	func poll() -> void:
		while not control_inbox.is_empty():
			control_received.emit(control_inbox.pop_front())
		while not data_inbox.is_empty():
			received.emit(data_inbox.pop_front())

	func close() -> void:
		open = false
		disconnected.emit()


func _link(player: String) -> DuoLink:
	var link := DuoLink.new()
	link.client = AppwriteClient.new()
	link.client.user_name = player
	return link


func _pair() -> Array:
	var host := _link("Player One")
	var guest := _link("Player Two")
	add_child_autofree(host)
	add_child_autofree(guest)
	var a := FakeRtc.new()
	var b := FakeRtc.new()
	a.other = b
	b.other = a
	host.attach(a, 0)
	guest.attach(b, 1)
	for i in 4:
		a.poll()
		b.poll()
	return [host, guest, a, b]


func test_the_hosts_pure_fight_choice_reaches_the_guest() -> void:
	var peers := _pair()
	var host: DuoLink = peers[0]
	var guest: DuoLink = peers[1]
	host.set_setup({"game": &"pure_fight"})
	(peers[3] as FakeRtc).poll()
	assert_true(guest.is_pure_fight())
	assert_true(host.is_pure_fight())


func test_start_hands_both_peers_the_same_pure_fight_config() -> void:
	var peers := _pair()
	var host: DuoLink = peers[0]
	var guest: DuoLink = peers[1]
	host.set_setup({"game": &"pure_fight", "zone": &"ember_rift"})
	guest.pick_legend(&"brann")
	(peers[2] as FakeRtc).poll()
	(peers[3] as FakeRtc).poll()
	var got: Array = []
	host.start_requested.connect(func(c: Dictionary) -> void: got.append(c))
	guest.start_requested.connect(func(c: Dictionary) -> void: got.append(c))
	host.set_ready(true)
	guest.set_ready(true)
	(peers[2] as FakeRtc).poll()
	(peers[3] as FakeRtc).poll()
	assert_true(host.start_match())
	(peers[3] as FakeRtc).poll()
	assert_eq(got.size(), 2)
	for config: Dictionary in got:
		assert_eq(config.mode, MatchRules.MODE_PURE_FIGHT_ONLINE)
		assert_eq(config.zone, &"ember_rift")
		assert_eq(config.fighters[1].character, &"brann")
		assert_false(config.fighters[0].is_ai)
		assert_false(config.fighters[1].is_ai)
	assert_eq(got[0], got[1], "identical on both peers")
	assert_true(MatchRules.problems(got[0]).is_empty())


func test_a_pure_fight_match_over_the_link_stays_in_sync_with_the_remote_peer() -> void:
	var a := FakeRtc.new()
	var b := FakeRtc.new()
	a.other = b
	b.other = a
	var link := _link("Player One")
	link.name = DuoLink.NODE_NAME
	get_tree().root.add_child(link)
	link.attach(a, 0)
	var config := PureFightNet.build_config({"host_legend": &"kael", "guest_legend": &"lyra"}, 77)
	link.match_seed = 77
	link.partner_loaded_seed = 77
	var level := PureFightMatch.new()
	level.skip_world = true
	level.configure(config)
	add_child(level)
	assert_true(level.online, "online over the open link")
	assert_eq(level.local_peer, 0)
	var remote_sim := PureFightNet.new_sim(77, [&"kael", &"lyra"] as Array[StringName])
	var remote := PureFightNet.new_session(remote_sim, b, 1, DuoMatch.INPUT_DELAY)
	var ai := PureFightAI.new()
	ai.setup(1, 4, 5)
	var desyncs: Array = []
	level.net_session.desynced.connect(func(f: int, _x: int, _y: int) -> void: desyncs.append(f))
	remote.desynced.connect(func(f: int, _x: int, _y: int) -> void: desyncs.append(f))
	for t in 1200:
		level.step_tick()
		remote.advance(ai.next_input(remote_sim))
	assert_eq(desyncs, [], "no desync")
	assert_gt(level.net_session.hashes_compared, 10, "hashes compared")
	assert_gt(level.sim.current_tick, 1000, "the match ran")
	b.close()
	level.queue_free()
	link.queue_free()
	await get_tree().process_frame
