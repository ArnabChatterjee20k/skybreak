extends GutTest

var _now := [0.0]


func _clock() -> float:
	return _now[0]


func test_a_packet_arrives_after_half_the_round_trip() -> void:
	var ends := LoopbackTransport.pair(_clock, 100.0)
	watch_signals(ends[1])
	ends[0].send(PackedByteArray([7]))
	_now[0] = 49.0
	ends[1].poll()
	assert_signal_not_emitted(ends[1], "received")
	_now[0] = 50.0
	ends[1].poll()
	assert_signal_emitted_with_parameters(ends[1], "received", [PackedByteArray([7])])


func test_loss_drops_about_the_configured_share() -> void:
	var ends := LoopbackTransport.pair(_clock, 0.0, 0.0, 0.02, 3)
	for i in 5000:
		ends[0].send(PackedByteArray([1]))
	assert_between(ends[0].dropped_packets, 50, 150)


func test_jitter_can_reorder_packets() -> void:
	var ends := LoopbackTransport.pair(_clock, 20.0, 10.0, 0.0, 5)
	var order: Array[int] = []
	ends[1].received.connect(func(bytes: PackedByteArray) -> void: order.append(bytes[0]))
	for i in 50:
		ends[0].send(PackedByteArray([i]))
		_now[0] += 1.0
	_now[0] += 100.0
	ends[1].poll()
	assert_eq(order.size(), 50)
	var sorted := order.duplicate()
	sorted.sort()
	assert_ne(order, sorted, "some packets overtook others")
