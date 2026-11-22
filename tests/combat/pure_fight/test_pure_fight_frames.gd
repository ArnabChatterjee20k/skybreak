extends GutTest
## Every move's frame data, measured in the sim, matches PureMoves (and so GAME_DESIGN §16.6),
## and the kit is fair: each legend has a reversal, an anti-air, a low, an overhead and a throw,
## and nothing is both safe on block and plus on hit beyond the lights.

const S := PureFighter.State


## [first contact tick after the press, defender free - attacker free] or [] when nothing hit.
func _measure(legend: StringName, id: StringName, block: bool) -> Array:
	var data := PureMoves.get_move(legend, id)
	var sim := PureFightDriver.fighting([legend, &"kael"] as Array[StringName], 600)
	var driver := PureFightDriver.new(sim)
	var guard_dir := 1 if data.guard == &"low" else 4
	var hold := [guard_dir if block else 5, ""]
	if data.guard in [&"overhead", &"high"] and block:
		hold = [4, ""]
	var start := sim.current_tick
	sim._start_move(0, id)
	sim.pf[1].guarding = block
	sim.pf[1].guard_since = -1000
	var contact := -1
	var attacker_free := -1
	var defender_free := -1
	for t in 200:
		driver.step([5, ""], hold)
		for e in sim.events:
			if contact < 0 and e.type in [PureFightSim.Ev.HIT, PureFightSim.Ev.BLOCK, PureFightSim.Ev.JUST_DEFEND,
					PureFightSim.Ev.COUNTER, PureFightSim.Ev.PUNISH]:
				contact = sim.current_tick - start
		if contact >= 0:
			if attacker_free < 0 and sim.pf[0].state in [S.IDLE, S.CROUCH, S.WALK]:
				attacker_free = sim.current_tick
			if defender_free < 0 and sim.pf[1].state in [S.IDLE, S.CROUCH, S.WALK]:
				defender_free = sim.current_tick
		if attacker_free >= 0 and defender_free >= 0:
			break
	if contact < 0:
		return []
	return [contact, defender_free - attacker_free]


func _measurable(data: Dictionary) -> bool:
	return data.kind != &"throw" and not data.grab and data.stance != &"air" \
		and not (data.box as Array).is_empty() and int(data.hits) == 1 and int(data.cinematic) == 0 \
		and data.chain_from == &""


func test_every_move_hits_on_its_listed_startup_frame() -> void:
	for legend in PureMoves.LEGENDS:
		for id in PureMoves.ids(legend):
			var data := PureMoves.get_move(legend, id)
			if not _measurable(data) and data.chain_from == &"":
				continue
			if data.chain_from != &"":
				continue
			var result := _measure(legend, id, false)
			assert_false(result.is_empty(), "%s %s connects at 600 mm" % [legend, id])
			if not result.is_empty():
				# Tick 0 is frame 1, so frame `startup` lands on tick startup - 1.
				assert_eq(result[0], int(data.startup) - 1, "%s %s startup" % [legend, id])


func test_on_block_and_on_hit_match_the_data() -> void:
	for legend in PureMoves.LEGENDS:
		for id in PureMoves.ids(legend):
			var data := PureMoves.get_move(legend, id)
			if not _measurable(data):
				continue
			var expected := PureMoves.advantage(data)
			var blocked := _measure(legend, id, true)
			if not blocked.is_empty():
				assert_eq(blocked[1], expected.x, "%s %s on block" % [legend, id])
			if expected.y != 999:
				var hit := _measure(legend, id, false)
				if not hit.is_empty():
					assert_eq(hit[1], expected.y, "%s %s on hit" % [legend, id])


func test_every_legend_has_a_reversal_anti_air_low_overhead_and_throw() -> void:
	for legend in PureMoves.LEGENDS:
		var reversal := false
		var anti_air := false
		var low := false
		var overhead := false
		var throw := false
		var techniques := 0
		var finisher := 0
		for id in PureMoves.ids(legend):
			var data := PureMoves.get_move(legend, id)
			var invuln: Array = data.invuln
			if data.kind == &"technique" and not invuln.is_empty() and int(invuln[0]) == 1 \
					and not (data.box as Array).is_empty():
				reversal = true
			if not (data.box as Array).is_empty() and int((data.box as Array)[3]) >= 1900 \
					and int(data.startup) <= 9:
				anti_air = true
			low = low or data.guard == &"low"
			overhead = overhead or data.guard == &"overhead"
			throw = throw or data.kind == &"throw"
			techniques += 1 if data.kind == &"technique" else 0
			finisher += 1 if data.kind == &"finisher" else 0
		assert_true(reversal, "%s reversal" % legend)
		assert_true(anti_air, "%s anti-air" % legend)
		assert_true(low, "%s low" % legend)
		assert_true(overhead, "%s overhead" % legend)
		assert_true(throw, "%s throw" % legend)
		assert_between(techniques, 3, 4, "%s techniques" % legend)
		assert_eq(finisher, 1, "%s finisher" % legend)
		assert_between(PureMoves.ids(legend).size(), 16, 22, "%s move count" % legend)


func test_nothing_is_safe_on_block_and_plus_heavy_at_once() -> void:
	for legend in PureMoves.LEGENDS:
		for id in PureMoves.ids(legend):
			var data := PureMoves.get_move(legend, id)
			if data.guard in [&"throw", &"none"] or data.stance == &"air":
				continue
			var adv := PureMoves.advantage(data)
			assert_lte(adv.x, 0, "%s %s is not plus on block" % [legend, id])
			if adv.x >= 0:
				assert_lte(int(data.damage), 40, "%s %s: only lights may be safe" % [legend, id])
			if data.kind == &"technique" and not (data.invuln as Array).is_empty():
				assert_lte(adv.x, -15, "%s %s: reversals are punishable" % [legend, id])


func test_the_design_doc_lists_every_move_with_its_frame_data() -> void:
	var doc := FileAccess.get_file_as_string("res://docs/GAME_DESIGN.md")
	for legend in PureMoves.LEGENDS:
		for row in PureFightFrameTable.rows(legend):
			assert_true(doc.contains(row), "GAME_DESIGN has: %s" % row)
