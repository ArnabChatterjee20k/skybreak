extends GutTest
## Issue #150: the defender can get out of, or round, an attacker's strings.

const A := FighterInput.Action
const S := FighterState.State
const E := CombatSim.EventType
const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]
const WATCH_TICKS := 120
## Out of a guarded string with a dodge or a vanish within this many ticks of the press.
const GUARD_ESCAPE_TICKS := 40

var _sim: CombatSim
var _previous: Array[FighterInput] = []


## The scenarios a defender must get out of: [option, guard held, timing].
static func required() -> Array:
	var cases := []
	for timing: String in EscapeRepro.TIMINGS:
		for guard in [false, true]:
			for option in ["back_dash", "sidestep", "vanish_side"]:
				cases.append([option, guard, timing])
			# Open, a press as a hit lands becomes the air tech, which follows the held direction (here: in).
			if guard or timing != "on_hit":
				cases.append(["vanish_behind", guard, timing])
		cases.append(["hold_back", false, timing])
		if timing != "on_hit":
			cases.append(["fly_up", false, timing])
	return cases


func test_every_legend_s_strings_can_be_escaped_by_dodge_vanish_walk_or_flight() -> void:
	for use_ai in [false, true]:
		for attacker in LEGENDS:
			for case: Array in required():
				var repro := EscapeRepro.new(attacker, case[0], case[1], case[2], use_ai)
				var result := repro.run(WATCH_TICKS)
				var label := "%s %s vs %s, guard %s, %s" % ["AI" if use_ai else "scripted", attacker, case[0],
					case[1], case[2]]
				assert_gte(result.escaped_at, 0, "%s: gets out within %d ticks" % [label, WATCH_TICKS])
				# The AI may read and punish an escape (PressureAI), so only the scripted attacker is timed.
				if case[1] and case[0] != "hold_back" and not use_ai:
					assert_lte(result.escaped_at, GUARD_ESCAPE_TICKS, "%s: out of the guard quickly" % label)


func test_a_dash_pressed_early_in_blockstun_still_comes_out_on_the_first_free_tick() -> void:
	_start(&"kael")
	var blocker := _sim.fighters[1]
	# Guard up long past its perfect-block window, then the attack.
	for _i in 30:
		_tick(0, A.BLOCK)
	_tick(A.LIGHT, A.BLOCK)
	for _i in 30:
		if blocker.state == S.BLOCKSTUN:
			break
		_tick(0, A.BLOCK)
	_tick(0, A.DASH, Vector2(0, -1))
	assert_eq(blocker.state, S.BLOCKSTUN)
	var stun_left := blocker.stun_ticks - blocker.state_ticks
	assert_gt(stun_left, CombatSim.INPUT_BUFFER_TICKS - 4, "pressed well before the stun ends")
	var waited := 0
	while blocker.state == S.BLOCKSTUN and waited < 60:
		_tick(0, 0, Vector2(0, -1))
		waited += 1
	assert_eq(blocker.state, S.DASHING, "the dodge comes out as the stun ends")
	assert_eq(blocker.dash_kind, FighterState.DashKind.DODGE)


func test_a_blocked_string_leaves_a_gap_before_each_next_light() -> void:
	for legend in LEGENDS:
		_start(legend)
		var lights := _sim.fighters[0].stats.move_set.light_string
		var blocker := _sim.fighters[1]
		for _i in 30:
			_tick(0, A.BLOCK)
		var attacker := _sim.fighters[0]
		_tick(A.LIGHT, A.BLOCK)
		var free_ticks := 0
		var gaps: Array[int] = []
		for _t in 150:
			var press := 0
			if attacker.state == S.ATTACKING and attacker.move != null and attacker.string_index > 0 \
					and attacker.move_tick == attacker.move.string_window_start_tick:
				press = A.LIGHT
			var events_before := blocker.state
			_tick(press, A.BLOCK)
			if blocker.state == S.BLOCKING and events_before != S.BLOCKSTUN or blocker.state == S.BLOCKING:
				free_ticks += 1
			for event: Dictionary in _sim.events:
				if event.type == E.BLOCK and event.target == 1:
					gaps.append(free_ticks)
					free_ticks = 0
			if attacker.state != S.ATTACKING and gaps.size() >= lights.size():
				break
		assert_eq(gaps.size(), lights.size(), "%s: every light blocked" % legend)
		for number in range(1, gaps.size()):
			assert_gte(gaps[number], _sim.hit_tuning.string_block_gap_ticks,
				"%s: free ticks before light %d" % [legend, number + 1])


func test_a_blocked_light_that_is_not_followed_keeps_its_blockstun() -> void:
	_start(&"kael")
	var blocker := _sim.fighters[1]
	for _i in 30:
		_tick(0, A.BLOCK)
	_tick(A.LIGHT, A.BLOCK)
	for _i in 30:
		if blocker.state == S.BLOCKSTUN:
			break
		_tick(0, A.BLOCK)
	var light: MoveData = _sim.fighters[0].stats.move_set.light_string[0]
	var longest := 0
	for _i in light.blockstun_ticks + light.hitstop_ticks + 5:
		if blocker.state == S.BLOCKSTUN:
			longest = maxi(longest, blocker.state_ticks)
		_tick(0, A.BLOCK)
	assert_eq(longest, light.blockstun_ticks, "no link: the move's blockstun stands")


func test_a_light_link_turns_only_part_way_toward_a_target_that_moved() -> void:
	_start(&"kael")
	var attacker := _sim.fighters[0]
	_tick(A.LIGHT)
	while attacker.move_tick < attacker.move.string_window_start_tick:
		_tick()
	# The defender teleports 90 degrees round; the next light starts from the old facing.
	var before := attacker.facing_yaw
	_sim.fighters[1].position = attacker.position + Vector3(1.8, 0, 0)
	_tick(A.LIGHT)
	while attacker.string_index < 2:
		_tick()
	var turned := absf(DetMath.angle_difference(before, attacker.facing_yaw))
	assert_almost_eq(turned, deg_to_rad(_sim.hit_tuning.follow_up_turn_degrees), 0.001)


func test_a_dodged_light_ends_the_string() -> void:
	_start(&"kael")
	var attacker := _sim.fighters[0]
	_tick(A.LIGHT, A.DASH)
	while attacker.move_tick < attacker.move.string_window_start_tick:
		_tick()
	_tick(A.LIGHT)
	var furthest := attacker.string_index
	for _i in 30:
		_tick()
		furthest = maxi(furthest, attacker.string_index)
	assert_eq(furthest, 1, "no second light after the first was dodged")


func test_a_sideways_vanish_goes_a_quarter_turn_round_a_close_target() -> void:
	_start(&"kael")
	var defender := _sim.fighters[1]
	defender.ki = 100 * FighterState.METER_UNIT
	var centre := _sim.fighters[0].position
	var from := defender.position - centre
	_tick(0, A.DASH | A.BLOCK, Vector2(1, 0))
	assert_eq(defender.state, S.VANISHING)
	var to := defender.position - centre
	var degrees := rad_to_deg(Vector2(from.x, from.z).angle_to(Vector2(to.x, to.z)))
	assert_almost_eq(absf(degrees), 90.0, 0.5, "a 6 m step at 1.8 m goes a quarter turn round, not 3 degrees")


func test_ascend_on_the_floor_jumps_out_of_the_guard_and_the_guard_climbs_in_the_air() -> void:
	_start(&"kael")
	var defender := _sim.fighters[1]
	_tick(0, A.BLOCK)
	assert_eq(defender.state, S.BLOCKING)
	_tick(0, A.BLOCK, Vector2.ZERO, 1)
	assert_eq(defender.state, S.FLYING, "jumped")
	var height := defender.position.y
	for _i in 30:
		_tick(0, A.BLOCK, Vector2.ZERO, 1)
	assert_eq(defender.state, S.BLOCKING, "guard back up in the air")
	assert_gt(defender.position.y, height + 1.0, "and still climbing")


func test_guard_drift_outpaces_every_legend_s_string_lunge() -> void:
	for legend in LEGENDS:
		var lights := Roster.character(legend).stats.move_set.light_string
		for number in range(1, lights.size()):
			var light: MoveData = lights[number - 1]
			var ticks: int = light.active_ticks + lights[number].startup_ticks
			var lunge: float = lights[number].step_distance / (ticks * CombatSim.TICK_SECONDS)
			assert_gt(_sim_tuning().guard_drift_speed, lunge, "%s light %d" % [legend, number + 1])


func test_the_ai_dodges_out_of_blockstun_and_punishes_dodges_in_seeded_bouts() -> void:
	var dodge_out := 0
	var punished := 0
	for pair: Array in [[&"kael", &"vexa"], [&"vexa", &"brann"]]:
		if dodge_out > 0 and punished > 0:
			break
		var bout := AIBout.new(3, [5, 4], false, pair)
		var last: Array[int] = [S.IDLE, S.IDLE]
		for _t in 3600:
			if bout.sim.round_over:
				bout.sim.start_round()
			bout.step()
			for event: Dictionary in bout.sim.events:
				if event.type == E.DODGE and last[event.fighter as int] == S.BLOCKSTUN:
					dodge_out += 1
				if event.type == E.GRAB and event.get("counter", false):
					punished += 1
			for i in 2:
				last[i] = bout.sim.fighters[i].state
	assert_gt(dodge_out, 0, "dodged out of a blockstring")
	assert_gt(punished, 0, "punished a dodge's recovery with a grab")


func test_pressure_ai_snapshot_restores_its_rolls() -> void:
	var first := PressureAI.new(5, 42)
	first.rng.randf()
	var saved := first.snapshot()
	var second := PressureAI.new(5, 1)
	second.restore(saved)
	assert_eq(second.rng.randf(), first.rng.randf())
	assert_eq(second.snapshot(), first.snapshot())


func _sim_tuning() -> MovementTuning:
	return CombatSim.DEFAULT_TUNING as MovementTuning


## Attacker (legend) at z = 1.8, Kael defending at the origin, both locked on, settled.
func _start(legend: StringName) -> void:
	_sim = CombatSim.new(7)
	_sim.add_fighter(Vector3(0, 0, 1.8), Roster.character(legend).stats)
	_sim.add_fighter(Vector3.ZERO, Roster.character(&"kael").stats)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	for _i in 20:
		_tick()


func _tick(attacker_held := 0, defender_held := 0, defender_move := Vector2.ZERO, defender_vertical := 0) -> void:
	var a := FighterInput.from_held(attacker_held, _previous[0])
	var d := FighterInput.from_held(defender_held, _previous[1])
	d.move = defender_move
	d.vertical = defender_vertical
	var inputs: Array[FighterInput] = [a, d]
	_sim.tick(inputs)
	_previous = inputs
