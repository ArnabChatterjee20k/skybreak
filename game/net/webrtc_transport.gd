class_name WebRtcTransport
extends NetTransport
## Peer-to-peer transport over a WebRTC data channel pair: "inputs" is
## unreliable and unordered (per-tick inputs), "control" is reliable (match
## setup, pause). Built into the web export; desktop builds need the official
## webrtc-native GDExtension (see game/net/README.md). Offer, answer and ICE
## candidates leave through the signals and arrive through the setters, so any
## signalling channel works (Appwrite here: AppwriteSignalling).

## Send this session description to the other peer ("offer" or "answer").
signal local_description_ready(type: String, sdp: String)
## Send this ICE candidate to the other peer.
signal local_candidate_ready(media: String, index: int, candidate: String)
## A packet on the reliable control channel.
signal control_received(bytes: PackedByteArray)
## Both channels are open.
signal connected
## The connection failed or closed.
signal disconnected

## Public STUN only; TURN is not set up (GAME_DESIGN §12.1).
const ICE_SERVERS := [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]
const _INPUTS_CHANNEL_ID := 1
const _CONTROL_CHANNEL_ID := 2

var _connection: WebRTCPeerConnection
var _inputs: WebRTCDataChannel
var _control: WebRTCDataChannel
var _was_open := false


## True when this build can open WebRTC connections (web export, or the GDExtension loaded).
static func is_available() -> bool:
	return OS.has_feature("web") or ClassDB.class_exists(&"WebRTCLibPeerConnection")


## Opens the connection; the offerer creates the offer, the other side waits for it.
func start(is_offerer: bool) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	_connection = WebRTCPeerConnection.new()
	var error := _connection.initialize({"iceServers": ICE_SERVERS})
	if error != OK:
		return error
	_connection.session_description_created.connect(_on_description_created)
	_connection.ice_candidate_created.connect(
		func(media: String, index: int, candidate: String) -> void:
			local_candidate_ready.emit(media, index, candidate))
	# Negotiated channels: both sides create them with the same ids, no in-band setup.
	_inputs = _connection.create_data_channel("inputs",
		{"negotiated": true, "id": _INPUTS_CHANNEL_ID, "ordered": false, "maxRetransmits": 0})
	_control = _connection.create_data_channel("control",
		{"negotiated": true, "id": _CONTROL_CHANNEL_ID, "ordered": true})
	if _inputs == null or _control == null:
		return ERR_CANT_CREATE
	if is_offerer:
		return _connection.create_offer()
	return OK


func set_remote_description(type: String, sdp: String) -> Error:
	return _connection.set_remote_description(type, sdp)


func add_remote_candidate(media: String, index: int, candidate: String) -> Error:
	return _connection.add_ice_candidate(media, index, candidate)


func send(bytes: PackedByteArray) -> void:
	if is_open():
		_inputs.put_packet(bytes)


func send_control(bytes: PackedByteArray) -> void:
	if is_open():
		_control.put_packet(bytes)


func poll() -> void:
	if _connection == null:
		return
	_connection.poll()
	var open := is_open()
	if open and not _was_open:
		connected.emit()
	var state := _connection.get_connection_state()
	if _was_open and not open or state == WebRTCPeerConnection.STATE_FAILED:
		disconnected.emit()
	_was_open = open
	if _inputs and _inputs.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		while _inputs.get_available_packet_count() > 0:
			received.emit(_inputs.get_packet())
	if _control and _control.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		while _control.get_available_packet_count() > 0:
			control_received.emit(_control.get_packet())


func is_open() -> bool:
	return _inputs != null and _control != null \
		and _inputs.get_ready_state() == WebRTCDataChannel.STATE_OPEN \
		and _control.get_ready_state() == WebRTCDataChannel.STATE_OPEN


func close() -> void:
	if _connection:
		_connection.close()


func _on_description_created(type: String, sdp: String) -> void:
	_connection.set_local_description(type, sdp)
	local_description_ready.emit(type, sdp)
