class_name KiRules
extends RefCounted
## Ki blasts, charged blasts, beams and beam clashes (GAME_DESIGN §5.8) as sim
## rules. CombatSim calls the hooks below; all state lives in fighters (move,
## move_tick, charge_ticks), sim.projectiles (Projectile.ki), sim.beams and
## sim.beam_clashes. Deterministic: integer ticks, DetMath only, sim rng only.

## What kind of ki shot a projectile is; NONE for weapon shots.
enum Shot { NONE, BLAST, CHARGED }

const DEFAULT_KIT_PATH := "res://game/combat/ki/kits/kael_ki_kit.tres"
const _KI_BLAST := FighterInput.Action.KI_BLAST
const _SPECIAL := FighterInput.Action.SPECIAL_1
const _ULTIMATE := FighterInput.Action.ULTIMATE
## Clash beat buttons: Q, E, F, R.
const BEAT_BUTTONS: Array[int] = [
	FighterInput.Action.KI_BLAST, FighterInput.Action.BLOCK,
	FighterInput.Action.GRAB, FighterInput.Action.CHARGE,
]
const _START_STATES: Array[FighterState.State] = [
	FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
]


static var _default_kit: KiKit


static func kit_of(fighter: FighterState) -> KiKit:
	var kit: KiKit = fighter.stats.ki_kit if fighter.stats else null
	if kit:
		return kit
	if _default_kit == null:
		_default_kit = load(DEFAULT_KIT_PATH) as KiKit
	return _default_kit


## True for a move this module runs (blast, charged blast, beams).
static func is_ki_move(fighter: FighterState, move: MoveData) -> bool:
	var kit := kit_of(fighter)
	return move != null and (move == kit.blast or move == kit.charged or kit.is_beam(move))


## Starts a buffered ki blast (Q), beam special (1) or beam ultimate (4) from a free state.
static func start(sim: CombatSim, index: int, input: FighterInput) -> void:
	var fighter := sim.fighters[index]
	if fighter.state not in _START_STATES or not sim._may_attack(fighter):
		return
	var kit := kit_of(fighter)
	if sim.is_buffered(index, _ULTIMATE) and kit.ultimate != null:
		if sim.try_spend_burst(index, kit.ultimate_burst_stocks):
			sim.consume_buffered(index, _ULTIMATE)
			_begin(sim, index, kit.ultimate)
			sim.events.append(_event(sim, CombatSim.EventType.BEAM_START, index, fighter.position, kit.ultimate))
		return
	if sim.is_buffered(index, _SPECIAL) and kit.beam != null:
		if sim._spend_ki(fighter, kit.beam.ki_cost):
			sim.consume_buffered(index, _SPECIAL)
			_begin(sim, index, kit.beam)
			sim.events.append(_event(sim, CombatSim.EventType.BEAM_START, index, fighter.position, kit.beam))
		return
	if sim.is_buffered(index, _KI_BLAST) and kit.blast != null and sim._spend_ki(fighter, kit.blast.ki_cost):
		sim.consume_buffered(index, _KI_BLAST)
		_begin(sim, index, kit.blast)
		# charge_ticks counts ticks Q stays held since the press (hold = charged blast).
		fighter.charge_ticks = 1 if input.is_held(_KI_BLAST) else 0


static func _begin(sim: CombatSim, index: int, move: MoveData) -> void:
	var fighter := sim.fighters[index]
	fighter.velocity = Vector3.ZERO
	sim._update_facing(index)
	sim._aim_at_target(index)
	fighter.begin_move(move)


## Moves a ki move on by one tick: hold-to-charge, firing, the beam's aim, its end.
static func advance(sim: CombatSim, index: int, input: FighterInput) -> void:
	var fighter := sim.fighters[index]
	if in_clash(sim, index):
		return # Locked head to head: the move waits for the clash.
	fighter.move_tick += 1
	var move := fighter.move
	var kit := kit_of(fighter)
	if fighter.move_tick >= fighter.move_total_ticks():
		sim._enter_free_state(fighter)
		return
	if move == kit.blast:
		if input.is_held(_KI_BLAST) and fighter.charge_ticks == fighter.move_tick:
			fighter.charge_ticks += 1
		if fighter.move_tick == move.startup_ticks:
			if fighter.charge_ticks > move.startup_ticks and kit.charged != null \
					and sim._spend_ki(fighter, maxi(kit.charged.ki_cost - move.ki_cost, 0)):
				# Held through the tap's startup: becomes the charged blast, startup counted from the press.
				var held := fighter.move_tick
				fighter.begin_move(kit.charged)
				fighter.move_tick = held
				fighter.charge_ticks = held
				sim.events.append(_event(sim, CombatSim.EventType.KI_CHARGE, index, sim._muzzle(fighter), kit.charged))
			else:
				_fire_blast(sim, index, Shot.BLAST)
	elif move == kit.charged:
		if input.is_held(_KI_BLAST) and fighter.charge_ticks == fighter.move_tick:
			fighter.charge_ticks += 1
		if fighter.move_tick == move.startup_ticks:
			_fire_blast(sim, index, Shot.CHARGED)
	elif kit.is_beam(move):
		if fighter.move_tick < move.startup_ticks - sim.ki_tuning.beam_aim_lock_ticks:
			# The tell tracks the target; the last beam_aim_lock_ticks of startup are committed.
			sim._update_facing(index)
			sim._aim_at_target(index)
		if fighter.move_tick == move.startup_ticks:
			_fire_beam(sim, index, move)


static func _fire_blast(sim: CombatSim, index: int, shot: Shot) -> void:
	var fighter := sim.fighters[index]
	var kit := kit_of(fighter)
	var charged := shot == Shot.CHARGED
	var move := kit.charged if charged else kit.blast
	var speed := kit.charged_speed if charged else kit.blast_speed
	var reach := kit.charged_range if charged else kit.blast_range
	var lifetime := ceili(reach / speed * CombatSim.TICKS_PER_SECOND)
	var projectile := sim._spawn_projectile(index, Weapon.Kind.NONE, sim._aim_direction(index) * speed, 0.0,
		kit.charged_radius if charged else kit.blast_radius, lifetime, move, Weapon.Effect.NONE)
	projectile.ki = shot
	if not charged and kit.blast_homing > 0.0:
		projectile.homing_target = fighter.lock_on_target
		projectile.homing_rate = kit.blast_homing
	var fired := _event(sim, CombatSim.EventType.KI_FIRE, index, projectile.position, move)
	fired["id"] = projectile.id
	fired["shot"] = shot
	sim.events.append(fired)


static func _fire_beam(sim: CombatSim, index: int, move: MoveData) -> void:
	var fighter := sim.fighters[index]
	var kit := kit_of(fighter)
	var beam := KiBeam.new()
	beam.id = sim._new_entity_id()
	beam.owner = index
	beam.move = move
	beam.origin = sim._muzzle(fighter)
	beam.direction = (fighter.aim_basis() * Vector3.FORWARD).normalized()
	beam.max_length = kit.range_for(move)
	beam.speed = kit.beam_speed
	beam.radius = kit.radius_for(move)
	if move == kit.beam and kit.beam_split_angle > 0.0:
		beam.split_angle = kit.beam_split_angle
		beam.split_radius = beam.radius * kit.beam_split_radius_share
	sim.beams.append(beam)
	var fired := _event(sim, CombatSim.EventType.BEAM_FIRE, index, beam.origin, move)
	fired["id"] = beam.id
	fired["direction"] = beam.direction
	sim.events.append(fired)


# Projectiles.

## Turns a homing blast toward its target by at most homing_rate this tick.
static func steer(sim: CombatSim, projectile: Projectile) -> void:
	var target := projectile.homing_target
	if projectile.ki != Shot.BLAST or projectile.homing_rate <= 0.0 or target < 0 \
			or target >= sim.fighters.size() or sim.fighters[target].is_knocked_out():
		return
	var speed := projectile.velocity.length()
	var wanted := sim.fighters[target].position - projectile.position
	if speed < 0.001 or wanted.length_squared() < 0.0001:
		return
	var current := projectile.velocity / speed
	wanted = wanted.normalized()
	var angle := DetMath.acos(clampf(current.dot(wanted), -1.0, 1.0))
	var most := projectile.homing_rate * CombatSim.TICK_SECONDS
	if angle <= most:
		projectile.velocity = wanted * speed
		return
	var axis := current.cross(wanted)
	if axis.length_squared() < 0.000001:
		return
	projectile.velocity = (DetMath.axis_angle(axis.normalized(), most) * current).normalized() * speed


## A reflected homing blast hunts the fighter who fired it.
static func reflected(projectile: Projectile, from_owner: int) -> void:
	if projectile.ki != Shot.NONE and projectile.homing_rate > 0.0:
		projectile.homing_target = from_owner


## True if the target's dash soaks up this tap blast (dash armour, §5.8); spends the ki.
static func absorbs(sim: CombatSim, target_index: int, projectile: Projectile, at: Vector3) -> bool:
	var target := sim.fighters[target_index]
	# Rush and flight-dash armour; a dodge (T-DEF2) evades with its i-frames instead.
	if projectile.ki != Shot.BLAST or target.state != FighterState.State.DASHING \
			or target.dash_kind == FighterState.DashKind.DODGE:
		return false
	var speed := projectile.velocity.length()
	if speed < 0.001 or target.dash_direction.dot(-projectile.velocity / speed) < sim.ki_tuning.dash_absorb_facing:
		return false
	if not sim._spend_ki(target, sim.ki_tuning.dash_absorb_ki_cost):
		return false
	var soaked := _event(sim, CombatSim.EventType.KI_ABSORB, target_index, at, projectile.move)
	soaked["id"] = projectile.id
	sim.events.append(soaked)
	return true


# Beams and clashes, once per tick after projectiles.

static func step(sim: CombatSim) -> void:
	_end_finished_beams(sim)
	if sim.round_over:
		return
	_step_clashes(sim)
	_find_clashes(sim)
	for beam in sim.beams:
		if beam.clash_id >= 0:
			continue
		beam.age += 1
		beam.length = minf(beam.length + beam.speed * CombatSim.TICK_SECONDS, beam.max_length)
		_beam_eats_blasts(sim, beam)
		_beam_contacts(sim, beam)


static func in_clash(sim: CombatSim, index: int) -> bool:
	for clash in sim.beam_clashes:
		if clash.side_of(index) >= 0:
			return true
	return false


## The clash fighter_index is in, or null.
static func clash_of(sim: CombatSim, index: int) -> BeamClash:
	for clash in sim.beam_clashes:
		if clash.side_of(index) >= 0:
			return clash
	return null


static func beam_of(sim: CombatSim, index: int) -> KiBeam:
	for beam in sim.beams:
		if beam.owner == index:
			return beam
	return null


## Beams whose owner left the move or reached recovery end; a whiff adds recovery.
static func _end_finished_beams(sim: CombatSim) -> void:
	var kept: Array[KiBeam] = []
	for beam in sim.beams:
		var owner := sim.fighters[beam.owner]
		var firing := owner.state == FighterState.State.ATTACKING and owner.move == beam.move \
			and owner.move_tick < beam.move.recovery_start_tick()
		if firing and not sim.round_over:
			kept.append(beam)
			continue
		if beam.clash_id >= 0:
			_drop_clash(sim, beam.clash_id)
		if not beam.touched and owner.state == FighterState.State.ATTACKING and owner.move == beam.move:
			owner.extra_recovery_ticks += sim.ki_tuning.beam_whiff_extra_recovery_ticks
		var ended := _event(sim, CombatSim.EventType.BEAM_END, beam.owner, beam.head(), beam.move)
		ended["id"] = beam.id
		ended["whiff"] = not beam.touched
		sim.events.append(ended)
	sim.beams = kept


static func _beam_eats_blasts(sim: CombatSim, beam: KiBeam) -> void:
	var team := sim.fighters[beam.owner].team
	var kept: Array[Projectile] = []
	for projectile in sim.projectiles:
		var eaten := false
		if projectile.ki != Shot.NONE and projectile.owner >= 0 and sim.fighters[projectile.owner].team != team:
			for ray in beam.rays():
				var points := CombatSim._closest_points(ray[0], ray[1], projectile.position, projectile.position)
				if points[0].distance_to(points[1]) <= beam.radius + projectile.radius:
					eaten = true
					break
		if eaten:
			var gone := _event(sim, CombatSim.EventType.KI_ABSORB, -1, projectile.position, projectile.move)
			gone["id"] = projectile.id
			sim.events.append(gone)
		else:
			kept.append(projectile)
	sim.projectiles = kept


static func _beam_contacts(sim: CombatSim, beam: KiBeam) -> void:
	var owner := sim.fighters[beam.owner]
	# Every body the rays touch, nearest first: the first one hit or guarding stops the beam.
	var touched: Array[Dictionary] = []
	for target_index in sim.fighters.size():
		var target := sim.fighters[target_index]
		if target_index == beam.owner or target.team == owner.team or not target.can_be_hit() \
				or (beam.hit_mask & (1 << target_index)) != 0:
			continue
		var body := target.hurtbox()
		var rays := beam.rays()
		for r in rays.size():
			var reach: float = (beam.radius if r == 0 else beam.split_radius) + float(body.radius)
			var points := CombatSim._closest_points(rays[r][0], rays[r][1], body.start, body.end)
			if points[0].distance_squared_to(points[1]) <= reach * reach:
				if not target.is_invincible_to(target.is_upper_body(points[0])) \
						and not DodgeRules.evades(sim, target, beam.move):
					touched.append({"target": target_index, "points": points, "radius": body.radius,
						"along": beam.origin.distance_to(points[0])})
				break
	touched.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.along < b.along or (a.along == b.along and a.target < b.target))
	var blocking_any := false
	for found in touched:
		var target_index: int = found.target
		var target := sim.fighters[target_index]
		var points: PackedVector3Array = found.points
		var radius: float = found.radius
		var contact := {
			"type": CombatSim.EventType.HIT, "attacker": beam.owner, "target": target_index, "move": beam.move,
			"yaw": DetMath.atan2(-beam.direction.x, -beam.direction.z), "pitch": 0.0, "side": 1,
			"position": points[1] + (points[0] - points[1]).limit_length(radius),
		}
		beam.touched = true
		beam.length = minf(beam.length, float(found.along) + radius)
		if sim._blocks(target, beam.origin):
			blocking_any = true
			_push_blocker(sim, beam, target_index, contact)
			break
		if target.is_armored():
			contact.type = CombatSim.EventType.ARMOR
		elif target.attack_phase() in [FighterState.AttackPhase.STARTUP, FighterState.AttackPhase.HOLD]:
			contact.type = CombatSim.EventType.COUNTER
		beam.hit_mask |= 1 << target_index
		# The body takes the beam: it ends there and the target is blown out of it.
		beam.max_length = beam.length
		sim._apply_hit(contact, true)
		break
	beam.block_ticks = beam.block_ticks + 1 if blocking_any else 0


## A blocked beam grinds the guard down, chips and shoves the blocker along it.
static func _push_blocker(sim: CombatSim, beam: KiBeam, target_index: int, contact: Dictionary) -> void:
	var tuning := sim.ki_tuning
	var target := sim.fighters[target_index]
	sim.apply_guard_damage(target_index, tuning.beam_block_guard_per_tick)
	if target.state == FighterState.State.GUARD_BROKEN:
		var broken := sim._event(CombatSim.EventType.GUARD_BREAK, contact, 0, sim.hit_tuning.guard_break_hitstop_ticks,
			MoveData.KnockbackType.NONE)
		sim.events.append(broken)
		return
	sim.apply_damage(target_index, beam.owner, tuning.beam_block_chip_per_tick)
	if target.is_knocked_out():
		sim.events.append(sim._event(CombatSim.EventType.KO, contact, tuning.beam_block_chip_per_tick,
			sim.hit_tuning.knockout_hitstop_ticks, MoveData.KnockbackType.NONE))
		return
	var stunned := target.state == FighterState.State.BLOCKSTUN
	if not stunned:
		sim._enter_stun(target, FighterState.State.BLOCKSTUN, tuning.beam_block_stun_ticks)
	else:
		target.stun_ticks = target.state_ticks + tuning.beam_block_stun_ticks
	var along := Vector3(beam.direction.x, 0.0, beam.direction.z)
	target.velocity = along.normalized() * tuning.beam_block_push_speed if along.length_squared() > 0.0001 \
		else Vector3.ZERO
	if beam.block_ticks % tuning.beam_block_event_every == 0:
		sim.events.append(sim._event(CombatSim.EventType.BLOCK, contact, 0, 0, MoveData.KnockbackType.NONE))


## Two opposing beams whose rays meet lock into a clash.
static func _find_clashes(sim: CombatSim) -> void:
	for a in sim.beams.size():
		var first := sim.beams[a]
		if first.clash_id >= 0:
			continue
		for b in range(a + 1, sim.beams.size()):
			var second := sim.beams[b]
			if second.clash_id >= 0 or sim.fighters[first.owner].team == sim.fighters[second.owner].team:
				continue
			var points := CombatSim._closest_points(first.origin, first.head(), second.origin, second.head())
			if points[0].distance_to(points[1]) > first.radius + second.radius:
				continue
			_start_clash(sim, first, second, (points[0] + points[1]) * 0.5)
			break


static func _start_clash(sim: CombatSim, first: KiBeam, second: KiBeam, at: Vector3) -> void:
	var tuning := sim.ki_tuning
	var clash := BeamClash.new()
	clash.id = sim._new_entity_id()
	clash.beams = PackedInt32Array([first.id, second.id])
	clash.owners = PackedInt32Array([first.owner, second.owner])
	clash.start_tick = sim.current_tick
	clash.centre = at
	var across := second.origin - first.origin
	clash.axis = across.normalized() if across.length_squared() > 0.0001 else first.direction
	clash.push = (first.move.damage - second.move.damage) / 100 * tuning.clash_push_per_100_damage
	for k in tuning.clash_beats:
		clash.beat_ticks.append(sim.current_tick + tuning.clash_lead_ticks + k * tuning.clash_beat_ticks)
		clash.beat_buttons.append(BEAT_BUTTONS[sim.rng.randi_range(0, BEAT_BUTTONS.size() - 1)])
	clash.end_tick = clash.beat_ticks[clash.beat_ticks.size() - 1] + tuning.clash_window_ticks \
		+ tuning.clash_settle_ticks
	first.clash_id = clash.id
	second.clash_id = clash.id
	first.touched = true
	second.touched = true
	sim.beam_clashes.append(clash)
	_fit_heads(sim, clash)
	var event := _event(sim, CombatSim.EventType.BEAM_CLASH, first.owner, at, first.move)
	event["target"] = second.owner
	event["id"] = clash.id
	sim.events.append(event)


static func _step_clashes(sim: CombatSim) -> void:
	for clash in sim.beam_clashes.duplicate():
		for side in 2:
			_judge_presses(sim, clash, side)
		clash.push = clampi(clash.push, -100, 100)
		if sim.current_tick >= clash.end_tick:
			_resolve_clash(sim, clash)
		else:
			_fit_heads(sim, clash)


## Scores this tick's presses of one side against the beats; mashing gives ground.
static func _judge_presses(sim: CombatSim, clash: BeamClash, side: int) -> void:
	var tuning := sim.ki_tuning
	var index := clash.owners[side]
	var fighter := sim.fighters[index]
	var sign := 1 if side == 0 else -1
	var now := sim.current_tick
	if fighter.hitstop_ticks > 0:
		return
	for button in BEAT_BUTTONS:
		if fighter.press_ages[CombatSim._action_index(button)] != 0 or (fighter.consumed_presses & button) != 0:
			continue
		# A beat press acts only here, never later as a buffered blast, block or grab.
		fighter.consumed_presses |= button
		var beat := -1
		for k in clash.beat_ticks.size():
			if absi(now - clash.beat_ticks[k]) <= tuning.clash_window_ticks and (clash.judged[side] & (1 << k)) == 0:
				beat = k
				break
		var gain := tuning.clash_push_miss
		if beat >= 0:
			clash.judged[side] |= 1 << beat
			if clash.beat_buttons[beat] == button:
				var close := absi(now - clash.beat_ticks[beat]) <= tuning.clash_perfect_ticks
				gain = tuning.clash_push_perfect if close else tuning.clash_push_good
				clash.good[side] += 1
		clash.push += gain * sign
		var event := _event(sim, CombatSim.EventType.CLASH_BEAT, index, clash.point(tuning.clash_metres_per_push), null)
		event["id"] = clash.id
		event["beat"] = beat
		event["gain"] = gain
		sim.events.append(event)
	# Spending ki mid-clash adds push.
	if fighter.press_ages[CombatSim._action_index(_SPECIAL)] == 0 and clash.spends[side] < tuning.clash_ki_spends \
			and (fighter.consumed_presses & _SPECIAL) == 0 and sim._spend_ki(fighter, tuning.clash_ki_cost):
		fighter.consumed_presses |= _SPECIAL
		clash.spends[side] += 1
		clash.push += tuning.clash_ki_push * sign


## Winner's beam hits the loser for full damage and the winner gains burst; a tie cancels both.
static func _resolve_clash(sim: CombatSim, clash: BeamClash) -> void:
	var tuning := sim.ki_tuning
	var winner_side := 0 if clash.push > 0 else (1 if clash.push < 0 else -1)
	var at := clash.point(tuning.clash_metres_per_push)
	var event := _event(sim, CombatSim.EventType.CLASH_END, clash.owners[0], at, null)
	event["id"] = clash.id
	event["winner"] = clash.owners[winner_side] if winner_side >= 0 else -1
	event["push"] = clash.push
	sim.events.append(event)
	sim.beam_clashes.erase(clash)
	var winner_beam: KiBeam = null
	for beam in sim.beams:
		if beam.clash_id == clash.id:
			beam.clash_id = -1
			if winner_side >= 0 and beam.owner == clash.owners[winner_side]:
				winner_beam = beam
	if winner_side < 0:
		# Even: both beams burst at the meeting point and both fighters recover.
		for side in 2:
			_end_move(sim, clash.owners[side])
		return
	var loser_index := clash.owners[1 - winner_side]
	_end_move(sim, loser_index)
	sim._add_burst(sim.fighters[clash.owners[winner_side]], tuning.clash_win_burst * CombatSim._UNIT)
	if winner_beam == null:
		return
	var loser := sim.fighters[loser_index]
	var contact := {
		"type": CombatSim.EventType.HIT, "attacker": winner_beam.owner, "target": loser_index,
		"move": winner_beam.move, "yaw": DetMath.atan2(-winner_beam.direction.x, -winner_beam.direction.z),
		"pitch": 0.0, "side": 1, "position": loser.position,
	}
	winner_beam.hit_mask |= 1 << loser_index
	winner_beam.max_length = minf(winner_beam.max_length,
		winner_beam.origin.distance_to(loser.position) + loser.stats.hurtbox_radius)
	sim._apply_hit(contact, true)


## Puts a fighter's beam move into its recovery (its beam ends next tick).
static func _end_move(sim: CombatSim, index: int) -> void:
	var fighter := sim.fighters[index]
	if fighter.state == FighterState.State.ATTACKING and fighter.move != null and kit_of(fighter).is_beam(fighter.move):
		fighter.move_tick = maxi(fighter.move_tick, fighter.move.recovery_start_tick())


## A clash whose beam ended: the other beam is free again.
static func _drop_clash(sim: CombatSim, clash_id: int) -> void:
	for clash in sim.beam_clashes.duplicate():
		if clash.id == clash_id:
			sim.beam_clashes.erase(clash)
	for beam in sim.beams:
		if beam.clash_id == clash_id:
			beam.clash_id = -1


## Beam heads end at the meeting point.
static func _fit_heads(sim: CombatSim, clash: BeamClash) -> void:
	var at := clash.point(sim.ki_tuning.clash_metres_per_push)
	for beam in sim.beams:
		if beam.clash_id == clash.id:
			beam.length = clampf((at - beam.origin).dot(beam.direction), 0.0, beam.max_length)


# Bookkeeping.

static func reset(sim: CombatSim) -> void:
	sim.beams = []
	sim.beam_clashes = []


static func canonicalize(sim: CombatSim) -> void:
	for beam in sim.beams:
		beam.origin = DetMath.canon(beam.origin)
		beam.direction = DetMath.canon(beam.direction)
		beam.length += 0.0
	for clash in sim.beam_clashes:
		clash.centre = DetMath.canon(clash.centre)
		clash.axis = DetMath.canon(clash.axis)


## Ki values for CombatSim.state_hash(); empty while nothing ki is alive, so older hashes hold.
static func state_values(sim: CombatSim) -> Array:
	var values: Array = []
	for beam in sim.beams:
		values.append_array(beam.state_values())
	for clash in sim.beam_clashes:
		values.append_array(clash.state_values())
	return values


static func _event(sim: CombatSim, type: CombatSim.EventType, fighter_index: int, at: Vector3,
		move: MoveData) -> Dictionary:
	return {"type": type, "fighter": fighter_index, "attacker": fighter_index, "position": at,
		"move_id": move.id if move else &"", "tick": sim.current_tick}
