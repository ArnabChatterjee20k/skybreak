extends SceneTree
## Prints the VoxelCameraFight frames where the camera comes too close to voxel
## geometry, with the mesh, its box and the ground under the lens.
##   godot --headless --path . -s res://game/debug/camera_clip_diag.gd -- <zone> [ticks] [seed]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := StringName(args[0]) if args.size() > 0 else &"verdant_falls"
	var ticks := int(args[1]) if args.size() > 1 else 1200
	var fight_seed := int(args[2]) if args.size() > 2 else 7
	var r := VoxelCameraFight.run(root, zone, fight_seed, ticks)
	var c := CameraClearance.sweep(r.zone_node, r.points)
	var zm: ZoneMatch = r.match
	var obstacles: CameraObstacles = zm.camera.obstacles
	for s: Dictionary in c.samples:
		var p: Vector3 = s.at
		var nodes: Array = (r.zone_node as Node).find_children(s.what.split(" ")[0], "", true, false)
		var desc := ""
		for n in nodes:
			if n is MeshInstance3D:
				desc += "%s parent %s box %s; " % [n.name, n.get_parent().name, (n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()]
		print("i%d at %s clear %.3f ground %.2f near %.2f inside %s | %s" % [s.index, p, s.clearance,
			obstacles.ground_at(p), obstacles.ground_near(p), obstacles.is_inside(p), desc])
	print("samples %d" % (c.samples as Array).size())
	quit()
