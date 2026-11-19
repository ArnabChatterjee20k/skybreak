extends GutTest

const LIGHT := FighterInput.Action.LIGHT
const State := FighterState.State
const Event := CombatSim.EventType
const UNIT := FighterState.METER_UNIT

var _sim: CombatSim
var _light: MoveData
var _previous: Array[FighterInput] = []


## Fighter 0 at the origin, fighter 1 two metres ahead with blocking set; both locked on.
func _start(stats: FighterStats = null) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO, stats)
	_sim.add_fighter(Vector3(0, 0, -2))
	_sim.lock_everyone_onto_nearest()
	_sim.fighters[1].blocking = true
	_light = _sim.fighters[0].stats.move_set.light_string[0]
	_previous = [FighterInput.new(), FighterInput.new()]


func _tick(ticks := 1, held := 0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]), FighterInput.from_held(0, _previous[1]),
		]
		_sim.tick(inputs)
		_previous = inputs


## Presses light and ticks until the first event; returns the events.
func _attack(limit := 30) -> Array[Dictionary]:
	_tick(1, LIGHT)
	for _i in limit:
		_tick()
		if not _sim.events.is_empty():
			return _sim.events
	return []


func _blocker() -> FighterState:
	return _sim.fighters[1]


func test_a_blocking_fighter_blocks_a_hit_from_the_front() -> void:
	_start()
	var events := _attack()
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, Event.BLOCK)
	assert_eq(events[0].damage, 0)
	assert_eq(events[0].hitstop, _light.hitstop_ticks / 2, "half hitstop")
	assert_eq(_blocker().health, 10_000 * UNIT, "no damage")
	assert_eq(_blocker().guard, (100 - _light.guard_damage) * UNIT)
	assert_eq(_blocker().state, State.BLOCKSTUN)
	assert_eq(_blocker().combo_hits, 0, "a block is not a combo hit")
	assert_eq(_sim.fighters[0].hitstop_ticks, _light.hitstop_ticks / 2)


func test_a_hit_from_behind_goes_through_the_block() -> void:
	_start()
	# Unlocked and facing away (-Z), so the attacker at +Z is behind.
	_blocker().lock_on_target = -1
	_blocker().facing_yaw = 0.0
	var events := _attack()
	assert_eq(events[0].type, Event.HIT)
	assert_eq(_blocker().state, State.HITSTUN)
	assert_eq(_blocker().health, (10_000 - _light.damage) * UNIT)


func test_a_blocked_hit_gives_the_attacker_contact_and_blocked_hit_ki() -> void:
	_start()
	var ki_before := _sim.fighters[0].ki
	_attack()
	assert_true(_sim.fighters[0].contact_blocked)
	assert_false(_sim.fighters[0].contact_hit)
	var passive := 7 * _sim.meter_tuning.ki_passive_per_second
	assert_eq(_sim.fighters[0].ki - ki_before, _sim.meter_tuning.ki_per_blocked_hit * UNIT + passive)


func test_blockstun_lasts_exactly_the_move_blockstun_after_hitstop() -> void:
	_start()
	_attack()
	_tick(_light.hitstop_ticks / 2 + _light.blockstun_ticks)
	assert_eq(_blocker().state, State.BLOCKSTUN, "still in blockstun on its last tick")
	_tick()
	assert_eq(_blocker().state, State.IDLE)
	assert_true(_blocker().blocking, "blocking stays set for T-D05")


func test_blocks_wear_the_guard_down_until_it_breaks() -> void:
	_start()
	_blocker().guard = 5 * UNIT
	var events := _attack()
	assert_eq(events.map(func(e: Dictionary) -> int: return e.type), [Event.BLOCK, Event.GUARD_BREAK])
	assert_eq(events[1].hitstop, 14)
	assert_eq(_blocker().state, State.GUARD_BROKEN)
	assert_eq(_blocker().guard, 0)
	assert_false(_blocker().blocking)


func test_a_guard_crushing_move_breaks_a_guard_below_its_threshold_in_one_block() -> void:
	var crusher := MoveData.new()
	crusher.id = &"crusher"
	crusher.startup_ticks = 3
	crusher.active_ticks = 2
	crusher.recovery_ticks = 10
	crusher.hitbox_offsets = PackedVector3Array([Vector3(0, 0, -1.2)])
	crusher.hitbox_radii = PackedFloat32Array([0.6])
	crusher.guard_damage = 1
	crusher.guard_break_below = 40
	crusher.hitstop_ticks = 10
	var stats := FighterStats.new()
	stats.move_set = MoveSet.new()
	stats.move_set.light_string = [crusher]
	_start(stats)
	_blocker().guard = 39 * UNIT
	var events := _attack()
	assert_eq(events.back().type, Event.GUARD_BREAK)
	assert_eq(_blocker().state, State.GUARD_BROKEN)

	_start(stats)
	_blocker().guard = 40 * UNIT
	_attack()
	assert_eq(_blocker().state, State.BLOCKSTUN, "at the threshold it holds")
	assert_eq(_blocker().guard, 39 * UNIT)


func test_a_guard_broken_fighter_is_hit_even_with_blocking_set() -> void:
	_start()
	_blocker().enter_state(State.GUARD_BROKEN)
	var events := _attack()
	assert_eq(events[0].type, Event.HIT)
	assert_eq(_blocker().state, State.HITSTUN)
