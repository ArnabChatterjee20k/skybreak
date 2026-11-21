class_name BrannVoxelView
extends BrannView
## Voxel Brann's view: BrannView unchanged, except that its crack pulse
## (BrannView.ember_energy) drives the voxel body's GLOW surface instead of
## the old figure's ember material. Each view owns its copy of the material.

## Emission per unit of ember energy, clamped so bloom stays a thin line glow.
const EMBER_GAIN := 0.7
const EMBER_MIN := 1.0
const EMBER_MAX := 2.6

## Hang the old smooth weapon models on his back and hip. Off by default:
## they don't match the voxel style. A VoxelArmory in the scene stows the voxel ones.
@export var stow_old_weapons := false

## How far the braid's centre line stays in front of his chest and belly
## fronts: the bib and the braid's own radius plus a little air.
const BRAID_CLEARANCE := 0.07
## Air between a fist and a boulder.
const FIST_CLEARANCE := 0.01

var _glow: ShaderMaterial
var _design: BrannVoxelDesign
var _braid := -1
var _spine := -1


func apply_state(fighter: FighterState, delta: float) -> void:
	super.apply_state(fighter, delta)
	_keep_braid_clear()
	for side: float in [1.0, -1.0]:
		_keep_fist_clear(side)
	if _glow:
		_glow.set_shader_parameter(&"emission_value", glow_energy(fighter, _time))


## The GLOW surface's emission for a state at a time.
static func glow_energy(fighter: FighterState, time: float) -> float:
	return clampf(ember_energy(fighter, time) * EMBER_GAIN, EMBER_MIN, EMBER_MAX)


## The braid's spring follows the head, so a tucked chin or a swing carries
## it into the belly: turn it about its root, toward the front, until every
## point along it is in front of the bib.
func _keep_braid_clear() -> void:
	if _design == null:
		_design = BrannVoxelDesign.new(_skeleton)
		_braid = _skeleton.find_bone(BrannFigure.BRAID_BONE)
		_spine = _skeleton.find_bone(&"Spine")
	var points := _design.braid_points()
	points.append(points[-1] + Vector3(0, -0.08, 0))
	for attempt in 6:
		var braid_global := _skeleton.get_bone_global_pose(_braid)
		var skin := braid_global * _skeleton.get_bone_global_rest(_braid).affine_inverse()
		var spine_skin := _skeleton.get_bone_global_pose(_spine) * _skeleton.get_bone_global_rest(_spine).affine_inverse()
		var to_rest := spine_skin.affine_inverse()
		var worst := 0.0
		var at := Vector3.ZERO
		for rest_point in points:
			var posed := skin * rest_point
			var q := to_rest * posed
			if q.y < BrannVoxelDesign.SKIRT_TOP or q.y > BrannVoxelDesign.SHOULDER_Y or absf(q.x) > 0.42:
				continue
			var deficit := BrannVoxelDesign.FRONT_Z + BRAID_CLEARANCE - q.z
			if deficit > worst:
				worst = deficit
				at = posed
		if worst <= 0.002:
			return
		var push := (spine_skin.basis * Vector3.BACK).normalized() * worst * 1.5
		var root := braid_global.origin
		var turn := Quaternion((at - root).normalized(), (at + push - root).normalized())
		braid_global.basis = Basis(turn) * braid_global.basis
		_skeleton.set_bone_global_pose(_braid, braid_global)


## His clips cock the fists by the shoulders, where the boulders sit: swing
## the upper arm about its root until the fist and forearm clear the rock.
func _keep_fist_clear(side: float) -> void:
	var prefix := "Left" if side > 0 else "Right"
	var shoulder := _skeleton.find_bone(StringName(prefix + "Shoulder"))
	var upper := _skeleton.find_bone(StringName(prefix + "UpperArm"))
	var hand := _skeleton.find_bone(StringName(prefix + "Hand"))
	var lower := _skeleton.find_bone(StringName(prefix + "LowerArm"))
	var points := BrannVoxelDesign.fist_points(side)
	var fore := BrannVoxelDesign.forearm_points(side)
	for attempt in 6:
		var to_rock := (_skeleton.get_bone_global_pose(shoulder) * _skeleton.get_bone_global_rest(shoulder).affine_inverse()).affine_inverse()
		var shoulder_basis := _skeleton.get_bone_global_pose(shoulder).basis.orthonormalized() \
			* _skeleton.get_bone_global_rest(shoulder).basis.orthonormalized().inverse()
		var skin := _skeleton.get_bone_global_pose(hand) * _skeleton.get_bone_global_rest(hand).affine_inverse()
		var fore_skin := _skeleton.get_bone_global_pose(lower) * _skeleton.get_bone_global_rest(lower).affine_inverse()
		var worst := 0.0
		var at := Vector3.ZERO
		var push := Vector3.ZERO
		for k in points.size() + fore.size():
			var posed := skin * points[k] if k < points.size() else fore_skin * fore[k - points.size()]
			var q := to_rock * posed
			var deficit := FIST_CLEARANCE - _design.boulder_sdf(q, side)
			if deficit > worst:
				worst = deficit
				at = posed
				push = shoulder_basis * _design.boulder_normal(q, side) * deficit * 1.3
		if worst <= 0.002:
			return
		var arm := _skeleton.get_bone_global_pose(upper)
		var root := arm.origin
		var turn := Quaternion((at - root).normalized(), (at + push - root).normalized())
		arm.basis = Basis(turn) * arm.basis
		_skeleton.set_bone_global_pose(upper, arm)


func _stow_weapons() -> void:
	if stow_old_weapons or bool(_skeleton.get_meta(WeaponModels.VOXEL_META, false)):
		super._stow_weapons()


## The view's own copy of the ember GLOW material (null before _ready).
func glow_material() -> ShaderMaterial:
	return _glow


func _own_ember(_figure: BrannFigure) -> void:
	var meshes := _skeleton.find_children("*", "MeshInstance3D", false, false)
	if meshes.is_empty():
		return
	var instance := meshes[0] as MeshInstance3D
	for s in instance.mesh.get_surface_count():
		var material := instance.mesh.surface_get_material(s) as ShaderMaterial
		if material == null:
			continue
		var emission: Variant = material.get_shader_parameter(&"emission_value")
		if emission == null or not is_equal_approx(float(emission), BrannVoxelDesign.GLOW_EMISSION):
			continue
		if _glow == null:
			_glow = material.duplicate() as ShaderMaterial
		instance.set_surface_override_material(s, _glow)
