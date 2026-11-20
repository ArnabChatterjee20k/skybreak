class_name PowerRules
extends RefCounted
## Powers and gadgets inside the sim (GAME_DESIGN §5.11, T-D26): picking them
## up, the timed buffs, Aegis, and every thrown or placed gadget. Pure sim
## code called by CombatSim; deterministic, all state in the state hash.

const _E := CombatSim.EventType
const _UNIT := FighterState.METER_UNIT
## States a gravity mine cannot pull.
const _UNPULLABLE: Array[FighterState.State] = [
	FighterState.State.GRABBED, FighterState.State.THROWING,
	FighterState.State.VANISHING, FighterState.State.KNOCKDOWN,
	FighterState.State.KO_FALL, FighterState.State.KO_DOWN,
]


## Takes a power drop: powers act at once, a gadget goes in the gadget slot
## (an older gadget falls out as a pickup).
static func pick_up(sim: CombatSim, index: int, pickup: WeaponPickup) -> void:
	var fighter := sim.fighters[index]
	var powers := fighter.powers
	match pickup.power:
		Power.Kind.OVERDRIVE_ORB:
			powers.overdrive_ticks = Power.OVERDRIVE_TICKS
		Power.Kind.BURST_SHARD:
			sim._add_burst(fighter, Power.BURST_SHARD_BURST * _UNIT)
		Power.Kind.AEGIS:
			powers.aegis = true
		Power.Kind.HASTE:
			powers.haste_ticks = Power.HASTE_TICKS
		_:
			if powers.gadget != Power.Kind.NONE:
				drop_power(sim, powers.gadget, fighter.position)
			powers.gadget = pickup.power
	sim.events.append(event(sim, _E.POWER_PICKUP, index, pickup.position, pickup.power, pickup.id))


## A power or gadget falling from at as a dropped pickup (10 s lifetime).
static func drop_power(sim: CombatSim, kind: Power.Kind, at: Vector3) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.id = sim._new_entity_id()
	pickup.power = kind
	pickup.position = sim._inside_arena(at)
	pickup.position.y = maxf(pickup.position.y, sim.floor_height() + sim.pickup_tuning.rest_height)
	pickup.phase = WeaponPickup.Phase.FALLING
	pickup.ticks_left = sim.pickup_tuning.dropped_lifetime_ticks
	pickup.dropped = true
	sim.pickups.append(pickup)
	return pickup


## Throws (bomb) or places (mine, decoy) the gadget in the slot.
static func use_gadget(sim: CombatSim, index: int) -> void:
	var fighter := sim.fighters[index]
	var gadget := Gadget.new()
	gadget.id = sim._new_entity_id()
	gadget.kind = fighter.powers.gadget
	gadget.owner = index
	fighter.powers.gadget = Power.Kind.NONE
	sim._update_facing(index)
	var aim := sim._aim_direction(index)
	match gadget.kind:
		Power.Kind.SPIKE_BOMB:
			gadget.position = sim._muzzle(fighter)
			gadget.velocity = aim * Power.BOMB_SPEED + Vector3.UP * 3.0
			gadget.phase = Gadget.Phase.FLYING
			gadget.ticks_left = Power.BOMB_FUSE_TICKS
		Power.Kind.GRAVITY_MINE:
			gadget.position = fighter.position + aim * Power.MINE_PLACE_DISTANCE
			gadget.phase = Gadget.Phase.ARMING
			gadget.ticks_left = Power.MINE_LIFETIME_TICKS
		Power.Kind.MIRROR_DECOY:
			var right := DetMath.rotate_y(Vector3.RIGHT, fighter.facing_yaw)
			gadget.position = fighter.position + right * Power.DECOY_SIDE_OFFSET
			gadget.phase = Gadget.Phase.MIRRORING
			gadget.ticks_left = Power.DECOY_TICKS
			gadget.facing_yaw = fighter.facing_yaw
			gadget.copied_move = fighter.powers.last_move
	sim.gadgets.append(gadget)
	fighter.begin_move(WeaponMoves.throw_move())
	sim.events.append(event(sim, _E.GADGET_THROW, index, gadget.position, gadget.kind, gadget.id))


## Aegis takes the hit instead: no damage, no stun. True if it did.
static func absorbs_hit(sim: CombatSim, contact: Dictionary, from_projectile: bool) -> bool:
	var target := sim.fighters[contact.target as int]
	if not target.powers.aegis:
		return false
	target.powers.aegis = false
	var attacker: int = contact.attacker
	if not from_projectile:
		sim.register_contact(attacker, true)
		sim._freeze(sim.fighters[attacker], target, 6)
	var shield := event(sim, _E.AEGIS_BREAK, contact.target, contact.position, Power.Kind.AEGIS, -1)
	shield["attacker"] = attacker
	shield["move_id"] = (contact.move as MoveData).id
	sim.events.append(shield)
	return true


## Movement speed percent from powers (Haste) for the fighter's current state.
static func speed_percent(fighter: FighterState) -> int:
	if fighter.powers.haste_ticks > 0 and fighter.state in [
			FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FALLING,
			FighterState.State.FLYING, FighterState.State.DASHING]:
		return Power.HASTE_PERCENT
	return 100


## Once per tick after projectiles: power timers, then every gadget.
static func step(sim: CombatSim) -> void:
	for index in sim.fighters.size():
		_count_powers(sim, index)
	var kept: Array[Gadget] = []
	for gadget in sim.gadgets:
		gadget.phase_ticks += 1
		gadget.ticks_left -= 1
		var alive := true
		match gadget.kind:
			Power.Kind.SPIKE_BOMB:
				alive = _step_bomb(sim, gadget)
			Power.Kind.GRAVITY_MINE:
				alive = _step_mine(sim, gadget)
			Power.Kind.MIRROR_DECOY:
				alive = _step_decoy(sim, gadget)
		if alive:
			kept.append(gadget)
	sim.gadgets = kept


## Knockout: timed powers and Aegis end at once and the held gadget is lost.
static func end_all(sim: CombatSim, index: int) -> void:
	var powers := sim.fighters[index].powers
	var at := sim.fighters[index].position
	if powers.overdrive_ticks > 0:
		sim.events.append(event(sim, _E.POWER_END, index, at, Power.Kind.OVERDRIVE_ORB, -1))
	if powers.haste_ticks > 0:
		sim.events.append(event(sim, _E.POWER_END, index, at, Power.Kind.HASTE, -1))
	powers.overdrive_ticks = 0
	powers.haste_ticks = 0
	powers.aegis = false
	powers.gadget = Power.Kind.NONE


static func _count_powers(sim: CombatSim, index: int) -> void:
	var fighter := sim.fighters[index]
	var powers := fighter.powers
	if fighter.move != null:
		powers.last_move = fighter.move.id
	if sim.round_over or fighter.hitstop_ticks > 0:
		return
	if powers.overdrive_ticks > 0:
		var rate := sim.meter_tuning.ki_passive_per_second
		if fighter.state == FighterState.State.CHARGING:
			rate = sim.meter_tuning.ki_charge_per_second
		sim._add_ki(fighter, rate * Power.OVERDRIVE_EXTRA_REGEN)
		powers.overdrive_ticks -= 1
		if powers.overdrive_ticks == 0:
			sim.events.append(event(sim, _E.POWER_END, index, fighter.position, Power.Kind.OVERDRIVE_ORB, -1))
	if powers.haste_ticks > 0:
		powers.haste_ticks -= 1
		if powers.haste_ticks == 0:
			sim.events.append(event(sim, _E.POWER_END, index, fighter.position, Power.Kind.HASTE, -1))


## Flies, lands and waits out the fuse; touching an opponent sets it off. False once it explodes.
static func _step_bomb(sim: CombatSim, bomb: Gadget) -> bool:
	if bomb.phase == Gadget.Phase.FLYING:
		var from := bomb.position
		bomb.velocity.y -= Power.BOMB_GRAVITY * CombatSim.TICK_SECONDS
		bomb.position = sim._inside_arena(bomb.position + bomb.velocity * CombatSim.TICK_SECONDS)
		var rest := sim.floor_height() + Power.BOMB_RADIUS
		if bomb.position.y <= rest:
			bomb.position.y = rest
			bomb.velocity = Vector3.ZERO
			bomb.phase = Gadget.Phase.RESTING
			bomb.phase_ticks = 0
		if not sim.round_over and _touches_opponent(sim, bomb, from):
			_explode(sim, bomb)
			return false
	if bomb.ticks_left <= 0:
		_explode(sim, bomb)
		return false
	return true


## The owner itself or a teammate: gadgets spare them (friendly fire is off).
static func _ally(sim: CombatSim, owner: int, index: int) -> bool:
	return index == owner or sim.fighters[index].team == sim.fighters[owner].team


static func _touches_opponent(sim: CombatSim, bomb: Gadget, from: Vector3) -> bool:
	for index in sim.fighters.size():
		var target := sim.fighters[index]
		if _ally(sim, bomb.owner, index) or not target.can_be_hit():
			continue
		var body := target.hurtbox()
		var points := CombatSim._closest_points(from, bomb.position, body.start, body.end)
		var reach: float = Power.BOMB_RADIUS + body.radius
		if points[0].distance_squared_to(points[1]) <= reach * reach:
			return true
	return false


## Launches every opponent in the blast through the normal hit and block rules.
static func _explode(sim: CombatSim, bomb: Gadget) -> void:
	sim.events.append(event(sim, _E.GADGET_EXPLODE, bomb.owner, bomb.position, bomb.kind, bomb.id))
	if sim.round_over:
		return
	for index in sim.fighters.size():
		var target := sim.fighters[index]
		if _ally(sim, bomb.owner, index) or not target.can_be_hit() or sim.round_over:
			continue
		var body := target.hurtbox()
		var points := CombatSim._closest_points(bomb.position, bomb.position, body.start, body.end)
		var reach: float = Power.BOMB_BLAST_RADIUS + body.radius
		if points[0].distance_squared_to(points[1]) > reach * reach:
			continue
		var away := target.position - bomb.position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = Vector3.FORWARD
		var contact := {
			"type": _E.HIT, "attacker": bomb.owner, "target": index, "move": Power.bomb_move(),
			"yaw": DetMath.atan2(-away.x, -away.z), "pitch": 0.0, "side": 1, "position": points[1],
		}
		if target.is_invincible_to(true) or DodgeRules.evades(sim, target, null):
			continue
		if sim._blocks(target, bomb.position):
			sim._apply_block(contact, true)
			continue
		if target.is_armored():
			contact.type = _E.ARMOR
		elif target.attack_phase() in [FighterState.AttackPhase.STARTUP, FighterState.AttackPhase.HOLD]:
			contact.type = _E.COUNTER
		sim._apply_hit(contact, true)


## Arms, waits for an opponent, then pulls everyone but its owner in. False when it is spent.
static func _step_mine(sim: CombatSim, mine: Gadget) -> bool:
	match mine.phase:
		Gadget.Phase.ARMING:
			if mine.phase_ticks >= Power.MINE_ARM_TICKS:
				mine.phase = Gadget.Phase.ARMED
				mine.phase_ticks = 0
		Gadget.Phase.ARMED:
			for index in sim.fighters.size():
				if not _ally(sim, mine.owner, index) and sim.fighters[index].can_be_hit() \
						and sim.fighters[index].position.distance_to(mine.position) <= Power.MINE_TRIGGER_RADIUS:
					mine.phase = Gadget.Phase.PULLING
					mine.phase_ticks = 0
					sim.events.append(event(sim, _E.MINE_TRIGGER, mine.owner, mine.position, mine.kind, mine.id))
					break
		Gadget.Phase.PULLING:
			if not sim.round_over:
				_pull(sim, mine)
			if mine.phase_ticks >= Power.MINE_PULL_TICKS:
				sim.events.append(event(sim, _E.GADGET_END, mine.owner, mine.position, mine.kind, mine.id))
				return false
			return true
	if mine.ticks_left <= 0:
		sim.events.append(event(sim, _E.GADGET_END, mine.owner, mine.position, mine.kind, mine.id))
		return false
	return true


static func _pull(sim: CombatSim, mine: Gadget) -> void:
	for index in sim.fighters.size():
		var fighter := sim.fighters[index]
		if _ally(sim, mine.owner, index) or fighter.state in _UNPULLABLE:
			continue
		var to_mine := mine.position - fighter.position
		var distance := to_mine.length()
		if distance > Power.MINE_PULL_RADIUS or distance < 0.5:
			continue
		var step := minf(Power.MINE_PULL_SPEED * CombatSim.TICK_SECONDS, distance - 0.5)
		fighter.position += to_mine / distance * step
		sim._clamp_to_arena(fighter)


## Copies its owner's motion and latest move; any opponent hit pops it. False when gone.
static func _step_decoy(sim: CombatSim, decoy: Gadget) -> bool:
	var owner := sim.fighters[decoy.owner]
	decoy.velocity = owner.velocity
	decoy.position = sim._inside_arena(decoy.position + owner.velocity * CombatSim.TICK_SECONDS)
	decoy.position.y = maxf(decoy.position.y, sim.tuning.ground_height)
	decoy.facing_yaw = owner.facing_yaw
	decoy.copied_move = owner.powers.last_move
	if _decoy_struck(sim, decoy):
		sim.events.append(event(sim, _E.DECOY_POP, decoy.owner, decoy.position, decoy.kind, decoy.id))
		return false
	if decoy.ticks_left <= 0:
		sim.events.append(event(sim, _E.GADGET_END, decoy.owner, decoy.position, decoy.kind, decoy.id))
		return false
	return true


## True if an opponent's hitbox or projectile touches the decoy; a projectile is used up.
static func _decoy_struck(sim: CombatSim, decoy: Gadget) -> bool:
	var half := Vector3.UP * (Power.DECOY_HEIGHT * 0.5 - Power.DECOY_RADIUS)
	var low := decoy.position - half
	var high := decoy.position + half
	for index in sim.fighters.size():
		if index == decoy.owner:
			continue
		for shape in sim.fighters[index].active_hitboxes():
			var points := CombatSim._closest_points(shape.start, shape.end, low, high)
			var reach: float = shape.radius + Power.DECOY_RADIUS
			if points[0].distance_squared_to(points[1]) <= reach * reach:
				return true
	for projectile in sim.projectiles:
		if projectile.owner == decoy.owner:
			continue
		var points := CombatSim._closest_points(projectile.position, projectile.position, low, high)
		var reach := projectile.radius + Power.DECOY_RADIUS
		if points[0].distance_squared_to(points[1]) <= reach * reach:
			sim.projectiles.erase(projectile)
			if projectile.thrown:
				sim._drop_pickup(projectile.weapon, projectile.ammo, projectile.position)
			return true
	return false


## An item event: {type, fighter, position, weapon (NONE), power (Power.Kind), id}.
static func event(sim: CombatSim, type: CombatSim.EventType, fighter_index: int, at: Vector3,
		power: Power.Kind, id: int) -> Dictionary:
	var made := sim._weapon_event(type, fighter_index, at, Weapon.Kind.NONE, id)
	made["power"] = power
	return made
