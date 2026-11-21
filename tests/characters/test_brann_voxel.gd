extends GutTest
## Voxel Brann look-dev v2 (docs/lookdev/brann.md): planar boulders that clear
## the head, a braid that stays in front of the belly, old weapons hideable.

const SCENE := "res://game/characters/brann_voxel/brann_voxel.tscn"
const LIGHT_1 := "res://game/combat/moves/brann/light_1.tres"

var _view: BrannVoxelView
var _design: BrannVoxelDesign


func before_all() -> void:
	_view = (load(SCENE) as PackedScene).instantiate() as BrannVoxelView
	add_child(_view)
	_design = BrannVoxelDesign.new(_skeleton())


func after_all() -> void:
	_view.free()


func _skeleton() -> Skeleton3D:
	return _view.model.get_node("%GeneralSkeleton") as Skeleton3D


func test_old_weapons_are_not_stowed_by_default() -> void:
	# The scene's VoxelArmory stows the voxel pair instead.
	var stowed := _skeleton().find_children("Stowed*", "", false, false)
	assert_eq(stowed.size(), 2)
	for attachment in stowed:
		for model in attachment.get_children():
			assert_true(model.has_meta(&"voxel"), "%s is the voxel model" % attachment.name)


func test_old_weapons_can_still_be_stowed() -> void:
	var view := (load(SCENE) as PackedScene).instantiate() as BrannVoxelView
	view.stow_old_weapons = true
	add_child_autofree(view)
	assert_eq(view.stowed_weapons().size(), 2)


func test_boulder_facets_are_axis_aligned_or_45_degrees() -> void:
	var clean := [0.0, 1.0, sqrt(0.5), sqrt(1.0 / 3.0)]
	var planes: PackedFloat32Array = _design.get(&"_boulder")
	for i in range(0, planes.size(), 4):
		for k in 3:
			var c := absf(planes[i + k])
			assert_true(clean.any(func(v: float) -> bool: return absf(v - c) < 1e-4), "facet %d component %.3f" % [i / 4, c])


func test_boulders_leave_a_notch_for_the_head() -> void:
	var nearest := 1e9
	for side: float in [1.0, -1.0]:
		var c := BrannVoxelDesign.boulder_center(side)
		for x in 25:
			for y in 25:
				for z in 25:
					var p := c + Vector3(x - 12, y - 12, z - 12) * 0.02
					if _design.boulder_sdf(p, side) < 0.0:
						nearest = minf(nearest, _design.head_sdf(p))
	assert_gt(nearest, 0.06, "boulder rock to head surface")


func test_clearance_parts_cover_the_boulders_head_and_belly() -> void:
	var parts := _design.clearance_parts()
	for bone: StringName in [&"LeftShoulder", &"RightShoulder", &"Head", &"Spine"]:
		assert_true(parts.has(bone), String(bone))


func test_braid_stays_in_front_of_the_belly_through_a_jab() -> void:
	var fighter := FighterState.new()
	fighter.enter_state(FighterState.State.IDLE)
	var move := load(LIGHT_1) as MoveData
	fighter.begin_move(move)
	var skeleton := _skeleton()
	var braid := skeleton.find_bone(BrannFigure.BRAID_BONE)
	var spine := skeleton.find_bone(&"Spine")
	var shallowest := 1e9
	while fighter.move_tick < move.total_ticks():
		fighter.state_ticks += 1
		fighter.move_tick += 1
		_view.apply_state(fighter, 1.0 / 60.0)
		var skin := skeleton.get_bone_global_pose(braid) * skeleton.get_bone_global_rest(braid).affine_inverse()
		var to_spine := (skeleton.get_bone_global_pose(spine) * skeleton.get_bone_global_rest(spine).affine_inverse()).affine_inverse()
		for p in _design.braid_points():
			var q := to_spine * (skin * p)
			if q.y > BrannVoxelDesign.SKIRT_TOP and q.y < BrannVoxelDesign.SHOULDER_Y:
				shallowest = minf(shallowest, q.z - BrannVoxelDesign.FRONT_Z)
	assert_gt(shallowest, 0.05, "braid in front of the belly")
