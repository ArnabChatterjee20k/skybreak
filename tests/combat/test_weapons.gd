extends GutTest

const A := FighterInput.Action
const E := CombatSim.EventType
const K := Weapon.Kind

var _sim: CombatSim
var _previous: Array[FighterInput] = []


## Fighter 0 at the origin, fighter 1 at target (-Z is ahead), both locked on.
func _start(target := Vector3(0, 0, -6)) -> void:
	_sim = CombatSim.new(5)
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(target)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]


## Runs ticks with fighter 0 holding held and fighter 1 holding other_held.
func _drive(ticks: int, held: int = 0, other_held: int = 0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]),
			FighterInput.from_held(other_held, _previous[1]),
		]
		_sim.tick(inputs)
		_previous = inputs


## Taps action once, then runs neutral ticks.
func _tap(action: int, then_ticks := 1) -> void:
	_drive(1, action)
	_drive(then_ticks)


## A grounded pickup of kind at position.
func _place(kind: K, at: Vector3) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.id = _sim.next_entity_id
	_sim.next_entity_id += 1
	pickup.kind = kind
	pickup.ammo = Weapon.full_ammo(kind)
	pickup.position = at
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	_sim.pickups.append(pickup)
	return pickup


func _arm(kind: K) -> void:
	_place(kind, Vector3(0, 0.6, 0))
	_tap(A.PICKUP, 10)


func _events_of(type: E, during: int, held := 0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for _i in during:
		_drive(1, held)
		for event in _sim.events:
			if event.type == type:
				found.append(event)
	return found


# Spawning.

func test_drops_spawn_from_the_sky_with_a_telegraph_then_fall_and_rest() -> void:
	_start()
	_sim.pickups_enabled = true
	_drive(_sim.pickup_tuning.first_spawn_ticks + 1)
	assert_eq(_sim.pickups.size(), 1, "one drop at the first spawn tick")
	var pickup := _sim.pickups[0]
	assert_eq(pickup.phase, WeaponPickup.Phase.TELEGRAPH)
	assert_almost_eq(pickup.position.y, _sim.floor_height() + _sim.pickup_tuning.drop_height, 0.01)
	var middle := Vector2.ZERO
	var planar := Vector2(pickup.position.x, pickup.position.z) - Vector2(0, -3)
	assert_between(planar.length(), _sim.pickup_tuning.spawn_distance_min - 0.01,
		_sim.pickup_tuning.spawn_distance_max + 0.01, "25-60 m from the fighters' midpoint")
	assert_false(pickup.can_be_picked_up(), "not grabbable during the telegraph")
	_drive(_sim.pickup_tuning.telegraph_ticks)
	assert_eq(pickup.phase, WeaponPickup.Phase.FALLING)
	_drive(120)
	assert_eq(pickup.phase, WeaponPickup.Phase.GROUNDED)
	assert_almost_eq(pickup.position.y, _sim.floor_height() + _sim.pickup_tuning.rest_height, 0.001)
	assert_eq(pickup.ammo, Weapon.full_ammo(pickup.kind))


func test_drops_despawn_after_their_lifetime() -> void:
	_start()
	_sim.pickups_enabled = true
	_sim.pickup_tuning = PickupTuning.new()
	_sim.pickup_tuning.spawn_interval_min_ticks = 100_000
	_sim.pickup_tuning.spawn_interval_max_ticks = 100_000
	var despawned := _events_of(E.PICKUP_DESPAWN,
		_sim.pickup_tuning.first_spawn_ticks + _sim.pickup_tuning.spawn_lifetime_ticks + 2)
	assert_eq(despawned.size(), 1)
	assert_eq(_sim.pickups.size(), 0)


func test_nothing_spawns_in_a_pure_duel() -> void:
	_start()
	_drive(3000)
	assert_eq(_sim.pickups.size(), 0)


func test_the_heartstring_bow_spawns_only_in_heartbloom() -> void:
	var tuning := PickupTuning.new()
	for zone in ZoneLayout.ZONE_IDS:
		var table := tuning.table_for(zone)
		assert_eq(table.has(K.HEARTSTRING_BOW), zone == &"heartbloom_gardens", "table of %s" % zone)
	assert_false(tuning.default_table.has(K.HEARTSTRING_BOW))
	for zone: StringName in [&"skyhold_ruins", &"heartbloom_gardens"]:
		var seen := {}
		for seed_value in 12:
			var sim := CombatSim.new(seed_value)
			sim.zone = zone
			for _i in 400:
				seen[sim._pick_kind(sim.pickup_tuning.table_for(zone))] = true
				sim.last_spawn_kind = K.NONE
		assert_eq(seen.has(K.HEARTSTRING_BOW), zone == &"heartbloom_gardens", "%s drops" % zone)
		assert_true(seen.size() >= 10, "%s drops many kinds" % zone)


func test_drops_never_repeat_the_previous_kind() -> void:
	var sim := CombatSim.new(9)
	var table := sim.pickup_tuning.table_for(&"shattered_mesa")
	for _i in 500:
		var previous := sim.last_spawn_kind
		var kind := sim._pick_kind(table)
		assert_ne(kind, previous)
		sim.last_spawn_kind = kind


# Pickup, inventory, switching.

func test_g_in_reach_picks_up_into_the_hand_with_a_short_recovery() -> void:
	_start()
	var pickup := _place(K.STORM_BLADE, Vector3(1.5, 0.6, 0))
	_drive(1, A.PICKUP)
	var me := _sim.fighters[0]
	assert_eq(me.held_weapon(), K.STORM_BLADE)
	assert_eq(me.weapons[0], K.STORM_BLADE)
	assert_eq(_sim.pickups.size(), 0)
	assert_eq(me.move_id(), &"weapon/pickup")
	assert_eq(me.move_total_ticks(), 7, "instant grab plus 6 ticks of recovery")
	assert_true(_sim.events.any(func(e: Dictionary) -> bool:
		return e.type == E.PICKUP and e.id == pickup.id and e.fighter == 0))


func test_g_out_of_reach_does_nothing_when_unarmed() -> void:
	_start()
	_place(K.STORM_BLADE, Vector3(4, 0.6, 0))
	_drive(1, A.PICKUP)
	assert_eq(_sim.fighters[0].held_weapon(), K.NONE)
	assert_eq(_sim.pickups.size(), 1)


func test_the_inventory_holds_three_weapons_and_a_fourth_replaces_the_one_in_hand() -> void:
	_start()
	for kind: K in [K.STORM_BLADE, K.ARC_REVOLVER, K.TITAN_HAMMER]:
		_arm(kind)
	var me := _sim.fighters[0]
	assert_eq(me.weapon_count(), 3)
	assert_eq(me.held_weapon(), K.TITAN_HAMMER)
	assert_eq(me.active_slot, 2)
	_arm(K.SKY_LANCE)
	assert_eq(me.weapon_count(), 3, "never more than three")
	assert_eq(me.weapons[2], K.SKY_LANCE, "replaced the hammer in hand")
	assert_eq(_sim.pickups.size(), 1, "the hammer dropped to the ground")
	assert_eq(_sim.pickups[0].kind, K.TITAN_HAMMER)
	assert_true(_sim.pickups[0].dropped)


func test_next_and_previous_cycle_unarmed_and_filled_slots_with_a_lockout() -> void:
	_start()
	_arm(K.STORM_BLADE)
	_arm(K.ARC_REVOLVER)
	var me := _sim.fighters[0]
	assert_eq(me.active_slot, 1)
	_drive(1, A.WEAPON_NEXT)
	assert_eq(me.active_slot, -1, "wraps to unarmed")
	assert_eq(me.switch_lockout, _sim.pickup_tuning.switch_lockout_ticks)
	assert_true(_sim.events.any(func(e: Dictionary) -> bool: return e.type == E.WEAPON_SWITCH))
	_drive(1, A.LIGHT)
	assert_ne(me.state, FighterState.State.ATTACKING, "no attacks during the switch")
	_drive(40)
	_tap(A.WEAPON_NEXT)
	assert_eq(me.held_weapon(), K.STORM_BLADE)
	_drive(10)
	_tap(A.WEAPON_PREVIOUS)
	assert_eq(me.held_weapon(), K.NONE)
	_drive(10)
	_tap(A.WEAPON_PREVIOUS)
	assert_eq(me.held_weapon(), K.ARC_REVOLVER)


func test_ammo_is_kept_per_weapon_across_switches() -> void:
	_start(Vector3(0, 0, -10))
	_arm(K.ARC_REVOLVER)
	_tap(A.LIGHT, 30)
	var me := _sim.fighters[0]
	assert_eq(me.ammo[0], 17)
	_tap(A.WEAPON_NEXT, 10)
	_tap(A.WEAPON_NEXT, 10)
	assert_eq(me.held_weapon(), K.ARC_REVOLVER)
	assert_eq(me.ammo[0], 17)


# Throwing and dropping.

func test_throw_sends_the_held_weapon_at_the_target_and_it_lands_as_a_pickup() -> void:
	_start(Vector3(0, 0, -40))
	_arm(K.TITAN_HAMMER)
	_drive(1, A.THROW)
	var me := _sim.fighters[0]
	assert_eq(me.held_weapon(), K.NONE)
	assert_eq(me.weapon_count(), 0)
	assert_eq(_sim.projectiles.size(), 1)
	var thrown := _sim.projectiles[0]
	assert_true(thrown.thrown)
	assert_eq(thrown.weapon, K.TITAN_HAMMER)
	assert_lt(thrown.velocity.z, -30.0, "flies toward the target")
	assert_eq(me.move_id(), &"weapon/throw")
	_drive(120)
	assert_eq(_sim.projectiles.size(), 0)
	assert_eq(_sim.pickups.size(), 1, "the hammer landed")
	assert_eq(_sim.pickups[0].kind, K.TITAN_HAMMER)


func test_a_thrown_weapon_hits_with_damage_and_a_short_stun() -> void:
	_start(Vector3(0, 0, -6))
	_arm(K.STORM_BLADE)
	var health := _sim.fighters[1].health
	var hits := _events_of(E.PROJECTILE_HIT, 30, 0)
	assert_eq(hits.size(), 0)
	_drive(1, A.PICKUP)
	hits = _events_of(E.PROJECTILE_HIT, 20)
	assert_eq(hits.size(), 1, "G with nothing in reach throws")
	assert_lt(_sim.fighters[1].health, health)
	assert_eq(_sim.pickups.size(), 1, "the blade dropped where it hit")


func test_a_knockout_drops_every_weapon() -> void:
	_start()
	_arm(K.STORM_BLADE)
	_arm(K.SKY_LANCE)
	_sim.apply_damage(0, 1, 20_000)
	var me := _sim.fighters[0]
	assert_true(me.is_knocked_out())
	assert_eq(me.weapon_count(), 0)
	assert_eq(_sim.pickups.size(), 2)
	assert_eq(_sim.events.filter(func(e: Dictionary) -> bool: return e.type == E.WEAPON_DROP).size(), 2)


func test_a_guard_break_drops_the_weapon_in_hand_only() -> void:
	_start()
	_arm(K.STORM_BLADE)
	_arm(K.SKY_LANCE)
	_sim.apply_guard_damage(0, 1_000)
	var me := _sim.fighters[0]
	assert_eq(me.state, FighterState.State.GUARD_BROKEN)
	assert_eq(me.weapon_count(), 1)
	assert_eq(me.weapons[0], K.STORM_BLADE, "the other slot is safe")
	assert_eq(me.held_weapon(), K.NONE)


# Melee move sets.

func test_every_melee_weapon_swaps_in_its_own_sane_move_set() -> void:
	var unarmed: MoveSet = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
	var signatures := {}
	for kind in Weapon.MELEE:
		var moves := WeaponMoves.move_set(kind, unarmed)
		var name := Weapon.weapon_name(kind)
		assert_between(moves.light_string.size(), 2, 5, "%s string length" % name)
		var all: Array[MoveData] = []
		all.append_array(moves.light_string)
		all.append_array([moves.smash, moves.breaker, moves.launcher, moves.rising, moves.spike, moves.sweep])
		for move in all:
			assert_true(String(move.id).begins_with(String(name) + "/"), "%s id" % move.id)
			assert_between(move.startup_ticks, 4, 30, "%s startup" % move.id)
			assert_between(move.active_ticks, 1, 8, "%s active" % move.id)
			assert_between(move.recovery_ticks, 6, 36, "%s recovery" % move.id)
			assert_between(move.damage, 150, 1600, "%s damage" % move.id)
			assert_gt(move.hitstun_ticks, move.blockstun_ticks, "%s is plus on hit vs block" % move.id)
			assert_false(move.hitboxes_at(move.startup_ticks).is_empty(), "%s has a hitbox" % move.id)
			assert_true(move.cancel_end_tick > move.cancel_start_tick, "%s cancel window" % move.id)
		assert_eq(moves.grab, unarmed.grab, "grab stays unarmed")
		assert_eq(moves.push_block, unarmed.push_block)
		var first := moves.light_string[0]
		signatures[[first.startup_ticks, first.damage, _reach(first)]] = name
	assert_eq(signatures.size(), Weapon.MELEE.size(), "each weapon has distinct frame data and reach")


func test_melee_weapons_trade_speed_for_reach_and_power_as_designed() -> void:
	var unarmed: MoveSet = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
	var gauntlets := WeaponMoves.move_set(K.KI_GAUNTLETS, unarmed)
	var lance := WeaponMoves.move_set(K.SKY_LANCE, unarmed)
	var hammer := WeaponMoves.move_set(K.TITAN_HAMMER, unarmed)
	var chakram := WeaponMoves.move_set(K.ORBIT_CHAKRAM, unarmed)
	assert_lt(gauntlets.light_string[0].startup_ticks, unarmed.light_string[0].startup_ticks, "gauntlets are fastest")
	assert_gt(gauntlets.light_string.size(), unarmed.light_string.size(), "and have the longest string")
	assert_gt(_reach(lance.light_string[0]), 3.0, "lance pokes far")
	assert_gt(hammer.smash.damage, unarmed.charged_smash[1].damage, "hammer hits huge")
	assert_gt(hammer.smash.guard_break_below, 0, "hammer crushes guards")
	assert_gt(chakram.light_string[0].hitbox_offsets[0].length() - chakram.light_string[0].hitbox_lengths[0] * 0.5,
		1.5, "chakram misses up close")


func test_a_held_blade_attacks_with_the_blade_move_set() -> void:
	_start(Vector3(0, 0, -2))
	_arm(K.STORM_BLADE)
	_drive(1, A.LIGHT)
	assert_eq(_sim.fighters[0].move_id(), &"blade/light_1")
	var hits := _events_of(E.HIT, 20)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].move_id, &"blade/light_1")


# Ranged weapons and projectiles.

func test_ranged_shots_spawn_projectiles_spend_ammo_and_hit_through_the_hit_pipeline() -> void:
	_start(Vector3(0, 0, -12))
	_arm(K.ARC_REVOLVER)
	var health := _sim.fighters[1].health
	_drive(1, A.LIGHT)
	var fired := _events_of(E.FIRE, 6)
	assert_eq(fired.size(), 1)
	assert_eq(_sim.fighters[0].ammo[0], 17)
	var hits := _events_of(E.HIT, 12)
	assert_eq(hits.size(), 1, "the bullet travels, then hits")
	assert_eq(hits[0].move_id, &"revolver/projectile")
	assert_lt(_sim.fighters[1].health, health)
	assert_eq(_sim.projectiles.size(), 0)


func test_projectiles_are_blocked_with_guard_damage() -> void:
	_start(Vector3(0, 0, -12))
	_arm(K.ARC_REVOLVER)
	var guard := _sim.fighters[1].guard
	var health := _sim.fighters[1].health
	_drive(1, A.LIGHT, A.BLOCK)
	var blocked := 0
	for _i in 20:
		_drive(1, 0, A.BLOCK)
		for event in _sim.events:
			if event.type == E.PROJECTILE_HIT and event.blocked:
				blocked += 1
	assert_eq(blocked, 1)
	assert_eq(_sim.fighters[1].health, health)
	assert_lt(_sim.fighters[1].guard, guard)


func test_a_perfect_block_reflects_a_shot_back_at_the_shooter() -> void:
	_start(Vector3(0, 0, -12))
	_arm(K.KI_BOW)
	var shooter_health := _sim.fighters[0].health
	_drive(1, A.LIGHT)
	_drive(14)
	assert_eq(_sim.projectiles.size(), 1)
	var reflected := false
	for _i in 30:
		var press := A.BLOCK if _sim.projectiles.size() > 0 \
			and _sim.projectiles[0].position.z < -9.5 and not reflected else 0
		_drive(1, 0, press)
		for event in _sim.events:
			if event.type == E.PROJECTILE_HIT and event.reflected:
				reflected = true
	assert_true(reflected)
	assert_lt(_sim.fighters[0].health, shooter_health, "the arrow came back")


func test_bow_arrows_drop_under_gravity_and_expire() -> void:
	_start(Vector3(0, 0, -200))
	_sim.fighters[0].lock_on_target = -1
	_arm(K.KI_BOW)
	_drive(1, A.LIGHT)
	_drive(15)
	assert_eq(_sim.projectiles.size(), 1)
	var arrow := _sim.projectiles[0]
	var vy := arrow.velocity.y
	_drive(5)
	assert_lt(arrow.velocity.y, vy, "gravity pulls the arrow down")
	_drive(130)
	assert_eq(_sim.projectiles.size(), 0, "expired or hit the floor")


func test_the_scatter_cannon_fires_spread_pellets_that_die_past_short_range() -> void:
	_start(Vector3(0, 0, -40))
	_arm(K.SCATTER_CANNON)
	_drive(1, A.LIGHT)
	_drive(8)
	assert_eq(_sim.projectiles.size(), 6)
	var directions := {}
	for pellet in _sim.projectiles:
		directions[pellet.velocity.normalized().snapped(Vector3.ONE * 0.001)] = true
	assert_gt(directions.size(), 1, "pellets spread")
	_drive(10)
	assert_eq(_sim.projectiles.size(), 0, "pellets die at about 12 m")
	assert_eq(_sim.fighters[1].health, _sim.fighters[1].stats.max_health * FighterState.METER_UNIT)


func test_the_repeater_fires_while_held_at_its_fire_rate() -> void:
	_start(Vector3(0, 0, -60))
	_arm(K.STORM_REPEATER)
	var fired := _events_of(E.FIRE, 60, A.LIGHT)
	assert_between(fired.size(), 9, 12, "about one shot every 6 ticks")
	assert_eq(_sim.fighters[0].ammo[0], 120 - fired.size())


func test_the_revolver_reloads_after_six_shots() -> void:
	_start(Vector3(0, 0, -60))
	_arm(K.ARC_REVOLVER)
	for _shot in 6:
		_tap(A.LIGHT, 20)
	var me := _sim.fighters[0]
	assert_eq(me.ammo[0], 12)
	assert_gt(me.reload_ticks, 0)
	_drive(1, A.LIGHT)
	assert_ne(me.state, FighterState.State.ATTACKING, "cannot fire while reloading")


func test_an_empty_ranged_weapon_is_thrown_on_the_next_shot() -> void:
	_start(Vector3(0, 0, -60))
	_arm(K.SCATTER_CANNON)
	for _shot in 8:
		_tap(A.LIGHT, 40)
	var me := _sim.fighters[0]
	assert_eq(me.ammo[0], 0)
	_drive(1, A.LIGHT)
	assert_eq(me.held_weapon(), K.NONE)
	assert_eq(_sim.projectiles.filter(func(p: Projectile) -> bool: return p.thrown).size(), 1)


func test_heartstring_arrows_make_the_target_smitten_and_unable_to_attack() -> void:
	_start(Vector3(0, 0, -10))
	_arm(K.HEARTSTRING_BOW)
	_drive(1, A.LIGHT)
	var hit := _events_of(E.PROJECTILE_HIT, 30)
	assert_eq(hit.size(), 1)
	var target := _sim.fighters[1]
	assert_gt(target.smitten_ticks, 0)
	assert_eq(target.smitten_by, 0)
	_drive(30)
	var before := target.position.distance_to(_sim.fighters[0].position)
	_drive(1, 0, A.LIGHT)
	assert_ne(target.state, FighterState.State.ATTACKING, "smitten cannot attack")
	_drive(10)
	assert_lt(target.position.distance_to(_sim.fighters[0].position), before, "drifts toward the shooter")


# Determinism and the bot match.

## A seeded match of two WeaponBots with drops on; returns [hash, weapons used].
func _bot_match(seed_value: int, ticks: int, zone := &"skyhold_ruins") -> Array:
	var sim := CombatSim.new(seed_value)
	sim.zone = zone
	sim.pickups_enabled = true
	# Weapon drops only; powers and gadgets have their own bot match (tests/combat/weapons).
	sim.pickup_tuning.powers_enabled = false
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	sim.lock_everyone_onto_nearest()
	var bots: Array[WeaponBot] = [WeaponBot.new(0, seed_value * 3 + 1), WeaponBot.new(1, seed_value * 3 + 2)]
	var used := {}
	var types := {}
	for _tick in ticks:
		var inputs: Array[FighterInput] = []
		for bot in bots:
			inputs.append(bot.next_input(sim))
		sim.tick(inputs)
		for event in sim.events:
			types[event.type] = true
			if event.type in [E.FIRE, E.WEAPON_THROW]:
				used[event.weapon] = true
			elif event.type in [E.HIT, E.BLOCK, E.COUNTER] and String(event.move_id).contains("/"):
				var prefix := String(event.move_id).get_slice("/", 0)
				for kind in Weapon.NAMES:
					if String(Weapon.NAMES[kind]) == prefix:
						used[kind] = true
		if sim.round_over:
			sim.start_round()
	return [sim.state_hash(), used, types]


func test_same_seed_and_inputs_give_the_same_hash_with_pickups_and_projectiles() -> void:
	var first := _bot_match(11, 2400)
	var second := _bot_match(11, 2400)
	assert_eq(first[0], second[0])
	assert_ne(first[0], _bot_match(12, 2400)[0], "a different seed plays differently")


func test_the_state_hash_covers_pickups_projectiles_and_inventory() -> void:
	_start()
	var base := _sim.state_hash()
	var pickup := _place(K.STORM_BLADE, Vector3(5, 0.6, 0))
	var with_pickup := _sim.state_hash()
	assert_ne(base, with_pickup)
	pickup.ticks_left -= 1
	assert_ne(with_pickup, _sim.state_hash())
	var before := _sim.state_hash()
	_sim.fighters[0].weapons[1] = K.KI_BOW
	assert_ne(before, _sim.state_hash())
	before = _sim.state_hash()
	_sim.fighters[0].smitten_ticks = 3
	assert_ne(before, _sim.state_hash())
	before = _sim.state_hash()
	_sim._spawn_projectile(0, K.KI_BOW, Vector3.FORWARD, 0.0, 0.2, 10, WeaponMoves.projectile_move(K.KI_BOW),
		Weapon.Effect.NONE)
	assert_ne(before, _sim.state_hash())


func test_a_3600_tick_seeded_bot_match_uses_at_least_three_weapons() -> void:
	var result := _bot_match(3, 3600)
	var used: Dictionary = result[1]
	var names := used.keys().map(func(kind: int) -> StringName: return Weapon.weapon_name(kind))
	gut.p("weapons used: %s" % [names])
	assert_gte(used.size(), 3, "weapons used: %s" % [names])
	var types: Dictionary = result[2]
	for type in [E.PICKUP_SPAWN, E.PICKUP]:
		assert_true(types.has(type), "a %s event" % E.keys()[type])


func test_longer_bot_matches_land_every_weapon_event() -> void:
	var types := {}
	for seed_value in [3, 4]:
		types.merge(_bot_match(seed_value, 7200)[2])
	# Bots grab every drop, so PICKUP_DESPAWN is covered by its own test above.
	for type in range(E.PICKUP_SPAWN, E.PROJECTILE_HIT + 1):
		if type != E.PICKUP_DESPAWN:
			assert_true(types.has(type), "a %s event" % E.keys()[type])


func _reach(move: MoveData) -> float:
	return move.hitbox_offsets[0].length() + move.hitbox_lengths[0] * 0.5 + move.hitbox_radii[0]
