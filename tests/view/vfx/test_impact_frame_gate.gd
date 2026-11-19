extends GutTest
## #77: screen-wide impact moments are earned and rationed.

const E := CombatSim.EventType


func _event(type: int, hitstop: int) -> Dictionary:
	return {"type": type, "attacker": 0, "target": 1, "position": Vector3.ZERO, "hitstop": hitstop}


func test_only_kos_and_guard_breaks_earn_one() -> void:
	assert_true(ImpactFrameGate.earns(_event(E.KO, 20)))
	assert_true(ImpactFrameGate.earns(_event(E.GUARD_BREAK, 14)))
	assert_false(ImpactFrameGate.earns(_event(E.COUNTER, 9)), "#77: a heavy counter")
	assert_false(ImpactFrameGate.earns(_event(E.COUNTER, 4)), "a light counter")
	assert_false(ImpactFrameGate.earns(_event(E.HIT, 9)), "a plain heavy")
	assert_false(ImpactFrameGate.earns(_event(E.HIT, 4), 8), "a light hit deep in a combo")
	assert_false(ImpactFrameGate.earns(_event(E.HIT, 9), 12), "#77: a long combo's heavy ender")
	for type in [E.BLOCK, E.PERFECT_BLOCK, E.ARMOR, E.GRAB, E.PUSH_BLOCK, E.PICKUP]:
		assert_false(ImpactFrameGate.earns(_event(type, 20)), E.find_key(type))


func test_at_most_one_moment_plays_per_three_seconds() -> void:
	var gate := ImpactFrameGate.new()
	var fired := 0
	var last := -10000
	# A KO-worthy event every 20 ticks for 30 s.
	for t in 30 * 60:
		gate.tick()
		if t % 20 == 0 and gate.try_fire(_event(E.GUARD_BREAK, 14)):
			assert_gte(t - last, ImpactFrameGate.COOLDOWN_TICKS, "spacing at tick %d" % t)
			last = t
			fired += 1
	assert_eq(ImpactFrameGate.COOLDOWN_TICKS, 180, "3 s at 60 ticks/s")
	assert_eq(fired, 10, "30 s of non-stop guard breaks earn 10 moments, not 90")


func test_unearned_events_do_not_start_the_cooldown() -> void:
	var gate := ImpactFrameGate.new()
	gate.tick()
	assert_false(gate.try_fire(_event(E.HIT, 9)))
	assert_eq(gate.cooldown_left(), 0)
	assert_true(gate.try_fire(_event(E.GUARD_BREAK, 14)))
	assert_eq(gate.cooldown_left(), ImpactFrameGate.COOLDOWN_TICKS)
	assert_false(gate.try_fire(_event(E.KO, 20)), "even a KO waits out the cooldown")


func test_match_vfx_rations_burst_lines_across_a_burst_of_guard_breaks() -> void:
	var sim := CombatSim.new(3)
	sim.add_fighter(Vector3(0, 1, 1))
	sim.add_fighter(Vector3(0, 1, -1))
	var vfx := MatchVfx.new()
	vfx.sim = sim
	add_child_autofree(vfx)
	var shown := 0
	for t in 600:
		var events: Array[Dictionary] = []
		if t % 30 == 0:
			events.append(_event(E.GUARD_BREAK, 14))
		vfx.react(events)
		if vfx.screen().is_active(VfxScreen.Mode.LINES):
			shown += 1
			vfx.screen().advance(1.0)  # let the lines finish
	assert_eq(shown, 4, "20 guard breaks in 10 s show 4 bursts (ticks 0, 180, 360, 540)")
