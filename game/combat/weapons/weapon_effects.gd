class_name WeaponEffects
extends RefCounted
## Weapon rules beyond plain shots (T-D26): repeater heat, the Ki Bow wall pin,
## the Heartstring Tether and its yank, and the Orbit Chakram disc. Pure sim
## code called by CombatSim; all state lives in FighterState and Projectile.

const _E := CombatSim.EventType
const _UNIT := FighterState.METER_UNIT
## States the tether does not drag (held, vanished, on the floor).
const _UNTETHERABLE: Array[FighterState.State] = [
	FighterState.State.GRABBED, FighterState.State.THROWING, FighterState.State.VANISHING,
]


## True while firing the repeater: its shot move is under way.
static func is_firing_repeater(fighter: FighterState) -> bool:
	return fighter.state == FighterState.State.ATTACKING and WeaponMoves.is_shot(fighter.move) \
		and fighter.held_weapon() == Weapon.Kind.STORM_REPEATER


## Heat rises while firing the repeater and cools otherwise; full heat overheats until cool.
static func count_heat(sim: CombatSim, index: int) -> void:
	var fighter := sim.fighters[index]
	if is_firing_repeater(fighter) and not fighter.overheated:
		fighter.heat = mini(fighter.heat + Weapon.REPEATER_HEAT_PER_TICK, Weapon.REPEATER_HEAT_MAX)
		if fighter.heat >= Weapon.REPEATER_HEAT_MAX:
			fighter.overheated = true
			sim.events.append(sim._weapon_event(_E.OVERHEAT, index, fighter.position,
				Weapon.Kind.STORM_REPEATER, -1))
		return
	fighter.heat = maxi(fighter.heat - Weapon.REPEATER_COOL_PER_TICK, 0)
	if fighter.heat == 0:
		fighter.overheated = false


## Movement while firing the repeater: steerable at 60% of normal speed.
static func move_while_firing(sim: CombatSim, fighter: FighterState, wish: Vector3) -> void:
	if not is_firing_repeater(fighter):
		return
	var airborne := fighter.position.y > sim.tuning.ground_height + 0.01
	var speed := sim.tuning.fly_speed if airborne else sim.tuning.ground_speed
	fighter.velocity = wish * speed * Weapon.REPEATER_MOVE_PERCENT / 100.0


## A level-3 arrow hit: a wall the target is knocked into within the window holds it there.
static func step_pins(sim: CombatSim) -> void:
	var edge := sim.tuning.arena_half_size - 0.05
	for index in sim.fighters.size():
		var fighter := sim.fighters[index]
		if fighter.pin_ticks <= 0 and not fighter.pinned:
			continue
		if fighter.state != FighterState.State.HITSTUN:
			fighter.pin_ticks = 0
			fighter.pinned = false
			continue
		fighter.pin_ticks = maxi(fighter.pin_ticks - 1, 0)
		var at_wall := absf(fighter.position.x) >= edge or absf(fighter.position.z) >= edge
		if not fighter.pinned and at_wall and fighter.pin_ticks > 0:
			fighter.pinned = true
			fighter.stun_ticks = fighter.state_ticks + Weapon.PIN_HOLD_TICKS
			sim.events.append(sim._weapon_event(_E.ARROW_PIN, index, fighter.position, Weapon.Kind.KI_BOW, -1))
		if fighter.pinned:
			fighter.velocity = Vector3.ZERO


## Ties shooter and target with a string as long as the distance between them.
static func tie(sim: CombatSim, shooter: int, target: int) -> void:
	untie(sim, shooter, false)
	untie(sim, target, false)
	var length := sim.fighters[shooter].position.distance_to(sim.fighters[target].position)
	for pair in [[shooter, target], [target, shooter]]:
		var fighter := sim.fighters[pair[0] as int]
		fighter.tether_partner = pair[1]
		fighter.tether_ticks = Weapon.TETHER_TICKS
		fighter.tether_length = length
	var tied := sim._weapon_event(_E.TETHER, shooter, sim.fighters[target].position,
		Weapon.Kind.HEARTSTRING_BOW, -1)
	tied["target"] = target
	tied["length"] = length
	sim.events.append(tied)


## Cuts the fighter's tether, if any, at both ends.
static func untie(sim: CombatSim, index: int, report: bool = true) -> void:
	var partner := sim.fighters[index].tether_partner
	if partner < 0:
		return
	for end in [index, partner]:
		var fighter := sim.fighters[end as int]
		fighter.tether_partner = -1
		fighter.tether_ticks = 0
		fighter.tether_length = 0.0
	if report:
		var cut := sim._weapon_event(_E.TETHER_END, index, sim.fighters[index].position,
			Weapon.Kind.HEARTSTRING_BOW, -1)
		cut["target"] = partner
		sim.events.append(cut)


## Counts tethers down and keeps tied fighters within the string's length, each giving way half.
static func step_tethers(sim: CombatSim) -> void:
	for index in sim.fighters.size():
		var fighter := sim.fighters[index]
		var partner := fighter.tether_partner
		if partner < index:
			continue
		var other := sim.fighters[partner]
		fighter.tether_ticks -= 1
		other.tether_ticks -= 1
		if fighter.tether_ticks <= 0 or fighter.is_knocked_out() or other.is_knocked_out() or sim.round_over:
			untie(sim, index)
			continue
		var between := other.position - fighter.position
		var excess := between.length() - fighter.tether_length
		if excess <= 0.0:
			continue
		var pull := between.normalized() * excess
		var movers := [fighter, other].filter(func(f: FighterState) -> bool: return f.state not in _UNTETHERABLE)
		if movers.size() == 2:
			fighter.position += pull * 0.5
			other.position -= pull * 0.5
		elif movers.size() == 1:
			(movers[0] as FighterState).position += pull if movers[0] == fighter else -pull


## RMB while tethered and free: yanks the partner in front of you, stunned for a follow-up. True if it did.
static func try_yank(sim: CombatSim, index: int) -> bool:
	var fighter := sim.fighters[index]
	var partner := fighter.tether_partner
	if partner < 0 or not sim._is_free(fighter) or not sim.is_buffered(index, FighterInput.Action.HEAVY):
		return false
	sim.consume_buffered(index, FighterInput.Action.HEAVY)
	var other := sim.fighters[partner]
	var toward := other.position - fighter.position
	var direction := toward.normalized() if toward.length_squared() > 0.0001 else Vector3.FORWARD
	var yanked := sim._weapon_event(_E.TETHER_YANK, index, other.position, Weapon.Kind.HEARTSTRING_BOW, -1)
	yanked["target"] = partner
	untie(sim, index, false)
	if other.state not in _UNTETHERABLE:
		sim._slide_to(other, fighter.position + direction * Weapon.YANK_DISTANCE, Weapon.YANK_TICKS)
		other.blocking = false
	sim.events.append(yanked)
	return true


## True while the fighter's Orbit Chakram disc is out.
static func disc_out(sim: CombatSim, index: int) -> bool:
	for projectile in sim.projectiles:
		if projectile.owner == index and projectile.effect == Weapon.Effect.DISC:
			return true
	return false


## Throws the Orbit Chakram's disc along the aim.
static func throw_disc(sim: CombatSim, index: int) -> void:
	var disc := sim._spawn_projectile(index, Weapon.Kind.ORBIT_CHAKRAM,
		sim._aim_direction(index) * Weapon.DISC_SPEED, 0.0, Weapon.DISC_RADIUS, Weapon.DISC_LIFETIME,
		WeaponMoves.disc_move(), Weapon.Effect.DISC)
	var thrown := sim._weapon_event(_E.FIRE, index, disc.position, Weapon.Kind.ORBIT_CHAKRAM, disc.id)
	thrown["count"] = 1
	sim.events.append(thrown)


## Turns the disc around after its way out and homes it back; true once it is caught.
static func steer_disc(sim: CombatSim, disc: Projectile) -> bool:
	if not disc.returning and disc.age >= Weapon.DISC_OUT_TICKS:
		disc.returning = true
		disc.hit_mask = 0
	if not disc.returning:
		return false
	var to_owner := sim.fighters[disc.owner].position - disc.position
	if to_owner.length() <= Weapon.DISC_CATCH_DISTANCE:
		sim.events.append(sim._weapon_event(_E.DISC_CATCH, disc.owner, disc.position,
			Weapon.Kind.ORBIT_CHAKRAM, disc.id))
		return true
	disc.velocity = to_owner.normalized() * Weapon.DISC_RETURN_SPEED
	return false
