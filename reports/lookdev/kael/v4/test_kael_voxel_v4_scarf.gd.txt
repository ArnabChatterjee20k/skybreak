extends GutTest
## Voxel Kael v4 scarf tail: a clean ribbon (straight edges, constant width,
## fringe only at the tip) whose rows move as one piece.

const SCENE_PATH := "res://game/characters/kael_voxel/kael_voxel.tscn"

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


## Per grid row: [first filled column, last filled column, filled column count].
func _row_spans() -> Dictionary:
	var spans := {}
	for y in _grid.size.y:
		var lo := 1 << 30
		var hi := -1
		var cols := 0
		for x in _grid.size.x:
			var any := false
			for z in _grid.size.z:
				if _grid.mats[_grid.index(x, y, z)] != 0:
					any = true
					break
			if any:
				lo = mini(lo, x)
				hi = maxi(hi, x)
				cols += 1
		if hi >= 0:
			spans[y] = [lo, hi, cols]
	return spans


func test_the_tail_edges_run_straight_down_the_columns_at_a_constant_width() -> void:
	var spans := _row_spans()
	var body_edges := {}
	for y: int in spans:
		var centre_y := _grid.center(0, y, 0).y
		if centre_y > KaelVoxelDesign.SCARF_END + 0.12:
			body_edges["%d-%d" % [spans[y][0], spans[y][1]]] = true
			assert_eq(spans[y][2], 9, "row at %.3f is 9 cells wide with no gaps" % centre_y)
	assert_eq(body_edges.size(), 1, "every body row has the same two edge columns")


func test_the_fringe_hangs_only_below_the_end() -> void:
	var spans := _row_spans()
	for y: int in spans:
		var span: Array = spans[y]
		if span[2] < span[1] - span[0] + 1:
			assert_lt(_grid.center(0, y, 0).y, KaelVoxelDesign.SCARF_END, "gapped rows only below the end")


func test_a_tail_row_is_weighted_the_same_across_its_width_and_depth() -> void:
	for y: float in [1.2, 1.0, 0.85, 0.7, 0.55]:
		var z := KaelVoxelDesign.scarf_depth(y)
		var ref: Array = _design.weights(KaelVoxelDesign.Tag.SCARF_TAIL, Vector3(KaelVoxelDesign.SCARF_X, y, z))
		for off: Vector3 in [Vector3(0.05, 0, 0), Vector3(-0.05, 0, 0), Vector3(0, 0, 0.011), Vector3(0.04, 0, -0.011)]:
			var w: Array = _design.weights(KaelVoxelDesign.Tag.SCARF_TAIL, Vector3(KaelVoxelDesign.SCARF_X, y, z) + off)
			assert_eq(w[0], ref[0], "same bones across the row at %.2f" % y)
			assert_eq(w[1], ref[1], "same weights across the row at %.2f" % y)
