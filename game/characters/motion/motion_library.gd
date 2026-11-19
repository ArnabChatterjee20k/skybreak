class_name MotionLibrary
extends AnimationLibrary
## Mocap clips retargeted onto SkeletonProfileHumanoid (tracks on %GeneralSkeleton), in place.
## Travel lives in root_motion so the sim stays in charge of position (no root motion in clips).
## Built by tools/build_motion_library.gd from tools/build_motion.py; sources in LICENSES.md.

const FPS := 60.0

## Clip -> per-frame Vector3(x, z, yaw) travel the clip had before it was made in place.
@export var root_motion: Dictionary[StringName, PackedVector3Array] = {}
## Clip -> per-frame foot contacts: bit 0 left foot planted, bit 1 right foot.
@export var foot_contacts: Dictionary[StringName, PackedByteArray] = {}
## Attack clip -> the bone whose head is the striking point.
@export var strike_bones: Dictionary[StringName, StringName] = {}
## Clip -> "source file [start s, end s]" for LICENSES.md.
@export var clip_sources: Dictionary[StringName, String] = {}


## Root travel at a clip time, interpolated between frames.
func root_at(clip: StringName, time: float) -> Vector3:
	var curve: PackedVector3Array = root_motion.get(clip, PackedVector3Array())
	if curve.is_empty():
		return Vector3.ZERO
	var f := clampf(time * FPS, 0.0, curve.size() - 1.0)
	var i := floori(f)
	return curve[i].lerp(curve[mini(i + 1, curve.size() - 1)], f - i)


func is_planted(clip: StringName, time: float, left: bool) -> bool:
	var contacts: PackedByteArray = foot_contacts.get(clip, PackedByteArray())
	if contacts.is_empty():
		return false
	var i := clampi(roundi(time * FPS), 0, contacts.size() - 1)
	return (contacts[i] & (1 if left else 2)) != 0
