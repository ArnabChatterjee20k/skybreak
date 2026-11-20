class_name DodgeRules
extends RefCounted
## Dodge rules (T-DEF2): start, travel, end, i-frames, anti-mash, perfect dodge and
## the grab punish of the recovery. Pure functions over CombatSim; all numbers live
## in CombatSim.dodge_tuning. Frames are the dodger's state_ticks while DASHING.

const _UNIT := FighterState.METER_UNIT
const _SINCE_CAP := 1 << 16
const _S := FighterState.State


## A dodge can start from a free state or out of a rush, never out of stun.
static func can_start_from(fighter: FighterState) -> bool:
	if fighter.state in [_S.IDLE, _S.MOVING, _S.FALLING, _S.FLYING]:
		return true
	return fighter.state == _S.DASHING and fighter.dash_kind == FighterState.DashKind.RUSH


## Starts the dodge the buffered Shift tap asks for. False when it is a rush
## (Shift toward the locked target), which the caller handles as a dash.
static func try_start(sim: CombatSim, index: int, input: FighterInput, wish: Vector3) -> bool:
	var fighter := sim.fighters[index]
	var direction := sim._steer_direction(fighter, input, wish)
	if direction != Vector3.ZERO and sim._points_at_target(index, direction):
		return false
	var kind := FighterDodge.Kind.SPOT if direction == Vector3.ZERO else FighterDodge.Kind.DIRECTIONAL
	var side := 1
	var planar := Vector3(direction.x, 0.0, direction.z)
	if fighter.lock_on_target >= 0 and planar.length_squared() > 0.0001:
		var forward := sim._attack_forward(index)
		var right := forward.cross(Vector3.UP)
		var across := planar.normalized().dot(right)
		if absf(across) >= absf(planar.normalized().dot(forward)):
			kind = FighterDodge.Kind.SIDESTEP
			side = 1 if across >= 0.0 else -1
	begin(sim, index, kind, direction, side)
	return true


## Puts the fighter into a dodge of kind, with chain, air and stale rules applied.
static func begin(sim: CombatSim, index: int, kind: FighterDodge.Kind, direction: Vector3, side: int) -> void:
	var fighter := sim.fighters[index]
	var tuning := sim.dodge_tuning
	var dodge := fighter.dodge
	if dodge.since_last < tuning.chain_window_ticks \
			or (dodge.chain >= 3 and dodge.since_last < tuning.stale_cooldown_ticks):
		dodge.chain += 1
	else:
		dodge.chain = 1
	var airborne := not sim._is_on_floor(fighter)
	var out_of_air := airborne and dodge.air_left <= 0
	if airborne:
		dodge.air_left = maxi(dodge.air_left - 1, 0)
	var startup := tuning.directional_startup_ticks
	var invuln := tuning.directional_invuln_ticks
	var recovery := tuning.directional_recovery_ticks
	if kind == FighterDodge.Kind.SPOT:
		startup = tuning.spot_startup_ticks
		invuln = tuning.spot_invuln_ticks
		recovery = tuning.spot_recovery_ticks
	var lost := 0
	if dodge.chain >= 2:
		recovery += tuning.chain_extra_recovery_ticks
		lost = tuning.chain_invuln_loss_ticks
	if dodge.chain >= 3 or out_of_air:
		lost = invuln
	dodge.kind = kind
	dodge.invuln_first = startup + 1
	dodge.invuln_last = startup + invuln - lost
	dodge.last_frame = startup + invuln + recovery
	dodge.travel_ticks = 0 if kind == FighterDodge.Kind.SPOT else startup + invuln
	dodge.side = side
	dodge.perfect = false
	dodge.punished = false
	sim.consume_buffered(index, FighterInput.Action.DASH)
	fighter.dash_kind = FighterState.DashKind.DODGE
	fighter.dash_direction = direction
	fighter.velocity = Vector3.ZERO
	fighter.enter_state(_S.DASHING)
	sim.events.append({
		"type": CombatSim.EventType.DODGE, "fighter": index, "position": fighter.position,
		"kind": kind, "side": side, "stale": dodge.invuln_last < dodge.invuln_first,
		"direction": direction,
	})


## Fraction of the travel done after ticks of n, eased out: 1 - (1 - t)^2.
static func eased(ticks: int, n: int) -> float:
	var left := 1.0 - float(mini(ticks, n)) / float(n)
	return 1.0 - left * left


## This tick's velocity: eased travel along the dodge, an arc around the target, or none.
static func move(sim: CombatSim, index: int) -> void:
	var fighter := sim.fighters[index]
	var dodge := fighter.dodge
	var tick := fighter.state_ticks
	fighter.velocity = Vector3.ZERO
	if tick >= dodge.travel_ticks:
		return
	var done := eased(tick, dodge.travel_ticks)
	var step := eased(tick + 1, dodge.travel_ticks) - done
	if dodge.kind == FighterDodge.Kind.DIRECTIONAL:
		fighter.velocity = fighter.dash_direction * (sim.dodge_tuning.directional_distance * step / CombatSim.TICK_SECONDS)
		return
	var target := fighter.lock_on_target
	if dodge.kind != FighterDodge.Kind.SIDESTEP or target < 0:
		return
	var centre := sim.fighters[target].position
	var offset := fighter.position - centre
	offset.y = 0.0
	var radius := offset.length()
	if radius < 0.0001:
		offset = -DetMath.forward(fighter.facing_yaw)
		radius = 1.0
	# Close in, the arc widens so it still covers the arc length at sidestep_min_radius.
	var arc := sim.dodge_tuning.sidestep_arc_degrees
	arc = clampf(arc * sim.dodge_tuning.sidestep_min_radius / radius, arc, sim.dodge_tuning.sidestep_max_arc_degrees)
	var angle := deg_to_rad(arc) * step * dodge.side
	var planar := DetMath.rotate_y(offset, angle)
	var destination := Vector3(centre.x + planar.x, fighter.position.y, centre.z + planar.z)
	fighter.velocity = (destination - fighter.position) / CombatSim.TICK_SECONDS


## Ends the dodge after its last frame; a Shift still held turns it into the flight-dash.
static func finish(sim: CombatSim, index: int, input: FighterInput) -> void:
	var fighter := sim.fighters[index]
	var dodge := fighter.dodge
	if fighter.state_ticks >= dodge.last_frame:
		fighter.velocity = Vector3.ZERO
		sim._end_dash(fighter)
	elif fighter.state_ticks >= sim.dodge_tuning.hold_to_dash_tick and input.is_held(FighterInput.Action.DASH):
		fighter.dash_kind = FighterState.DashKind.SUSTAINED
		if fighter.dash_direction == Vector3.ZERO:
			fighter.dash_direction = sim._neutral_dash_direction(index, input)
		dodge.invuln_last = mini(dodge.invuln_last, fighter.state_ticks)


## True while a flight-dash that grew out of a dodge still owes the dodge's frames.
static func owes_frames(fighter: FighterState) -> bool:
	return fighter.dodge.is_dodging() and fighter.state_ticks < fighter.dodge.last_frame


## Once per tick, after the fighter moved: ends finished dodges, counts the
## chain rest, refreshes air dodges and the perfect-dodge ki cooldown.
static func step(sim: CombatSim, fighter: FighterState) -> void:
	var dodge := fighter.dodge
	if dodge.kind != FighterDodge.Kind.NONE \
			and (fighter.state != _S.DASHING or fighter.state_ticks > dodge.last_frame):
		dodge.kind = FighterDodge.Kind.NONE
		dodge.since_last = 0
	elif dodge.kind == FighterDodge.Kind.NONE:
		dodge.since_last = mini(dodge.since_last + 1, _SINCE_CAP)
	dodge.ki_cooldown = maxi(dodge.ki_cooldown - 1, 0)
	if fighter.state != _S.GRABBED:
		dodge.punished = false
	if fighter.is_grounded() or fighter.state == _S.HITSTUN \
			or (dodge.kind == FighterDodge.Kind.NONE and dodge.since_last >= sim.dodge_tuning.air_refresh_ticks):
		dodge.air_left = sim.dodge_tuning.air_dodges


## A tracking move (Sweep) turns after a target that sidesteps it, up to the tuning's turn rate.
static func track_sidestep(sim: CombatSim, index: int) -> void:
	var attacker := sim.fighters[index]
	var target := attacker.lock_on_target
	if target < 0 or attacker.move == null or attacker.move.id not in sim.dodge_tuning.tracking_move_ids \
			or attacker.attack_phase() == FighterState.AttackPhase.RECOVERY:
		return
	var dodger := sim.fighters[target]
	if dodger.state != _S.DASHING or dodger.dodge.kind != FighterDodge.Kind.SIDESTEP:
		return
	var look := dodger.position - attacker.position
	if Vector2(look.x, look.z).length_squared() < 0.0001:
		return
	var turn := DetMath.angle_difference(attacker.facing_yaw, DetMath.atan2(-look.x, -look.z))
	var most := deg_to_rad(sim.dodge_tuning.tracking_turn_degrees_per_tick)
	attacker.facing_yaw = DetMath.wrap_angle(attacker.facing_yaw + clampf(turn, -most, most))


## True on an i-frame of a dodge, unless move tracks sidesteps and this is one.
static func evades(sim: CombatSim, target: FighterState, move_data: MoveData) -> bool:
	if not is_invulnerable(target):
		return false
	return not (move_data != null and target.dodge.kind == FighterDodge.Kind.SIDESTEP
		and move_data.id in sim.dodge_tuning.tracking_move_ids)


static func is_invulnerable(fighter: FighterState) -> bool:
	return fighter.state == _S.DASHING and fighter.dodge.is_invulnerable(fighter.state_ticks)


## In the frames after the i-frames: throws land as counter-hits.
static func in_recovery(fighter: FighterState) -> bool:
	return fighter.state == _S.DASHING and fighter.dodge.in_recovery(fighter.state_ticks)


## The evaded strike as a PERFECT_DODGE contact if it met the perfect window, else empty.
static func evaded_contact(sim: CombatSim, attacker_index: int, target_index: int, at: Vector3) -> Dictionary:
	var target := sim.fighters[target_index]
	if not target.dodge.in_perfect_window(target.state_ticks, sim.dodge_tuning.perfect_window_ticks):
		return {}
	var attacker := sim.fighters[attacker_index]
	return {
		"type": CombatSim.EventType.PERFECT_DODGE, "attacker": attacker_index, "target": target_index,
		"move": attacker.move, "yaw": attacker.facing_yaw, "pitch": attacker.aim_pitch,
		"side": attacker.aim_side, "position": at,
	}


## Pays out a perfect dodge once per dodge: shorter recovery, a fresh chain, ki
## (once per cooldown) and, for a strike or a ki shot or beam, a freeze on the attacker only.
static func apply_perfect(sim: CombatSim, contact: Dictionary, from_projectile: bool = false,
		freezes_attacker: bool = false) -> void:
	var target := sim.fighters[contact.target as int]
	var dodge := target.dodge
	var tuning := sim.dodge_tuning
	if dodge.perfect or not is_invulnerable(target):
		return
	dodge.perfect = true
	dodge.chain = 0
	dodge.last_frame = maxi(dodge.last_frame - tuning.perfect_recovery_cut_ticks, dodge.invuln_last)
	var paid := 0
	if dodge.ki_cooldown == 0:
		paid = tuning.perfect_ki
		sim._add_ki(target, paid * _UNIT)
		dodge.ki_cooldown = tuning.perfect_ki_cooldown_ticks
	var freeze := 0
	var attacker_index: int = contact.attacker
	if (not from_projectile or freezes_attacker) and attacker_index >= 0:
		freeze = tuning.perfect_attacker_freeze_ticks
		var attacker := sim.fighters[attacker_index]
		attacker.hitstop_ticks = maxi(attacker.hitstop_ticks, freeze)
	var event := sim._event(CombatSim.EventType.PERFECT_DODGE, contact, 0, freeze, MoveData.KnockbackType.NONE)
	event["ki"] = paid
	event["projectile"] = from_projectile
	sim.events.append(event)


## A projectile meeting a dodge's i-frames passes through it; in the perfect window it pays out
## (a ki shot also freezes its owner). True if this was the perfect dodge.
static func evade_projectile(sim: CombatSim, projectile: Projectile, target_index: int, at: Vector3) -> bool:
	projectile.hit_mask |= 1 << target_index
	var target := sim.fighters[target_index]
	if not target.dodge.in_perfect_window(target.state_ticks, sim.dodge_tuning.perfect_window_ticks):
		return false
	apply_perfect(sim, {
		"type": CombatSim.EventType.PERFECT_DODGE, "attacker": projectile.owner, "target": target_index,
		"move": projectile.move, "position": at,
	}, true, projectile.ki != KiRules.Shot.NONE)
	return true


## A beam tick meeting a dodge's i-frames is evaded; in the perfect window the beam's
## owner freezes, but the beam keeps going.
static func evade_beam(sim: CombatSim, owner_index: int, beam_move: MoveData, target_index: int, at: Vector3) -> void:
	var target := sim.fighters[target_index]
	if not target.dodge.in_perfect_window(target.state_ticks, sim.dodge_tuning.perfect_window_ticks):
		return
	apply_perfect(sim, {
		"type": CombatSim.EventType.PERFECT_DODGE, "attacker": owner_index, "target": target_index,
		"move": beam_move, "position": at,
	}, true, true)
