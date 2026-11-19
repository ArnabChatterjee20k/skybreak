extends GutTest
## T-D14's open weapon points, filled by T-D26: bow draw and pin, Heartstring
## Tether, chakram disc, repeater heat, swap-cancel, quick-swap, ranged combo
## scaling, counter-hit drops, HUD ammo.

const A := FighterInput.Action
const E := CombatSim.EventType
const K := Weapon.Kind
const S := FighterState.State

var _sim: CombatSim
var _previous: Array[FighterInput] = []


func _start(target := Vector3(0, 0, -6), me := Vector3.ZERO) -> void:
	_sim = CombatSim.new(9)
	_sim.add_fighter(me)
	_sim.add_fighter(target)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]


func _drive(ticks: int, held := 0, other_held := 0, move := Vector2.ZERO, other_move := Vector2.ZERO) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]),
			FighterInput.from_held(other_held, _previous[1]),
		]
		inputs[0].move = move
		inputs[1].move = other_move
		_sim.tick(inputs)
		_previous = inputs
		seen.append_array(_sim.events)
	return seen


func _join(first: Array, second: Array) -> Array:
	var joined := first.duplicate()
	joined.append_array(second)
	return joined


func _of(events: Array, type: E) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event.type == type)


## Gives fighter index the weapon kind in hand (picked up where it stands).
func _arm(kind: K, index := 0) -> void:
	var pickup := WeaponPickup.new()
	pickup.id = _sim._new_entity_id()
	pickup.kind = kind
	pickup.ammo = Weapon.full_ammo(kind)
	pickup.position = _sim.fighters[index].position + Vector3(0, -0.4, 0)
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	_sim.pickups.append(pickup)
	if index == 0:
		_drive(1, A.PICKUP)
	else:
		_drive(1, 0, A.PICKUP)
	_drive(10)


# Ki Bow.

func test_a_tapped_bow_shot_is_a_level_one_arrow() -> void:
	_start(Vector3(0, 0, -200))
	_arm(K.KI_BOW)
	var fired := _of(_join(_drive(1, A.LIGHT), _drive(20)), E.FIRE)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0].level, 1)
	assert_almost_eq(_sim.projectiles[0].velocity.length(), 70.0, 2.0)
	assert_eq(_sim.projectiles[0].effect, Weapon.Effect.NONE)


func test_holding_the_bow_draws_through_three_levels_with_events() -> void:
	_start(Vector3(0, 0, -200))
	_arm(K.KI_BOW)
	var seen := _drive(14 + Weapon.DRAW_LEVEL_TICKS[1] + 10, A.LIGHT)
	var draws := _of(seen, E.BOW_DRAW)
	assert_eq(draws.map(func(d: Dictionary) -> int: return d.level), [2, 3])
	assert_eq(_of(seen, E.FIRE).size(), 0, "nothing fires while drawing")
	assert_eq(_sim.fighters[0].draw_level(), 3)
	var fired := _of(_drive(3), E.FIRE)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0].level, 3)
	var arrow := _sim.projectiles[0]
	assert_almost_eq(arrow.velocity.length(), 70.0 * 1.6, 3.0)
	assert_eq(arrow.effect, Weapon.Effect.PIN)
	assert_eq(arrow.move.id, &"bow/projectile_3")


func test_a_full_draw_fires_by_itself_at_the_cap() -> void:
	_start(Vector3(0, 0, -200))
	_arm(K.KI_BOW)
	var fired := _of(_drive(14 + Weapon.DRAW_MAX_TICKS + 5, A.LIGHT), E.FIRE)
	assert_eq(fired.size(), 1)


func test_a_level_three_arrow_pierces_every_fighter_in_line() -> void:
	_sim = CombatSim.new(9)
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(Vector3(0, 0, -10))
	_sim.add_fighter(Vector3(0, 0, -16))
	_sim.fighters[0].lock_on_target = 1
	_previous = [FighterInput.new(), FighterInput.new(), FighterInput.new()]
	var neutral := FighterInput.new()
	var drive := func(ticks: int, held: int) -> Array[Dictionary]:
		var seen: Array[Dictionary] = []
		for _i in ticks:
			var inputs: Array[FighterInput] = [FighterInput.from_held(held, _previous[0]), neutral, neutral]
			_sim.tick(inputs)
			_previous[0] = inputs[0]
			seen.append_array(_sim.events)
		return seen
	var pickup := WeaponPickup.new()
	pickup.id = _sim._new_entity_id()
	pickup.kind = K.KI_BOW
	pickup.ammo = 12
	pickup.position = Vector3(0, 0.6, 0)
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	_sim.pickups.append(pickup)
	drive.call(1, A.PICKUP)
	drive.call(10, 0)
	drive.call(14 + Weapon.DRAW_LEVEL_TICKS[1] + 2, A.LIGHT)
	var seen: Array[Dictionary] = drive.call(30, 0)
	var targets := _of(seen, E.HIT).map(func(h: Dictionary) -> int: return h.target)
	targets.sort()
	assert_eq(targets, [1, 2], "one arrow, both fighters")


func test_a_level_three_arrow_pins_the_target_to_a_wall() -> void:
	var edge := 300.0
	_start(Vector3(0, 0, -edge + 4.0), Vector3(0, 0, -edge + 16.0))
	_arm(K.KI_BOW)
	_drive(14 + Weapon.DRAW_LEVEL_TICKS[1] + 2, A.LIGHT)
	var seen := _drive(30)
	assert_eq(_of(seen, E.ARROW_PIN).size(), 1)
	var them := _sim.fighters[1]
	assert_true(them.pinned)
	assert_eq(them.state, S.HITSTUN)
	var at := them.position
	_drive(20)
	assert_almost_eq(them.position, at, Vector3.ONE * 0.1, "stuck to the wall")
	_drive(Weapon.PIN_HOLD_TICKS + 60)
	assert_false(them.pinned)
	assert_ne(them.state, S.HITSTUN)


func test_a_level_one_arrow_never_pins() -> void:
	var edge := 300.0
	_start(Vector3(0, 0, -edge + 4.0), Vector3(0, 0, -edge + 16.0))
	_arm(K.KI_BOW)
	var seen := _join(_drive(1, A.LIGHT), _drive(60))
	assert_eq(_of(seen, E.HIT).size(), 1)
	assert_eq(_of(seen, E.ARROW_PIN).size(), 0)


# Heartstring Tether.

func _tether(distance := 10.0) -> void:
	_start(Vector3(0, 0, -distance))
	_arm(K.HEARTSTRING_BOW)
	_drive(16 + Weapon.DRAW_LEVEL_TICKS[1] + 2, A.LIGHT)


func test_a_charged_heartstring_shot_ties_shooter_and_target() -> void:
	_tether()
	var seen := _drive(30)
	var tied := _of(seen, E.TETHER)
	assert_eq(tied.size(), 1)
	assert_eq(tied[0].fighter, 0)
	assert_eq(tied[0].target, 1)
	var me := _sim.fighters[0]
	var them := _sim.fighters[1]
	assert_eq(me.tether_partner, 1)
	assert_eq(them.tether_partner, 0)
	assert_eq(them.smitten_ticks, 0, "the tether shot is not a smitten arrow")
	var length := me.tether_length
	assert_almost_eq(length, me.position.distance_to(them.position), 0.5)
	_drive(60, 0, 0, Vector2.ZERO, Vector2(0, -1))
	assert_lte(me.position.distance_to(them.position), length + 0.01, "cannot run further apart")


func test_a_tether_runs_out_after_four_seconds() -> void:
	_tether()
	_drive(30)
	var seen := _drive(Weapon.TETHER_TICKS)
	assert_eq(_of(seen, E.TETHER_END).size(), 1)
	assert_eq(_sim.fighters[0].tether_partner, -1)
	assert_eq(_sim.fighters[1].tether_partner, -1)


func test_rmb_yanks_the_other_fighter_in_for_a_follow_up() -> void:
	_tether()
	_drive(40)
	var seen := _drive(1, 0, A.HEAVY)
	assert_eq(_of(seen, E.TETHER_YANK).size(), 1, "either end can yank")
	assert_eq(_sim.fighters[0].state, S.BLOCKSTUN, "the yanked fighter cannot act")
	_drive(Weapon.YANK_TICKS + 1)
	assert_almost_eq(_sim.fighters[0].position.distance_to(_sim.fighters[1].position), Weapon.YANK_DISTANCE, 0.3)
	assert_eq(_sim.fighters[1].tether_partner, -1, "a yank spends the tether")


# Orbit Chakram.

func test_the_chakram_neutral_heavy_throws_a_disc_that_hits_out_and_back() -> void:
	_start(Vector3(0, 0, -6))
	_arm(K.ORBIT_CHAKRAM)
	var seen := _join(_drive(1, A.HEAVY), _drive(12))
	var fired := _of(seen, E.FIRE)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0].weapon, K.ORBIT_CHAKRAM)
	assert_eq(_sim.projectiles[0].effect, Weapon.Effect.DISC)
	seen.append_array(_drive(90))
	var hits := _of(seen, E.HIT).filter(func(h: Dictionary) -> bool: return h.move_id == &"chakram/disc_hit")
	assert_eq(hits.size(), 2, "once out, once back")
	assert_eq(_of(seen, E.DISC_CATCH).size(), 1)
	assert_eq(_sim.projectiles.size(), 0)


func test_only_one_disc_is_out_at_a_time() -> void:
	_start(Vector3(0, 0, -60))
	_arm(K.ORBIT_CHAKRAM)
	_drive(1, A.HEAVY)
	_drive(28)
	assert_eq(_sim.projectiles.size(), 1)
	_drive(1, A.HEAVY)
	_drive(14)
	assert_eq(_sim.projectiles.size(), 1, "the second throw waits for the catch")


# Storm Repeater.

func test_the_repeater_overheats_after_two_seconds_and_cools_in_one_and_a_half() -> void:
	_start(Vector3(0, 0, -200))
	_arm(K.STORM_REPEATER)
	var seen := _drive(130, A.LIGHT)
	var hot := _of(seen, E.OVERHEAT)
	assert_eq(hot.size(), 1)
	assert_true(_sim.fighters[0].overheated)
	var fired := _of(_drive(80, A.LIGHT), E.FIRE)
	assert_eq(fired.size(), 0, "no fire while overheated")
	fired = _of(_drive(30, A.LIGHT), E.FIRE)
	assert_gt(fired.size(), 0, "cooled down")


func test_firing_the_repeater_moves_at_sixty_percent_speed() -> void:
	_start(Vector3(0, 0, -200))
	_sim.fighters[0].lock_on_target = -1
	_arm(K.STORM_REPEATER)
	_drive(5, A.LIGHT, 0, Vector2(0, 1))
	var from := _sim.fighters[0].position
	_drive(30, A.LIGHT, 0, Vector2(0, 1))
	var speed := from.distance_to(_sim.fighters[0].position) / (30 * CombatSim.TICK_SECONDS)
	assert_eq(_sim.fighters[0].state, S.ATTACKING)
	assert_almost_eq(speed, _sim.tuning.ground_speed * 0.6, 0.3)


func test_a_dash_absorbs_repeater_bullets_for_ki() -> void:
	_start(Vector3(0, 0, -6))
	var them := _sim.fighters[1]
	them.enter_state(S.DASHING)
	them.dash_kind = FighterState.DashKind.SUSTAINED
	them.dash_direction = Vector3.ZERO
	them.ki = 50 * FighterState.METER_UNIT
	var health := them.health
	var shot := _sim._spawn_projectile(0, K.STORM_REPEATER, Vector3(0, 0, -100), 0.0, 0.18, 30,
		WeaponMoves.projectile_move(K.STORM_REPEATER), Weapon.Effect.NONE)
	shot.position = them.position + Vector3(0, 0, 3)
	var ki_before := them.ki
	var seen := _drive(3, 0, A.DASH)
	assert_eq(_of(seen, E.BULLET_ABSORB).size(), 1)
	assert_eq(them.health, health)
	assert_gt(them.ki, ki_before + FighterState.METER_UNIT, "+2 ki, more than a few ticks of dash cost")
	assert_eq(_sim.projectiles.size(), 0)


# Swapping.

## Fighter 0 with a blade in slot 0 and a revolver in slot 1, the blade in hand.
func _two_weapons(target := Vector3(0, 0, -1.8)) -> void:
	_start(target)
	_arm(K.STORM_BLADE)
	_arm(K.ARC_REVOLVER)
	_drive(1, A.WEAPON_PREVIOUS)
	_drive(10)
	assert_eq(_sim.fighters[0].held_weapon(), K.STORM_BLADE)


func test_c_quick_swaps_to_the_last_weapon_and_back() -> void:
	_two_weapons(Vector3(0, 0, -30))
	var me := _sim.fighters[0]
	var seen := _drive(1, A.QUICK_SWAP)
	assert_eq(me.held_weapon(), K.ARC_REVOLVER)
	assert_eq(_of(seen, E.WEAPON_SWITCH).size(), 1)
	assert_gt(me.switch_lockout, 0)
	_drive(10)
	_drive(1, A.QUICK_SWAP)
	assert_eq(me.held_weapon(), K.STORM_BLADE)
	_drive(10)
	_drive(1, A.WEAPON_NEXT)
	_drive(10)
	_drive(1, A.WEAPON_NEXT)
	_drive(10)
	assert_eq(me.held_weapon(), K.NONE)
	_drive(1, A.QUICK_SWAP)
	assert_eq(me.held_weapon(), K.ARC_REVOLVER, "from unarmed, back to the last weapon")


func test_quick_swap_after_the_last_weapon_is_gone_goes_unarmed() -> void:
	_two_weapons(Vector3(0, 0, -30))
	var me := _sim.fighters[0]
	_drive(1, A.QUICK_SWAP)
	_drive(10)
	_drive(1, A.THROW)
	_drive(20)
	assert_eq(me.held_weapon(), K.NONE)
	_drive(1, A.QUICK_SWAP)
	assert_eq(me.held_weapon(), K.STORM_BLADE)


func test_swap_cancel_after_contact_spends_ten_ki_into_the_new_weapon() -> void:
	_two_weapons()
	var me := _sim.fighters[0]
	me.ki = 40 * FighterState.METER_UNIT
	var seen := _drive(1, A.LIGHT)
	for _i in 30:
		seen.append_array(_drive(1))
		if me.contact_hit:
			break
	assert_true(me.contact_hit, "the blade light hit")
	var ki := me.ki
	# Pressed during the hit's hitstop: buffered, it swaps the moment the freeze ends.
	seen = _drive(1, A.WEAPON_NEXT | A.LIGHT)
	seen.append_array(_drive(6))
	assert_eq(_of(seen, E.SWAP_CANCEL).size(), 1)
	assert_eq(me.held_weapon(), K.ARC_REVOLVER)
	assert_eq(me.move_id(), &"revolver/shot", "the new weapon's move comes out at once")
	assert_lt(me.ki, ki - 9 * FighterState.METER_UNIT)


func test_no_swap_cancel_on_a_whiff_or_without_ki() -> void:
	_two_weapons(Vector3(0, 0, -30))
	var me := _sim.fighters[0]
	me.ki = 40 * FighterState.METER_UNIT
	_drive(1, A.LIGHT)
	_drive(8)
	var seen := _drive(1, A.WEAPON_NEXT)
	assert_eq(_of(seen, E.SWAP_CANCEL).size(), 0, "no contact, no cancel")
	assert_eq(me.held_weapon(), K.STORM_BLADE)
	_two_weapons()
	me = _sim.fighters[0]
	me.ki = 5 * FighterState.METER_UNIT
	_drive(1, A.LIGHT)
	for _i in 30:
		_drive(1)
		if me.contact_hit:
			break
	me.ki = 5 * FighterState.METER_UNIT
	seen = _drive(1, A.WEAPON_NEXT)
	seen.append_array(_drive(5))
	assert_eq(_of(seen, E.SWAP_CANCEL).size(), 0, "too little ki")


# Hits.

func test_ranged_hits_start_combos_at_eighty_percent_for_the_whole_combo() -> void:
	_start(Vector3(0, 0, -3))
	_arm(K.ARC_REVOLVER)
	var shot := WeaponMoves.projectile_move(K.ARC_REVOLVER)
	var seen := _join(_drive(1, A.LIGHT), _drive(8))
	var hits := _of(seen, E.HIT)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].damage, _sim.scaled_damage(shot, 1) * 80 / 100)
	assert_eq(_sim.fighters[1].combo_starter_percent, 80)
	_drive(10)
	assert_eq(_sim.fighters[1].state, S.HITSTUN, "still in the combo")
	seen = _join(_drive(1, A.LIGHT), _drive(8))
	hits = _of(seen, E.HIT)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].damage, _sim.scaled_damage(shot, 2) * 80 / 100, "kept for the combo")


func test_melee_combos_stay_at_full_damage() -> void:
	_start(Vector3(0, 0, -1.6))
	var seen := _join(_drive(1, A.LIGHT), _drive(10))
	var hits := _of(seen, E.HIT)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].damage, _sim.scaled_damage(_sim.fighters[0].stats.move_set.light_string[0], 1))
	assert_eq(_sim.fighters[1].combo_starter_percent, 100)


func test_a_counter_hit_heavy_knocks_the_weapon_out_of_hand() -> void:
	_start(Vector3(0, 0, -2.6))
	_arm(K.STORM_BLADE, 1)
	var seen := _join(_drive(1, A.HEAVY, A.HEAVY), _drive(20))
	var counters := _of(seen, E.COUNTER)
	assert_eq(counters.size(), 1)
	assert_eq(_sim.fighters[1].held_weapon(), K.NONE)
	var drops := _of(seen, E.WEAPON_DROP)
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].weapon, K.STORM_BLADE)


func test_a_counter_hit_light_keeps_the_weapon() -> void:
	_start(Vector3(0, 0, -1.6))
	_arm(K.STORM_BLADE, 1)
	var seen := _join(_drive(1, A.LIGHT, A.HEAVY), _drive(20))
	assert_eq(_of(seen, E.COUNTER).size(), 1)
	assert_eq(_sim.fighters[1].held_weapon(), K.STORM_BLADE)


# HUD and hash.

func test_held_ammo_reads_the_weapon_in_hand_for_the_hud() -> void:
	_two_weapons(Vector3(0, 0, -30))
	var me := _sim.fighters[0]
	assert_eq(me.held_ammo(), -1, "melee has no ammo")
	_drive(1, A.QUICK_SWAP)
	assert_eq(me.held_ammo(), 18)
	_drive(10)
	_drive(1, A.LIGHT)
	_drive(10)
	assert_eq(me.held_ammo(), 17)
	assert_eq(me.held_ammo(), me.ammo[me.active_slot])


func test_the_state_hash_covers_the_new_weapon_state() -> void:
	_start()
	var me := _sim.fighters[0]
	for change: Callable in [
		func() -> void: me.heat = 9,
		func() -> void: me.overheated = true,
		func() -> void: me.draw_ticks = 3,
		func() -> void: me.pin_ticks = 3,
		func() -> void: me.tether_partner = 1,
		func() -> void: me.tether_length = 4.0,
		func() -> void: me.last_slot = 1,
		func() -> void: me.combo_starter_percent = 80,
	]:
		var before := _sim.state_hash()
		change.call()
		assert_ne(before, _sim.state_hash())
	var shot := _sim._spawn_projectile(0, K.ORBIT_CHAKRAM, Vector3.FORWARD, 0.0, 0.5, 10,
		WeaponMoves.disc_move(), Weapon.Effect.DISC)
	var before := _sim.state_hash()
	shot.returning = true
	assert_ne(before, _sim.state_hash())


# Knockout and round reset (T-D16 merge).

func test_a_knockout_during_a_tether_cuts_it_at_both_ends() -> void:
	_tether()
	_drive(30)
	var them := _sim.fighters[1]
	assert_eq(them.tether_partner, 0)
	them.powers.haste_ticks = 100
	them.powers.aegis = true
	them.health = 0
	var seen := _drive(1)
	assert_eq(them.state, S.KO_FALL)
	assert_eq(_of(seen, E.TETHER_END).size(), 1)
	assert_eq(_sim.fighters[0].tether_partner, -1)
	assert_eq(them.tether_partner, -1)
	assert_eq(them.tether_ticks, 0)
	assert_eq(them.powers.haste_ticks, 0, "powers end on a KO")
	assert_false(them.powers.aegis)
	assert_eq(_of(seen, E.POWER_END).size(), 1)
	seen = _drive(30)
	assert_eq(_of(seen, E.TETHER_END).size(), 0, "cut only once")


func test_a_knockout_while_pinned_releases_the_pin() -> void:
	var edge := 300.0
	_start(Vector3(0, 0, -edge + 4.0), Vector3(0, 0, -edge + 16.0))
	_arm(K.KI_BOW)
	_drive(14 + Weapon.DRAW_LEVEL_TICKS[1] + 2, A.LIGHT)
	_drive(30)
	var them := _sim.fighters[1]
	assert_true(them.pinned)
	them.health = 0
	_drive(1)
	assert_eq(them.state, S.KO_FALL)
	assert_false(them.pinned)
	assert_eq(them.pin_ticks, 0)
	_drive(30)
	assert_false(them.pinned, "a KO'd fighter is never pinned again")
	assert_true(them.is_ko_state(), "stays knocked out")


func test_start_round_clears_gadgets_and_weapon_and_power_state() -> void:
	_tether()
	_drive(30)
	var me := _sim.fighters[0]
	me.heat = 9
	me.overheated = true
	me.draw_ticks = 4
	me.last_slot = 1
	me.powers.haste_ticks = 50
	me.powers.overdrive_ticks = 50
	me.powers.aegis = true
	me.powers.gadget = Power.Kind.SPIKE_BOMB
	var them := _sim.fighters[1]
	them.pin_ticks = 5
	them.pinned = true
	them.combo_starter_percent = 80
	_sim.gadgets.append(Gadget.new())
	_sim.start_round()
	assert_eq(_sim.gadgets.size(), 0)
	for fighter in _sim.fighters:
		assert_eq(fighter.tether_partner, -1)
		assert_eq(fighter.tether_ticks, 0)
		assert_eq(fighter.heat, 0)
		assert_false(fighter.overheated)
		assert_eq(fighter.draw_ticks, 0)
		assert_eq(fighter.last_slot, -1)
		assert_eq(fighter.pin_ticks, 0)
		assert_false(fighter.pinned)
		assert_eq(fighter.combo_starter_percent, 100)
		assert_eq(fighter.held_weapon(), K.NONE)
		assert_eq(fighter.powers.state_values(), FighterPowers.new().state_values())
	_drive(10)
	assert_eq(_sim.gadgets.size(), 0)
