class_name AppwriteSignalling
extends Node
## Duo lobby and WebRTC signalling over two Appwrite TablesDB tables: the host
## creates a lobby row under a short code, the guest joins it, then offer, answer
## and ICE candidates travel as rows in skybreak_signals, polled about twice a
## second (signalling tolerates the latency; inputs then go P2P).

## The lobby exists (host) or was joined (guest); code is what the partner types.
signal lobby_ready(code: String, seed_value: int, ai_count: int)
## The data channels are open: start the match.
signal peer_connected(transport: WebRtcTransport, local_peer: int)
## Something went wrong; message is for the status line.
signal failed(message: String)
## Progress for the status line.
signal status_changed(message: String)

const LOBBIES := "skybreak_lobbies"
const SIGNALS := "skybreak_signals"
const POLL_SECONDS := 0.5
## Without an open data channel this long after the partner shows up, P2P failed
## (both behind strict NATs: needs TURN, which is not set up).
const CONNECT_TIMEOUT_SECONDS := 30.0
const P2P_FAILED_MESSAGE := "Could not connect directly to your partner. One of your networks blocks peer-to-peer (it needs a TURN relay, not set up yet). Try another network, e.g. a phone hotspot."
const CODE_LENGTH := 5
## No 0/O or 1/I, so codes read out loud survive.
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

## The signed-in client; set it before adding this node to share the lobby's sign-in.
var client: AppwriteClient
## Off only in tests, which check the row flow without the WebRTC extension.
var require_webrtc := true
## Makes the transport; tests and the dev lag tool wrap or replace it.
var transport_factory: Callable = func() -> WebRtcTransport: return WebRtcTransport.new()
var transport: WebRtcTransport
var lobby_code: String = ""
var is_host: bool = false
var _partner_id: String = ""
var _seen: Dictionary = {}
var _polling := false
var _poll_timer: Timer
var _connect_deadline_ms: int = -1
var _closed := false


func _ready() -> void:
	if client == null:
		client = AppwriteClient.new()
	if client.get_parent() == null:
		add_child(client)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_SECONDS
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)


func _process(_delta: float) -> void:
	if transport and not transport.is_open() and not _closed:
		transport.poll()
		if _connect_deadline_ms > 0 and Time.get_ticks_msec() > _connect_deadline_ms:
			_connect_deadline_ms = -1
			_poll_timer.stop()
			failed.emit(P2P_FAILED_MESSAGE)


## Opens a new lobby with a fresh code and match seed.
func host(ai_count: int) -> void:
	is_host = true
	if not _ready_to_start():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := rng.randi() & 0x7FFFFFFF
	for attempt in 3:
		lobby_code = new_code(rng)
		var response := await client.create_row(LOBBIES, lobby_code, {
			"code": lobby_code, "host": client.user_id, "guest": "", "status": "open",
			"seed": seed_value, "ai_count": ai_count,
		}, lobby_permissions(client.user_id))
		if not response.error:
			status_changed.emit("Lobby %s: waiting for your partner" % lobby_code)
			lobby_ready.emit(lobby_code, seed_value, ai_count)
			_poll_timer.start()
			return
		if response.code != 409:
			failed.emit("Could not create the lobby: " + response.error)
			return
	failed.emit("Could not find a free lobby code")


## Joins the lobby with this code.
func join(code: String) -> void:
	is_host = false
	lobby_code = code.strip_edges().to_upper()
	if not _ready_to_start():
		return
	var response := await client.get_row(LOBBIES, lobby_code)
	if response.error:
		failed.emit("No lobby %s (%s)" % [lobby_code, response.error])
		return
	var lobby: Dictionary = response.body
	if lobby.get("status") != "open" or lobby.get("guest", "") not in ["", client.user_id]:
		failed.emit("Lobby %s is already full" % lobby_code)
		return
	_partner_id = lobby.get("host", "")
	response = await client.update_row(LOBBIES, lobby_code,
		{"guest": client.user_id, "status": "full"})
	if response.error:
		failed.emit("Could not join: " + response.error)
		return
	lobby_ready.emit(lobby_code, int(lobby.get("seed", 0)), int(lobby.get("ai_count", 1)))
	status_changed.emit("Joined %s: connecting to your partner" % lobby_code)
	if not _start_transport(false):
		return
	_poll_timer.start()


## A random lobby code from CODE_ALPHABET.
static func new_code(rng: RandomNumberGenerator) -> String:
	var code := ""
	for i in CODE_LENGTH:
		code += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
	return code


## Lobby row permissions (README): any signed-in player reads and claims it, the host deletes it.
static func lobby_permissions(host_id: String) -> Array[String]:
	return ['read("users")', 'update("users")', 'delete("user:%s")' % host_id]


## Signal row permissions. Appwrite refuses a client granting a role it does not hold
## (user:<partner>), so rows are readable by signed-in players; the inbox query
## filters by lobby and receiver, and the receiver deletes each row after use.
static func signal_permissions(_from_id: String, _to_id: String) -> Array[String]:
	return ['read("users")', 'delete("users")']


## Stops polling and closes the connection; the host marks the lobby closed.
func close() -> void:
	if _closed:
		return
	_closed = true
	_connect_deadline_ms = -1
	if _poll_timer:
		_poll_timer.stop()
	if transport:
		transport.close()
	if is_host and lobby_code and client.is_signed_in():
		client.update_row(LOBBIES, lobby_code, {"status": "closed"})


## Hands the open transport over (to DuoLink); this node stops touching it.
func release_transport() -> WebRtcTransport:
	var handed := transport
	transport = null
	_closed = true
	_connect_deadline_ms = -1
	if _poll_timer:
		_poll_timer.stop()
	return handed


func _ready_to_start() -> bool:
	if require_webrtc and not WebRtcTransport.is_available():
		failed.emit("WebRTC is not available in this build (desktop needs the webrtc-native GDExtension; see game/net/README.md)")
		return false
	if not client.is_signed_in():
		failed.emit("Sign in first")
		return false
	return true


func _start_transport(offerer: bool) -> bool:
	transport = transport_factory.call()
	transport.local_description_ready.connect(
		func(type: String, sdp: String) -> void: _send_signal(type, {"type": type, "sdp": sdp}))
	transport.local_candidate_ready.connect(
		func(media: String, index: int, candidate: String) -> void:
			_send_signal("ice", {"media": media, "index": index, "candidate": candidate}))
	transport.connected.connect(_on_connected)
	transport.disconnected.connect(func() -> void:
		if not _closed:
			_poll_timer.stop()
			failed.emit(P2P_FAILED_MESSAGE))
	var error := transport.start(offerer)
	if error != OK:
		failed.emit("WebRTC failed to start (%s)" % error_string(error))
		return false
	_connect_deadline_ms = Time.get_ticks_msec() + int(CONNECT_TIMEOUT_SECONDS * 1000.0)
	return true


func _send_signal(kind: String, payload: Dictionary) -> void:
	var response := await client.create_row(SIGNALS, "", {
		"lobby": lobby_code, "from": client.user_id, "to": _partner_id,
		"kind": kind, "payload": JSON.stringify(payload),
	}, signal_permissions(client.user_id, _partner_id))
	if response.error and not _closed:
		failed.emit("Signalling failed: " + response.error)


func _poll() -> void:
	if _polling or _closed:
		return
	_polling = true
	if is_host and _partner_id.is_empty():
		var lobby := await client.get_row(LOBBIES, lobby_code)
		var guest: String = lobby.body.get("guest", "")
		if guest and not _closed:
			_partner_id = guest
			status_changed.emit("Partner joined: connecting")
			_start_transport(true)
	elif transport:
		var response := await client.list_rows(SIGNALS, [
			AppwriteClient.equal_query("lobby", lobby_code),
			AppwriteClient.equal_query("to", client.user_id),
			AppwriteClient.order_ascending_query("$createdAt"),
		])
		for row: Dictionary in response.body.get("rows", []):
			var id: String = row["$id"]
			if _seen.has(id) or _closed or transport == null:
				continue
			_seen[id] = true
			_apply_signal(row)
			client.delete_row(SIGNALS, id)
	_polling = false


func _apply_signal(row: Dictionary) -> void:
	var payload: Variant = JSON.parse_string(row.get("payload", "{}"))
	if not payload is Dictionary:
		return
	match row.get("kind", ""):
		"offer", "answer":
			transport.set_remote_description(payload["type"], payload["sdp"])
		"ice":
			transport.add_remote_candidate(payload["media"], int(payload["index"]), payload["candidate"])


func _on_connected() -> void:
	_poll_timer.stop()
	_connect_deadline_ms = -1
	status_changed.emit("Connected")
	if is_host:
		client.update_row(LOBBIES, lobby_code, {"status": "in_match"})
	peer_connected.emit(transport, 0 if is_host else 1)
