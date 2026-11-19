extends SceneTree
## Re-records the canonical golden replays into tests/qa/goldens/replays/.
## godot --headless --path . -s res://game/debug/qa/bless_goldens.gd -- --replays [--only <name>]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var only := ""
	if args.has("--only") and args.find("--only") + 1 < args.size():
		only = args[args.find("--only") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GoldenReplayCatalog.DIRECTORY))
	var failures := 0
	for spec in GoldenReplayCatalog.specs():
		if not only.is_empty() and spec.name != only:
			continue
		var started := Time.get_ticks_msec()
		var replay := GoldenReplay.record(spec)
		var gaps := GoldenReplayCatalog.missing(spec, replay)
		var check := GoldenReplay.from_json(replay.to_json()).play()
		if not check.ok:
			push_error("%s does not replay from its own JSON: %s" % [spec.name, check.message])
			failures += 1
			continue
		if not gaps.is_empty():
			push_error("%s no longer covers what it should: %s; change its spec" % [spec.name, ", ".join(gaps)])
			failures += 1
			continue
		var path := GoldenReplayCatalog.path_for(spec.name)
		replay.save(path)
		print("blessed %s: %d ticks, %d round starts, %d bytes, %d ms, events %s" % [spec.name, replay.ticks,
			replay.round_starts.size(), FileAccess.get_file_as_string(path).length(),
			Time.get_ticks_msec() - started, replay.coverage])
	quit(1 if failures > 0 else 0)
