extends GutTest
## Baked voxel characters: the committed bake must be current and equal a
## fresh build, VoxelBody must use it, and stale or foreign bakes are refused.

const SCENE := "res://game/characters/kael_voxel/kael_voxel.tscn"
const DESIGN := preload("res://game/characters/kael_voxel/kael_voxel_design.gd")
const BakeTool := preload("res://tools/voxel_bake.gd")
const REBAKE := "rebake with: godot --headless --path . -s res://tools/voxel_bake.gd"

var _root: Node


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()


## Kael's skeleton, from the scene with its VoxelBody left out.
func _skeleton() -> Skeleton3D:
	var opened: Array = BakeTool.open_scene(SCENE, get_tree())
	_root = opened[0]
	return opened[2]


func test_the_bake_tool_finds_the_kael_scene() -> void:
	assert_has(BakeTool.voxel_scenes("res://game/characters"), SCENE)


func test_kaels_bake_is_present_and_current() -> void:
	var why := []
	var bake := VoxelBake.load_for(DESIGN, _skeleton(), why)
	assert_not_null(bake, "%s; %s" % [why[0] if why else "", REBAKE])


func test_a_fresh_build_equals_the_baked_mesh() -> void:
	var skeleton := _skeleton()
	var bake := VoxelBake.load_for(DESIGN, skeleton)
	if bake == null:
		fail_test("no current bake; " + REBAKE)
		return
	var fresh := VoxelBody.build(DESIGN.new(skeleton) as VoxelDesign)
	var built := VoxelBake.checksum(fresh)
	var loaded := VoxelBake.checksum(bake.mesh)
	assert_eq(built[0], bake.vertex_count, "vertex count")
	assert_eq(built[1], bake.mesh_checksum, "fresh build vs the checksum stored at bake time")
	assert_eq(loaded, built, "baked mesh as loaded vs fresh build")
	assert_eq(bake.mesh.get_surface_count(), fresh.get_surface_count())


func test_voxel_body_puts_the_baked_mesh_and_skin_on_the_rig() -> void:
	var bake := VoxelBake.load_for(DESIGN, _skeleton())
	if bake == null:
		fail_test("no current bake; " + REBAKE)
		return
	var t0 := Time.get_ticks_usec()
	var view: Node = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(view)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	gut.p("kael_voxel.tscn instantiate + ready: %.1f ms" % ms)
	var body: VoxelBody = view.get_node("VoxelBody")
	var target := body.get_node(body.mesh_path) as MeshInstance3D
	assert_eq(target.mesh, bake.mesh)
	assert_eq(target.skin, bake.skin)
	assert_lt(ms, 5000.0, "loading a bake takes milliseconds, a live build 10+ s")


func test_skins_bind_every_bone_at_its_rest() -> void:
	var skeleton := _skeleton()
	var skin := VoxelBody.rest_skin(skeleton)
	assert_eq(skin.get_bind_count(), skeleton.get_bone_count())
	for i in skeleton.get_bone_count():
		assert_eq(skin.get_bind_pose(i), skeleton.get_bone_global_rest(i).affine_inverse())


func _fake_bake(skeleton: Skeleton3D, source_hash: String) -> String:
	var bake := VoxelBake.new()
	bake.source_hash = source_hash
	bake.mesh = ArrayMesh.new()
	bake.skin = VoxelBody.rest_skin(skeleton)
	for i in skeleton.get_bone_count():
		bake.bone_names.append(skeleton.get_bone_name(i))
		bake.bone_rests.append(skeleton.get_bone_global_rest(i).origin)
	var path := "user://test_voxel_bake_%d.res" % randi()
	assert_eq(bake.save_to(path), OK)
	return path


func test_a_bake_of_other_sources_is_refused() -> void:
	var skeleton := _skeleton()
	var path := _fake_bake(skeleton, "0".repeat(64))
	var why := []
	assert_null(VoxelBake.load_for(DESIGN, skeleton, why, path))
	assert_string_contains(why[0], "stale")
	DirAccess.remove_absolute(path)


func test_a_bake_with_matching_sources_and_rig_is_accepted() -> void:
	var skeleton := _skeleton()
	var path := _fake_bake(skeleton, VoxelBake.source_hash_for(DESIGN))
	assert_not_null(VoxelBake.load_for(DESIGN, skeleton, [], path))
	DirAccess.remove_absolute(path)


func test_a_bake_for_another_rest_pose_is_refused() -> void:
	var skeleton := _skeleton()
	var path := _fake_bake(skeleton, VoxelBake.source_hash_for(DESIGN))
	skeleton.set_bone_rest(1, skeleton.get_bone_rest(1).translated(Vector3(0.0, 0.01, 0.0)))
	var why := []
	assert_null(VoxelBake.load_for(DESIGN, skeleton, why, path))
	assert_string_contains(why[0], "rig")
	DirAccess.remove_absolute(path)


func test_the_source_hash_covers_the_design_and_the_kit() -> void:
	var h := VoxelBake.source_hash_for(DESIGN)
	assert_eq(h.length(), 64)
	assert_eq(h, VoxelBake.source_hash_for(DESIGN), "stable")
	assert_ne(h, VoxelBake.source_hash_for(VoxelDesign), "design-specific")
