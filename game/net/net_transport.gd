class_name NetTransport
extends RefCounted
## Moves byte packets between this peer and the others; RollbackSession only
## sees send() and the received signal. Inputs go unreliable and unordered.

## A packet from another peer, delivered during poll().
signal received(bytes: PackedByteArray)


## Sends bytes to every other peer; may be dropped, delayed or reordered.
func send(_bytes: PackedByteArray) -> void:
	pass


## Delivers packets that have arrived; call once per frame.
func poll() -> void:
	pass


## True while packets can flow.
func is_open() -> bool:
	return false
