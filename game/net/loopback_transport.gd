class_name LoopbackTransport
extends NetTransport
## In-process transport for tests: one-way latency, jitter and loss from a
## seeded rng, against a clock the test advances (milliseconds).

var latency_ms: float = 0.0
var jitter_ms: float = 0.0
## Chance in 0..1 that a packet is dropped.
var loss: float = 0.0
var rng := RandomNumberGenerator.new()
var sent_packets: int = 0
var dropped_packets: int = 0
var sent_bytes: int = 0
var _clock: Callable
## The other end, weak so the pair is not a reference cycle; the caller keeps both ends.
var _peer: WeakRef
## [deliver_at_ms, bytes] pairs waiting to arrive at this end.
var _in_flight: Array = []


func _init(clock: Callable, seed_value: int = 0) -> void:
	_clock = clock
	rng.seed = seed_value


## Makes two connected ends. rtt_ms is split evenly between the two directions.
static func pair(clock: Callable, rtt_ms: float = 0.0, jitter: float = 0.0,
		loss_chance: float = 0.0, seed_value: int = 0) -> Array[LoopbackTransport]:
	var a := LoopbackTransport.new(clock, seed_value)
	var b := LoopbackTransport.new(clock, seed_value + 1)
	for end in [a, b]:
		end.latency_ms = rtt_ms * 0.5
		end.jitter_ms = jitter
		end.loss = loss_chance
	a._peer = weakref(b)
	b._peer = weakref(a)
	return [a, b]


func send(bytes: PackedByteArray) -> void:
	sent_packets += 1
	sent_bytes += bytes.size()
	if rng.randf() < loss:
		dropped_packets += 1
		return
	var delay := maxf(latency_ms + rng.randf_range(-jitter_ms, jitter_ms), 0.0)
	var peer := _peer.get_ref() as LoopbackTransport
	if peer == null:
		return
	peer._in_flight.append([float(_clock.call()) + delay, bytes.duplicate()])


func poll() -> void:
	var now := float(_clock.call())
	var waiting: Array = []
	var arrived: Array = []
	for packet: Array in _in_flight:
		if packet[0] <= now:
			arrived.append(packet)
		else:
			waiting.append(packet)
	_in_flight = waiting
	arrived.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for packet: Array in arrived:
		received.emit(packet[1])


func is_open() -> bool:
	return _peer != null and _peer.get_ref() != null
