class_name SpecialRules
extends RefCounted
## Legend specials (T-SP1): keys 1/2/3 start a SpecialKit move from a free state or
## as a SPECIAL cancel; travel, blink, counter stance, Vexa's afterimage decoy and
## Kael's Momentum. Pure functions over CombatSim; state lives in FighterState
## (move, move_tick) and FighterState.specials. Deterministic: ticks, DetMath, no rng.

const _S := FighterState.State
const _E := CombatSim.EventType
const _UNIT := FighterState.METER_UNIT
## Key of each special slot (index 0 = key 1).
const SLOT_ACTIONS: Array[int] = [
	FighterInput.Action.SPECIAL_1, FighterInput.Action.SPECIAL_2, FighterInput.Action.SPECIAL_3,
]
const _ULTIMATE := FighterInput.Action.ULTIMATE
## States a special starts from without a cancel.
const START_STATES: Array[FighterState.State] = [_S.IDLE, _S.MOVING, _S.FLYING]
## A rush stops travelling once this close to its target (planar m).
const RUSH_ARRIVAL := 1.1
## Wish input below this length counts as neutral (DECOY_STEP goes straight back).
const _DEADZONE := 0.5


## The legend's kit, or null for a legend without specials yet.
static func kit_of(fighter: FighterState) -> SpecialKit:
	return fighter.stats.special_kit if fighter.stats else null


## True when the fighter's kit has a special on key slot (1-3): no other system reads that key.
static func owns_key(fighter: FighterState, slot: int) -> bool:
	var kit := kit_of(fighter)
	return kit != null and kit.special_for(slot) != null


## The special the fighter is performing, or null.
static func current(fighter: FighterState) -> SpecialMove:
	if fighter.state != _S.ATTACKING or fighter.move == null:
		return null
	var kit := kit_of(fighter)
	return kit.special_of(fighter.move) if kit else null


## True when a special may start now: free, or a SPECIAL cancel of a move that made contact.
static func can_start(sim: CombatSim, index: int) -> bool:
	var fighter := sim.fighters[index]
	if not sim._may_attack(fighter):
		return false
	if fighter.state in START_STATES:
		return true
	return fighter.state == _S.ATTACKING and sim.can_cancel_into(index, MoveData.CancelLevel.SPECIAL)


## Starts a buffered special (1/2/3) or kit ultimate (4). A key this kit owns is always
## consumed once the fighter could act, so no other system (ki beam on 1) also reads it.
static func start(sim: CombatSim, index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := sim.fighters[index]
	var kit := kit_of(fighter)
	if kit == null:
		return
	if kit.ultimate != null and sim.is_buffered(index, _ULTIMATE) and can_start(sim, index):
		sim.consume_buffered(index, _ULTIMATE)
		if sim.try_spend_burst(index, kit.ultimate_burst_stocks):
			begin(sim, index, kit.ultimate, kit.ultimate.move_for(input.vertical), wish)
		else:
			_deny(sim, index, 4)
		return
	for slot in range(1, SLOT_ACTIONS.size() + 1):
		var action: int = SLOT_ACTIONS[slot - 1]
		var special := kit.special_for(slot)
		if special == null or not sim.is_buffered(index, action):
			continue
		if not can_start(sim, index):
			return # Stays buffered: it comes out when the fighter can act.
		sim.consume_buffered(index, action)
		var move := special.move_for(input.vertical)
		if not sim._spend_ki(fighter, move.ki_cost):
			_deny(sim, index, slot)
			return
		begin(sim, index, special, move, wish)
		return


## Puts the fighter into special's move (ki or burst already paid).
static func begin(sim: CombatSim, index: int, special: SpecialMove, move: MoveData, wish: Vector3) -> void:
	var fighter := sim.fighters[index]
	var state := fighter.specials
	fighter.velocity = Vector3.ZERO
	sim._update_facing(index)
	sim._aim_at_target(index)
	fighter.begin_move(move)
	state.used += 1
	var forward := sim._attack_forward(index)
	state.travel_direction = forward
	match special.effect:
		SpecialMove.Effect.RUSH:
			var pitch := fighter.aim_pitch
			var variant := special.variant_of(move)
			if variant != 0:
				pitch = special.variant_pitch * variant
			state.travel_direction = (forward * DetMath.cos(pitch) + Vector3.UP * DetMath.sin(pitch)).normalized()
		SpecialMove.Effect.LEAP:
			var reach := special.travel_distance
			var target := fighter.lock_on_target
			if target >= 0:
				var gap := sim.fighters[target].position - fighter.position
				gap.y = 0.0
				reach = clampf(gap.length() - 1.0, 0.0, special.travel_distance)
			state.leap_from = fighter.position
			state.leap_to = fighter.position + forward * reach
		SpecialMove.Effect.DECOY_STEP:
			var planar := Vector3(wish.x, 0.0, wish.z)
			state.travel_direction = -forward if planar.length() < _DEADZONE else planar.normalized()
			_place_decoy(sim, index)
	sim.events.append({
		"type": _E.SPECIAL_START, "fighter": index, "position": fighter.position,
		"slot": special.slot, "move_id": move.id, "variant": special.variant_of(move),
		"cue": special.tell_cue, "tick": sim.current_tick,
	})


## Per-tick movement of the special in progress; call after the plain attack movement.
static func move(sim: CombatSim, index: int) -> void:
	var fighter := sim.fighters[index]
	var special := current(fighter)
	if special == null or fighter.holding_charge:
		return
	var tick := fighter.move_tick
	if special.rehit_ticks.has(tick):
		fighter.hit_targets = 0
	var state := fighter.specials
	var travelling := tick >= special.travel_start_tick and tick < special.travel_end_tick
	var touched := fighter.contact_hit or fighter.contact_blocked
	match special.effect:
		SpecialMove.Effect.RUSH, SpecialMove.Effect.DECOY_STEP:
			var arrived := special.effect == SpecialMove.Effect.RUSH and _arrived(sim, index)
			if travelling and not (special.stop_on_contact and touched) and not arrived:
				var ticks := special.travel_end_tick - special.travel_start_tick
				fighter.velocity = state.travel_direction * (special.travel_distance / (ticks * CombatSim.TICK_SECONDS))
		SpecialMove.Effect.LEAP:
			if travelling:
				var ticks := float(special.travel_end_tick - special.travel_start_tick)
				var seconds := ticks * CombatSim.TICK_SECONDS
				var s := (float(tick - special.travel_start_tick) + 0.5) / ticks
				var planar := state.leap_to - state.leap_from
				planar.y = 0.0
				fighter.velocity = planar / seconds
				# Parabola y = 4h s (1 - s): its slope over the whole leap.
				fighter.velocity.y = special.leap_height * 4.0 * (1.0 - 2.0 * s) / seconds
		SpecialMove.Effect.BLINK:
			if tick == special.blink_tick:
				_blink(sim, index, special)
		SpecialMove.Effect.COUNTER:
			pass


## A rush stops on reaching its locked target, rather than running under or over it.
static func _arrived(sim: CombatSim, index: int) -> bool:
	var fighter := sim.fighters[index]
	if fighter.lock_on_target < 0:
		return false
	var gap := sim.fighters[fighter.lock_on_target].position - fighter.position
	return Vector2(gap.x, gap.z).length() <= RUSH_ARRIVAL


## Reappears behind the locked target (or blink_range ahead when it is far or unlocked).
static func _blink(sim: CombatSim, index: int, special: SpecialMove) -> void:
	var fighter := sim.fighters[index]
	var forward := sim._attack_forward(index)
	var destination := fighter.position + forward * special.blink_range
	var target := fighter.lock_on_target
	if target >= 0:
		var other := sim.fighters[target]
		var gap := other.position - fighter.position
		var planar := Vector3(gap.x, 0.0, gap.z)
		if planar.length() <= special.blink_range:
			destination = other.position + forward * special.blink_behind
			destination.y = other.position.y
	fighter.position = destination
	sim._clamp_to_arena(fighter)
	if fighter.position.y < fighter.stand_height:
		fighter.position.y = fighter.stand_height
	sim._update_facing(index)
	sim._aim_at_target(index)
	sim.events.append({
		"type": _E.SPECIAL_BLINK, "fighter": index, "position": fighter.position,
		"move_id": fighter.move_id(), "tick": sim.current_tick,
	})


# Counter stance.

## True if a strike from move landing on target now is caught by its counter stance.
static func catches(target: FighterState, move: MoveData) -> bool:
	var special := current(target)
	if special == null or special.effect != SpecialMove.Effect.COUNTER or move == null:
		return false
	if move.kind != MoveData.Kind.STRIKE or target.move != special.move:
		return false
	return target.move_tick >= special.counter_start_tick and target.move_tick < special.counter_end_tick


## The contact for a caught strike; CombatSim._resolve_hits hands it to apply_counter().
static func caught_contact(sim: CombatSim, attacker_index: int, target_index: int, at: Vector3) -> Dictionary:
	var attacker := sim.fighters[attacker_index]
	return {
		"type": _E.SPECIAL_COUNTER, "attacker": attacker_index, "target": target_index,
		"move": attacker.move, "yaw": attacker.facing_yaw, "pitch": attacker.aim_pitch,
		"side": attacker.aim_side, "position": at, "dodge_punish": false,
	}


## The stance holder turns and performs the riposte; the attacker freezes long enough to eat it.
static func apply_counter(sim: CombatSim, contact: Dictionary) -> void:
	var attacker_index: int = contact.attacker
	var holder_index: int = contact.target
	var attacker := sim.fighters[attacker_index]
	var holder := sim.fighters[holder_index]
	var special := current(holder)
	if special == null or special.counter_move == null:
		return
	if attacker.state == _S.ATTACKING and attacker.move == contact.move:
		attacker.string_queued = false
		attacker.string_dropped = true
	var hitstop := sim.hit_tuning.perfect_block_hitstop_ticks
	sim._freeze(attacker, holder, hitstop)
	attacker.hitstop_ticks += special.counter_freeze_ticks
	var look := attacker.position - holder.position
	look.y = 0.0
	if look.length_squared() > 0.0001:
		holder.facing_yaw = DetMath.atan2(-look.x, -look.z)
	holder.begin_move(special.counter_move)
	holder.aim_pitch = 0.0
	sim.events.append({
		"type": _E.SPECIAL_COUNTER, "fighter": holder_index, "attacker": attacker_index,
		"target": attacker_index, "position": contact.position, "move_id": special.counter_move.id,
		"caught": (contact.move as MoveData).id, "hitstop": hitstop, "tick": sim.current_tick,
	})


# Afterimage decoy (Vexa).

static func _place_decoy(sim: CombatSim, index: int) -> void:
	var fighter := sim.fighters[index]
	var kit := kit_of(fighter)
	var state := fighter.specials
	if state.has_decoy():
		sim.events.append(_decoy_event(sim, _E.DECOY_FADE, index))
	state.decoy_ticks = kit.decoy_ticks
	state.decoy_position = fighter.position
	state.decoy_yaw = fighter.facing_yaw
	sim.events.append(_decoy_event(sim, _E.DECOY_SPAWN, index))


## Counts decoys down; a decoy touched by an opponent's hitbox or shot bursts. Call once per tick.
static func step(sim: CombatSim) -> void:
	for index in sim.fighters.size():
		var fighter := sim.fighters[index]
		var state := fighter.specials
		if not state.has_decoy():
			continue
		if fighter.is_knocked_out() or sim.round_over:
			state.decoy_ticks = 0
			continue
		var striker := _decoy_striker(sim, index)
		if striker != -2:
			_burst(sim, index)
			continue
		state.decoy_ticks -= 1
		if state.decoy_ticks == 0:
			sim.events.append(_decoy_event(sim, _E.DECOY_FADE, index))


## Index of the opponent whose hitbox touches the decoy (-1 for a shot, used up), or -2 for none.
static func _decoy_striker(sim: CombatSim, owner: int) -> int:
	var fighter := sim.fighters[owner]
	var kit := kit_of(fighter)
	if kit == null:
		return -2
	var half := Vector3.UP * maxf(kit.decoy_height * 0.5 - kit.decoy_radius, 0.0)
	var low := fighter.specials.decoy_position - half
	var high := fighter.specials.decoy_position + half
	for index in sim.fighters.size():
		var other := sim.fighters[index]
		if index == owner or other.team == fighter.team or other.hitstop_ticks > 0:
			continue
		for shape in other.active_hitboxes():
			var points := CombatSim._closest_points(shape.start, shape.end, low, high)
			var reach: float = shape.radius + kit.decoy_radius
			if points[0].distance_squared_to(points[1]) <= reach * reach:
				return index
	for projectile in sim.projectiles:
		if projectile.owner == owner or sim.fighters[projectile.owner].team == fighter.team:
			continue
		var points := CombatSim._closest_points(projectile.position, projectile.position, low, high)
		var reach := projectile.radius + kit.decoy_radius
		if points[0].distance_squared_to(points[1]) <= reach * reach:
			sim.projectiles.erase(projectile)
			if projectile.thrown:
				sim._drop_pickup(projectile.weapon, projectile.ammo, projectile.position)
			return -1
	return -2


## The decoy bursts: every opponent in the blast radius is hit (or blocks) as by a projectile.
static func _burst(sim: CombatSim, owner: int) -> void:
	var fighter := sim.fighters[owner]
	var kit := kit_of(fighter)
	var at := fighter.specials.decoy_position
	sim.events.append(_decoy_event(sim, _E.DECOY_BURST, owner))
	fighter.specials.decoy_ticks = 0
	if kit.decoy_blast == null:
		return
	for index in sim.fighters.size():
		var target := sim.fighters[index]
		if index == owner or target.team == fighter.team or not target.can_be_hit():
			continue
		var body := target.hurtbox()
		var points := CombatSim._closest_points(at, at, body.start, body.end)
		var reach: float = kit.decoy_blast_radius + body.radius
		if points[0].distance_squared_to(points[1]) > reach * reach:
			continue
		if DodgeRules.evades(sim, target, kit.decoy_blast):
			continue
		var away := target.position - at
		away.y = 0.0
		var yaw := DetMath.atan2(-away.x, -away.z) if away.length_squared() > 0.0001 else fighter.facing_yaw
		var contact := {
			"type": _E.HIT, "attacker": owner, "target": index, "move": kit.decoy_blast,
			"yaw": yaw, "pitch": 0.0, "side": 1, "position": points[1], "dodge_punish": false,
		}
		if sim._blocks(target, at):
			contact.type = _E.BLOCK
			sim._apply_block(contact, true)
		else:
			sim._apply_hit(contact, true)
		if sim.round_over:
			return


static func _decoy_event(sim: CombatSim, type: CombatSim.EventType, index: int) -> Dictionary:
	var state := sim.fighters[index].specials
	return {"type": type, "fighter": index, "position": state.decoy_position, "yaw": state.decoy_yaw,
		"tick": sim.current_tick}


static func _deny(sim: CombatSim, index: int, slot: int) -> void:
	sim.events.append({
		"type": _E.SPECIAL_DENIED, "fighter": index, "position": sim.fighters[index].position,
		"slot": slot, "tick": sim.current_tick,
	})


# Momentum (Kael).

## Damage after the attacker's Momentum bonus.
static func boosted_damage(sim: CombatSim, attacker_index: int, damage: int) -> int:
	if attacker_index < 0:
		return damage
	var fighter := sim.fighters[attacker_index]
	var kit := kit_of(fighter)
	if kit == null or kit.mechanic != SpecialKit.Mechanic.MOMENTUM:
		return damage
	return damage * (100 + fighter.specials.momentum * kit.momentum_percent_per_hit) / 100


## A landed hit builds the attacker's Momentum.
static func on_hit_landed(sim: CombatSim, attacker_index: int) -> void:
	if attacker_index < 0:
		return
	var fighter := sim.fighters[attacker_index]
	var kit := kit_of(fighter)
	if kit != null and kit.mechanic == SpecialKit.Mechanic.MOMENTUM:
		fighter.specials.momentum = mini(fighter.specials.momentum + 1, kit.momentum_max_stacks)


## Taking damage loses all Momentum.
static func on_damaged(sim: CombatSim, target_index: int) -> void:
	sim.fighters[target_index].specials.momentum = 0


## Momentum bonus in percent, for the HUD.
static func momentum_percent(fighter: FighterState) -> int:
	var kit := kit_of(fighter)
	if kit == null or kit.mechanic != SpecialKit.Mechanic.MOMENTUM:
		return 0
	return fighter.specials.momentum * kit.momentum_percent_per_hit


# Round, hashing, AI.

static func reset_fighter(fighter: FighterState) -> void:
	fighter.specials.reset()


## Specials values for CombatSim.state_hash(); empty while no fighter has any, so older hashes hold.
## Kept out of FighterState.state_values() so golden digest rows keep a fixed width.
static func state_values(sim: CombatSim) -> Array:
	var values: Array = []
	var any := false
	for fighter in sim.fighters:
		var own := fighter.specials.state_values()
		any = any or not own.is_empty()
		values.append(own)
	return values if any else []


static func canonicalize(sim: CombatSim) -> void:
	for fighter in sim.fighters:
		var state := fighter.specials
		state.travel_direction = DetMath.canon(state.travel_direction)
		state.leap_from = DetMath.canon(state.leap_from)
		state.leap_to = DetMath.canon(state.leap_to)
		state.decoy_position = DetMath.canon(state.decoy_position)
		state.decoy_yaw += 0.0


## The key (1-3) of a special for role that the fighter can afford and that suits distance, or 0.
## Level gates come from each SpecialMove's ai_min_level.
static func ai_pick(sim: CombatSim, index: int, role: SpecialMove.AiRole, distance: float, level: int) -> int:
	var fighter := sim.fighters[index]
	var kit := kit_of(fighter)
	if kit == null:
		return 0
	for special in kit.specials:
		if special == null or special.ai_role != role or level < special.ai_min_level:
			continue
		if distance < special.ai_min_range or distance > special.ai_max_range:
			continue
		if fighter.ki < special.ki_cost() * _UNIT:
			continue
		return special.slot
	return 0
