extends SceneTree
## Issue sweep stills: an all-AI ZoneMatch stepped tick by tick, a PNG saved at each
## listed tick (camera on slot 0). Needs a renderer (xvfb-run).
##   godot --path . --resolution 1280x720 -s res://tools/diag/issue_stills.gd -- \
##       <out dir> <zone> <legend,legend[,..]> <level> <seed> <tick,tick,..> [voxel|classic]

const ZONE_MATCH := "res://game/levels/zone_match.tscn"


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var zone := StringName(args[1])
	var legends := args[2].split(",")
	var level := int(args[3])
	var seed_value := int(args[4])
	var ticks: Array[int] = []
	for t in args[5].split(","):
		ticks.append(int(t))
	var voxel := args.size() < 7 or args[6] != "classic"
	DirAccess.make_dir_recursive_absolute(out)
	var fighters := []
	for i in legends.size():
		fighters.append({"character": StringName(legends[i]), "team": i, "is_ai": true, "ai_level": level})
	var node: ZoneMatch = (load(ZONE_MATCH) as PackedScene).instantiate()
	node.sim.rng.seed = seed_value
	node.configure({"zone": zone, "fighters": fighters, "rounds": 3,
		"mode": &"ffa" if legends.size() > 2 else &"versus", "voxel_zone": voxel})
	root.add_child(node)
	node.set_process(false)
	node.set_physics_process(false)
	await process_frame
	var last: int = ticks.max()
	for t in range(1, last + 1):
		node.step_tick()
		node.present_frame(1.0, 1.0 / 60.0)
		# One drawn frame per tick, so VFX lifetimes run as in a match.
		await process_frame
		if ticks.has(t):
			await RenderingServer.frame_post_draw
			var path := "%s/%s_t%04d.png" % [out, zone, t]
			root.get_viewport().get_texture().get_image().save_png(path)
			var p := node.sim.fighters.map(func(f: FighterState) -> String:
				return "%s %s" % [FighterState.State.find_key(f.state), f.position])
			print("STILL %s %s" % [path, p])
	quit(0)
