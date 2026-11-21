extends GutTest
## Voxel Kael v3 look-dev rules: a folded, tapered, fringed scarf tail skinned
## on the scarf chain, toe caps off the shin, and plain finger plates.

const SCENE_PATH := "res://game/characters/kael_voxel/kael_voxel.tscn"
const SCARF_BONES: Array[StringName] = [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]

var _scene: Node
var _design: KaelVoxelDesign


func before_all() -> void:
	_scene = (load(SCENE_PATH) as PackedScene).instantiate()
	var skeleton := _scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_design = KaelVoxelDesign.new(skeleton)


func after_all() -> void:
	_scene.free()


func _bone_names(packed: Array) -> Array[StringName]:
	var names: Array[StringName] = []
	var ids: PackedInt32Array = packed[0]
	var ws: PackedFloat32Array = packed[1]
	for i in 4:
		if ws[i] > 0.0001:
			names.append(_design.skeleton.get_bone_name(ids[i]))
	return names


func test_the_scarf_tail_bends_back_and_forth_at_least_twice_along_its_length() -> void:
	var line := _design.scarf_tail_line()
	var turns := 0
	var last_sign := 0
	for i in range(1, line.size()):
		var dz := line[i].z - line[i - 1].z
		if absf(dz) < 0.0005:
			continue
		var s := 1 if dz > 0.0 else -1
		if last_sign != 0 and s != last_sign:
			turns += 1
		last_sign = s
	assert_gte(turns, 2, "the tail folds at least twice in depth")


func test_the_scarf_tail_tapers_and_ends_in_fringe() -> void:
	var g := _design.build_scarf_tail()
	var widths := {}
	for y in g.size.y:
		var lo := 1 << 30
		var hi := -1
		for z in g.size.z:
			for x in g.size.x:
				if g.mats[g.index(x, y, z)] != 0:
					lo = mini(lo, x)
					hi = maxi(hi, x)
		if hi >= 0:
			widths[y] = hi - lo + 1
	var rows: Array = widths.keys()
	rows.sort()
	# The lowest rows (fringe) hang as separate strands.
	var most_gaps := 0
	for k in 4:
		var filled := []
		for x in g.size.x:
			var any := false
			for z in g.size.z:
				if g.mats[g.index(x, rows[k], z)] != 0:
					any = true
			filled.append(any)
		var gaps := 0
		for x in range(1, filled.size() - 1):
			if not filled[x] and filled[x - 1] and filled[x + 1]:
				gaps += 1
		most_gaps = maxi(most_gaps, gaps)
	assert_gte(most_gaps, 2, "the end breaks into fringe strands")
	var upper_rows := rows.slice(rows.size() / 3, rows.size() * 2 / 3)
	var body := 0
	for r: int in upper_rows:
		body = maxi(body, widths[r])
	assert_lt(widths[rows[5]], body, "the tail narrows toward its end")


func test_the_scarf_tail_is_skinned_only_on_the_scarf_chain() -> void:
	for p: Vector3 in _design.scarf_tail_line():
		for bone in _bone_names(_design.weights(KaelVoxelDesign.Tag.SCARF_TAIL, p)):
			assert_has(SCARF_BONES, bone, "tail at %s weighted to %s" % [p, bone])


func test_the_toe_caps_do_not_follow_the_shin() -> void:
	for side: float in [1.0, -1.0]:
		var tag := KaelVoxelDesign.Tag.LEG_L if side > 0.0 else KaelVoxelDesign.Tag.LEG_R
		for p: Vector3 in [Vector3(0.137 * side, 0.12, 0.19), Vector3(0.137 * side, 0.16, 0.12)]:
			var names := _bone_names(_design.weights(tag, p))
			for bone in names:
				assert_false(String(bone).ends_with("LowerLeg"), "toe cap at %s weighted to %s" % [p, bone])


func test_the_finger_plates_carry_no_rivets_or_engraved_seams() -> void:
	var g := _design.build_gauntlet(1.0)
	var plates := 0
	for i in g.mats.size():
		if g.tags[i] < KaelVoxelDesign.FINGER_BASE:
			continue
		assert_false(g.mats[i] in [KaelVoxelDesign.Mat.RIVET, KaelVoxelDesign.Mat.ENGRAVE], "busy detail on a finger")
		if g.mats[i] == KaelVoxelDesign.Mat.BRASS:
			plates += 1
	assert_gt(plates, 0, "each finger still has its brass plate")
