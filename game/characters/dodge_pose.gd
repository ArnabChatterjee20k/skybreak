class_name DodgePose
extends RefCounted
## Procedural dodge motion for CharacterView (T-DEF2): a crisp lean, bank or twist of the
## model that snaps in on the dodge's first frames, holds through the i-frames and settles by
## its last frame. Read-only on the sim; the legend's MotionProfile sets the amounts.

## Share of the pose on a stale dodge (no i-frames): visibly half-hearted, so it reads.
const STALE_SHARE := 0.5
## Grounded dodges lean less, so the planted feet stay near the floor.
const GROUND_SHARE := 0.6


## 0..1 pose weight on (fractional) frame f of the dodge: in by the first i-frame, held to the
## last i-frame (or the end of travel), out by the last frame. Zero when not dodging.
static func weight(fighter: FighterState, sub_tick: float) -> float:
	if fighter.state != FighterState.State.DASHING or fighter.dash_kind != FighterState.DashKind.DODGE:
		return 0.0
	var dodge := fighter.dodge
	var frame := float(fighter.state_ticks) - 1.0 + clampf(sub_tick, 0.0, 1.0)
	var rise := float(maxi(dodge.invuln_first, 2))
	var hold := float(maxi(dodge.invuln_last, dodge.travel_ticks))
	var end := float(maxi(dodge.last_frame, 1))
	var w := 0.0
	if frame < rise:
		w = _ease_out(frame / rise)
	elif frame <= hold:
		w = 1.0
	else:
		w = 1.0 - _smooth((frame - hold) / maxf(end - hold, 1.0))
	if dodge.invuln_last < dodge.invuln_first:
		w *= STALE_SHARE
	return clampf(w, 0.0, 1.0)


## Model-space offset (apply on top of the model's rest transform). local_direction is the
## dodge direction in model space (facing -Z); grounded keeps the lean small.
static func offset(fighter: FighterState, sub_tick: float, profile: MotionProfile,
		local_direction: Vector3, grounded: bool) -> Transform3D:
	var w := weight(fighter, sub_tick)
	if w <= 0.0 or profile == null:
		return Transform3D.IDENTITY
	var share := GROUND_SHARE if grounded else 1.0
	var basis := Basis.IDENTITY
	var lift := Vector3.ZERO
	match fighter.dodge.kind:
		FighterDodge.Kind.DIRECTIONAL:
			var planar := Vector3(local_direction.x, 0.0, local_direction.z)
			if planar.length_squared() > 0.0001:
				# Lean the head into the travel: rotate about the axis across it.
				var axis := planar.normalized().cross(Vector3.DOWN).normalized()
				basis = Basis(axis, deg_to_rad(profile.dodge_lean_degrees) * w * share)
			lift = Vector3(0, local_direction.y, 0) * 0.1 * w
		FighterDodge.Kind.SIDESTEP:
			var side := float(fighter.dodge.side)
			basis = Basis(Vector3.FORWARD, deg_to_rad(profile.dodge_roll_degrees) * side * w * share) \
				* Basis(Vector3.UP, deg_to_rad(15.0) * -side * w)
		FighterDodge.Kind.SPOT:
			basis = Basis(Vector3.UP, deg_to_rad(profile.dodge_twist_degrees) * w) \
				* Basis(Vector3.RIGHT, deg_to_rad(8.0) * w * share)
	if not grounded:
		lift += Vector3.DOWN * profile.dodge_drop * w
	return Transform3D(basis, lift)


## Hips lowered (m) on a grounded dodge; CharacterView adds it to the layers' crouch so the feet stay planted.
static func crouch(fighter: FighterState, sub_tick: float, profile: MotionProfile) -> float:
	if profile == null:
		return 0.0
	return profile.dodge_drop * weight(fighter, sub_tick)


static func _ease_out(t: float) -> float:
	var left := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - left * left * left


static func _smooth(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
