class_name FighterCamera
extends Camera3D
## Fight camera. Free orbit around the player when unlocked; over-the-shoulder
## framing of both fighters when locked on. Click captures the mouse, Esc frees it.

## Vertical FOV in degrees; the locked camera widens it for big height gaps.
@export var base_fov := 75.0
## How fast the FOV eases to its goal, per second.
@export var fov_sharpness := 6.0
## Radians of camera turn per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025
## Exponential smoothing rates (per second). The camera follows the player
## rigidly; only its offset from the player (boom) and its rotation are smoothed,
## so fast flight never stretches the camera distance.
@export var position_sharpness := 14.0
@export var rotation_sharpness := 9.0
## How fast the shoulder blends to its new side, in sides per second.
@export var shoulder_switch_speed := 2.5
## How fast the locked-on mouse orbit springs back once the mouse stops.
@export var orbit_return_sharpness := 4.0
## How fast the close/far framing follows the fighters' distance, per second.
## Low on purpose: boom length and side angle change over ~0.5 s or more.
@export var range_blend_sharpness := 2.5
## Seconds without mouse movement before the orbit starts springing back.
@export var orbit_return_delay := 0.2

## Mouse orbit offset while locked on (x yaw, y pitch); FighterInput.camera_offset.
var orbit := Vector2.ZERO
var free_yaw := 0.0
var free_pitch := deg_to_rad(15.0)

var _shoulder := 1.0
var _shoulder_goal := 1.0
var _seconds_since_mouse_moved := 0.0
var _has_pose := false
var _far_blend := -1.0
## Camera position relative to the player, smoothed.
var _offset := Vector3.ZERO
var _was_locked := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_mouse_motion(event.relative)


## Turns the camera by a mouse movement in pixels (right/down positive).
func add_mouse_motion(relative: Vector2) -> void:
	var turn := relative * mouse_sensitivity
	free_yaw -= turn.x
	free_pitch += turn.y
	orbit = LockOnFraming.clamp_orbit(orbit + Vector2(-turn.x, turn.y))
	_seconds_since_mouse_moved = 0.0


## Camera heading in radians, for FighterInput.view_yaw.
func view_yaw() -> float:
	return global_rotation.y


## Moves the camera toward its framing for this frame. target is ignored when unlocked.
func follow(player: Vector3, target: Vector3, locked: bool, delta: float) -> void:
	_seconds_since_mouse_moved += delta
	var goal: Transform3D
	var fov_goal := LockOnFraming.locked_fov(base_fov, player, target) if locked else base_fov
	if locked:
		if _seconds_since_mouse_moved > orbit_return_delay:
			orbit = orbit.lerp(Vector2.ZERO, _blend(orbit_return_sharpness, delta))
		_shoulder_goal = LockOnFraming.shoulder_side_for(global_transform, target, _shoulder_goal)
		_shoulder = move_toward(_shoulder, _shoulder_goal, shoulder_switch_speed * delta)
		var range_goal := LockOnFraming.range_blend(player.distance_to(target))
		if _far_blend < 0.0:
			_far_blend = range_goal
		else:
			_far_blend = lerpf(_far_blend, range_goal, _blend(range_blend_sharpness, delta))
		goal = LockOnFraming.locked_pose(player, target, _shoulder, orbit, _far_blend)
	else:
		if _was_locked and _has_pose:
			_continue_free_orbit_from_here(player)
		free_pitch = clampf(free_pitch, LockOnFraming.MIN_FREE_PITCH, LockOnFraming.MAX_FREE_PITCH)
		goal = LockOnFraming.free_pose(player, free_yaw, free_pitch)
	_was_locked = locked

	if not _has_pose:
		global_transform = goal
		fov = fov_goal
		_offset = goal.origin - player
		_has_pose = true
		return
	fov = lerpf(fov, fov_goal, _blend(fov_sharpness, delta))
	# slerp turns the offset around the player instead of cutting through it.
	_offset = _offset.slerp(goal.origin - player, _blend(position_sharpness, delta))
	var position_now := player + _offset
	var rotation_now := global_basis.get_rotation_quaternion().slerp(
		goal.basis.get_rotation_quaternion(), _blend(rotation_sharpness, delta))
	global_transform = Transform3D(Basis(rotation_now), position_now)


## Starts the free orbit where the camera already is, so unlocking doesn't swing it.
func _continue_free_orbit_from_here(player: Vector3) -> void:
	var from_pivot := global_position - (player + Vector3.UP * LockOnFraming.FREE_LOOK_HEIGHT)
	if from_pivot.length() < 0.01:
		return
	var direction := from_pivot.normalized()
	free_yaw = atan2(direction.x, direction.z)
	free_pitch = asin(clampf(direction.y, -1.0, 1.0))


## Frame-rate independent lerp weight for exponential smoothing.
static func _blend(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)
