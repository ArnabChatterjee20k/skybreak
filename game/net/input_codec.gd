class_name InputCodec
extends RefCounted
## Compact wire form of a FighterInput: 8 bytes typically, 18 at most.
## Both peers simulate the decoded input, so local play quantises too.
## Layout: flags u8, held u24, move x/y s8, view_yaw u16, then pressed u24,
## released u24 and camera_offset 2 x s16 only when their flag is set.

const _HAS_PRESSED := 1 << 4
const _HAS_RELEASED := 1 << 5
const _HAS_CAMERA := 1 << 6
const _YAW_STEPS := 65536
## Camera offset radians per step (range about +-4 rad).
const _CAMERA_STEP := 1.0 / 8192.0


## Appends input to buffer.
static func write(buffer: StreamPeerBuffer, input: FighterInput) -> void:
	var camera_x := clampi(roundi(input.camera_offset.x / _CAMERA_STEP), -32767, 32767)
	var camera_y := clampi(roundi(input.camera_offset.y / _CAMERA_STEP), -32767, 32767)
	var flags := (clampi(input.vertical, -1, 1) + 1) | ((clampi(input.target_switch, -1, 1) + 1) << 2)
	if input.pressed_actions != 0:
		flags |= _HAS_PRESSED
	if input.released_actions != 0:
		flags |= _HAS_RELEASED
	if camera_x != 0 or camera_y != 0:
		flags |= _HAS_CAMERA
	buffer.put_u8(flags)
	_put_u24(buffer, input.held_actions)
	buffer.put_8(clampi(roundi(input.move.x * 127.0), -127, 127))
	buffer.put_8(clampi(roundi(input.move.y * 127.0), -127, 127))
	buffer.put_u16(posmod(roundi(input.view_yaw / TAU * _YAW_STEPS), _YAW_STEPS))
	if flags & _HAS_PRESSED:
		_put_u24(buffer, input.pressed_actions)
	if flags & _HAS_RELEASED:
		_put_u24(buffer, input.released_actions)
	if flags & _HAS_CAMERA:
		buffer.put_16(camera_x)
		buffer.put_16(camera_y)


## Reads one input written by write().
static func read(buffer: StreamPeerBuffer) -> FighterInput:
	var input := FighterInput.new()
	var flags := buffer.get_u8()
	input.vertical = (flags & 3) - 1
	input.target_switch = ((flags >> 2) & 3) - 1
	input.held_actions = _get_u24(buffer)
	var move := Vector2(buffer.get_8(), buffer.get_8()) / 127.0
	input.move = move.normalized() if move.length_squared() > 1.0 else move
	input.view_yaw = buffer.get_u16() * TAU / _YAW_STEPS
	if flags & _HAS_PRESSED:
		input.pressed_actions = _get_u24(buffer)
	if flags & _HAS_RELEASED:
		input.released_actions = _get_u24(buffer)
	if flags & _HAS_CAMERA:
		input.camera_offset = Vector2(buffer.get_16(), buffer.get_16()) * _CAMERA_STEP
	return input


static func encode(input: FighterInput) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	write(buffer, input)
	return buffer.data_array


static func decode(bytes: PackedByteArray) -> FighterInput:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	return read(buffer)


## Encoded neutral input (nothing held, no movement).
static func neutral() -> PackedByteArray:
	return encode(FighterInput.new())


## Prediction for the next tick: the same input held, with no new presses or releases.
static func predict_from(bytes: PackedByteArray) -> PackedByteArray:
	var input := decode(bytes)
	input.pressed_actions = 0
	input.released_actions = 0
	input.target_switch = 0
	return encode(input)


static func _put_u24(buffer: StreamPeerBuffer, value: int) -> void:
	buffer.put_u16(value & 0xFFFF)
	buffer.put_u8((value >> 16) & 0xFF)


static func _get_u24(buffer: StreamPeerBuffer) -> int:
	var low := buffer.get_u16()
	return low | (buffer.get_u8() << 16)
