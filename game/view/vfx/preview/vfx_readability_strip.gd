extends SceneTree
## Renders a heavy hit, a counter, a guard break and a K.O. through VfxOcclusionRig,
## prints the peak head/torso coverage per beat and writes one frame strip per beat.
## xvfb-run godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility \
##   --fixed-fps 60 -s res://game/view/vfx/preview/vfx_readability_strip.gd -- <out dir>

## Frames rendered per beat, and how many of them go on the strip.
const FRAMES := {&"light": 16, &"heavy": 24, &"counter": 24, &"guard_break": 30, &"ko": 150}
const STRIP_FRAMES := 8
const THUMB := Vector2i(320, 180)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else ""
	var rig := VfxOcclusionRig.new()
	root.add_child(rig)
	for i in 5:
		await process_frame
	for scenario: StringName in FRAMES:
		var count: int = FRAMES[scenario]
		var frames: Array[Image] = []
		var peak := [0.0, 0.0]
		var loser_seen := 0
		rig.play(scenario)
		for f in count:
			if f > 0:
				rig.advance_frame()
			await process_frame
			var images: Array[Image] = await rig.capture()
			var cover := VfxOcclusionRig.coverage(images)
			for i in 2:
				peak[i] = maxf(peak[i], cover[i].x)
			if cover[1].y > 0.0 and cover[1].x <= 0.3:
				loser_seen += 1
			frames.append(images[0])
			if OS.has_environment("VFX_STRIP_FRAMES") and out != "":
				images[0].save_png("%s/%s_%03d.png" % [out, scenario, f])
				print("  %s frame %d: attacker %.1f%% target %.1f%%" % [scenario, f, cover[0].x * 100.0, cover[1].x * 100.0])
		rig.finish()
		print("%-12s peak cover attacker %5.1f%%  target %5.1f%%  target visible %d/%d frames" % [
			scenario, peak[0] * 100.0, peak[1] * 100.0, loser_seen, count])
		if out != "":
			_strip(frames, "%s/%s.png" % [out, scenario])
		# Let every effect finish before the next beat.
		for i in 240:
			rig.advance_frame()
			await process_frame
	quit(0)


func _strip(frames: Array[Image], path: String) -> void:
	var picks := mini(STRIP_FRAMES, frames.size())
	var strip := Image.create(THUMB.x * picks, THUMB.y, false, Image.FORMAT_RGB8)
	for i in picks:
		var index := int(round(float(i) * (frames.size() - 1) / maxf(picks - 1, 1)))
		if frames.size() > 40:
			# Long beats: dense at the start, then spread out.
			index = [0, 1, 2, 3, 5, 10, 40, 100][i] if i < 8 else index
		var thumb := frames[index].duplicate() as Image
		thumb.convert(Image.FORMAT_RGB8)
		thumb.resize(THUMB.x, THUMB.y)
		strip.blit_rect(thumb, Rect2i(Vector2i.ZERO, THUMB), Vector2i(i * THUMB.x, 0))
	strip.save_png(path)
