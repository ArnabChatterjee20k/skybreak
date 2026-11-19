class_name FighterInput
extends RefCounted
## One fighter's controls for one combat tick. The sim reads only this, never
## Input or the camera, so the same struct serves keyboard, AI, replays and
## a second local player.

enum Action {
	LIGHT = 1 << 0,
	HEAVY = 1 << 1,
	BLOCK = 1 << 2,
	DASH = 1 << 3,
	GRAB = 1 << 4,
	KI_BLAST = 1 << 5,
	CHARGE = 1 << 6,
	SPECIAL_1 = 1 << 7,
	SPECIAL_2 = 1 << 8,
	SPECIAL_3 = 1 << 9,
	ULTIMATE = 1 << 10,
	TRANSFORM = 1 << 11,
	BREAKER = 1 << 12,
	LOCK_TOGGLE = 1 << 13,
	PICKUP = 1 << 14, ## G: pick up a weapon in reach; with none in reach, throw the held one.
	WEAPON_NEXT = 1 << 15, ## Cycle Unarmed -> slot 1 -> slot 2 -> slot 3.
	WEAPON_PREVIOUS = 1 << 16,
	THROW = 1 << 17, ## Throw the held weapon.
}

## Bitmasks of Action values: held this tick, went down this tick, went up this tick.
var held_actions: int = 0
var pressed_actions: int = 0
var released_actions: int = 0
## Planar movement relative to the camera: x = strafe right, y = forward. Length <= 1.
var move: Vector2 = Vector2.ZERO
## Vertical movement: -1 descend, 0 none, +1 ascend.
var vertical: int = 0
## Camera heading in radians; free-flight movement is relative to it.
var view_yaw: float = 0.0
## Mouse orbit offset while locked on, in radians: x = yaw, y = pitch.
var camera_offset: Vector2 = Vector2.ZERO
## Lock-on target switch requested this tick: -1 previous, 0 none, +1 next.
var target_switch: int = 0


## Builds an input from held actions, deriving pressed/released from last tick.
static func from_held(held: int, previous: FighterInput) -> FighterInput:
	var input := FighterInput.new()
	input.held_actions = held
	input.pressed_actions = held & ~previous.held_actions
	input.released_actions = previous.held_actions & ~held
	return input


func is_held(action: Action) -> bool:
	return (held_actions & action) != 0


func is_pressed(action: Action) -> bool:
	return (pressed_actions & action) != 0


func is_released(action: Action) -> bool:
	return (released_actions & action) != 0
