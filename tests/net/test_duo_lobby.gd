extends GutTest
## The Duo screen and WebRTC wiring, without touching the network.

const FakeClient := preload("res://tests/net/fake_appwrite_client.gd")


## A Duo screen that never reads the player's real remembered session.
func _new_screen() -> DuoScreen:
	var link := DuoLink.new()
	link.client = FakeClient.new()
	add_child_autofree(link)
	var screen := DuoScreen.new()
	screen.link = link
	screen.session_store = SessionStore.new("user://test_duo_lobby_none.cfg", "user://test_duo_lobby_none.key")
	add_child_autofree(screen)
	screen.enter()
	return screen


func test_the_duo_screen_opens_on_sign_in_with_a_masked_password() -> void:
	var screen := _new_screen()
	assert_eq(screen.page, DuoScreen.Page.SIGN_IN)
	assert_true(screen.password_field.secret, "password is masked")
	assert_true(screen.email_field.is_visible_in_tree())
	assert_false(screen.host_button.is_visible_in_tree())


func test_a_short_code_is_refused() -> void:
	var screen := _new_screen()
	screen.code_field.text = "AB"
	screen.join_room()
	assert_string_contains(screen.status_label.text, "5-letter")
	assert_eq(screen.link.stage, DuoLink.Stage.IDLE)


func test_the_webrtc_transport_refuses_to_start_without_the_extension() -> void:
	if WebRtcTransport.is_available():
		pass_test("WebRTC is available in this build")
		return
	var transport := WebRtcTransport.new()
	assert_eq(transport.start(true), ERR_UNAVAILABLE)
	assert_false(transport.is_open())
	transport.send(PackedByteArray([1]))
	transport.poll()


func test_without_webrtc_the_screen_says_so() -> void:
	if WebRtcTransport.is_available():
		pass_test("WebRTC is available in this build")
		return
	var screen := _new_screen()
	assert_string_contains(screen.status_label.text, "webrtc-native")


func test_lobby_codes_use_the_unambiguous_alphabet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 100:
		var code := AppwriteSignalling.new_code(rng)
		assert_eq(code.length(), AppwriteSignalling.CODE_LENGTH)
		for letter in code:
			assert_true(letter in AppwriteSignalling.CODE_ALPHABET, letter)


func test_queries_use_appwrite_json_syntax() -> void:
	assert_eq(JSON.stringify(AppwriteClient.equal_query("to", "u1")),
		'{"attribute":"to","method":"equal","values":["u1"]}')


func test_rows_go_to_the_tablesdb_endpoints() -> void:
	var client: FakeClient = add_child_autofree(FakeClient.new())
	await client.create_row("skybreak_lobbies", "ABCDE", {"code": "ABCDE"})
	await client.update_row("skybreak_lobbies", "ABCDE", {"status": "full"})
	await client.delete_row("skybreak_lobbies", "ABCDE")
	assert_eq(client.calls[0].path, "/tablesdb/skybreak/tables/skybreak_lobbies/rows")
	assert_eq(client.calls[0].body.rowId, "ABCDE")
	assert_eq(client.calls[1].path, "/tablesdb/skybreak/tables/skybreak_lobbies/rows/ABCDE")
	assert_eq(client.calls[1].body, {"data": {"status": "full"}})
	assert_eq(client.calls[2].method, HTTPClient.METHOD_DELETE)


func test_net_code_holds_no_appwrite_secrets() -> void:
	for file in DirAccess.get_files_at("res://game/net"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://game/net/" + file)
		assert_false(text.contains("X-Appwrite-Key"), file + " sends no API key")
		assert_false(text.contains("standard_"), file + " embeds no API key")


func test_the_main_menu_opens_the_duo_screen() -> void:
	assert_true(MainMenu.duo_available())
	var front := FrontEnd.new()
	front.light_backdrop = true
	front.skip_splash = true
	add_child_autofree(front)
	assert_true(front.screens.has(&"duo_lobby"))
	assert_true(front.screens[&"duo_lobby"] is DuoScreen)


class OpenedTransport:
	extends WebRtcTransport
	var polls := 0
	var open := false

	func is_open() -> bool:
		return open

	func poll() -> void:
		polls += 1
		if open:
			connected.emit()


func test_signalling_keeps_polling_until_the_open_transport_says_connected() -> void:
	# Regression: polling stopped once is_open() was true, so connected never fired.
	var signalling := AppwriteSignalling.new()
	signalling.client = FakeClient.new()
	add_child_autofree(signalling)
	var transport := OpenedTransport.new()
	signalling.transport = transport
	transport.connected.connect(signalling._on_connected)
	watch_signals(signalling)
	transport.open = true
	signalling._process(0.016)
	assert_eq(transport.polls, 1)
	assert_signal_emitted(signalling, "peer_connected")
