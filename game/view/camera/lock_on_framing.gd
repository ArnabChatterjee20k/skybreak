class_name LockOnFraming
extends RefCounted
## Where the fight camera wants to be, as pure functions of fighter positions.
## FighterCamera smooths toward these poses; tests check them directly.

## Range bands (design §4.2). Near: shorter boom swung ~25° aside so spacing
## reads. Mid: the standard framing. Far: behind and low with a narrowed FOV so
## the opponent stays readable. Entering and leaving a band use different
## distances (hysteresis) so the framing doesn't flicker at the edges.
enum Band { NEAR, MID, FAR }
const NEAR_ENTER := 9.0
const NEAR_EXIT := 11.0
const FAR_ENTER := 32.0
const FAR_EXIT := 28.0
## far_blend each band eases toward: 0 = near framing, 1 = far framing.
const BAND_BLEND := {Band.NEAR: 0.0, Band.MID: 0.5, Band.FAR: 1.0}
## Far band zoom: keep a 2 m fighter at least this tall (px at 1080p), but
## never narrower than MIN_ZOOM_FOV.
const FAR_OPPONENT_PIXELS := 40.0
const MIN_ZOOM_FOV := 40.0
const CLOSE_RANGE := 5.0
const FAR_RANGE := 40.0
const CLOSE_SIDE_ANGLE := deg_to_rad(25.0)
## Boom lengths keep the camera about 6-6.5 m from the player, so the 2 m tall fighter
## stays at least ~15% of screen height even with the FOV fully widened.
const CLOSE_BOOM_LENGTH := 4.0
const FAR_BOOM_LENGTH := 6.5
const CLOSE_HEIGHT := 1.2
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
const MAX_FOV_BOOST := 17.0
## Height of a fighter, for on-screen size targets (m).
const FIGHTER_HEIGHT := 2.0
const FIGHTER_RADIUS := 0.5
## Near band: aim for at least this gap between the fighters on screen, as a
## fraction of the width (the asserted minimum is 10%; the extra leaves margin
## while the band blend settles). The side swing grows in steps up to the maximum.
const MIN_NEAR_SCREEN_GAP := 0.13
const SIDE_ANGLE_STEP := deg_to_rad(5.0)
const MAX_EXTRA_SIDE_ANGLE := deg_to_rad(65.0)
## Where the player sits while locked: this far from the screen centre toward
## the edge away from the shoulder, as a fraction of the half width (1/3 from the edge).
const PLAYER_SCREEN_OFFSET := 1.0 / 3.0
## In the near band the player moves further toward the edge to make room.
const NEAR_PLAYER_SCREEN_OFFSET := 0.45
## The opponent must cross past the player by this much (fraction of the half
## width) before the shoulder flips.
const SHOULDER_SWITCH_MARGIN := 0.05
## Stacked fighters (T-117b): when the height angle between them passes the
## pitch limit while they are close, no pitch can show both. The camera blends
## (over STACK_BLEND_ANGLE) to a side-on view of their midpoint, pulled back
## until both fit inside STACK_FRAME_FILL of the screen height. Only up to
## STACK_MAX_HEIGHT apart; bigger gaps keep the widen-and-arrow framing.
const STACK_BLEND_ANGLE := deg_to_rad(20.0)
const STACK_MAX_HEIGHT := 12.0
const STACK_FADE_HEIGHT := 4.0
const STACK_FRAME_FILL := 0.7
## Screen shape the framing aims for.
const DEFAULT_VERTICAL_FOV := 75.0
const ASPECT := 16.0 / 9.0


## Camera pose while locked on. shoulder: -1 camera left of the player .. +1 right
## (blends smoothly); the opponent shows on the shoulder side of the screen.
## orbit: mouse offset in radians (x yaw, y pitch), clamped to the orbit limits.
## far_blend: 0 close .. 1 far; negative means "from the current distance".
## vertical_fov: degrees, used to put the player at PLAYER_SCREEN_OFFSET.
## hold_facing: the camera's current flat forward; used instead of the noisy
## fighter-to-fighter direction when they are almost on top of each other.
static func locked_pose(player: Vector3, target: Vector3, shoulder: float, orbit: Vector2,
		far_blend: float = -1.0, vertical_fov: float = DEFAULT_VERTICAL_FOV,
		hold_facing: Vector3 = Vector3.ZERO) -> Transform3D:
	if far_blend < 0.0:
		far_blend = BAND_BLEND[band_for(player.distance_to(target), Band.MID)]
	var stacked := stack_weight(player, target)
	var facing := stable_facing(player, target, hold_facing)
	# Stacked, the horizontal direction between them is meaningless: keep the held one.
	var hold := Vector3(hold_facing.x, 0.0, hold_facing.z)
	if stacked > 0.0 and hold.length() > 0.01:
		var blended := facing.lerp(hold.normalized(), stacked)
		facing = blended.normalized() if blended.length() > 0.01 else hold.normalized()
	var pose := _pose_with_side(player, target, shoulder, orbit, far_blend, vertical_fov, 0.0, facing)
	# Near band: swing further aside until the fighters' silhouettes are apart
	# (not when stacked: they are apart vertically).
	var near_weight := clampf(1.0 - far_blend * 2.0, 0.0, 1.0) * (1.0 - stacked)
	var wanted_gap := MIN_NEAR_SCREEN_GAP
	var extra := 0.0
	while near_weight > 0.0 and extra < MAX_EXTRA_SIDE_ANGLE 			and screen_gap(pose, vertical_fov, player, target) < wanted_gap:
		extra += SIDE_ANGLE_STEP
		pose = _pose_with_side(player, target, shoulder, orbit, far_blend, vertical_fov, extra, facing)
	if stacked > 0.0:
		var side_on := _stacked_pose(player, target, shoulder, facing, vertical_fov)
		pose = Transform3D(
			Basis(pose.basis.get_rotation_quaternion().slerp(side_on.basis.get_rotation_quaternion(), stacked)),
			pose.origin.lerp(side_on.origin, stacked))
	return pose


## True when point is in front of the camera and inside the frame.
static func is_in_view(camera: Transform3D, vertical_fov: float, point: Vector3) -> bool:
	var local := camera.affine_inverse() * point
	if local.z >= -0.01:
		return false
	var tan_half_v := tan(deg_to_rad(vertical_fov) / 2.0)
	return absf(local.x / -local.z) <= tan_half_v * ASPECT and absf(local.y / -local.z) <= tan_half_v


## 0-1: how much to widen and pull back for a view lagging its framing by
## angle (radians): none under 15°, full at 60°.
static func lag_widen(angle: float) -> float:
	return smoothstep(deg_to_rad(15.0), deg_to_rad(60.0), angle)


## 0-1: how much the stacked (side-on) framing takes over.
static func stack_weight(player: Vector3, target: Vector3) -> float:
	var gap := target - player
	var height := absf(gap.y)
	var flat := Vector2(gap.x, gap.z).length()
	var limit := MAX_VIEW_PITCH_UP if gap.y > 0.0 else MAX_VIEW_PITCH_DOWN
	var steep := clampf((atan2(height, maxf(flat, 0.01)) - limit) / STACK_BLEND_ANGLE, 0.0, 1.0)
	var close := clampf((STACK_MAX_HEIGHT - height) / STACK_FADE_HEIGHT, 0.0, 1.0)
	return smoothstep(0.0, 1.0, steep) * close


## Flat direction from player to target, or hold_facing (when given) if
## they are exactly on top of each other.
static func stable_facing(player: Vector3, target: Vector3, hold_facing: Vector3) -> Vector3:
	var flat := Vector3(target.x - player.x, 0.0, target.z - player.z)
	if flat.length() > 0.01:
		return flat.normalized()
	var hold := Vector3(hold_facing.x, 0.0, hold_facing.z)
	return hold.normalized() if hold.length() > 0.01 else Vector3.FORWARD


## Side-on view of a vertically stacked pair: from beside them (shoulder
## side, at the close side angle), level with their midpoint, far enough
## back that both fit.
static func _stacked_pose(player: Vector3, target: Vector3, shoulder: float, facing: Vector3,
		vertical_fov: float) -> Transform3D:
	var mid := player.lerp(target, 0.5)
	var half_extent := absf(target.y - player.y) * 0.5 + FIGHTER_HEIGHT * 0.5
	var tan_half_v := tan(deg_to_rad(vertical_fov) / 2.0) * STACK_FRAME_FILL
	var distance := maxf(half_extent / tan_half_v, CLOSE_BOOM_LENGTH + 1.5)
	var back := (-facing).rotated(Vector3.UP, CLOSE_SIDE_ANGLE * shoulder)
	var position := mid + back * distance + Vector3.UP * 0.5
	return _looking_at(position, mid)


## Horizontal gap between the two fighters' screen boxes as a fraction of the
## screen width; negative when they overlap, 1 when either is behind the camera.
static func screen_gap(camera: Transform3D, vertical_fov: float, a: Vector3, b: Vector3) -> float:
	var box_a := _screen_box_ndc(camera, vertical_fov, a)
	var box_b := _screen_box_ndc(camera, vertical_fov, b)
	if not box_a.has_area() or not box_b.has_area():
		return 1.0
	return maxf(box_b.position.x - box_a.end.x, box_a.position.x - box_b.end.x) / 2.0


## A standing fighter's box in normalised screen space (x and y in -1..1).
static func _screen_box_ndc(camera: Transform3D, vertical_fov: float, centre: Vector3) -> Rect2:
	var local := camera.affine_inverse() * centre
	if local.z >= -0.1:
		return Rect2()
	var tan_half_v := tan(deg_to_rad(vertical_fov) / 2.0)
	var depth := -local.z
	var at := Vector2(local.x / (depth * tan_half_v * ASPECT), local.y / (depth * tan_half_v))
	var half := Vector2(FIGHTER_RADIUS / (depth * tan_half_v * ASPECT), FIGHTER_HEIGHT * 0.5 / (depth * tan_half_v))
	return Rect2(at - half, half * 2.0)


static func _pose_with_side(player: Vector3, target: Vector3, shoulder: float, orbit: Vector2,
		far_blend: float, vertical_fov: float, extra_side: float, facing: Vector3) -> Transform3D:
	var to_target := target - player
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var clamped := clamp_orbit(orbit)

	var behind := -facing
	var side_angle := (lerpf(CLOSE_SIDE_ANGLE, 0.0, far_blend) + extra_side) * shoulder
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
	var near_weight := clampf(1.0 - far_blend * 2.0, 0.0, 1.0)
	var player_offset := lerpf(PLAYER_SCREEN_OFFSET, NEAR_PLAYER_SCREEN_OFFSET, near_weight)
	var aside := atan(player_offset * tan_half_h) * shoulder
	var to_player := player - position
	var heading := Vector3(to_player.x, 0.0, to_player.z).rotated(Vector3.UP, -aside)
	var midpoint_pitch := _clamp_pitch(player.lerp(target, 0.5) - position)
	var look := heading.normalized() * Vector2(midpoint_pitch.x, midpoint_pitch.z).length() + Vector3.UP * midpoint_pitch.y
	var pose := _looking_at(position, position + look)
	# Pitch skews where a yaw offset lands on screen; nudge the yaw until the
	# player is at the intended screen x.
	var wanted_x := -player_offset * shoulder * tan_half_h
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


## The band for a fighter distance, given the current band (hysteresis).
static func band_for(distance: float, current: Band) -> Band:
	var near_edge := NEAR_EXIT if current == Band.NEAR else NEAR_ENTER
	var far_edge := FAR_EXIT if current == Band.FAR else FAR_ENTER
	if distance < near_edge:
		return Band.NEAR
	if distance > far_edge:
		return Band.FAR
	return Band.MID


## Narrowest useful FOV (degrees) for an opponent this far from the camera:
## keeps them FAR_OPPONENT_PIXELS tall, between MIN_ZOOM_FOV and base_fov.
static func far_zoom_fov(base_fov: float, camera_to_opponent: float) -> float:
	var half_tan := FIGHTER_HEIGHT * 1080.0 / (2.0 * FAR_OPPONENT_PIXELS * maxf(camera_to_opponent, 0.01))
	return clampf(rad_to_deg(2.0 * atan(half_tan)), MIN_ZOOM_FOV, base_fov)


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



## Exchange cam (hybrid): side-on to the fighters' line, both bodies about
## EXCHANGE_HEIGHT of the screen, or the pair fitting EXCHANGE_FILL of the width
## (beam clashes), centred on their midpoint. axis is the horizontal side the
## camera sits on (kept by the caller so it never flips across the line).
const EXCHANGE_HEIGHT := 0.38
const EXCHANGE_FILL := 0.8
const EXCHANGE_LIFT := 0.7


static func exchange_pose(a: Vector3, b: Vector3, axis: Vector3, vertical_fov: float) -> Transform3D:
	var distance := exchange_distance(a, b, vertical_fov)
	return exchange_pose_at(a, b, axis, distance)


## Side-on pose at a given distance from the pair's midpoint.
static func exchange_pose_at(a: Vector3, b: Vector3, axis: Vector3, distance: float) -> Transform3D:
	var mid := a.lerp(b, 0.5)
	var position := mid + axis.normalized() * distance + Vector3.UP * EXCHANGE_LIFT
	return _looking_at(position, mid + Vector3.UP * 0.2)


## Distance from the midpoint that frames the pair side-on with vertical_fov.
static func exchange_distance(a: Vector3, b: Vector3, vertical_fov: float) -> float:
	var tan_v := tan(deg_to_rad(vertical_fov) / 2.0)
	var tan_h := tan_v * ASPECT
	var gap := Vector2(b.x - a.x, b.z - a.z).length()
	var for_height := (FIGHTER_HEIGHT + absf(b.y - a.y)) / (2.0 * EXCHANGE_HEIGHT * tan_v)
	var for_width := (gap + FIGHTER_RADIUS * 4.0) / (2.0 * tan_h * EXCHANGE_FILL)
	return maxf(for_height, for_width)


## The vertical FOV that frames the pair side-on from distance (inverse of
## exchange_distance), for when obstacles keep the camera closer.
static func exchange_fov_at(a: Vector3, b: Vector3, distance: float) -> float:
	var gap := Vector2(b.x - a.x, b.z - a.z).length()
	var tan_for_height := (FIGHTER_HEIGHT + absf(b.y - a.y)) / (2.0 * EXCHANGE_HEIGHT * distance)
	var tan_for_width := (gap + FIGHTER_RADIUS * 4.0) / (2.0 * ASPECT * EXCHANGE_FILL * distance)
	return rad_to_deg(2.0 * atan(maxf(tan_for_height, tan_for_width)))


## The side axis perpendicular to a->b that keeps a on the screen's left.
static func exchange_axis(a: Vector3, b: Vector3) -> Vector3:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if d.length() < 0.01:
		return Vector3.BACK
	return d.normalized().cross(Vector3.UP).normalized()
