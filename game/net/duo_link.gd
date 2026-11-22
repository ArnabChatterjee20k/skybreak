class_name DuoLink
extends Node
## The Duo connection, kept at /root/DuoLink so it outlives scene changes (menu ->
## match -> menu). Owns the signed-in AppwriteClient, the lobby/signalling and the
## open WebRTC transport, and runs the lobby protocol on the reliable control
## channel: names, legend picks, the host's setup, ready flags, start and a
## loaded barrier, so both peers start the match on the same tick.

signal changed
signal failed(message: String)
## The host sent start: config is the MatchConfig dictionary to launch.
signal start_requested(config: Dictionary)
signal partner_left

const NODE_NAME := "DuoLink"
const PROTOCOL := 1

enum Stage { IDLE, HOSTING, JOINING, CONNECTED }

var client: AppwriteClient
var signalling: AppwriteSignalling
var webrtc: WebRtcTransport
## What RollbackSession sends over: webrtc, or a LaggyTransport around it (dev).
var transport: NetTransport
var stage := Stage.IDLE
var local_peer: int = -1
var lobby_code: String = ""
var status: String = ""
var partner_name: String = ""
## Lobby picks: host_legend, guest_legend, zone, ai_count, ai_level, lives, minutes.
var setup := {
	"host_legend": &"kael", "guest_legend": &"vexa", "zone": &"heartbloom_gardens",
	"ai_count": 1, "ai_level": DuoMatch.DEFAULT_AI_LEVEL, "lives": DuoFlow.DEFAULT_LIVES,
	"minutes": DuoFlow.DEFAULT_MINUTES,
}
var ready_flags: Array[bool] = [false, false]
## Seed of the match the partner reported loaded (-1 none).
var partner_loaded_seed: int = -1
var match_seed: int = -1


## The link at /root/DuoLink, created on first use.
static func instance(tree: SceneTree) -> DuoLink:
	var existing := tree.root.get_node_or_null(NODE_NAME) as DuoLink
	if existing:
		return existing
	var link := DuoLink.new()
	link.name = NODE_NAME
	tree.root.add_child(link)
	return link


static func find(tree: SceneTree) -> DuoLink:
	return tree.root.get_node_or_null(NODE_NAME) as DuoLink if tree else null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if client == null:
		client = AppwriteClient.new()
	if client.get_parent() == null:
		add_child(client)


func _process(_delta: float) -> void:
	if webrtc:
		webrtc.poll()


func is_connected_to_partner() -> bool:
	return stage == Stage.CONNECTED and webrtc != null and webrtc.is_open()


func is_host() -> bool:
	return local_peer == 0


## Opens a lobby; the code arrives through changed (lobby_code).
func host() -> void:
	_new_signalling()
	stage = Stage.HOSTING
	signalling.host(int(setup.ai_count))


func join(code: String) -> void:
	_new_signalling()
	stage = Stage.JOINING
	signalling.join(code)


## Closes the lobby and the connection and tells the partner.
func leave() -> void:
	var was_host := is_host()
	if is_connected_to_partner():
		send_control({"t": "leave"})
		webrtc.poll()
	stage = Stage.IDLE
	if signalling:
		signalling.close()
		signalling.queue_free()
		signalling = null
	if webrtc:
		webrtc.close()
	if was_host and lobby_code and client.is_signed_in():
		client.update_row(AppwriteSignalling.LOBBIES, lobby_code, {"status": "closed"})
	webrtc = null
	transport = null
	stage = Stage.IDLE
	local_peer = -1
	lobby_code = ""
	partner_name = ""
	ready_flags = [false, false]
	partner_loaded_seed = -1
	match_seed = -1
	_set_status("")


func send_control(message: Dictionary) -> void:
	if webrtc and webrtc.is_open():
		webrtc.send_control(JSON.stringify(message).to_utf8_buffer())


## Sets this player's legend and tells the partner.
func pick_legend(legend: StringName) -> void:
	setup["host_legend" if is_host() else "guest_legend"] = legend
	ready_flags[local_peer] = false
	send_control({"t": "pick", "legend": String(legend)})
	changed.emit()


## Host only: zone, AI count and level, lives, minutes.
func set_setup(values: Dictionary) -> void:
	if not is_host():
		return
	for key: String in ["zone", "ai_count", "ai_level", "lives", "minutes"]:
		if values.has(key):
			setup[key] = values[key]
	ready_flags = [false, false]
	send_control({"t": "setup", "zone": String(setup.zone), "ai_count": setup.ai_count,
		"ai_level": setup.ai_level, "lives": setup.lives, "minutes": setup.minutes})
	changed.emit()


func set_ready(value: bool) -> void:
	ready_flags[local_peer] = value
	send_control({"t": "ready", "ready": value})
	changed.emit()


func both_ready() -> bool:
	return ready_flags[0] and ready_flags[1]


## Host only, once both are ready: picks the seed, tells the guest, starts locally.
func start_match() -> bool:
	if not is_host() or not both_ready() or not is_connected_to_partner():
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Both peers launch the same wire form, so they build identical sims.
	var config := _unwire_config(_wire_config(DuoMatch.build_config(setup, rng.randi() & 0x7FFFFFFF)))
	_begin(config)
	send_control({"t": "start", "config": _wire_config(config)})
	start_requested.emit(config)
	return true


## The match scene is built and its session waits: tell the partner.
func report_loaded() -> void:
	send_control({"t": "loaded", "seed": match_seed})


func partner_loaded() -> bool:
	return match_seed >= 0 and partner_loaded_seed == match_seed


## Back in the lobby after a match: nobody is ready yet.
func reset_for_lobby() -> void:
	ready_flags = [false, false]
	partner_loaded_seed = -1
	match_seed = -1
	changed.emit()


func _begin(config: Dictionary) -> void:
	match_seed = int(config.seed)
	ready_flags = [false, false]


func _new_signalling() -> void:
	if signalling:
		signalling.close()
		signalling.queue_free()
	signalling = AppwriteSignalling.new()
	signalling.client = client
	add_child(signalling)
	signalling.status_changed.connect(_set_status)
	signalling.failed.connect(_on_failed)
	signalling.lobby_ready.connect(func(code: String, _seed: int, _ai: int) -> void:
		lobby_code = code
		changed.emit())
	signalling.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(open: WebRtcTransport, peer: int) -> void:
	var handed := signalling.release_transport() if signalling else null
	attach(handed if handed else open, peer)


## Takes over an open transport as peer (0 host, 1 guest) and starts the lobby protocol.
func attach(open: WebRtcTransport, peer: int) -> void:
	webrtc = open
	local_peer = peer
	stage = Stage.CONNECTED
	webrtc.control_received.connect(_on_control)
	webrtc.disconnected.connect(_on_disconnected)
	transport = _dev_transport(webrtc)
	send_control({"t": "hello", "v": PROTOCOL, "name": client.user_name})
	if is_host():
		set_setup({})
	else:
		pick_legend(setup.guest_legend)
	_set_status("Connected to your partner")


func _dev_transport(raw: WebRtcTransport) -> NetTransport:
	var lag := float(DevParams.get_value("net_lag", "0"))
	var jitter := float(DevParams.get_value("net_jitter", "0"))
	var loss := float(DevParams.get_value("net_loss", "0"))
	if lag <= 0.0 and jitter <= 0.0 and loss <= 0.0:
		return raw
	return LaggyTransport.new(raw, lag, jitter, loss, 7 + local_peer)


func _on_control(bytes: PackedByteArray) -> void:
	var message: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not message is Dictionary:
		return
	var partner := 1 - local_peer
	match String(message.get("t", "")):
		"hello":
			partner_name = String(message.get("name", "Partner"))
			if int(message.get("v", 0)) != PROTOCOL:
				_on_failed("Your partner runs a different game version: both reload the game")
		"pick":
			setup["guest_legend" if is_host() else "host_legend"] = StringName(message.get("legend", "kael"))
			ready_flags[partner] = false
		"setup":
			if not is_host():
				setup.zone = StringName(message.get("zone", setup.zone))
				for key: String in ["ai_count", "ai_level", "lives", "minutes"]:
					setup[key] = int(message.get(key, setup[key]))
				ready_flags = [false, false]
		"ready":
			ready_flags[partner] = bool(message.get("ready", false))
		"start":
			if not is_host():
				var config := _unwire_config(message.get("config", {}))
				_begin(config)
				start_requested.emit(config)
		"loaded":
			partner_loaded_seed = int(message.get("seed", -1))
		"leave":
			_set_status("Your partner left")
			partner_left.emit()
	changed.emit()


func _on_disconnected() -> void:
	if stage == Stage.CONNECTED:
		_set_status("Connection to your partner lost")
		partner_left.emit()
		changed.emit()


func _on_failed(message: String) -> void:
	_set_status(message)
	failed.emit(message)
	changed.emit()


func _set_status(message: String) -> void:
	status = message
	changed.emit()


## JSON has no StringName and turns ints into floats: send plain values.
static func _wire_config(config: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(config))


static func _unwire_config(wire: Dictionary) -> Dictionary:
	var fighters: Array[Dictionary] = []
	for entry: Dictionary in wire.get("fighters", []):
		fighters.append(MatchRules.fighter(StringName(entry.get("character", "kael")),
			int(entry.get("team", 0)), bool(entry.get("is_ai", false)), int(entry.get("ai_level", 3))))
	var config := MatchRules.make(MatchRules.MODE_DUO, StringName(wire.get("zone", "heartbloom_gardens")),
		fighters, int(wire.get("rounds", 1)))
	config["seed"] = int(wire.get("seed", 0))
	config["lives"] = int(wire.get("lives", DuoFlow.DEFAULT_LIVES))
	config["minutes"] = int(wire.get("minutes", DuoFlow.DEFAULT_MINUTES))
	return config
