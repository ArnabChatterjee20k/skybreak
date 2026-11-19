class_name FigureSpring
extends RefCounted
## Spring lag for one secondary bone (hood point, cloth tail): its tip trails
## behind the animated parent and swings back. Stepped at a fixed rate, so the
## same sequence of poses always gives the same swing.

var bone: int
var parent: int
## Tip of the bone in its own rest space.
var tip: Vector3
var stiffness := 180.0
var damping := 14.0
var _position := Vector3.ZERO
var _velocity := Vector3.ZERO
var _started := false


func _init(skeleton: Skeleton3D, bone_name: StringName, tip_offset: Vector3,
		spring_stiffness := 180.0, spring_damping := 14.0) -> void:
	bone = skeleton.find_bone(bone_name)
	parent = skeleton.get_bone_parent(bone)
	tip = tip_offset
	stiffness = spring_stiffness
	damping = spring_damping


## Advances dt seconds. push is an extra acceleration in skeleton space
## (e.g. the wind of the fighter's own movement), then poses the bone.
func step(skeleton: Skeleton3D, dt: float, push := Vector3.ZERO) -> void:
	var anchor := _anchor(skeleton)
	var target := anchor * tip
	if not _started:
		_position = target
		_velocity = Vector3.ZERO
		_started = true
	var acceleration := (target - _position) * stiffness - _velocity * damping + push
	_velocity += acceleration * dt
	_position += _velocity * dt
	var length := tip.length() * anchor.basis.get_scale().y
	var direction := _position - anchor.origin
	if direction.length_squared() < 1e-10:
		direction = target - anchor.origin
	_position = anchor.origin + direction.normalized() * length
	pose(skeleton)


## Poses the bone toward the current simulated tip.
func pose(skeleton: Skeleton3D) -> void:
	if not _started:
		return
	var anchor := _anchor(skeleton)
	var rest_direction := (anchor.basis * tip).normalized()
	var direction := (_position - anchor.origin).normalized()
	var swing := Quaternion(rest_direction, direction) if rest_direction.dot(direction) > -0.999 \
		else Quaternion.IDENTITY
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var rest_basis := skeleton.get_bone_rest(bone).basis
	var local := parent_basis.inverse() * Basis(swing) * parent_basis * rest_basis
	skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())


func tip_position() -> Vector3:
	return _position


func _anchor(skeleton: Skeleton3D) -> Transform3D:
	return skeleton.get_bone_global_pose(parent) * skeleton.get_bone_rest(bone)
