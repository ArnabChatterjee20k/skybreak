extends GutTest
## Powers and gadgets (GAME_DESIGN §5.11, T-D26).

const A := FighterInput.Action
const E := CombatSim.EventType
const P := Power.Kind
const S := FighterState.State
const UNIT := FighterState.METER_UNIT

var _sim: CombatSim
var _previous: Array[FighterInput] = []


## Fighter 0 at the origin, fighter 1 at target (-Z is ahead), both locked on.
func _start(target := Vector3(0, 0, -6), seed_value := 7) -> void:
	_sim = CombatSim.new(seed_value)
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(target)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]


## Runs ticks; returns every event raised meanwhile.
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


func _of(events: Array, type: E) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event.type == type)


## A grounded power drop of kind at position.
func _place(kind: P, at: Vector3) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.id = _sim._new_entity_id()
	pickup.power = kind
	pickup.position = at
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	_sim.pickups.append(pickup)
	return pickup


## Fighter 0 picks up kind where it stands, then waits out the recovery.
func _take(kind: P) -> Array[Dictionary]:
	_place(kind, Vector3(0, 0.6, 0))
	var seen := _drive(1, A.PICKUP)
	seen.append_array(_drive(10))
	return seen


func test_sky_drops_alternate_weapons_and_powers() -> void:
	_start(Vector3(0, 0, -6))
	_sim.pickups_enabled = true
	_sim.pickup_tuning.first_spawn_ticks = 1
	_sim.pickup_tuning.spawn_interval_min_ticks = 10
	_sim.pickup_tuning.spawn_interval_max_ticks = 10
	_sim.pickup_tuning.max_pickups = 99
	var spawns := _of(_drive(80), E.PICKUP_SPAWN)
	assert_gte(spawns.size(), 6)
	for i in spawns.size():
		var is_power: bool = spawns[i].power != P.NONE
		assert_eq(is_power, i % 2 == 1, "drop %d alternates" % i)
		if is_power:
			assert_eq(spawns[i].weapon, Weapon.Kind.NONE)


func test_powers_can_be_switched_off_for_weapon_only_drops() -> void:
	_start()
	_sim.pickups_enabled = true
	_sim.pickup_tuning.powers_enabled = false
	_sim.pickup_tuning.first_spawn_ticks = 1
	_sim.pickup_tuning.spawn_interval_min_ticks = 10
	_sim.pickup_tuning.spawn_interval_max_ticks = 10
	_sim.pickup_tuning.max_pickups = 99
	for spawn in _of(_drive(60), E.PICKUP_SPAWN):
		assert_eq(spawn.power, P.NONE)


func test_g_takes_a_power_drop_with_the_pickup_recovery() -> void:
	_start()
	_place(P.HASTE, Vector3(0, 0.6, 0))
	var seen := _drive(1, A.PICKUP)
	var taken := _of(seen, E.POWER_PICKUP)
	assert_eq(taken.size(), 1)
	assert_eq(taken[0].power, P.HASTE)
	assert_eq(_sim.fighters[0].move_id(), &"weapon/pickup")
	assert_eq(_sim.pickups.size(), 0)
	assert_eq(_sim.fighters[0].weapon_count(), 0, "a power is not a weapon")


func test_overdrive_orb_triples_ki_regen_for_ten_seconds() -> void:
	_start(Vector3(0, 0, -40))
	_take(P.OVERDRIVE_ORB)
	var me := _sim.fighters[0]
	var them := _sim.fighters[1]
	me.ki = 0
	them.ki = 0
	_drive(60)
	assert_eq(me.ki, them.ki * 3, "ki regen x3")
	assert_eq(me.powers.active_auras(), [P.OVERDRIVE_ORB] as Array[Power.Kind])
	var ended := _of(_drive(Power.OVERDRIVE_TICKS), E.POWER_END)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].power, P.OVERDRIVE_ORB)
	me.ki = 0
	them.ki = 0
	_drive(30)
	assert_eq(me.ki, them.ki, "back to normal")


func test_burst_shard_adds_fifty_burst() -> void:
	_start()
	var before := _sim.fighters[0].burst
	_take(P.BURST_SHARD)
	assert_eq(_sim.fighters[0].burst - before, Power.BURST_SHARD_BURST * UNIT)


func test_aegis_absorbs_the_next_hit_completely_then_drops() -> void:
	_start(Vector3(0, 0, -1.6))
	var them := _sim.fighters[1]
	them.powers.aegis = true
	var health := them.health
	var seen := _drive(1, A.LIGHT)
	seen.append_array(_drive(20))
	assert_eq(_of(seen, E.AEGIS_BREAK).size(), 1)
	assert_eq(_of(seen, E.HIT).size(), 0)
	assert_eq(them.health, health, "no damage")
	assert_ne(them.state, S.HITSTUN, "no stun")
	assert_false(them.powers.aegis)
	_drive(1, A.LIGHT)
	_drive(20)
	assert_lt(them.health, health, "the next hit lands")


func test_haste_adds_twenty_percent_movement_for_eight_seconds() -> void:
	var travel: Array[float] = []
	for hasted in [false, true]:
		_start(Vector3(0, 0, -200))
		_sim.fighters[0].lock_on_target = -1
		if hasted:
			_take(P.HASTE)
		else:
			_drive(11)
		_drive(30, 0, 0, Vector2(0, 1))
		var from := _sim.fighters[0].position
		_drive(30, 0, 0, Vector2(0, 1))
		travel.append(from.distance_to(_sim.fighters[0].position))
	assert_almost_eq(travel[1], travel[0] * 1.2, 0.01, "20% faster")
	var ended := _of(_drive(Power.HASTE_TICKS), E.POWER_END)
	assert_eq(ended.size(), 1)
	assert_eq(_sim.fighters[0].powers.haste_ticks, 0)


func test_spike_bomb_explodes_on_contact_and_launches() -> void:
	_start(Vector3(0, 0, -8))
	_take(P.SPIKE_BOMB)
	assert_eq(_sim.fighters[0].powers.gadget, P.SPIKE_BOMB)
	var them := _sim.fighters[1]
	var health := them.health
	var seen := _drive(1, A.PICKUP)
	assert_eq(_of(seen, E.GADGET_THROW).size(), 1)
	assert_eq(_sim.gadgets.size(), 1)
	assert_eq(_sim.fighters[0].powers.gadget, P.NONE)
	seen = _drive(30)
	assert_eq(_of(seen, E.GADGET_EXPLODE).size(), 1)
	var hits := _of(seen, E.HIT)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].move_id, &"gadget/spike_bomb")
	assert_eq(hits[0].knockback_type, MoveData.KnockbackType.LAUNCH)
	assert_lt(them.health, health)
	assert_eq(_sim.gadgets.size(), 0)


func test_spike_bomb_goes_off_after_its_fuse_and_spares_its_owner() -> void:
	_start(Vector3(0, 0, -200))
	_sim.fighters[0].lock_on_target = -1
	_take(P.SPIKE_BOMB)
	var health := _sim.fighters[0].health
	_drive(1, A.PICKUP)
	var seen := _drive(Power.BOMB_FUSE_TICKS - 2)
	assert_eq(_of(seen, E.GADGET_EXPLODE).size(), 0)
	assert_eq(_sim.gadgets[0].phase, Gadget.Phase.RESTING, "landed on the floor")
	seen = _drive(3)
	assert_eq(_of(seen, E.GADGET_EXPLODE).size(), 1)
	assert_eq(_sim.fighters[0].health, health)


func test_a_blocked_spike_bomb_does_guard_damage_only() -> void:
	_start(Vector3(0, 0, -8))
	_take(P.SPIKE_BOMB)
	var them := _sim.fighters[1]
	var health := them.health
	var guard := them.guard
	var seen := _drive(1, A.PICKUP, A.BLOCK)
	seen.append_array(_drive(30, 0, A.BLOCK))
	assert_eq(_of(seen, E.BLOCK).size(), 1)
	assert_eq(them.health, health)
	assert_lt(them.guard, guard)


func test_gravity_mine_arms_triggers_and_pulls_opponents_in_for_two_seconds() -> void:
	_start(Vector3(0, 0, -8))
	_take(P.GRAVITY_MINE)
	_drive(1, A.PICKUP)
	var mine := _sim.gadgets[0]
	assert_almost_eq(mine.position.distance_to(_sim.fighters[0].position), Power.MINE_PLACE_DISTANCE, 0.3)
	var owner_at := _sim.fighters[0].position
	var seen := _drive(Power.MINE_ARM_TICKS + 2)
	assert_eq(_of(seen, E.MINE_TRIGGER).size(), 1)
	var before := _sim.fighters[1].position.distance_to(mine.position)
	_drive(40)
	assert_lt(_sim.fighters[1].position.distance_to(mine.position), before - 4.0, "pulled in")
	assert_eq(_sim.fighters[0].position, owner_at, "its owner is not pulled")
	seen = _drive(Power.MINE_PULL_TICKS)
	assert_eq(_of(seen, E.GADGET_END).size(), 1)
	assert_eq(_sim.gadgets.size(), 0)


func test_an_untriggered_mine_fizzles() -> void:
	_start(Vector3(0, 0, -100))
	_take(P.GRAVITY_MINE)
	_drive(1, A.PICKUP)
	var seen := _drive(Power.MINE_LIFETIME_TICKS + 2)
	assert_eq(_of(seen, E.MINE_TRIGGER).size(), 0)
	assert_eq(_of(seen, E.GADGET_END).size(), 1)


func test_mirror_decoy_copies_its_owner_and_lasts_three_seconds() -> void:
	_start(Vector3(0, 0, -60))
	_drive(1, A.LIGHT)
	_drive(30)
	_take(P.MIRROR_DECOY)
	_drive(1, A.PICKUP)
	var decoy := _sim.gadgets[0]
	assert_eq(decoy.phase, Gadget.Phase.MIRRORING)
	assert_almost_eq(decoy.position.distance_to(_sim.fighters[0].position), Power.DECOY_SIDE_OFFSET, 0.3)
	_drive(20)
	var offset := decoy.position - _sim.fighters[0].position
	_drive(20, 0, 0, Vector2(1, 0))
	assert_almost_eq(decoy.position - _sim.fighters[0].position, offset, Vector3.ONE * 0.6,
		"moves as its owner moves")
	_drive(1, A.LIGHT)
	_drive(2)
	assert_eq(decoy.copied_move, _sim.fighters[0].move_id(), "copies the latest action")
	var seen := _drive(Power.DECOY_TICKS)
	assert_eq(_of(seen, E.GADGET_END).size(), 1)
	assert_eq(_sim.gadgets.size(), 0)


func test_any_opponent_hit_pops_the_decoy() -> void:
	_start(Vector3(0, 0, -60))
	_take(P.MIRROR_DECOY)
	_drive(1, A.PICKUP)
	var decoy := _sim.gadgets[0]
	var shot := _sim._spawn_projectile(1, Weapon.Kind.ARC_REVOLVER, Vector3.ZERO, 0.0, 0.2, 30,
		WeaponMoves.projectile_move(Weapon.Kind.ARC_REVOLVER), Weapon.Effect.NONE)
	shot.position = decoy.position + Vector3(0, 0, -3)
	shot.velocity = Vector3(0, 0, 60)
	var seen := _drive(6)
	assert_eq(_of(seen, E.DECOY_POP).size(), 1)
	assert_eq(_sim.gadgets.size(), 0)
	assert_false(_sim.projectiles.has(shot), "the shot is used up")


func test_a_new_gadget_replaces_the_held_one_which_drops() -> void:
	_start()
	_take(P.SPIKE_BOMB)
	_take(P.GRAVITY_MINE)
	assert_eq(_sim.fighters[0].powers.gadget, P.GRAVITY_MINE)
	assert_eq(_sim.pickups.size(), 1)
	assert_eq(_sim.pickups[0].power, P.SPIKE_BOMB)
	assert_true(_sim.pickups[0].dropped)


func test_g_uses_the_gadget_before_throwing_the_weapon() -> void:
	_start(Vector3(0, 0, -20))
	var blade := WeaponPickup.new()
	blade.id = _sim._new_entity_id()
	blade.kind = Weapon.Kind.STORM_BLADE
	blade.position = Vector3(0, 0.6, 0)
	blade.phase = WeaponPickup.Phase.GROUNDED
	blade.ticks_left = 600
	_sim.pickups.append(blade)
	_drive(1, A.PICKUP)
	_drive(10)
	_take(P.SPIKE_BOMB)
	_drive(1, A.PICKUP)
	assert_eq(_sim.fighters[0].held_weapon(), Weapon.Kind.STORM_BLADE)
	assert_eq(_sim.gadgets.size(), 1)


func test_the_state_hash_covers_powers_and_gadgets() -> void:
	_start()
	var before := _sim.state_hash()
	_sim.fighters[0].powers.aegis = true
	assert_ne(before, _sim.state_hash())
	before = _sim.state_hash()
	_sim.fighters[0].powers.haste_ticks = 5
	assert_ne(before, _sim.state_hash())
	before = _sim.state_hash()
	_sim.fighters[0].powers.gadget = P.GRAVITY_MINE
	assert_ne(before, _sim.state_hash())
	before = _sim.state_hash()
	_place(P.AEGIS, Vector3(4, 0.6, 0))
	assert_ne(before, _sim.state_hash())
	before = _sim.state_hash()
	_sim.pickups[0].power = P.HASTE
	assert_ne(before, _sim.state_hash())
	before = _sim.state_hash()
	_drive(1, A.PICKUP)
	before = _sim.state_hash()
	_sim.gadgets[0].ticks_left -= 1
	assert_ne(before, _sim.state_hash())


func test_gadgets_spare_teammates() -> void:
	_start(Vector3(0, 0, -8))
	_sim.fighters[1].team = _sim.fighters[0].team
	_take(P.SPIKE_BOMB)
	var health := _sim.fighters[1].health
	_drive(1, A.PICKUP)
	var seen := _drive(Power.BOMB_FUSE_TICKS + 10)
	assert_eq(_of(seen, E.GADGET_EXPLODE).size(), 1, "goes off on its fuse, not on the teammate")
	assert_eq(_of(seen, E.HIT).size(), 0)
	assert_eq(_sim.fighters[1].health, health)


# Bot match.

## A seeded 2-bot match with busy power drops; returns [hash, event type -> count, powers taken].
func _bot_match(seed_value: int, ticks: int) -> Array:
	var sim := CombatSim.new(seed_value)
	sim.pickups_enabled = true
	sim.pickup_tuning.spawn_interval_min_ticks = 240
	sim.pickup_tuning.spawn_interval_max_ticks = 360
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	sim.lock_everyone_onto_nearest()
	var bots: Array[PowerBot] = [PowerBot.new(0, seed_value * 3 + 1), PowerBot.new(1, seed_value * 3 + 2)]
	var counts := {}
	var taken := {}
	for _tick in ticks:
		var inputs: Array[FighterInput] = []
		for bot in bots:
			inputs.append(bot.next_input(sim))
		sim.tick(inputs)
		for event in sim.events:
			counts[event.type] = counts.get(event.type, 0) + 1
			if event.type == E.POWER_PICKUP:
				taken[event.power] = true
		if sim.round_over:
			sim.start_round()
	return [sim.state_hash(), counts, taken]


func test_a_3600_tick_bot_match_uses_powers_and_gadgets() -> void:
	var result := _bot_match(6, 3600) # seed 5 stopped throwing a gadget once air knockback changed (polish batch 2)
	var counts: Dictionary = result[1]
	var taken: Dictionary = result[2]
	var names := taken.keys().map(func(kind: int) -> StringName: return Power.power_name(kind))
	gut.p("powers taken: %s; gadgets thrown: %d" % [names, counts.get(E.GADGET_THROW, 0)])
	assert_gte(taken.size(), 2, "powers taken: %s" % [names])
	assert_gt(counts.get(E.GADGET_THROW, 0), 0, "a gadget was used")
	assert_gt(counts.get(E.HIT, 0), 0)


func test_bot_matches_with_powers_are_deterministic() -> void:
	var first := _bot_match(5, 3600)
	assert_eq(first[0], _bot_match(5, 3600)[0])
	assert_ne(first[0], _bot_match(6, 3600)[0], "a different seed plays differently")

