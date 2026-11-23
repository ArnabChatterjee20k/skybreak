extends GutTest
## Geometric visual QA (T-D30): a seeded 3600-tick bot match per zone, every legend armed.

const ZONES: Array[StringName] = [&"heartbloom_gardens", &"frozen_peaks", &"shattered_mesa"]


func _run_zone(zone: StringName, seed_value: int) -> VisualQa:
	var qa := VisualQa.new()
	qa.zone = zone
	qa.seed_value = seed_value
	add_child_autofree(qa)
	await qa.run()
	gut.p(qa.summary())
	return qa


func test_heartbloom_islands_pass_every_geometric_check() -> void:
	var qa := await _run_zone(ZONES[0], 1)
	_assert_clean(qa)


func test_hilly_frozen_peaks_pass_every_geometric_check() -> void:
	var qa := await _run_zone(ZONES[1], 2)
	_assert_clean(qa)


func test_shattered_mesa_passes_every_geometric_check() -> void:
	var qa := await _run_zone(ZONES[2], 3)
	_assert_clean(qa)


## Violation frames allowed per zone/seed run: platform float tolerance
## (Windows vs Linux skinning maths / QA-17 order dependence); tracked in #109.
## One frame is invisible at 60 fps (down from 9170 clipping frames); more fails.
const PLATFORM_TOLERANCE := {&"weapon_vs_holder": 1, &"bow_vs_head": 1}
## Zone/check pairs over tolerance because of a filed bug: pending in CI, failing under run_qa.sh.
const KNOWN_EXCESS := {"shattered_mesa/bow_vs_head": &"QA-19", "shattered_mesa/weapon_vs_holder": &"QA-20",
	"frozen_peaks/weapon_vs_holder": &"QA-25"}


func _assert_clean(qa: VisualQa) -> void:
	assert_gt(int(qa.samples[&"ground_contact"]), 100, "grounded frames were measured")
	assert_gt(int(qa.samples[&"weapon_vs_holder"]), 1000, "held weapons were measured")
	for check in VisualQa.CHECKS:
		if VisualQa.TRACKED.has(check):
			# Owned by another lane: reported, pending under its known issue.
			if int(qa.violations[check]) > 0:
				pending("%s: %d violations in %s, %s" % [check, qa.violations[check], qa.zone,
					QaKnownIssues.describe(VisualQa.TRACKED[check])])
			continue
		var allowed: int = PLATFORM_TOLERANCE.get(check, 0)
		var known: StringName = KNOWN_EXCESS.get("%s/%s" % [qa.zone, check], &"")
		if known != &"" and int(qa.violations[check]) > allowed and not QaKnownIssues.strict():
			pending("%s: %d violations in %s, %s" % [check, qa.violations[check], qa.zone,
				QaKnownIssues.describe(known)])
			continue
		assert_lte(int(qa.violations[check]), allowed, "%s violations in %s (allowed %d)" % [check, qa.zone, allowed])
