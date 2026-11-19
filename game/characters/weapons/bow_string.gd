class_name BowString
extends Node3D
## A bow's drawn string (T-D30): while drawn, the string runs from both limb tips to the
## string hand's palm, and the bow's one nocked arrow (T-D26's) lies on it through the grip.
## Updated after the skeleton's modifiers so it follows the final hand pose.

const ARROW_LEAD := 0.18
## Nocked arrow length from nock to tip, in its own space (PowerModels.nocked_arrow).
const ARROW_LENGTH := 0.92
const STRING_RADIUS := 0.012

## Whether the bow is being drawn (set by the weapon layer).
var drawn := false
## World points of the drawn string (top tip, nock, bottom tip) and the arrow tip, for QA.
var tip_top := Vector3.ZERO
var nock := Vector3.ZERO
var tip_bottom := Vector3.ZERO
var arrow_tip := Vector3.ZERO
## The bow's nocked arrow (a child of the bow; nock at its origin, tip along -Z), or null.
var arrow: Node3D

var _skeleton: Skeleton3D
var _layers: MotionLayers
var _hand := -1
var _socket := Transform3D.IDENTITY
var _rest_string: Node3D
var _upper: MeshInstance3D
var _lower: MeshInstance3D


## Hooks the bow model (which holds a "String" part) to the skeleton's string hand.
func setup(bow: Node3D, skeleton: Skeleton3D, string_hand: StringName, color: Color) -> void:
	name = "BowString"
	_skeleton = skeleton
	_layers = skeleton.get_node_or_null("MotionLayers") as MotionLayers
	_hand = skeleton.find_bone(string_hand)
	_socket = WeaponGrip.hand_socket(skeleton, string_hand)
	_rest_string = bow.get_node_or_null("String")
	_upper = _segment(color, STRING_RADIUS)
	_lower = _segment(color, STRING_RADIUS)
	bow.add_child(self)
	top_level = true
	skeleton.skeleton_updated.connect(_follow)


func _segment(color: Color, radius: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	part.mesh = mesh
	part.material_override = WeaponModels.material(color, true)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.visible = false
	add_child(part)
	return part


func _exit_tree() -> void:
	if _skeleton != null and _skeleton.skeleton_updated.is_connected(_follow):
		_skeleton.skeleton_updated.disconnect(_follow)


## Moves the string to the hand; hides it and shows the rest string when not drawn.
func _follow() -> void:
	var bow := get_parent() as Node3D
	if bow == null or not bow.is_inside_tree() or _hand < 0:
		return
	var at := bow.global_transform
	tip_top = at * WeaponGrip.BOW_TIP
	tip_bottom = at * Vector3(WeaponGrip.BOW_TIP.x, -WeaponGrip.BOW_TIP.y, WeaponGrip.BOW_TIP.z)
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand) * _socket
	var back := at.basis.z.normalized()
	var pulled := (hand.origin - at.origin).dot(back) > (at.basis * WeaponGrip.BOW_STRING_REST).length() + 0.05
	# The drawn string shows once the string hand has reached the anchor, not while it travels there.
	var arrived := _layers == null or _layers.bow_at_anchor()
	var show := drawn and pulled and arrived
	nock = hand.origin if show else at * WeaponGrip.BOW_STRING_REST
	var grip := at.origin
	var along := (grip - nock).normalized()
	arrow_tip = grip + along * ARROW_LEAD
	if _rest_string != null:
		_rest_string.visible = not show
	for part in [_upper, _lower]:
		(part as MeshInstance3D).visible = show
	if show:
		_place(_upper, tip_top, nock)
		_place(_lower, tip_bottom, nock)
	if arrow != null and is_instance_valid(arrow):
		if show:
			# Nock on the string at the palm, shaft through the grip.
			var scale := at.basis.get_scale()
			var z := -along
			var x := at.basis.y.normalized().cross(z).normalized()
			arrow.global_transform = Transform3D(Basis(x, z.cross(x), z).scaled_local(scale), nock)
			arrow_tip = arrow.global_transform * Vector3(0, 0, -ARROW_LENGTH)
		else:
			arrow.transform = Transform3D(Basis.IDENTITY, arrow.position)


static func _place(part: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var length := maxf(along.length(), 0.001)
	var y := along / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	part.global_transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
