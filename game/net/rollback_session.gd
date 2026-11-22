class_name RollbackSession
extends RefCounted
## Rollback netcode over any NetTransport. Every peer runs the same CombatSim:
## local inputs are delayed input_delay ticks and sent each tick (with
## redundancy), missing remote inputs are predicted (last input held), and a
## late input that differs rewinds the sim up to MAX_ROLLBACK ticks and
## re-simulates. AI fighters are driven by bots on every peer, so they cost no
## traffic. Periodic state hashes detect desyncs; a frame-advantage estimate
## slows the peer that runs ahead.

## A confirmed state hash differs between the peers.
signal desynced(frame: int, local_hash: int, remote_hash: int)
## This peer's state hash at frame, once every input up to it is confirmed.
signal hash_checked(frame: int, local_hash: int)

const MAX_ROLLBACK := 8
## Confirmed state hashes are exchanged every this many ticks.
const HASH_INTERVAL := 30
## Most inputs one packet carries (oldest unacknowledged first).
const MAX_INPUTS_PER_PACKET := 24
## A sync skip happens at most once per this many ticks (about 10% slowdown).
const SYNC_SKIP_SPACING := 10
## While the other peer has been silent this long (ms), send at most every QUIET_SEND_MS:
## a stalled or hidden browser tab cannot drain 60 packets a second, and every
## packet repeats the unacknowledged inputs anyway.
const QUIET_AFTER_MS := 250
const QUIET_SEND_MS := 100
## Average frame advantage (ticks) above which this peer skips a tick.
const SYNC_THRESHOLD := 1.0
const _SNAPSHOTS := MAX_ROLLBACK + 2
const _KIND_INPUTS := 1
const _NONE := 1 << 40

var sim: CombatSim
var transport: NetTransport
var local_peer: int
var peer_count: int
var input_delay: int
## Owning peer per fighter, or -1 for an AI fighter.
var fighter_peers: Array[int] = []
## Per fighter: an object with next_input(sim) -> FighterInput for AI fighters, else null.
var bots: Array = []
## Optional match rules with after_tick(sim), run after every tick on every peer
## (round restarts); rolled back with the sim. If they have accepts_input() and it
## is false (intro countdown), every fighter gets neutral input that tick. A
## state_hash() of theirs joins the desync check.
var rules: Object
## Next tick to simulate; frames count from 0 at session start.
var frame: int = 0

# Statistics, for tests and the debug overlay.
var rollbacks: int = 0
var rollback_frames: int = 0
var max_rollback_depth: int = 0
var stalls: int = 0
var sync_skips: int = 0
var desync_frame: int = -1
var hashes_compared: int = 0
var rtt_ms: float = 0.0
## Last state hash both peers agreed on, and its frame (-1 before the first).
var matched_hash: int = 0
var matched_hash_frame: int = -1
## Clock time of the last packet from another peer (0 before the first).
var last_receive_ms: int = 0

var _clock: Callable
## Per peer: frame -> encoded input, as confirmed by its owner.
var _confirmed: Array[Dictionary] = []
## Per peer: highest frame up to which every input is confirmed.
var _contiguous: PackedInt64Array
## Per remote peer: frame -> encoded input used when that frame was simulated.
var _used: Array[Dictionary] = []
## Per peer: the highest of our frames it acknowledged.
var _acked_by: PackedInt64Array
var _rollback_to: int = _NONE
var _snapshots: Array = []
## frame -> state hash at the start of that frame (latest simulation of it).
var _hash_at: Dictionary = {}
var _next_hash_frame: int = HASH_INTERVAL
var _local_hashes: Dictionary = {}
var _remote_hashes: Dictionary = {}
var _last_hash_frame: int = -1
var _last_hash: int = 0
var _remote_frame: PackedInt64Array
var _remote_advantage: PackedFloat64Array
var _advantages: PackedFloat64Array = PackedFloat64Array()
var _last_skip_frame: int = -SYNC_SKIP_SPACING
var _echo_ms: int = 0
var _echo_received_at: int = 0
var _last_send_ms: int = -QUIET_SEND_MS


## fighter_peers[i] is the peer controlling fighter i (-1 = AI, driven by bots[i]).
## clock returns milliseconds; tests pass a virtual one.
func _init(combat_sim: CombatSim, net: NetTransport, local: int, peers: int,
		owners: Array[int], ai: Array = [], delay: int = 2,
		clock: Callable = Callable()) -> void:
	sim = combat_sim
	transport = net
	local_peer = local
	peer_count = peers
	fighter_peers = owners
	input_delay = clampi(delay, 0, MAX_ROLLBACK - 1)
	bots = ai.duplicate()
	bots.resize(owners.size())
	_clock = clock if clock.is_valid() else Time.get_ticks_msec
	_contiguous.resize(peers)
	_acked_by.resize(peers)
	_remote_frame.resize(peers)
	_remote_advantage.resize(peers)
	var neutral := InputCodec.neutral()
	for peer in peers:
		var inputs := {}
		for f in input_delay:
			inputs[f] = neutral
		_confirmed.append(inputs)
		_used.append({})
		_contiguous[peer] = input_delay - 1
		_acked_by[peer] = -1
	_snapshots.resize(_SNAPSHOTS)
	if transport:
		transport.received.connect(on_receive)


## Runs one tick with this peer's input. Returns false when the tick was held
## back (waiting for the remote, or slowing down to let it catch up); the
## input is then dropped. Call once per physics tick.
func advance(local_input: FighterInput) -> bool:
	poll()
	if _must_wait():
		stalls += 1
		_send()
		return false
	if _should_slow_down():
		sync_skips += 1
		_last_skip_frame = frame
		_send()
		return false
	_add_confirmed(local_peer, frame + input_delay, InputCodec.encode(local_input))
	_simulate(frame)
	frame += 1
	_prune()
	_send()
	return true


## Takes in arrived packets and rewinds if a late input changed the past; advance() does this too.
func poll() -> void:
	if transport:
		transport.poll()
	_apply_rollback()
	_confirm_hashes()


## Handles one packet from the transport.
func on_receive(bytes: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	if bytes.size() < 2 or buffer.get_u8() != _KIND_INPUTS:
		return
	var sender := buffer.get_u8()
	if sender >= peer_count or sender == local_peer:
		return
	last_receive_ms = _now()
	var their_frame := buffer.get_32()
	var acks := PackedInt64Array()
	for peer in peer_count:
		acks.append(buffer.get_32())
	var sent_ms := buffer.get_u32()
	var echo_ms := buffer.get_u32()
	var echo_hold := buffer.get_u16()
	var advantage := buffer.get_16() / 100.0
	var hash_frame := buffer.get_32()
	var hash_value := buffer.get_64()
	var start := buffer.get_32()
	var count := buffer.get_u8()
	_remote_frame[sender] = maxi(_remote_frame[sender], their_frame)
	_acked_by[sender] = maxi(_acked_by[sender], acks[local_peer])
	_remote_advantage[sender] = advantage
	if sent_ms >= _echo_ms:
		_echo_ms = sent_ms
		_echo_received_at = _now()
	if echo_ms > 0:
		var sample := float(_now() - echo_ms - echo_hold)
		if sample >= 0.0:
			rtt_ms = sample if rtt_ms == 0.0 else lerpf(rtt_ms, sample, 0.1)
	if hash_frame >= 0:
		_remote_hashes[hash_frame] = hash_value
		_compare_hash(hash_frame)
	for i in count:
		var begin := buffer.get_position()
		InputCodec.read(buffer)
		var input_bytes := bytes.slice(begin, buffer.get_position())
		_add_confirmed(sender, start + i, input_bytes)


## Milliseconds since the last packet from another peer (since the session start before one).
func ms_since_remote() -> int:
	if last_receive_ms == 0:
		last_receive_ms = _now()
	return _now() - last_receive_ms


## Highest frame up to which every peer's input is confirmed.
func confirmed_frame() -> int:
	return _min_contiguous()


func _now() -> int:
	return int(_clock.call()) & 0x7FFFFFFF


func _add_confirmed(peer: int, at: int, bytes: PackedByteArray) -> void:
	if at <= _contiguous[peer] or _confirmed[peer].has(at):
		return
	_confirmed[peer][at] = bytes
	if peer != local_peer and at < frame:
		var used: Variant = _used[peer].get(at)
		if used == null or used != bytes:
			_rollback_to = mini(_rollback_to, at)
	while _confirmed[peer].has(_contiguous[peer] + 1):
		_contiguous[peer] += 1


func _input_for(peer: int, at: int) -> PackedByteArray:
	var bytes: Variant = _confirmed[peer].get(at)
	if bytes != null:
		return bytes
	return InputCodec.predict_from(_confirmed[peer][_contiguous[peer]])


func _simulate(at: int) -> void:
	# Frames up to the confirmed one can never be rewound to again: no snapshot needed.
	if at > _min_contiguous():
		_snapshots[at % _SNAPSHOTS] = [at, sim.snapshot(), _bot_snapshots(),
			SimSnapshot.capture(rules) if rules else null]
	if at % HASH_INTERVAL == 0:
		_hash_at[at] = _state_hash()
	var live: bool = rules == null or not rules.has_method(&"accepts_input") or rules.accepts_input()
	var inputs: Array[FighterInput] = []
	for i in fighter_peers.size():
		var peer := fighter_peers[i]
		if not live:
			if peer >= 0 and peer != local_peer:
				_used[peer][at] = _input_for(peer, at)
			inputs.append(FighterInput.new())
			continue
		if peer < 0:
			inputs.append(bots[i].next_input(sim) if bots[i] else FighterInput.new())
			continue
		var bytes := _input_for(peer, at)
		if peer != local_peer:
			_used[peer][at] = bytes
		inputs.append(InputCodec.decode(bytes))
	sim.tick(inputs)
	if rules:
		rules.after_tick(sim)


func _state_hash() -> int:
	if rules and rules.has_method(&"state_hash"):
		return hash([sim.state_hash(), rules.state_hash()])
	return sim.state_hash()


func _bot_snapshots() -> Array:
	var saved: Array = []
	for bot: Variant in bots:
		saved.append(SimSnapshot.capture(bot) if bot else null)
	return saved


func _apply_rollback() -> void:
	if _rollback_to >= frame:
		_rollback_to = _NONE
		return
	var to := _rollback_to
	_rollback_to = _NONE
	var saved: Array = _snapshots[to % _SNAPSHOTS]
	assert(saved != null and saved[0] == to, "rollback target outside the snapshot window")
	sim.restore(saved[1])
	for i in bots.size():
		if bots[i]:
			(saved[2][i] as SimSnapshot).restore_into(bots[i])
	if rules:
		(saved[3] as SimSnapshot).restore_into(rules)
	var depth := frame - to
	rollbacks += 1
	rollback_frames += depth
	max_rollback_depth = maxi(max_rollback_depth, depth)
	for f in range(to, frame):
		_simulate(f)


func _prune() -> void:
	var keep_from := frame - _SNAPSHOTS - 2
	for peer in peer_count:
		var oldest := mini(keep_from, _contiguous[peer] - 1)
		if peer == local_peer:
			oldest = mini(oldest, _min_ack())
		for at: int in _confirmed[peer].keys():
			if at < oldest:
				_confirmed[peer].erase(at)
		for at: int in _used[peer].keys():
			if at < keep_from:
				_used[peer].erase(at)
	for at: int in _hash_at.keys():
		if at < keep_from:
			_hash_at.erase(at)


func _min_contiguous() -> int:
	var lowest := _NONE
	for peer in peer_count:
		lowest = mini(lowest, _contiguous[peer])
	return lowest


func _min_remote_contiguous() -> int:
	var lowest := _NONE
	for peer in peer_count:
		if peer != local_peer:
			lowest = mini(lowest, _contiguous[peer])
	return lowest


func _min_ack() -> int:
	var lowest := _NONE
	for peer in peer_count:
		if peer != local_peer:
			lowest = mini(lowest, _acked_by[peer])
	return lowest


## Predicting further than MAX_ROLLBACK past the last confirmed input would leave no snapshot to rewind to.
func _must_wait() -> bool:
	return frame > _min_remote_contiguous() + MAX_ROLLBACK


func _should_slow_down() -> bool:
	var advantage := _local_advantage()
	_advantages.append(advantage)
	if _advantages.size() > 32:
		_advantages = _advantages.slice(_advantages.size() - 32)
	if frame - _last_skip_frame < SYNC_SKIP_SPACING or _advantages.size() < 16:
		return false
	var average := 0.0
	for value in _advantages:
		average += value
	average /= _advantages.size()
	var remote := 0.0
	for peer in peer_count:
		if peer != local_peer:
			remote += _remote_advantage[peer] / (peer_count - 1)
	return (average - remote) * 0.5 >= SYNC_THRESHOLD


## How many ticks this peer runs ahead of the slowest remote, by its last reported frame plus half the round trip.
func _local_advantage() -> float:
	var ahead := -INF
	for peer in peer_count:
		if peer == local_peer:
			continue
		var estimate := _remote_frame[peer] + rtt_ms * 0.5 * CombatSim.TICKS_PER_SECOND / 1000.0
		ahead = maxf(ahead, frame - estimate)
	return 0.0 if ahead == -INF else ahead


func _confirm_hashes() -> void:
	while frame > _next_hash_frame and _min_contiguous() >= _next_hash_frame - 1:
		var at := _next_hash_frame
		if _hash_at.has(at):
			_local_hashes[at] = _hash_at[at]
			_last_hash_frame = at
			_last_hash = _hash_at[at]
			hash_checked.emit(at, _last_hash)
			_compare_hash(at)
		_next_hash_frame += HASH_INTERVAL


func _compare_hash(at: int) -> void:
	if not _local_hashes.has(at) or not _remote_hashes.has(at):
		return
	hashes_compared += 1
	var local_hash: int = _local_hashes[at]
	var remote_hash: int = _remote_hashes[at]
	_local_hashes.erase(at)
	_remote_hashes.erase(at)
	if local_hash == remote_hash:
		matched_hash = local_hash
		matched_hash_frame = at
	if local_hash != remote_hash and desync_frame < 0:
		desync_frame = at
		desynced.emit(at, local_hash, remote_hash)


func _send() -> void:
	if transport == null:
		return
	var sent_at := _now()
	if last_receive_ms > 0 and sent_at - last_receive_ms > QUIET_AFTER_MS \
			and sent_at - _last_send_ms < QUIET_SEND_MS:
		return
	_last_send_ms = sent_at
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(_KIND_INPUTS)
	buffer.put_u8(local_peer)
	buffer.put_32(frame)
	for peer in peer_count:
		buffer.put_32(_contiguous[peer])
	var now := _now()
	buffer.put_u32(now)
	buffer.put_u32(_echo_ms)
	buffer.put_u16(clampi(now - _echo_received_at, 0, 65535) if _echo_ms > 0 else 0)
	buffer.put_16(clampi(roundi(_local_advantage() * 100.0), -32767, 32767))
	buffer.put_32(_last_hash_frame)
	buffer.put_64(_last_hash)
	var newest := frame + input_delay - 1
	var start := maxi(_min_ack() + 1, 0)
	start = maxi(start, _oldest_local())
	var count := clampi(newest - start + 1, 0, MAX_INPUTS_PER_PACKET)
	buffer.put_32(start)
	buffer.put_u8(count)
	for i in count:
		buffer.put_data(_confirmed[local_peer][start + i])
	transport.send(buffer.data_array)


func _oldest_local() -> int:
	var oldest := _NONE
	for at: int in _confirmed[local_peer].keys():
		oldest = mini(oldest, at)
	return oldest
