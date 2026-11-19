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
## Exponential smoothing rates (per second): position follows faster than rotation.
@export var position_sharpness := 14.0
@export var rotation_sharpness := 9.0
## How fast the shoulder blends to its new side, in sides per second.
@export var shoulder_switch_speed := 2.5
## How fast the locked-on mouse orbit springs back once the mouse stops.
@export var orbit_return_sharpness := 4.0
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
		goal = LockOnFraming.locked_pose(player, target, _shoulder, orbit)
	else:
		free_pitch = clampf(free_pitch, LockOnFraming.MIN_FREE_PITCH, LockOnFraming.MAX_FREE_PITCH)
		goal = LockOnFraming.free_pose(player, free_yaw, free_pitch)

	if not _has_pose:
		global_transform = goal
		fov = fov_goal
		_has_pose = true
		return
	fov = lerpf(fov, fov_goal, _blend(fov_sharpness, delta))
	var position_now := global_position.lerp(goal.origin, _blend(position_sharpness, delta))
	var rotation_now := global_basis.get_rotation_quaternion().slerp(
		goal.basis.get_rotation_quaternion(), _blend(rotation_sharpness, delta))
	global_transform = Transform3D(Basis(rotation_now), position_now)


## Frame-rate independent lerp weight for exponential smoothing.
static func _blend(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)
