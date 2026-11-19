class_name LockOnFraming
extends RefCounted
## Where the fight camera wants to be, as pure functions of fighter positions.
## FighterCamera smooths toward these poses; tests check them directly.

## Range bands in metres: at CLOSE_RANGE the camera sits to the side, at
## FAR_RANGE directly behind and low.
const CLOSE_RANGE := 5.0
const FAR_RANGE := 40.0
const CLOSE_SIDE_ANGLE := deg_to_rad(25.0)
const CLOSE_BOOM_LENGTH := 4.5
const FAR_BOOM_LENGTH := 8.0
const CLOSE_HEIGHT := 1.8
const FAR_HEIGHT := 0.7
const SHOULDER_OFFSET := 0.9
## Mouse orbit limits while locked on.
const MAX_ORBIT_YAW := deg_to_rad(35.0)
const MAX_ORBIT_PITCH := deg_to_rad(20.0)
## Free (unlocked) camera.
const FREE_BOOM_LENGTH := 6.0
const FREE_LOOK_HEIGHT := 1.2
const MIN_FREE_PITCH := deg_to_rad(-70.0)
const MAX_FREE_PITCH := deg_to_rad(60.0)
## How much of the opponent's elevation the boom follows: opponent above means
## camera below, so both stay in view.
const ELEVATION_FOLLOW := 0.7
## Steepest the locked camera may look down / up. Bigger height gaps pull the
## camera back and widen the FOV instead of tilting further.
const MAX_VIEW_PITCH_DOWN := deg_to_rad(35.0)
const MAX_VIEW_PITCH_UP := deg_to_rad(25.0)
## Most the FOV widens (degrees) for big height gaps.
const MAX_FOV_BOOST := 10.0
## The opponent must cross this far past centre before the shoulder flips.
const SHOULDER_SWITCH_MARGIN := 0.15


## Camera pose while locked on. shoulder: -1 camera left of the player .. +1 right
## (blends smoothly); the opponent shows on the shoulder side of the screen.
## orbit: mouse offset in radians (x yaw, y pitch), clamped to the orbit limits.
static func locked_pose(player: Vector3, target: Vector3, shoulder: float, orbit: Vector2) -> Transform3D:
	var to_target := target - player
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var facing := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var far_blend := range_blend(to_target.length())
	var clamped := clamp_orbit(orbit)

	var behind := -facing
	var side_angle := lerpf(CLOSE_SIDE_ANGLE, 0.0, far_blend) * shoulder
	var boom := behind.rotated(Vector3.UP, side_angle + clamped.x)
	var boom_side := boom.cross(Vector3.UP).normalized()
	var elevation := atan2(to_target.y, maxf(flat.length(), 0.01))
	var boom_pitch := clampf(clamped.y - elevation * ELEVATION_FOLLOW, -MAX_VIEW_PITCH_UP, MAX_VIEW_PITCH_DOWN)
	boom = boom.rotated(boom_side, boom_pitch)

	var position := player \
		+ boom * lerpf(CLOSE_BOOM_LENGTH, FAR_BOOM_LENGTH, far_blend) \
		+ Vector3.UP * lerpf(CLOSE_HEIGHT, FAR_HEIGHT, far_blend) \
		+ facing.cross(Vector3.UP).normalized() * SHOULDER_OFFSET * shoulder
	var look_at_point := player.lerp(target, 0.5)
	position = _pulled_back_to_pitch_limit(position, look_at_point, behind)
	return _looking_at(position, look_at_point)


## Vertical FOV in degrees for a locked camera with base_fov normally.
## Widens linearly once the height angle between the fighters passes the pitch
## limit, reaching MAX_FOV_BOOST 30 degrees later.
static func locked_fov(base_fov: float, player: Vector3, target: Vector3) -> float:
	var gap := target - player
	var height_angle := atan2(absf(gap.y), maxf(Vector2(gap.x, gap.z).length(), 0.01))
	var limit := MAX_VIEW_PITCH_UP if gap.y > 0.0 else MAX_VIEW_PITCH_DOWN
	var excess := clampf((height_angle - limit) / deg_to_rad(30.0), 0.0, 1.0)
	return base_fov + MAX_FOV_BOOST * excess


## Camera pose while not locked on: orbit the player at yaw/pitch.
static func free_pose(player: Vector3, yaw: float, pitch: float) -> Transform3D:
	var clamped_pitch := clampf(pitch, MIN_FREE_PITCH, MAX_FREE_PITCH)
	var boom := Vector3.BACK.rotated(Vector3.RIGHT, -clamped_pitch).rotated(Vector3.UP, yaw)
	var pivot := player + Vector3.UP * FREE_LOOK_HEIGHT
	return _looking_at(pivot + boom * FREE_BOOM_LENGTH, pivot)


## 0 at close range, 1 at far range.
static func range_blend(distance: float) -> float:
	return clampf((distance - CLOSE_RANGE) / (FAR_RANGE - CLOSE_RANGE), 0.0, 1.0)


static func clamp_orbit(orbit: Vector2) -> Vector2:
	return Vector2(
		clampf(orbit.x, -MAX_ORBIT_YAW, MAX_ORBIT_YAW),
		clampf(orbit.y, -MAX_ORBIT_PITCH, MAX_ORBIT_PITCH))


## Which shoulder to sit on: the side of the screen the opponent is on.
## Keeps the current side while the opponent is inside the centre margin.
static func shoulder_side_for(camera: Transform3D, target: Vector3, current_side: float) -> float:
	var local := camera.affine_inverse() * target
	if local.z >= 0.0:
		return current_side
	var screen_x := local.x / -local.z
	if screen_x > SHOULDER_SWITCH_MARGIN:
		return 1.0
	if screen_x < -SHOULDER_SWITCH_MARGIN:
		return -1.0
	return signf(current_side) if current_side != 0.0 else 1.0


## Slides the camera horizontally away from the look point until looking at it
## is no steeper than the pitch limits. Keeps the camera's height.
static func _pulled_back_to_pitch_limit(position: Vector3, look_at_point: Vector3, behind: Vector3) -> Vector3:
	var to_look := look_at_point - position
	var flat := Vector3(to_look.x, 0.0, to_look.z)
	var limit := MAX_VIEW_PITCH_DOWN if to_look.y < 0.0 else MAX_VIEW_PITCH_UP
	var needed := absf(to_look.y) / tan(limit)
	if flat.length() >= needed:
		return position
	var away := -flat.normalized() if flat.length() > 0.01 else behind
	return position + away * (needed - flat.length())


static func _looking_at(position: Vector3, look_at_point: Vector3) -> Transform3D:
	var direction := look_at_point - position
	if direction.length() < 0.001:
		return Transform3D(Basis.IDENTITY, position)
	var up := Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.99 else Vector3.BACK
	return Transform3D(Basis.looking_at(direction, up), position)
