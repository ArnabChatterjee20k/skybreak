class_name DuoLobby
extends Control
## Duo online lobby (GAME_DESIGN §8.2): sign in with a player account, host or
## join with a code, connect P2P, then run the rollback match. Until the arena takes a RollbackSession
## (match_started), it shows a text readout of the shared match.

## The match is running; an arena can draw session.sim and feed session.advance().
signal match_started(session: RollbackSession)

const INPUT_DELAY := 2

var session: RollbackSession
var signalling: AppwriteSignalling
## Set before adding the lobby to swap the HTTP layer or the session file (tests).
var client: AppwriteClient
var session_store: SessionStore
var _seed: int = 0
var _ai_count: int = 1
var _player_input: KeyboardMouseInput

@onready var _code_field: LineEdit = %CodeField
@onready var _ai_count_field: SpinBox = %AiCount
@onready var _status: Label = %Status
@onready var _readout: Label = %Readout
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _sign_in_box: Control = %SignInBox
@onready var _email_field: LineEdit = %EmailField
@onready var _password_field: LineEdit = %PasswordField
@onready var _remember_check: CheckBox = %RememberCheck
@onready var _sign_in_button: Button = %SignInButton
@onready var _signed_in_row: Control = %SignedInRow
@onready var _player_name: Label = %PlayerName
@onready var _sign_out_button: Button = %SignOutButton


func _ready() -> void:
	if client == null:
		client = AppwriteClient.new()
	if session_store == null:
		session_store = SessionStore.new()
	signalling = AppwriteSignalling.new()
	signalling.client = client
	add_child(signalling)
	signalling.status_changed.connect(_show_status)
	signalling.failed.connect(_on_failed)
	signalling.lobby_ready.connect(_on_lobby_ready)
	signalling.peer_connected.connect(_on_peer_connected)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_sign_in_button.pressed.connect(_on_sign_in_pressed)
	_password_field.text_submitted.connect(func(_text: String) -> void: _on_sign_in_pressed())
	_sign_out_button.pressed.connect(_on_sign_out_pressed)
	_show_signed_in()
	if not WebRtcTransport.is_available():
		_show_status("WebRTC is missing in this build: see game/net/README.md")
	restore_saved_session()


## Signs back in from a remembered session, if there is one.
func restore_saved_session() -> void:
	var saved := session_store.load_session()
	if saved.is_empty():
		return
	_remember_check.button_pressed = true
	_set_sign_in_enabled(false)
	_show_status("Signing in")
	var error := await client.restore_session(saved)
	_set_sign_in_enabled(true)
	if error:
		session_store.clear()
		_show_status("Saved sign-in expired: sign in again")
	else:
		session_store.save(client.export_session())
		_show_status("Signed in as %s" % client.user_name)
	_show_signed_in()


func _on_sign_in_pressed() -> void:
	var email := _email_field.text.strip_edges()
	var password := _password_field.text
	if email.is_empty() or password.is_empty():
		_show_status("Type your email and password")
		return
	_set_sign_in_enabled(false)
	_show_status("Signing in")
	var error := await client.sign_in_with_email(email, password)
	password = ""
	_password_field.clear()
	_set_sign_in_enabled(true)
	if error:
		_show_status("Sign-in failed: " + error)
		_show_signed_in()
		return
	if _remember_check.button_pressed:
		session_store.save(client.export_session())
	else:
		session_store.clear()
	_show_status("Signed in as %s" % client.user_name)
	_show_signed_in()


func _on_sign_out_pressed() -> void:
	_sign_out_button.disabled = true
	session_store.clear()
	await client.sign_out()
	_sign_out_button.disabled = false
	_show_status("Signed out")
	_show_signed_in()


func _show_signed_in() -> void:
	var signed_in := client.is_signed_in()
	_sign_in_box.visible = not signed_in
	_signed_in_row.visible = signed_in
	_player_name.text = "Signed in as %s" % client.user_name if signed_in else ""
	_set_buttons_enabled(true)


func _set_sign_in_enabled(enabled: bool) -> void:
	_sign_in_button.disabled = not enabled
	_email_field.editable = enabled
	_password_field.editable = enabled


func _exit_tree() -> void:
	if signalling:
		signalling.close()


func _physics_process(_delta: float) -> void:
	if session == null:
		return
	session.advance(_player_input.read_tick(0.0, Vector2.ZERO))
	_readout.text = _describe()


func _on_host_pressed() -> void:
	_set_buttons_enabled(false)
	signalling.host(int(_ai_count_field.value))


func _on_join_pressed() -> void:
	if _code_field.text.strip_edges().length() != AppwriteSignalling.CODE_LENGTH:
		_show_status("Type the %d-letter code from your partner" % AppwriteSignalling.CODE_LENGTH)
		return
	_set_buttons_enabled(false)
	signalling.join(_code_field.text)


func _on_lobby_ready(code: String, seed_value: int, ai_count: int) -> void:
	_code_field.text = code
	_seed = seed_value
	_ai_count = ai_count


func _on_peer_connected(transport: WebRtcTransport, local_peer: int) -> void:
	var sim := DuoMatch.new_sim(_seed, _ai_count)
	session = RollbackSession.new(sim, transport, local_peer, DuoMatch.HUMAN_PEERS,
		DuoMatch.fighter_peers(sim), DuoMatch.new_bots(sim, _seed), INPUT_DELAY)
	session.rules = DuoMatch.new()
	session.desynced.connect(func(frame: int, _mine: int, _theirs: int) -> void:
		_show_status("Desync at tick %d" % frame))
	_player_input = KeyboardMouseInput.new()
	add_child(_player_input)
	_show_status("Connected: you fly fighter %d" % (local_peer + 1))
	match_started.emit(session)


func _on_failed(message: String) -> void:
	_show_status(message)
	_set_buttons_enabled(true)


func _show_status(message: String) -> void:
	_status.text = message


func _set_buttons_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled
	_sign_out_button.disabled = not enabled


func _describe() -> String:
	var lines: PackedStringArray = [
		"Tick %d  RTT %.0f ms  rollbacks %d (max %d)  stalls %d  sync skips %d" % [
			session.frame, session.rtt_ms, session.rollbacks, session.max_rollback_depth,
			session.stalls, session.sync_skips],
	]
	for i in session.sim.fighters.size():
		var fighter := session.sim.fighters[i]
		var who := "AI" if session.fighter_peers[i] < 0 else \
			("you" if session.fighter_peers[i] == session.local_peer else "partner")
		lines.append("%d %-7s hp %5.1f  %s  %s" % [i + 1, who, fighter.health_display(),
			FighterState.State.keys()[fighter.state], fighter.position.snapped(Vector3.ONE * 0.1)])
	return "\n".join(lines)
