class_name LaggyTransport
extends NetTransport
## Dev tool: wraps a real transport and delays, jitters or drops outgoing packets,
## and can hold everything back for a moment (a forced rollback burst on the other
## peer). Only built from DevParams in debug builds (DuoLink).

var inner: NetTransport
var delay_ms: float = 0.0
var jitter_ms: float = 0.0
var loss: float = 0.0
var rng := RandomNumberGenerator.new()
var held_packets: int = 0
var dropped_packets: int = 0
## [send_at_ms, bytes], in send order.
var _queue: Array = []
var _hold_until_ms: int = 0


func _init(wrapped: NetTransport, delay: float, jitter: float, loss_chance: float, seed_value: int = 1) -> void:
	inner = wrapped
	delay_ms = delay
	jitter_ms = jitter
	loss = loss_chance
	rng.seed = seed_value
	inner.received.connect(func(bytes: PackedByteArray) -> void: received.emit(bytes))


## Holds every outgoing packet for ms (they leave together afterwards).
func hold(ms: int) -> void:
	_hold_until_ms = Time.get_ticks_msec() + ms


func send(bytes: PackedByteArray) -> void:
	if rng.randf() < loss:
		dropped_packets += 1
		return
	var at := Time.get_ticks_msec() + maxf(delay_ms + rng.randf_range(-jitter_ms, jitter_ms), 0.0)
	_queue.append([at, bytes])


func poll() -> void:
	var now := Time.get_ticks_msec()
	if now >= _hold_until_ms:
		var waiting: Array = []
		for packet: Array in _queue:
			if packet[0] <= now:
				inner.send(packet[1])
			else:
				waiting.append(packet)
		_queue = waiting
	else:
		held_packets = _queue.size()
	inner.poll()


func is_open() -> bool:
	return inner.is_open()
