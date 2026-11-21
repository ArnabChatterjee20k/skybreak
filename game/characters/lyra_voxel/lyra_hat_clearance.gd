class_name LyraHatClearance
extends SkeletonModifier3D
## Keeps Lyra's hat off the floor (view-only): adds a Hat bone under Head that
## the hat is skinned to, and when the hat's lowest point would go below the
## floor (knockdown, lying down) rocks the hat on the top edge of her skull by
## the smallest tilt that clears it, lifting the low side of the brim. Runs
## last. Pure function of the pose, so the same clip frame gives the same hat.

## The floor in skeleton space (her soles when standing).
@export var floor_y := 0.0
## Gap kept between the hat's lowest point and the floor.
@export var clearance := 0.02
## How far from the crown's axis the hat rocks: on the skull's top edge, just
## in front of the face, so a brim tipped over her face stays off it.
@export var pivot_radius := 0.12
## Most the hat may tip off her head, in radians.
@export var max_tilt := deg_to_rad(80.0)

var _hat := -1
var _head := -1
var _samples := PackedVector4Array()
var _crown_base := Vector3.ZERO


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton != null:
		ensure_hat_bone(skeleton)


## Adds the Hat bone (a child of Head at Head's rest) if the rig lacks it.
static func ensure_hat_bone(skeleton: Skeleton3D) -> int:
	var id := skeleton.find_bone(LyraVoxelDesign.HAT_BONE)
	if id >= 0:
		return id
	var head := skeleton.find_bone(&"Head")
	if head < 0:
		return -1
	skeleton.add_bone(LyraVoxelDesign.HAT_BONE)
	id = skeleton.find_bone(LyraVoxelDesign.HAT_BONE)
	skeleton.set_bone_parent(id, head)
	skeleton.set_bone_rest(id, Transform3D.IDENTITY)
	skeleton.reset_bone_pose(id)
	return id


func _setup(skeleton: Skeleton3D) -> bool:
	if _hat >= 0:
		return true
	_hat = ensure_hat_bone(skeleton)
	_head = skeleton.find_bone(&"Head")
	if _hat < 0:
		return false
	_samples = LyraVoxelDesign.hat_extremes()
	_crown_base = Vector3(0.0, LyraVoxelDesign.HAT_Y, 0.0)
	return true


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not _setup(skeleton):
		return
	var pose := skeleton.get_bone_global_pose(_hat)
	# Rest skeleton space -> current skeleton space for anything on the hat.
	var m := pose * skeleton.get_bone_global_rest(_hat).affine_inverse()
	var target := floor_y + clearance
	if lowest(m) >= target:
		return
	var up := (m.basis * Vector3.UP).normalized()
	# The brim's low side: straight down, flattened onto the brim's plane.
	var low := Vector3.DOWN - up * Vector3.DOWN.dot(up)
	if low.length() < 1e-3:
		low = m.basis * Vector3.BACK
		low -= up * low.dot(up)
	low = low.normalized()
	var axis := low.cross(up).normalized()
	var pivot := m * _crown_base - low * pivot_radius
	var lo := 0.0
	var hi := max_tilt
	if lowest(_tilted(m, pivot, axis, hi)) >= target:
		for _i in 12:
			var mid := (lo + hi) * 0.5
			if lowest(_tilted(m, pivot, axis, mid)) >= target:
				hi = mid
			else:
				lo = mid
	var global := _tilted(pose, pivot, axis, hi)
	var parent := skeleton.get_bone_global_pose(_head)
	var local := parent.affine_inverse() * global
	skeleton.set_bone_pose_position(_hat, local.origin)
	skeleton.set_bone_pose_rotation(_hat, local.basis.get_rotation_quaternion())


## The lowest point of the hat under the rest-to-now transform m.
func lowest(m: Transform3D) -> float:
	var best := INF
	for s in _samples:
		best = minf(best, (m * Vector3(s.x, s.y, s.z)).y - s.w)
	return best


static func _tilted(t: Transform3D, pivot: Vector3, axis: Vector3, angle: float) -> Transform3D:
	var turn := Basis(axis, angle)
	return Transform3D(turn * t.basis, pivot + turn * (t.origin - pivot))
