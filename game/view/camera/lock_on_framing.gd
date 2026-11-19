class_name LockOnFraming
extends RefCounted
## Where the fight camera wants to be, as pure functions of fighter positions.
## FighterCamera smooths toward these poses; tests check them directly.

## Range bands in metres: at CLOSE_RANGE the camera sits to the side, at
## FAR_RANGE directly behind and low.
const CLOSE_RANGE := 5.0
const FAR_RANGE := 40.0
const CLOSE_SIDE_ANGLE := deg_to_rad(25.0)
## Boom lengths keep the camera about 6-6.5 m from the player, so the 2 m tall fighter
## stays at least ~15% of screen height even with the FOV fully widened.
const CLOSE_BOOM_LENGTH := 6.0
const FAR_BOOM_LENGTH := 6.5
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
## Steepest the locked camera may look down / up. Beyond that the opponent may
## leave the frame; OpponentMarker then points at it.
const MAX_VIEW_PITCH_DOWN := deg_to_rad(35.0)
const MAX_VIEW_PITCH_UP := deg_to_rad(25.0)
## Most the FOV widens (degrees) for big height gaps.
const MAX_FOV_BOOST := 10.0
## Where the player sits while locked: this far from the screen centre toward
## the edge away from the shoulder, as a fraction of the half width (1/3 from the edge).
const PLAYER_SCREEN_OFFSET := 1.0 / 3.0
## The opponent must cross past the player by this much (fraction of the half
## width) before the shoulder flips.
const SHOULDER_SWITCH_MARGIN := 0.05
## Screen shape the framing aims for.
const DEFAULT_VERTICAL_FOV := 75.0
const ASPECT := 16.0 / 9.0


## Camera pose while locked on. shoulder: -1 camera left of the player .. +1 right
## (blends smoothly); the opponent shows on the shoulder side of the screen.
## orbit: mouse offset in radians (x yaw, y pitch), clamped to the orbit limits.
## far_blend: 0 close .. 1 far; negative means "from the current distance".
## vertical_fov: degrees, used to put the player at PLAYER_SCREEN_OFFSET.
static func locked_pose(player: Vector3, target: Vector3, shoulder: float, orbit: Vector2,
		far_blend: float = -1.0, vertical_fov: float = DEFAULT_VERTICAL_FOV) -> Transform3D:
	var to_target := target - player
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var facing := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	if far_blend < 0.0:
		far_blend = range_blend(to_target.length())
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
	# Aim beside the player so they sit 1/3 from the edge and the opponent gets
	# the open side; pitch still frames the midpoint.
	var tan_half_h := tan(deg_to_rad(vertical_fov) / 2.0) * ASPECT
	var aside := atan(PLAYER_SCREEN_OFFSET * tan_half_h) * shoulder
	var to_player := player - position
	var heading := Vector3(to_player.x, 0.0, to_player.z).rotated(Vector3.UP, -aside)
	var midpoint_pitch := _clamp_pitch(player.lerp(target, 0.5) - position)
	var look := heading.normalized() * Vector2(midpoint_pitch.x, midpoint_pitch.z).length() + Vector3.UP * midpoint_pitch.y
	var pose := _looking_at(position, position + look)
	# Pitch skews where a yaw offset lands on screen; nudge the yaw until the
	# player is at the intended screen x.
	var wanted_x := -PLAYER_SCREEN_OFFSET * shoulder * tan_half_h
	for _pass in 3:
		var local := pose.affine_inverse() * player
		if local.z >= -0.01:
			break
		var error := atan(local.x / -local.z) - atan(wanted_x)
		look = look.rotated(Vector3.UP, -error)
		pose = _looking_at(position, position + look)
	return pose


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


## Which shoulder to sit on: the opponent should be on the shoulder side of the
## player on screen. Flips once the opponent crosses past the player by the
## margin; there is no dead zone around the screen centre.
static func shoulder_side_for(camera: Transform3D, player: Vector3, target: Vector3, current_side: float) -> float:
	var view := camera.affine_inverse()
	var player_local := view * player
	var target_local := view * target
	if player_local.z >= 0.0 or target_local.z >= 0.0:
		return current_side if current_side != 0.0 else 1.0
	var gap := target_local.x / -target_local.z - player_local.x / -player_local.z
	var margin := SHOULDER_SWITCH_MARGIN * tan(deg_to_rad(DEFAULT_VERTICAL_FOV) / 2.0) * ASPECT
	if current_side >= 0.0 and gap < -margin:
		return -1.0
	if current_side <= 0.0 and gap > margin:
		return 1.0
	return current_side if current_side != 0.0 else 1.0


## Direction with its pitch limited to the view pitch limits; keeps its heading.
static func _clamp_pitch(direction: Vector3) -> Vector3:
	var flat := Vector2(direction.x, direction.z)
	var heading := flat.normalized() if flat.length() > 0.001 else Vector2(0, -1)
	var pitch := clampf(atan2(direction.y, flat.length()), -MAX_VIEW_PITCH_DOWN, MAX_VIEW_PITCH_UP)
	return Vector3(heading.x * cos(pitch), sin(pitch), heading.y * cos(pitch))


static func _looking_at(position: Vector3, look_at_point: Vector3) -> Transform3D:
	var direction := look_at_point - position
	if direction.length() < 0.001:
		return Transform3D(Basis.IDENTITY, position)
	var up := Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.99 else Vector3.BACK
	return Transform3D(Basis.looking_at(direction, up), position)
