extends SceneTree
## Fight camera on every voxel zone (T-135): both-on-screen at near/far range and
## the closest the camera came to solid voxel geometry (CameraClearance).
##   godot --headless --path . -s res://game/debug/voxel_camera_qa.gd -- [ticks] [seed]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ticks := int(args[0]) if args.size() > 0 else 1800
	var fight_seed := int(args[1]) if args.size() > 1 else 7
	for id: StringName in VoxelZoneView.BUILDERS:
		if OS.get_environment("VCQA_ONLY") != "" and OS.get_environment("VCQA_ONLY") != String(id):
			continue
		var t := Time.get_ticks_msec()
		var r := VoxelCameraFight.run(root, id, fight_seed, ticks)
		var fight_ms := Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		var c := CameraClearance.sweep(r.zone_node, r.points)
		var first: Dictionary = c.samples[0] if not (c.samples as Array).is_empty() else {}
		print("%-16s bake=%s locked %d both %.1f%% | near %d %.1f%% | far %d %.1f%% (worst gap %.0f m) | clip frames %d min %.2f m first %s | %d+%d ms" % [
			id, r.from_bake, r.locked, 100.0 * r.both_on / maxi(r.locked, 1), r.near, 100.0 * r.near_on / maxi(r.near, 1),
			r.far, 100.0 * r.far_on / maxi(r.far, 1), r.worst_gap, (c.samples as Array).size(), c.min,
			first, fight_ms, Time.get_ticks_msec() - t])
		(r.match as Node).free()
		for gap: float in [2.0, 14.0]:
			for side in 5:
				var w := VoxelCameraFight.backed_against(root, id, gap, 420, side)
				var wc := CameraClearance.sweep(w.zone_node, w.points)
				var wf: Dictionary = wc.samples[0] if not (wc.samples as Array).is_empty() else {}
				print("  wall %s me %s them %s gap %.0f side %d: frames %d both %.1f%% | clip frames %d min %.2f first %s" % [
					w.wall, w.get("me_at", Vector3.ZERO).snapped(Vector3.ONE * 0.1), w.get("them_at", Vector3.ZERO).snapped(Vector3.ONE * 0.1), gap, side, w.locked, 100.0 * w.both_on / maxi(w.locked, 1), (wc.samples as Array).size(), wc.min, wf])
				(w.match as Node).free()
	quit()
