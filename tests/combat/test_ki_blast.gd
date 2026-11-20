extends GutTest
## T-UX2: Q fires ki blasts (GAME_DESIGN §4 frame data, §5.8): tap = rapid shot, hold = charged blast.

const Q := FighterInput.Action.KI_BLAST
const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK
const UNIT := FighterState.METER_UNIT
const E := CombatSim.EventType

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _events: Array[Dictionary] = []


func _start(target := Vector3(0, 0, -8)) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(target)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	_events = []


## Runs ticks with fighter 0 holding held and fighter 1 holding other_held; collects events.
func _drive(ticks: int, held := 0, other_held := 0, other_move := Vector2.ZERO) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]),
			FighterInput.from_held(other_held, _previous[1]),
		]
		inputs[1].move = other_move
		_sim.tick(inputs)
		_events.append_array(_sim.events)
		_previous = inputs


func _of(type: E) -> Array[Dictionary]:
	return _events.filter(func(e: Dictionary) -> bool: return e.type == type)


func test_a_tap_fires_one_blast_at_move_tick_8_for_4_ki() -> void:
	_start(Vector3(0, 0, -60))
	var ki := _sim.fighters[0].ki
	_drive(1, Q)
	assert_eq(_sim.fighters[0].move_id(), &"ki/blast")
	_drive(7)
	assert_eq(_sim.projectiles.size(), 0, "nothing before the startup ends")
	_drive(1)
	assert_eq(_sim.projectiles.size(), 1)
	var blast := _sim.projectiles[0]
	assert_true(KiBlasts.is_blast(blast))
	assert_eq(blast.level, KiBlasts.TAP)
	assert_eq(_of(E.KI_BLAST).size(), 1)
	assert_eq(_of(E.KI_BLAST)[0].level, KiBlasts.TAP)
	# Passive ki per second is also the stored gain per tick.
	assert_eq(_sim.fighters[0].ki, ki - KiBlasts.TAP_KI * UNIT + 9 * _sim.meter_tuning.ki_passive_per_second)


func test_the_blast_flies_at_the_locked_target() -> void:
	_start(Vector3(0, 0, -60))
	_drive(8, Q)
	_drive(1)
	var blast := _sim.projectiles[0]
	assert_lt(blast.velocity.z, -KiBlasts.TAP_SPEED * 0.9, "toward the target (-Z)")


func test_holding_q_turns_it_into_a_charged_blast_at_move_tick_22_for_20_ki() -> void:
	_start(Vector3(0, 0, -60))
	var ki := _sim.fighters[0].ki
	_drive(22, Q)
	assert_eq(_sim.fighters[0].move_id(), &"ki/charged_blast")
	assert_eq(_sim.projectiles.size(), 0)
	_drive(1, Q)
	assert_eq(_sim.projectiles.size(), 1)
	assert_eq(_sim.projectiles[0].level, KiBlasts.CHARGED)
	assert_eq(_sim.projectiles[0].radius, KiBlasts.CHARGED_RADIUS)
	assert_eq(_sim.fighters[0].ki, ki - KiBlasts.CHARGED_KI * UNIT + 23 * _sim.meter_tuning.ki_passive_per_second)


func test_releasing_during_the_hold_fires_the_tap_shot() -> void:
	_start(Vector3(0, 0, -60))
	_drive(12, Q)
	assert_eq(_sim.projectiles.size(), 0, "held past the tap's startup: still waiting")
	_drive(1)
	assert_eq(_sim.projectiles.size(), 1)
	assert_eq(_sim.projectiles[0].level, KiBlasts.TAP)


func test_without_ki_for_the_charged_blast_a_hold_fires_a_tap() -> void:
	_start(Vector3(0, 0, -60))
	_sim.fighters[0].ki = 10 * UNIT
	_drive(30, Q)
	assert_eq(_of(E.KI_BLAST).size(), 1)
	assert_eq(_of(E.KI_BLAST)[0].level, KiBlasts.TAP)


func test_without_4_ki_q_does_nothing() -> void:
	_start(Vector3(0, 0, -60))
	_sim.fighters[0].ki = 3 * UNIT
	_drive(1, Q)
	assert_eq(_sim.fighters[0].state, FighterState.State.IDLE)
	_drive(20)
	assert_eq(_sim.projectiles.size(), 0)


func test_a_tap_blast_hits_for_120_damage_and_a_charged_blast_for_700_at_the_ranged_starter_percent() -> void:
	_start()
	var health := _sim.fighters[1].health
	_drive(1, Q)
	_drive(30)
	assert_eq(_of(E.PROJECTILE_HIT).size(), 1)
	assert_eq(_of(E.HIT)[0].move_id, &"ki_blast/projectile")
	assert_eq(_sim.fighters[1].health, health - 120 * UNIT * Weapon.RANGED_COMBO_PERCENT / 100)
	_start()
	health = _sim.fighters[1].health
	_drive(23, Q)
	_drive(40)
	assert_eq(_of(E.HIT)[0].move_id, &"charged_blast/projectile")
	assert_eq(_sim.fighters[1].health, health - 700 * UNIT * Weapon.RANGED_COMBO_PERCENT / 100)


func test_a_dash_absorbs_tap_blasts_but_not_charged_ones() -> void:
	_start()
	_drive(8, Q)
	_drive(1, 0, DASH, Vector2(0, 1))
	_drive(20, 0, DASH, Vector2(0, 1))
	assert_eq(_of(E.BULLET_ABSORB).size(), 1, "tap absorbed")
	assert_eq(_of(E.HIT).size(), 0)
	_start(Vector3(0, 0, -14))
	_drive(22, Q)
	_drive(1, Q, DASH, Vector2(0, 1))
	_drive(20, 0, DASH, Vector2(0, 1))
	assert_eq(_of(E.BULLET_ABSORB).size(), 0)
	assert_eq(_of(E.HIT).size(), 1, "the charged blast hits through the dash")


func test_blocking_takes_the_blast_on_the_guard() -> void:
	_start()
	_drive(1, Q, BLOCK)
	_drive(30, 0, BLOCK)
	assert_eq(_of(E.BLOCK).size(), 1)
	assert_true(_of(E.PROJECTILE_HIT)[0].blocked)


func test_q_while_charging_ki_cancels_the_charge_into_a_blast() -> void:
	_start(Vector3(0, 0, -60))
	_drive(5, FighterInput.Action.CHARGE)
	assert_eq(_sim.fighters[0].state, FighterState.State.CHARGING)
	_drive(1, Q)
	assert_eq(_sim.fighters[0].move_id(), &"ki/blast")


func test_ki_blasts_replay_identically() -> void:
	var hashes: Array[int] = []
	for _run in 2:
		_start()
		for i in 240:
			_drive(1, Q if (i / 10) % 3 != 2 else 0, DASH if i % 50 < 6 else 0, Vector2(0, 1))
		hashes.append(_sim.state_hash())
	assert_eq(hashes[0], hashes[1])
