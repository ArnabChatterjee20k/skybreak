extends SceneTree
## Renders every FlightScenarios route for review by eye (the playtester agent
## or a human): per scenario a contact sheet of every 15th frame, a full-size
## frame every 60 ticks, and a telemetry line per sampled frame.
##
## godot --path . --fullscreen --resolution 1920x1080 --disable-vsync -s res://game/debug/playtest_capture.gd -- <output dir>
##
## The output dir defaults to user://playtest; keep it outside the repo.

const SHEET_EVERY := 15
const FULL_FRAME_EVERY := 60
const THUMB := Vector2i(480, 270)
const SHEET_COLUMNS := 5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://playtest")
	out_dir = out_dir.trim_suffix("/").trim_suffix("\\") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for scenario_name in FlightScenarios.all():
		await _capture(scenario_name, FlightScenarios.all()[scenario_name], out_dir)
	print("Playtest frames written to ", out_dir)
	quit()


func _capture(scenario_name: String, scenario: Dictionary, out_dir: String) -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var settings := GraphicsSettings.new()
	settings.vsync_enabled = false
	settings.apply_to(root)
	var playtest := FlightPlaytest.new(arena, scenario)
	var thumbs: Array[Image] = []
	var telemetry := PackedStringArray()
	while not playtest.is_finished():
		var frame := playtest.advance()
		if frame.tick % SHEET_EVERY != 0:
			continue
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if frame.tick % FULL_FRAME_EVERY == 0:
			image.save_png(out_dir + "%s_f%03d.png" % [scenario_name, frame.tick])
		var thumb := image.duplicate()
		thumb.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		thumbs.append(thumb)
		telemetry.append(_describe(arena, frame))
	_save_sheet(out_dir + scenario_name + "_sheet.png", thumbs)
	FileAccess.open(out_dir + scenario_name + ".txt", FileAccess.WRITE).store_string("\n".join(telemetry) + "\n")
	arena.queue_free()
	await process_frame


func _describe(arena: Node, frame: Dictionary) -> String:
	var player: FighterState = arena.sim.fighters[0]
	return "f%03d player %s %s pos=%s speed=%.1f | opponent pos=%s | gap=%.1fm | locked=%s opponent_on_screen=%s" % [
		frame.tick, FighterState.State.keys()[player.state], FighterState.DashKind.keys()[player.dash_kind],
		player.position.snapped(Vector3.ONE * 0.1), player.velocity.length(),
		arena.sim.fighters[1].position.snapped(Vector3.ONE * 0.1),
		frame.player.distance_to(frame.opponent), frame.locked, frame.opponent_on_screen]


func _save_sheet(path: String, thumbs: Array[Image]) -> void:
	var rows := ceili(thumbs.size() / float(SHEET_COLUMNS))
	var sheet := Image.create(THUMB.x * SHEET_COLUMNS, THUMB.y * rows, false, thumbs[0].get_format())
	for i in thumbs.size():
		sheet.blit_rect(thumbs[i], Rect2i(Vector2i.ZERO, THUMB),
			Vector2i(i % SHEET_COLUMNS, i / SHEET_COLUMNS) * THUMB)
	sheet.save_png(path)
