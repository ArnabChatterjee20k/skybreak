extends GutTest
## Voxel Kael scarf tail seen edge-on: neighbouring rows share enough depth that
## no notch opens at a fold or a chain joint, even at the scarf sim's hardest bend.

const SCENE_PATH := "res://game/characters/kael_voxel/kael_voxel.tscn"
const CHAIN: Array[StringName] = [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]
## Hardest joint bend ScarfLag reaches (scarf_scan.gd: 93 deg at Scarf1-Scarf2
## in the 3-hit combo, 35 deg or less below it), rounded up.
const MAX_BEND := deg_to_rad(100.0)

var _scene: Node
var _design: KaelVoxelDesign
var _grid: VoxelGrid


func before_all() -> void:
	_scene = (load(SCENE_PATH) as PackedScene).instantiate()
	var skeleton := _scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_design = KaelVoxelDesign.new(skeleton)
	_grid = _design.build_scarf_tail()


func after_all() -> void:
	_scene.free()


## Contiguous filled z runs [first, last] of one grid row and column.
func _runs(x: int, y: int) -> Array:
	var out := []
	var start := -1
	for z in _grid.size.z + 1:
		var on := z < _grid.size.z and _grid.mats[_grid.index(x, y, z)] != 0
		if on and start < 0:
			start = z
		elif not on and start >= 0:
			out.append(Vector2i(start, z - 1))
			start = -1
	return out


## Every place two rows meet in a column: [x, y of the upper row, first z, last z] of their shared depth.
func _junctions() -> Array:
	var out := []
	for x in _grid.size.x:
		for y in _grid.size.y - 1:
			for a: Vector2i in _runs(x, y + 1):
				for b: Vector2i in _runs(x, y):
					var z0 := maxi(a.x, b.x)
					var z1 := mini(a.y, b.y)
					if z1 >= z0:
						out.append([x, y + 1, z0, z1])
	return out


## Skin matrices with every chain joint below Scarf1 bent by angle about X (edge-on).
func _bent(angles: Array) -> Dictionary:
	var skeleton := _design.skeleton
	var mats := {}
	var acc := Transform3D()
	for i in CHAIN.size():
		var id := skeleton.find_bone(CHAIN[i])
		if i > 0:
			var joint := skeleton.get_bone_global_rest(id).origin
			var turn := Transform3D(Basis(Vector3.RIGHT, angles[i - 1]), Vector3.ZERO)
			acc = acc * Transform3D(Basis(), joint) * turn * Transform3D(Basis(), -joint)
		mats[id] = acc
	return mats


func _posed(p: Vector3, mats: Dictionary) -> Vector3:
	var packed: Array = _design.weights(KaelVoxelDesign.Tag.SCARF_TAIL, p)
	var ids: PackedInt32Array = packed[0]
	var ws: PackedFloat32Array = packed[1]
	var out := Vector3.ZERO
	for i in 4:
		if ws[i] > 0.0:
			out += (mats.get(ids[i], Transform3D()) as Transform3D) * p * ws[i]
	return out


func test_neighbouring_tail_rows_share_the_full_two_cell_thickness_at_rest() -> void:
	var junctions := _junctions()
	assert_gt(junctions.size(), 100, "the tail has rows to check")
	var thin := 0
	for j: Array in junctions:
		if _grid.center(0, j[1], 0).y > KaelVoxelDesign.SCARF_END + KaelVoxelDesign.FINE_CELL and j[3] - j[2] + 1 < 2:
			thin += 1
	assert_eq(thin, 0, "no row meets the next through a single cell, folds included")


func test_edge_on_joints_keep_at_least_a_cell_of_overlap_at_the_sims_hardest_bend() -> void:
	var cell := _grid.cell
	for case: Array in [[MAX_BEND, MAX_BEND, MAX_BEND, MAX_BEND], [-MAX_BEND, -MAX_BEND, -MAX_BEND, -MAX_BEND],
			[MAX_BEND, -MAX_BEND, MAX_BEND, -MAX_BEND], [MAX_BEND, 0.0, 0.0, 0.0], [-MAX_BEND, 0.0, 0.0, 0.0]]:
		var mats := _bent(case)
		var thinnest := INF
		var at := 0.0
		for j: Array in _junctions():
			var base := _grid.origin + Vector3((j[0] + 0.5) * cell, j[1] * cell, 0.0)
			var p0 := Vector3(base.x, base.y, _grid.origin.z + j[2] * cell)
			var p1 := Vector3(base.x, base.y, _grid.origin.z + (j[3] + 1) * cell)
			var overlap := _posed(p0, mats).distance_to(_posed(p1, mats)) / cell
			if overlap < thinnest:
				thinnest = overlap
				at = base.y
		assert_gte(thinnest, 1.0, "bends %s deg: thinnest joint overlap %.2f cells at y %.3f" % [str(case.map(func(a: float): return roundi(rad_to_deg(a)))), thinnest, at])

