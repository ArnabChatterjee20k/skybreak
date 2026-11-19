extends GutTest
## Lobby and WebRTC wiring, without touching the network.

const LOBBY_PATH := "res://game/net/duo_lobby.tscn"


## A lobby that never reads the player's real remembered session.
func _new_lobby() -> DuoLobby:
	var lobby: DuoLobby = (load(LOBBY_PATH) as PackedScene).instantiate()
	lobby.session_store = SessionStore.new("user://test_duo_lobby_none.cfg",
		"user://test_duo_lobby_none.key")
	return add_child_autofree(lobby)


func test_the_lobby_scene_opens_with_sign_in_host_and_join() -> void:
	var lobby := _new_lobby()
	assert_not_null(lobby.get_node("%HostButton"))
	assert_not_null(lobby.get_node("%JoinButton"))
	assert_true(lobby.get_node("%PasswordField").secret, "password is masked")
	assert_true(lobby.get_node("%SignInBox").visible)
	assert_not_null(lobby.signalling)
	assert_null(lobby.session)


func test_without_webrtc_the_lobby_says_so_instead_of_signing_in() -> void:
	if WebRtcTransport.is_available():
		pass_test("WebRTC is available in this build")
		return
	var lobby := _new_lobby()
	lobby.get_node("%HostButton").pressed.emit()
	assert_string_contains(lobby.get_node("%Status").text, "webrtc-native")
	assert_eq(lobby.signalling.client.user_id, "", "never signed in")
	assert_false(lobby.get_node("%HostButton").disabled, "buttons usable again")


func test_a_short_code_is_refused() -> void:
	var lobby := _new_lobby()
	lobby.get_node("%CodeField").text = "AB"
	lobby.get_node("%JoinButton").pressed.emit()
	assert_string_contains(lobby.get_node("%Status").text, "5-letter")


func test_the_webrtc_transport_refuses_to_start_without_the_extension() -> void:
	if WebRtcTransport.is_available():
		pass_test("WebRTC is available in this build")
		return
	var transport := WebRtcTransport.new()
	assert_eq(transport.start(true), ERR_UNAVAILABLE)
	assert_false(transport.is_open())
	transport.send(PackedByteArray([1]))
	transport.poll()


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


func test_net_code_holds_no_appwrite_secrets() -> void:
	for file in DirAccess.get_files_at("res://game/net"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://game/net/" + file)
		assert_false(text.contains("X-Appwrite-Key"), file + " sends no API key")
		assert_false(text.contains("standard_"), file + " embeds no API key")
