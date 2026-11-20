extends SceneTree
## Bakes every voxel character (a scene with a VoxelBody) to
## game/characters/voxel_kit/baked/<design>.res, so it loads in milliseconds.
##   godot --headless --path . -s res://tools/voxel_bake.gd [-- options]
## Options:
##   --scene=<res://...tscn>  only this scene (repeatable); default: every
##                            scene under res://game/characters with a VoxelBody
##   --check                  write nothing; exit 1 if a bake is missing or stale
##   --time                   write nothing; build live and print phase timings
## Exits 1 on any error.

const SEARCH_ROOT := "res://game/characters"


func _initialize() -> void:
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
	if scenes.is_empty():
		scenes = voxel_scenes(SEARCH_ROOT)
	var failed := false
	for path in scenes:
		var ok := _run(path, check, time)
		failed = failed or not ok
	quit(1 if failed else 0)


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


## The design script and skeleton of a voxel scene (the scene stays out of the tree).
static func open_scene(path: String) -> Array:
	var root: Node = (load(path) as PackedScene).instantiate()
	var body := root.find_child("VoxelBody", true, false) as VoxelBody
	if body == null:
		for n in root.find_children("*", "Node", true, false):
			if n is VoxelBody:
				body = n
				break
	if body == null:
		root.free()
		return []
	var skeleton := (body.get_node(body.mesh_path) as MeshInstance3D).get_parent() as Skeleton3D
	return [root, body.design, skeleton]


func _run(path: String, check: bool, time: bool) -> bool:
	var opened := open_scene(path)
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
