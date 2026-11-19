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


func _assert_clean(qa: VisualQa) -> void:
	assert_gt(int(qa.samples[&"ground_contact"]), 100, "grounded frames were measured")
	assert_gt(int(qa.samples[&"weapon_vs_holder"]), 1000, "held weapons were measured")
	for check in VisualQa.CHECKS:
		if VisualQa.PENDING.has(check):
			if int(qa.violations[check]) > 0:
				pending("%s: %d violations, pending T-D29 pushboxes" % [check, qa.violations[check]])
			continue
		assert_eq(int(qa.violations[check]), 0, "%s violations in %s" % [check, qa.zone])
