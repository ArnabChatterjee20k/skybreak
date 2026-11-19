extends GutTest
## Email/password sign-in, the remembered session and the signed-in lobby flow,
## all over a fake HTTP layer.

const FakeClient := preload("res://tests/net/fake_appwrite_client.gd")
const LOBBY_PATH := "res://game/net/duo_lobby.tscn"
const SESSION_PATH := "user://test_skybreak_session.cfg"
const KEY_PATH := "user://test_skybreak_install.key"
## A made-up password: the tests check it never leaves the sign-in request.
const PASSWORD := "not-a-real-password-7731"
const EMAIL := "skybreak-player-1@example.com"
const PLAYER := "skybreak-player-1"

var store: SessionStore


func before_each() -> void:
	store = SessionStore.new(SESSION_PATH, KEY_PATH)
	store.clear()


func after_each() -> void:
	store.clear()
	if FileAccess.file_exists(KEY_PATH):
		DirAccess.remove_absolute(KEY_PATH)


func _new_client() -> FakeClient:
	var client: FakeClient = FakeClient.new()
	client.accept_sign_in(PLAYER, "Player One")
	return client


func _new_lobby(client: FakeClient) -> DuoLobby:
	var lobby: DuoLobby = (load(LOBBY_PATH) as PackedScene).instantiate()
	lobby.client = client
	lobby.session_store = store
	add_child_autofree(lobby)
	return lobby


func _sign_in_through_ui(lobby: DuoLobby, remember: bool) -> void:
	lobby.get_node("%EmailField").text = EMAIL
	lobby.get_node("%PasswordField").text = PASSWORD
	lobby.get_node("%RememberCheck").button_pressed = remember
	lobby.get_node("%SignInButton").pressed.emit()
	await wait_until(func() -> bool: return lobby.client.is_signed_in(), 1.0)


func test_sign_in_posts_email_and_password_to_the_email_session_endpoint() -> void:
	var client: FakeClient = add_child_autofree(_new_client())
	var error: String = await client.sign_in_with_email(" " + EMAIL + " ", PASSWORD)
	assert_eq(error, "")
	var posts := client.calls_to(HTTPClient.METHOD_POST, "/account/sessions/email")
	assert_eq(posts.size(), 1)
	assert_eq(posts[0].body, {"email": EMAIL, "password": PASSWORD})
	assert_true("X-Appwrite-Project: " + AppwriteClient.PROJECT_ID in posts[0].headers)
	assert_eq(client.calls_to(HTTPClient.METHOD_POST, "/account/sessions/anonymous").size(), 0,
		"no anonymous sessions")
	assert_eq(client.user_id, PLAYER)
	assert_eq(client.user_name, "Player One")


func test_later_requests_carry_the_session_cookie() -> void:
	var client: FakeClient = add_child_autofree(_new_client())
	await client.sign_in_with_email(EMAIL, PASSWORD)
	await client.get_document("skybreak_lobbies", "ABCDE")
	var gets := client.calls_to(HTTPClient.METHOD_GET, "/databases/skybreak/")
	assert_true("Cookie: %s=cookie-%s" % [FakeClient.SESSION_COOKIE, PLAYER] in gets[0].headers)


func test_a_wrong_password_leaves_the_player_signed_out() -> void:
	var client: FakeClient = add_child_autofree(FakeClient.new())
	client.replies["POST /account/sessions/email"] = {"code": 401,
		"body": {"message": "Invalid credentials."}}
	var error: String = await client.sign_in_with_email(EMAIL, "wrong")
	assert_string_contains(error, "401")
	assert_false(client.is_signed_in())
	assert_eq(client.export_session().cookies, {})


func test_the_exported_session_holds_no_password() -> void:
	var client: FakeClient = add_child_autofree(_new_client())
	await client.sign_in_with_email(EMAIL, PASSWORD)
	var exported := client.export_session()
	assert_false(JSON.stringify(exported).contains(PASSWORD))
	assert_eq(exported.user_id, PLAYER)


func test_remember_me_saves_the_session_encrypted_and_without_the_password() -> void:
	var lobby := _new_lobby(_new_client())
	await _sign_in_through_ui(lobby, true)
	assert_true(store.has_session(), "session saved")
	var raw := FileAccess.get_file_as_bytes(SESSION_PATH)
	assert_false(raw.get_string_from_ascii().contains(PASSWORD), "no password in the file")
	assert_false(raw.get_string_from_ascii().contains("cookie-" + PLAYER), "file is encrypted")
	var saved := store.load_session()
	assert_eq(saved.user_id, PLAYER)
	assert_eq((saved.cookies as Dictionary)[FakeClient.SESSION_COOKIE], "cookie-" + PLAYER)
	assert_false(var_to_str(saved).contains(PASSWORD), "no password in the saved values")
	assert_eq(lobby.get_node("%PasswordField").text, "", "password field cleared")


func test_without_remember_me_nothing_is_saved() -> void:
	var lobby := _new_lobby(_new_client())
	await _sign_in_through_ui(lobby, false)
	assert_true(lobby.client.is_signed_in())
	assert_false(store.has_session())


func test_the_lobby_shows_the_player_name_and_sign_out_once_signed_in() -> void:
	var lobby := _new_lobby(_new_client())
	assert_true(lobby.get_node("%SignInBox").visible)
	assert_false(lobby.get_node("%SignedInRow").visible)
	await _sign_in_through_ui(lobby, false)
	assert_false(lobby.get_node("%SignInBox").visible)
	assert_true(lobby.get_node("%SignedInRow").visible)
	assert_string_contains(lobby.get_node("%PlayerName").text, "Player One")


func test_sign_out_ends_the_session_and_clears_the_saved_one() -> void:
	var lobby := _new_lobby(_new_client())
	await _sign_in_through_ui(lobby, true)
	var client: FakeClient = lobby.client
	lobby.get_node("%SignOutButton").pressed.emit()
	await wait_until(func() -> bool: return not client.is_signed_in(), 1.0)
	assert_eq(client.calls_to(HTTPClient.METHOD_DELETE, "/account/sessions/current").size(), 1)
	assert_false(store.has_session())
	assert_eq(client.export_session().cookies, {})
	assert_true(lobby.get_node("%SignInBox").visible)


func test_a_remembered_session_signs_back_in_on_restart() -> void:
	var first := _new_client()
	add_child_autofree(first)
	await first.sign_in_with_email(EMAIL, PASSWORD)
	store.save(first.export_session())
	var client := _new_client()
	var lobby := _new_lobby(client)
	await wait_until(func() -> bool: return client.is_signed_in(), 1.0)
	assert_eq(client.user_id, PLAYER)
	assert_eq(client.calls_to(HTTPClient.METHOD_POST, "/account/sessions/email").size(), 0,
		"no password needed")
	assert_eq(client.calls_to(HTTPClient.METHOD_PATCH, "/account/sessions/current").size(), 1,
		"session extended")
	var account := client.calls_to(HTTPClient.METHOD_GET, "/account")
	assert_true("Cookie: %s=cookie-%s" % [FakeClient.SESSION_COOKIE, PLAYER] in account[0].headers)
	assert_true(lobby.get_node("%SignedInRow").visible)


func test_an_expired_remembered_session_is_dropped() -> void:
	store.save({"cookies": {FakeClient.SESSION_COOKIE: "stale"}, "fallback_cookies": "",
		"user_id": PLAYER, "user_name": "Player One"})
	var client: FakeClient = FakeClient.new()
	client.replies["GET /account"] = {"code": 401, "body": {"message": "expired"}}
	var lobby := _new_lobby(client)
	await wait_until(func() -> bool: return not store.has_session(), 1.0)
	assert_false(client.is_signed_in())
	assert_false(store.has_session())
	assert_true(lobby.get_node("%SignInBox").visible)


func test_hosting_before_sign_in_is_refused() -> void:
	var signalling := AppwriteSignalling.new()
	signalling.client = FakeClient.new()
	signalling.require_webrtc = false
	add_child_autofree(signalling)
	watch_signals(signalling)
	await signalling.host(1)
	assert_signal_emitted_with_parameters(signalling, "failed", ["Sign in first"])
	assert_eq((signalling.client as FakeClient).calls.size(), 0)


func test_the_host_creates_the_lobby_as_the_signed_in_player() -> void:
	var client := _new_client()
	var signalling := AppwriteSignalling.new()
	signalling.client = client
	signalling.require_webrtc = false
	add_child_autofree(signalling)
	await client.sign_in_with_email(EMAIL, PASSWORD)
	await signalling.host(2)
	signalling.close()
	var creates := client.calls_to(HTTPClient.METHOD_POST, "/databases/skybreak/collections/skybreak_lobbies/documents")
	assert_eq(creates.size(), 1)
	var body: Dictionary = creates[0].body
	assert_eq(body.documentId, signalling.lobby_code)
	assert_eq(body.data.host, PLAYER)
	assert_eq(body.data.status, "open")
	assert_eq(body.data.ai_count, 2.0)
	assert_eq(body.permissions, ['read("users")', 'update("users")', 'delete("user:%s")' % PLAYER])


func test_the_guest_claims_the_lobby_with_its_own_user_id() -> void:
	var client: FakeClient = FakeClient.new()
	client.accept_sign_in("skybreak-player-2", "Player Two")
	client.replies["GET /databases/skybreak/collections/skybreak_lobbies/documents/ABCDE"] = {
		"code": 200, "body": {"$id": "ABCDE", "code": "ABCDE", "host": PLAYER, "guest": "",
			"status": "open", "seed": 99, "ai_count": 1}}
	var signalling := AppwriteSignalling.new()
	signalling.client = client
	signalling.require_webrtc = false
	add_child_autofree(signalling)
	watch_signals(signalling)
	await client.sign_in_with_email("skybreak-player-2@example.com", PASSWORD)
	await signalling.join("abcde")
	signalling.close()
	var updates := client.calls_to(HTTPClient.METHOD_PATCH, "/databases/skybreak/collections/skybreak_lobbies/documents/ABCDE")
	assert_eq(updates[0].body, {"data": {"guest": "skybreak-player-2", "status": "full"}})
	assert_signal_emitted_with_parameters(signalling, "lobby_ready", ["ABCDE", 99, 1])


func test_signal_documents_are_readable_by_both_players_and_deletable_by_the_receiver() -> void:
	assert_eq(AppwriteSignalling.signal_permissions("skybreak-player-1", "skybreak-player-2"),
		['read("user:skybreak-player-2")', 'read("user:skybreak-player-1")',
			'delete("user:skybreak-player-2")'] as Array[String])


func test_net_code_signs_in_without_anonymous_sessions() -> void:
	for file in DirAccess.get_files_at("res://game/net"):
		if file.ends_with(".gd"):
			var text := FileAccess.get_file_as_string("res://game/net/" + file)
			assert_false(text.contains("sessions/anonymous"), file)
