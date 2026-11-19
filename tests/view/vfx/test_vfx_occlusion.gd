extends GutTest
## #76 / #77: rendered readability. Each beat plays through the real CombatFeedback in
## VfxOcclusionRig and is measured per frame against an ID mask of both fighters.
## Needs a renderer: run under xvfb with --rendering-method gl_compatibility --fixed-fps 60.
## Headless (dummy renderer) runs mark these pending.

## Peak share of either fighter's head/torso an ordinary beat may wash out.
const NORMAL_MAX := 0.15
## Peak share at the K.O.
const KO_MAX := 0.30
## Share of K.O. frames the loser must stay visible in (on screen, at most KO_MAX covered).
const KO_VISIBLE := 0.85
const FRAMES := {&"light": 16, &"heavy": 24, &"counter": 24, &"guard_break": 30, &"ko": 150}

var _rig: VfxOcclusionRig


func before_each() -> void:
	_rig = VfxOcclusionRig.new()
	add_child_autofree(_rig)


func after_each() -> void:
	Engine.time_scale = 1.0


func _can_render() -> bool:
	return DisplayServer.get_name() != "headless"


## Per frame [attacker cover, target cover, target pixels].
func _measure(scenario: StringName) -> Array[Vector3]:
	for i in 3:
		await get_tree().process_frame
	var samples: Array[Vector3] = []
	_rig.play(scenario)
	for f in FRAMES[scenario]:
		if f > 0:
			_rig.advance_frame()
		await get_tree().process_frame
		var cover := VfxOcclusionRig.coverage(await _rig.capture())
		samples.append(Vector3(cover[0].x, cover[1].x, cover[1].y))
	_rig.finish()
	return samples


func _peak(samples: Array[Vector3]) -> float:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, maxf(s.x, s.y))
	return peak


func test_ordinary_beats_never_wash_out_more_than_15_percent_of_a_head_or_torso() -> void:
	if not _can_render():
		pending("needs a renderer (xvfb + gl_compatibility)")
		return
	for scenario: StringName in [&"light", &"heavy", &"counter", &"guard_break"]:
		var samples := await _measure(scenario)
		assert_eq(samples.size(), FRAMES[scenario])
		assert_gt(samples[0].z, 100.0, "%s: the target is on screen" % scenario)
		assert_lte(_peak(samples), NORMAL_MAX, "%s peak head/torso coverage" % scenario)
		for i in 240:
			_rig.advance_frame()
			await get_tree().process_frame


func test_the_ko_covers_at_most_30_percent_and_keeps_the_falling_loser_visible() -> void:
	if not _can_render():
		pending("needs a renderer (xvfb + gl_compatibility)")
		return
	var samples := await _measure(&"ko")
	assert_lte(_peak(samples), KO_MAX, "KO peak head/torso coverage")
	var seen := 0
	for s in samples:
		if s.z > 0.0 and s.y <= KO_MAX:
			seen += 1
	assert_gte(float(seen) / samples.size(), KO_VISIBLE, "loser visible in %d/%d KO frames" % [seen, samples.size()])
	var start: Vector3 = Vector3(0.0, 1.0, -0.8)
	assert_gt(_rig.sim.fighters[1].position.distance_to(start), 2.0, "the loser actually fell away during the beat")


func test_coverage_counts_only_pixels_an_effect_really_shifts() -> void:
	var ids := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	var shown := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	var body: Color = VfxOcclusionRig.IDS[1]
	for x in 4:
		ids.set_pixel(x, 0, body)
		shown.set_pixel(x, 0, body)
	shown.set_pixel(0, 0, Color.WHITE)
	shown.set_pixel(1, 0, body + Color(0.1, 0.1, 0.1, 0.0))
	var cover := VfxOcclusionRig.coverage([shown, ids] as Array[Image])
	assert_almost_eq(cover[1].x, 0.25, 0.001, "one of four pixels washed out; a faint glow does not count")
	assert_eq(cover[1].y, 4.0)
	assert_eq(cover[0].y, 0.0, "no attacker pixels")
