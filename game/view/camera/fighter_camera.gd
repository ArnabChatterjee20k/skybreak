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
## Fastest the view may turn, in degrees per second (anti-nausea). At 60 fps
## that is 3 degrees per frame, so re-locks never snap.
@export var max_turn_speed := 180.0
## A player jump longer than this in one frame (m) is a teleport, e.g. a vanish
## step; normal movement tops out around 1.3 m per frame.
@export var teleport_distance := 3.0
## How fast the camera glides after a teleport, per second (~0.2 s to settle).
@export var teleport_glide_sharpness := 18.0
## How fast the shoulder blends to its new side, in sides per second.
@export var shoulder_switch_speed := 2.5
## How fast the locked-on mouse orbit springs back once the mouse stops.
@export var orbit_return_sharpness := 4.0
## How fast the close/far framing follows the fighters' distance, per second.
## Low on purpose: boom length and side angle change over ~0.5 s or more.
@export var range_blend_sharpness := 2.5
## How fast the boom length (camera distance to the player) eases, per second.
## Slower than position_sharpness so lock/unlock and band changes never pump.
@export var boom_sharpness := 4.0
## The player's centre is kept inside this fraction of the half-screen, so a
## capped re-lock turn can never swing them out of frame.
@export var player_frame_limit := 0.8
## Hit shake: largest camera offset (m) at full trauma, and trauma lost per
## second. Offset only, never rotation, and it scales with trauma squared so
## light hits barely move the view.
@export var max_shake_offset := 0.25
@export var shake_decay := 2.5
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
## The point the camera follows: the player, except while gliding after a teleport.
var _anchor := Vector3.ZERO
var _gliding := false
var _was_locked := false
var _band := LockOnFraming.Band.MID
## True from a re-lock until the view has turned onto the new framing; the
## shoulder side stays fixed meanwhile so it can't flip mid-swing.
var _relock_turning := false
var _trauma := 0.0
var _shake_time := 0.0


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


## Adds hit shake; trauma 0-1, capped at 1 in total.
func shake(trauma: float) -> void:
	_trauma = minf(_trauma + trauma, 1.0)


## Current shake trauma, 0 when still.
func shake_trauma() -> float:
	return _trauma


## Which shoulder the camera is heading for: -1 left, +1 right.
func shoulder_side() -> float:
	return _shoulder_goal


## The camera's current range band (LockOnFraming.Band).
func range_band() -> LockOnFraming.Band:
	return _band


## Camera heading in radians, for FighterInput.view_yaw.
func view_yaw() -> float:
	return global_rotation.y


## Moves the camera toward its framing for this frame. target is ignored when unlocked.
func follow(player: Vector3, target: Vector3, locked: bool, delta: float) -> void:
	_seconds_since_mouse_moved += delta
	var goal: Transform3D
	var fov_goal := base_fov
	if locked:
		if _seconds_since_mouse_moved > orbit_return_delay:
			orbit = orbit.lerp(Vector2.ZERO, _blend(orbit_return_sharpness, delta))
		if not _was_locked and _has_pose:
			_relock_turning = true
		if not _relock_turning:
			_shoulder_goal = LockOnFraming.shoulder_side_for(global_transform, player, target, _shoulder_goal)
		_shoulder = move_toward(_shoulder, _shoulder_goal, shoulder_switch_speed * delta)
		_band = LockOnFraming.band_for(player.distance_to(target), _band)
		var range_goal: float = LockOnFraming.BAND_BLEND[_band]
		if _far_blend < 0.0:
			_far_blend = range_goal
		else:
			_far_blend = lerpf(_far_blend, range_goal, _blend(range_blend_sharpness, delta))
		var widened := LockOnFraming.locked_fov(base_fov, player, target)
		var zoomed := LockOnFraming.far_zoom_fov(widened, global_position.distance_to(target))
		# The zoom follows the band directly; fov_sharpness eases it over ~0.5 s.
		# A big height gap widens the view instead; zooming then would lose the opponent.
		var height_gap_widening := widened > base_fov + 0.01
		# No zoom mid re-lock either: a narrow FOV while the view is still turning
		# would crop the player out.
		var zoom := _band == LockOnFraming.Band.FAR and not height_gap_widening and not _relock_turning
		fov_goal = zoomed if zoom else widened
		goal = LockOnFraming.locked_pose(player, target, _shoulder, orbit, _far_blend, fov_goal)
		if _relock_turning and (-global_basis.z).angle_to(-goal.basis.z) < deg_to_rad(10.0):
			_relock_turning = false
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
		_anchor = player
		_has_pose = true
		return
	fov = lerpf(fov, fov_goal, _blend(fov_sharpness, delta))
	# slerp turns the offset around the player instead of cutting through it;
	# its orbit is capped like the view turn so the two stay in step.
	var offset_from := _offset
	var goal_offset := goal.origin - player
	_offset = offset_from.slerp(goal_offset, _blend(position_sharpness, delta))
	var orbit_angle := offset_from.angle_to(_offset)
	var max_orbit := deg_to_rad(max_turn_speed) * delta
	if orbit_angle > max_orbit:
		_offset = offset_from.slerp(_offset, max_orbit / orbit_angle)
	# Direction from the slerp, length eased on its own, slower.
	var boom := lerpf(offset_from.length(), goal_offset.length(), _blend(boom_sharpness, delta))
	if _offset.length() > 0.001:
		_offset = _offset.normalized() * boom
	_follow_anchor(player, delta)
	var position_now := _anchor + _offset
	var rotation_from := global_basis.get_rotation_quaternion()
	var rotation_now := rotation_from.slerp(
		goal.basis.get_rotation_quaternion(), _blend(rotation_sharpness, delta))
	var turn := rotation_from.angle_to(rotation_now)
	var max_turn := deg_to_rad(max_turn_speed) * delta
	if turn > max_turn:
		rotation_now = rotation_from.slerp(rotation_now, max_turn / turn)
	global_transform = Transform3D(Basis(rotation_now), position_now)
	# Keep the followed point in frame, still within the turn cap.
	_keep_in_frame(_anchor)
	var kept := global_basis.get_rotation_quaternion()
	var total := rotation_from.angle_to(kept)
	if total > max_turn:
		global_basis = Basis(rotation_from.slerp(kept, max_turn / total))
	_apply_shake(delta)


## Offsets the camera by the shake; the next frame starts again from the
## unshaken pose (position comes from _anchor + _offset), so it never drifts.
func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_shake_time += delta
	var amount := max_shake_offset * _trauma * _trauma
	var jitter := Vector3(sin(_shake_time * 71.0), sin(_shake_time * 53.0 + 1.3), 0.0)
	global_position += global_basis * jitter * amount
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)


## Follows the player rigidly, but glides over ~0.2 s after a teleport so a
## vanish step doesn't read as a camera cut.
func _follow_anchor(player: Vector3, delta: float) -> void:
	if not _gliding and _anchor.distance_to(player) > teleport_distance:
		_gliding = true
	if not _gliding:
		_anchor = player
		return
	_anchor = _anchor.lerp(player, _blend(teleport_glide_sharpness, delta))
	if _anchor.distance_to(player) < 0.05:
		_anchor = player
		_gliding = false


## Turns the view just enough to bring point back inside player_frame_limit of
## the screen; does nothing while it is already inside.
func _keep_in_frame(point: Vector3) -> void:
	var local := global_transform.affine_inverse() * point
	if local.z > -0.01:
		return
	var tan_v := tan(deg_to_rad(fov) / 2.0) * player_frame_limit
	var tan_h := tan_v * _aspect()
	var yaw_excess := atan(-local.x / local.z) - atan(tan_h) * signf(local.x)
	var pitch_excess := atan(local.y / -local.z) - atan(tan_v) * signf(local.y)
	var yaw := yaw_excess if absf(local.x / -local.z) > tan_h else 0.0
	var pitch := pitch_excess if absf(local.y / -local.z) > tan_v else 0.0
	if yaw == 0.0 and pitch == 0.0:
		return
	var b := global_basis.rotated(Vector3.UP, -yaw)
	b = b.rotated(b.x, pitch)
	global_basis = b.orthonormalized()


func _aspect() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return LockOnFraming.ASPECT
	var size := viewport.get_visible_rect().size
	return size.x / size.y if size.y > 0.0 else LockOnFraming.ASPECT


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
