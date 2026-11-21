extends SceneTree
## Packs every zone's WEB-tier bake into <out>/zones/ for the web build
## (ZoneBakePacks): one .pck per zone plus manifest.json. The web export leaves
## all bakes out of index.pck; tools/web/build_web.sh runs this after it.
##   godot --headless --path . -s res://tools/web/pack_zone_bakes.gd -- <out dir>
## Exits 1 if a bake is missing or stale (rebake: tools/voxel_zone_bake.gd).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: pack_zone_bakes.gd -- <out dir>")
		quit(1)
		return
	var out := args[0]
	DirAccess.remove_absolute(out.path_join(ZoneBakePacks.DIR).path_join(ZoneBakePacks.MANIFEST))
	var entries: Array[Dictionary] = []
	var failed := false
	for id: StringName in VoxelZoneView.BUILDERS:
		var t0 := Time.get_ticks_msec()
		var e := ZoneBakePacks.pack_zone(out, id, ZoneBakePacks.TIER, VoxelZoneView.BUILDERS[id])
		if e.has("error"):
			printerr("pack_zone_bakes: ", e.error)
			failed = true
			continue
		entries.append(e)
		print("pack_zone_bakes: %s -> %s/%s: %.1f MB (%d ms)" % [id, ZoneBakePacks.DIR, e.file,
			e.size / 1048576.0, Time.get_ticks_msec() - t0])
	if failed:
		quit(1)
		return
	var err := ZoneBakePacks.write_manifest(out, entries)
	if err != OK:
		printerr("pack_zone_bakes: writing the manifest failed (%s)" % error_string(err))
	quit(0 if err == OK else 1)
