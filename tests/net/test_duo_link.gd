extends GutTest
## DuoLink's lobby protocol between two peers over a fake reliable control channel:
## names, picks, the host's setup, ready flags, start with one config, loaded barrier.


class FakeRtc:
	extends WebRtcTransport
	var other: FakeRtc
	var inbox: Array[PackedByteArray] = []
	var open := true

	func is_open() -> bool:
		return open

	func send_control(bytes: PackedByteArray) -> void:
		if open and other.open:
			other.inbox.append(bytes)

	func send(_bytes: PackedByteArray) -> void:
		pass

	func poll() -> void:
		while not inbox.is_empty():
			control_received.emit(inbox.pop_front())

	func close() -> void:
		open = false
		disconnected.emit()


var host: DuoLink
var guest: DuoLink


func before_each() -> void:
	host = _link("Player One")
	guest = _link("Player Two")
	var a := FakeRtc.new()
	var b := FakeRtc.new()
	a.other = b
	b.other = a
	host.attach(a, 0)
	guest.attach(b, 1)
	_pump()


func _link(player: String) -> DuoLink:
	var link := DuoLink.new()
	link.client = AppwriteClient.new()
	link.client.user_name = player
	add_child_autofree(link)
	return link


func _pump() -> void:
	for i in 4:
		host.webrtc.poll()
		guest.webrtc.poll()


func test_both_peers_learn_each_others_names() -> void:
	assert_eq(host.partner_name, "Player Two")
	assert_eq(guest.partner_name, "Player One")
	assert_true(host.is_host())
	assert_false(guest.is_host())


func test_picks_and_the_hosts_setup_reach_the_partner() -> void:
	host.pick_legend(&"brann")
	guest.pick_legend(&"lyra")
	host.set_setup({"zone": &"frozen_peaks", "ai_count": 2, "lives": 9, "minutes": 8, "ai_level": 5})
	_pump()
	for link in [host, guest]:
		assert_eq(link.setup.host_legend, &"brann")
		assert_eq(link.setup.guest_legend, &"lyra")
		assert_eq(link.setup.zone, &"frozen_peaks")
		assert_eq(int(link.setup.ai_count), 2)
		assert_eq(int(link.setup.lives), 9)


func test_only_the_guest_cannot_change_the_setup() -> void:
	guest.set_setup({"zone": &"ember_rift"})
	_pump()
	assert_ne(host.setup.zone, &"ember_rift")


func test_the_match_starts_only_once_both_are_ready() -> void:
	assert_false(host.start_match())
	host.set_ready(true)
	_pump()
	assert_false(host.start_match(), "the guest is not ready")
	guest.set_ready(true)
	_pump()
	assert_true(host.both_ready())
	assert_true(guest.both_ready())


func test_a_setup_change_clears_both_ready_flags() -> void:
	host.set_ready(true)
	guest.set_ready(true)
	_pump()
	host.set_setup({"minutes": 3})
	_pump()
	assert_false(host.both_ready())
	assert_false(guest.both_ready())


func test_start_hands_both_peers_the_same_config_and_the_loaded_barrier_waits_for_both() -> void:
	var configs: Array[Dictionary] = []
	host.start_requested.connect(func(config: Dictionary) -> void: configs.append(config))
	guest.start_requested.connect(func(config: Dictionary) -> void: configs.append(config))
	host.set_ready(true)
	guest.set_ready(true)
	_pump()
	assert_true(host.start_match())
	_pump()
	assert_eq(configs.size(), 2)
	assert_eq(configs[0], configs[1], "both peers launch an identical config")
	assert_eq(configs[0].mode, MatchRules.MODE_DUO)
	assert_eq(DuoMatch.new_sim(configs[0]).state_hash(), DuoMatch.new_sim(configs[1]).state_hash())
	assert_false(host.partner_loaded())
	host.report_loaded()
	_pump()
	assert_true(guest.partner_loaded())
	assert_false(host.partner_loaded())
	guest.report_loaded()
	_pump()
	assert_true(host.partner_loaded())


func test_leaving_tells_the_partner() -> void:
	watch_signals(guest)
	host.leave()
	guest.webrtc.poll()
	assert_signal_emitted(guest, "partner_left")
	assert_eq(host.stage, DuoLink.Stage.IDLE)


func test_the_duo_screen_goes_back_to_host_or_join_when_the_partner_leaves() -> void:
	var screen := DuoScreen.new()
	screen.link = guest
	screen.session_store = SessionStore.new("user://test_duo_link_none.cfg", "user://test_duo_link_none.key")
	add_child_autofree(screen)
	guest.client.user_id = "skybreak-player-2"
	screen.enter()
	screen.refresh()
	assert_eq(screen.page, DuoScreen.Page.SETUP)
	host.leave()
	guest.webrtc.poll()
	assert_eq(screen.page, DuoScreen.Page.CHOOSE)
	assert_string_contains(screen.status_label.text, "left")
	assert_eq(guest.stage, DuoLink.Stage.IDLE)
