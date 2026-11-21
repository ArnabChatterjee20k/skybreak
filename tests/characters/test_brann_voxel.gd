extends GutTest
## Voxel Brann look-dev v3 (docs/lookdev/brann.md): planar boulders that clear
## the head, a braid chain that hangs from the beard in front of the belly,
## wrists without gaps, calm big panels, old weapons hideable.

const SCENE := "res://game/characters/brann_voxel/brann_voxel.tscn"
const LIGHT_1 := "res://game/combat/moves/brann/light_1.tres"
const MOVES := "res://game/combat/moves/brann/"

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
	assert_eq(_view.stowed_weapons().size(), 0)
	assert_eq(_skeleton().find_children("Stowed*", "", false, false).size(), 0)


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


func test_braid_stays_out_of_the_chest_and_belly_through_a_jab() -> void:
	var fighter := FighterState.new()
	fighter.enter_state(FighterState.State.IDLE)
	var move := load(LIGHT_1) as MoveData
	fighter.begin_move(move)
	var skeleton := _skeleton()
	# Joints below the root (which sits in the beard), each in the torso bone it hangs over.
	var over := [&"Chest", &"Chest", &"Spine"]
	var shallowest := 1e9
	while fighter.move_tick < move.total_ticks():
		fighter.state_ticks += 1
		fighter.move_tick += 1
		_view.apply_state(fighter, 1.0 / 60.0)
		var joints := _view.braid_joints()
		for k in range(1, joints.size()):
			var bone := skeleton.find_bone(over[k - 1])
			var back := (skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()).affine_inverse()
			shallowest = minf(shallowest, _design.torso_sdf(back * joints[k]))
	assert_gt(shallowest, 0.05, "braid centre line outside the stone (bead radius plus the bib)")


func test_braid_chain_bones_rest_along_the_braid() -> void:
	var skeleton := _skeleton()
	var pts := BrannVoxelDesign.braid_points()
	for k in BrannVoxelDesign.BRAID_BONES.size():
		var bone := skeleton.find_bone(BrannVoxelDesign.BRAID_BONES[k])
		assert_gt(bone, -1, String(BrannVoxelDesign.BRAID_BONES[k]))
		assert_almost_eq(skeleton.get_bone_global_rest(bone).origin, pts[k], Vector3.ONE * 1e-4)
	assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(skeleton.find_bone(&"Braid1"))), "Head")


func test_braid_is_skinned_only_to_the_chain() -> void:
	var names := {}
	for x in range(-3, 4):
		for y in 40:
			var w: Array = _design.weights(BrannVoxelDesign.Tag.BRAID, Vector3(x * 0.01, 1.42 - y * 0.012, 0.39))
			for i in 4:
				if w[1][i] > 0.0:
					names[_skeleton().get_bone_name(w[0][i])] = true
	assert_eq(names.keys().size(), 3, str(names.keys()))
	for bone: String in names:
		assert_true(StringName(bone) in BrannVoxelDesign.BRAID_BONES, bone)


## Steps the view through a state with a velocity (model space +Z forward) and
## returns the widest angle of any braid segment off straight down (world) and
## off his chest's down axis, in degrees.
func _widest_braid_angles(state: FighterState.State, velocity: Vector3, ticks: int) -> Vector2:
	var fighter := FighterState.new()
	fighter.enter_state(state)
	fighter.velocity = Basis(Vector3.UP, fighter.facing_yaw) * Vector3(-velocity.x, velocity.y, -velocity.z)
	var skeleton := _skeleton()
	var chest := skeleton.find_bone(&"UpperChest")
	var widest := Vector2.ZERO
	for t in ticks:
		fighter.state_ticks += 1
		_view.apply_state(fighter, 1.0 / 60.0)
		var down := ((skeleton.get_bone_global_pose(chest) * skeleton.get_bone_global_rest(chest).affine_inverse()).basis
			* Vector3.DOWN).normalized()
		var j := _view.braid_joints()
		for i in j.size() - 1:
			var d := j[i + 1] - j[i]
			widest.x = maxf(widest.x, rad_to_deg(d.angle_to(Vector3.DOWN)))
			widest.y = maxf(widest.y, rad_to_deg(d.angle_to(down)))
	return widest


func test_braid_never_sticks_out_in_walk_run_dash_or_flight() -> void:
	var cases := {
		"walk": [FighterState.State.MOVING, Vector3(0, 0, 3.0)],
		"run back": [FighterState.State.MOVING, Vector3(0, 0, -7.0)],
		"strafe": [FighterState.State.MOVING, Vector3(7.0, 0, 0)],
		"dash": [FighterState.State.DASHING, Vector3(0, 0, 16.0)],
		"flight": [FighterState.State.FLYING, Vector3(0, 2.0, 12.0)],
		"dash back": [FighterState.State.DASHING, Vector3(0, 0, -16.0)],
	}
	for label: String in cases:
		var widest := _widest_braid_angles(cases[label][0], cases[label][1], 90)
		assert_lt(widest.y, 55.0, "%s: braid segment off his chest's down axis (deg)" % label)
		assert_lt(widest.x, 70.0, "%s: braid segment off vertical (deg), never near horizontal" % label)


func test_braid_root_stays_in_the_beard() -> void:
	_widest_braid_angles(FighterState.State.DASHING, Vector3(0, 0, 16.0), 30)
	var skeleton := _skeleton()
	var head := skeleton.find_bone(&"Head")
	var head_skin := skeleton.get_bone_global_pose(head) * skeleton.get_bone_global_rest(head).affine_inverse()
	var root := _view.braid_joints()[0]
	assert_lt(root.distance_to(head_skin * BrannVoxelDesign.braid_points()[0]), 0.06, "braid root to the beard's bottom")
	var bone := skeleton.find_bone(&"Braid1")
	assert_almost_eq(skeleton.get_bone_global_pose(bone).origin, root, Vector3.ONE * 1e-3)


func test_wrist_cuff_stays_filled_through_every_move() -> void:
	var checks := _design.gap_checks()
	var skeleton := _skeleton()
	var widest := 0.0
	var where := ""
	var files := Array(DirAccess.get_files_at(MOVES))
	files.sort()
	for file: String in files:
		var move := load(MOVES + file.trim_suffix(".remap")) as MoveData
		if move == null:
			continue
		var fighter := FighterState.new()
		fighter.enter_state(FighterState.State.IDLE)
		fighter.begin_move(move)
		while fighter.move_tick < move.total_ticks():
			fighter.state_ticks += 1
			fighter.move_tick += 1
			_view.apply_state(fighter, 1.0 / 60.0)
			if fighter.move_tick % 3 != 0:
				continue
			for name: String in checks:
				var seam: Array = checks[name]
				var a := skeleton.find_bone(seam[0])
				var b := skeleton.find_bone(seam[2])
				var skin_a := skeleton.get_bone_global_pose(a) * skeleton.get_bone_global_rest(a).affine_inverse()
				var back := (skeleton.get_bone_global_pose(b) * skeleton.get_bone_global_rest(b).affine_inverse()).affine_inverse()
				for p: Vector3 in seam[1]:
					var gap: float = (seam[3] as Callable).call(back * (skin_a * p))
					if gap > widest:
						widest = gap
						where = "%s in %s tick %d" % [name, move.id, fighter.move_tick]
	assert_lt(widest, BrannVoxelDesign.FINE_CELL, "widest wrist gap %.3f m (%s)" % [widest, where])


func test_wrist_plug_hides_inside_forearm_and_palm_at_rest() -> void:
	for side: float in [1.0, -1.0]:
		for p in BrannVoxelDesign.cuff_mouth_points(side):
			assert_lt(minf(BrannVoxelDesign.palm_sdf(p, side), BrannVoxelDesign.wrist_plug_sdf(p, side)), 0.0)


func test_big_panels_keep_value_noise_at_most_three_percent() -> void:
	for mat: int in [BrannVoxelDesign.Mat.STONE, BrannVoxelDesign.Mat.TROUSER, BrannVoxelDesign.Mat.LEATHER]:
		assert_lte(float(BrannVoxelDesign.NOISE[mat]), 0.03)


func test_torso_stone_has_no_light_chips() -> void:
	# Fully exposed flat stone, no occlusion: every voxel stays within the noise band.
	var base: Color = BrannVoxelDesign.COLORS[BrannVoxelDesign.Mat.STONE]
	var brightest := 0.0
	for i in 400:
		var c := Vector3i(i % 20, i / 20, 3)
		var col := _design.color(BrannVoxelDesign.Mat.STONE, Vector3(0, 1.2, 0.3), c, Vector3.BACK, 0.0, 1.0)
		brightest = maxf(brightest, col.v / base.v)
	assert_lt(brightest, 1.04)
