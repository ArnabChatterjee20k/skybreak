extends SceneTree
## Bakes every voxel character (a scene with a VoxelBody) to
## game/characters/voxel_kit/baked/<design>.res, so it loads in milliseconds,
## plus the rigid parts (every VoxelWeapons design, Lyra's astrolabe rings)
## to baked/rigid/.
##   godot --headless --path . -s res://tools/voxel_bake.gd [-- options]
## Options:
##   --scene=<res://...tscn>  only this scene (repeatable); default: every
##                            scene under res://game/characters with a VoxelBody
##   --check                  write nothing; exit 1 if a bake is missing or stale
##   --time                   write nothing; build live and print phase timings
## Exits 1 on any error.

const SEARCH_ROOT := "res://game/characters"


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var scenes: Array[String] = []
	var check := false
	var time := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scenes.append(a.trim_prefix("--scene="))
		elif a == "--check":
			check = true
		elif a == "--time":
			time = true
		else:
			printerr("voxel_bake: unknown option ", a)
			quit(1)
			return
	var only_scenes := not scenes.is_empty()
	if scenes.is_empty():
		scenes = voxel_scenes(SEARCH_ROOT)
	var failed := false
	for path in scenes:
		var ok := _run(path, check, time)
		failed = failed or not ok
	if not time and not only_scenes:
		for kind: Weapon.Kind in VoxelWeapons.DESIGNS:
			var ok := _run_weapon(kind, check)
			failed = failed or not ok
	quit(1 if failed else 0)


func _run_weapon(kind: Weapon.Kind, check: bool) -> bool:
	var script := load(VoxelWeapons.DESIGNS[kind]) as Script
	if check:
		return _check_rigid(script, VoxelWeapons.BAKE_SOURCES, "")
	var t0 := Time.get_ticks_msec()
	var built: Array[ArrayMesh] = [VoxelWeapons.build_mesh(script.new() as VoxelWeaponDesign)]
	return _save_rigid(script, built, VoxelWeapons.BAKE_SOURCES, "", Time.get_ticks_msec() - t0)


static func _check_rigid(script: Script, sources: Array[String], key: String) -> bool:
	var why := []
	if VoxelBake.load_rigid(script, sources, key, why).is_empty():
		printerr("voxel_bake: %s: %s" % [VoxelBake.rigid_path_for(script, key), why[0]])
		return false
	print("voxel_bake: %s: current" % VoxelBake.rigid_path_for(script, key))
	return true


static func _save_rigid(script: Script, built: Array[ArrayMesh], sources: Array[String], key: String, built_ms: int) -> bool:
	var bake := VoxelBake.make_rigid(script, built, sources)
	var out := VoxelBake.rigid_path_for(script, key)
	var err := bake.save_rigid_to(out)
	if err != OK:
		printerr("voxel_bake: saving %s failed (%s)" % [out, error_string(err)])
		return false
	var t0 := Time.get_ticks_usec()
	var loaded := ResourceLoader.load(out, "", ResourceLoader.CACHE_MODE_IGNORE) as VoxelBake
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var reloaded := VoxelBake.make_rigid(script, loaded.parts, sources)
	var ok := reloaded.vertex_count == bake.vertex_count and reloaded.mesh_checksum == bake.mesh_checksum
	print("voxel_bake: %s -> %s: built %d ms, loads %.1f ms, %d verts, %s, %d KiB%s" % [
		script.resource_path.get_file(), out, built_ms, load_ms, bake.vertex_count, bake.mesh_checksum.left(16),
		FileAccess.get_file_as_bytes(out).size() / 1024, "" if ok else " RELOAD MISMATCH"])
	return ok


## Every .tscn under dir whose text uses voxel_body.gd, sorted.
static func voxel_scenes(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		var path := dir.path_join(f)
		if f.ends_with(".tscn") and FileAccess.get_file_as_string(path).contains("voxel_kit/voxel_body.gd"):
			out.append(path)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(voxel_scenes(dir.path_join(d)))
	out.sort()
	return out


## [scene root, design script, skeleton] of a voxel scene, or [] without a
## VoxelBody. The scene enters the tree (some figures build their skeleton in
## _ready) with its VoxelBody swapped for a plain node, so nothing builds.
static func open_scene(path: String, tree: SceneTree) -> Array:
	var root: Node = (load(path) as PackedScene).instantiate()
	var body: VoxelBody = null
	for n in root.find_children("*", "Node", true, false):
		if n is VoxelBody:
			body = n
			break
	if body == null:
		root.free()
		return []
	var stand_in := Node.new()
	var parent := body.get_parent()
	parent.add_child(stand_in)
	parent.move_child(stand_in, body.get_index())
	stand_in.name = body.name
	parent.remove_child(body)
	tree.root.add_child(root)
	var target := stand_in.get_node_or_null(body.mesh_path) as MeshInstance3D
	var design := body.design
	body.free()
	if target == null or not (target.get_parent() is Skeleton3D):
		printerr("voxel_bake: %s: mesh_path doesn't lead to a MeshInstance3D under a Skeleton3D" % path)
		root.free()
		return []
	return [root, design, target.get_parent()]


func _run(path: String, check: bool, time: bool) -> bool:
	var opened := open_scene(path, self)
	if opened.is_empty():
		printerr("voxel_bake: no VoxelBody in ", path)
		return false
	var root: Node = opened[0]
	var design: Script = opened[1]
	var skeleton: Skeleton3D = opened[2]
	var ok := true
	if time:
		_time(design, skeleton)
	elif check:
		var why := []
		if VoxelBake.load_for(design, skeleton, why) == null:
			printerr("voxel_bake: %s: %s" % [path, why[0]])
			ok = false
		else:
			print("voxel_bake: %s: current" % path)
	else:
		var t0 := Time.get_ticks_msec()
		var bake := VoxelBake.make(design, skeleton)
		var built_ms := Time.get_ticks_msec() - t0
		var out := VoxelBake.path_for(design)
		var err := bake.save_to(out)
		if err != OK:
			printerr("voxel_bake: saving %s failed (%s)" % [out, error_string(err)])
			ok = false
		else:
			t0 = Time.get_ticks_usec()
			var loaded := ResourceLoader.load(out, "", ResourceLoader.CACHE_MODE_IGNORE) as VoxelBake
			var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
			var sum := VoxelBake.checksum(loaded.mesh)
			ok = sum[0] == bake.vertex_count and sum[1] == bake.mesh_checksum
			print("voxel_bake: %s -> %s: built %d ms, loads %.1f ms, %d verts, %s, %d KiB%s" % [
				path, out, built_ms, load_ms, bake.vertex_count, bake.mesh_checksum.left(16),
				FileAccess.get_file_as_bytes(out).size() / 1024, "" if ok else " RELOAD MISMATCH"])
	if not time:
		for n in root.find_children("*", "Node3D", true, false):
			if n is LyraAstrolabe:
				var ring_design: Script = n.design
				if check:
					ok = _check_rigid(ring_design, LyraAstrolabe.BAKE_SOURCES, LyraAstrolabe.BAKE_KEY) and ok
				else:
					# Built fresh here (never from an old bake), so the bake matches the sources.
					var t0 := Time.get_ticks_msec()
					var built: Array[ArrayMesh] = []
					built.assign(LyraAstrolabe.build(ring_design.new(skeleton) as LyraVoxelDesign))
					ok = _save_rigid(ring_design, built, LyraAstrolabe.BAKE_SOURCES, LyraAstrolabe.BAKE_KEY,
						Time.get_ticks_msec() - t0) and ok
	root.free()
	return ok


static func _time(design: Script, skeleton: Skeleton3D) -> void:
	var d := design.new(skeleton) as VoxelDesign
	var t0 := Time.get_ticks_usec()
	var grids := d.build_grids()
	var t1 := Time.get_ticks_usec()
	var soft := d.soft_materials()
	for g in grids:
		if not soft.is_empty():
			g.smooth(soft)
	var t2 := Time.get_ticks_usec()
	var materials := VoxelBody.materials_for(d)
	var mesh := ArrayMesh.new()
	for g in grids:
		VoxelBody.append_part(mesh, VoxelMesher.build(g, d.color, d.surface_of, d.weights, materials, d.blur_cells(g)))
	var t3 := Time.get_ticks_usec()
	var sum := VoxelBake.checksum(mesh)
	print("voxel_bake: %s: paint %d ms, smooth %d ms, mesh %d ms, total %d ms; %d verts, %s" % [
		design.resource_path.get_file(), (t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000,
		(t3 - t0) / 1000, sum[0], sum[1]])
