class_name DuoLobby
extends Control
## Duo online lobby (GAME_DESIGN §8.2): host or join with a code, connect P2P,
## then run the rollback match. Until the arena takes a RollbackSession
## (match_started), it shows a text readout of the shared match.

## The match is running; an arena can draw session.sim and feed session.advance().
signal match_started(session: RollbackSession)

const INPUT_DELAY := 2

var session: RollbackSession
var signalling: AppwriteSignalling
var _seed: int = 0
var _ai_count: int = 1
var _player_input: KeyboardMouseInput

@onready var _code_field: LineEdit = %CodeField
@onready var _ai_count_field: SpinBox = %AiCount
@onready var _status: Label = %Status
@onready var _readout: Label = %Readout
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton


func _ready() -> void:
	signalling = AppwriteSignalling.new()
	add_child(signalling)
	signalling.status_changed.connect(_show_status)
	signalling.failed.connect(_on_failed)
	signalling.lobby_ready.connect(_on_lobby_ready)
	signalling.peer_connected.connect(_on_peer_connected)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	if not WebRtcTransport.is_available():
		_show_status("WebRTC is missing in this build: see game/net/README.md")


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
