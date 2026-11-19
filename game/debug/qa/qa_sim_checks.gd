class_name QaSimChecks
extends RefCounted
## Sim invariants checked after every tick of a soak match. Pure: reads a CombatSim
## (and optional MatchFlow), returns violations as {check, fighter, value, limit, detail}.

## Longest time (s) a fighter may stay in one state; states not listed may stay forever.
const STUCK_SECONDS := {
	FighterState.State.DASHING: 5.0,
	FighterState.State.VANISHING: 2.0,
	FighterState.State.CHARGING: 20.0,
	FighterState.State.GUARD_BROKEN: 5.0,
	FighterState.State.ATTACKING: 6.0,
	FighterState.State.HITSTUN: 6.0,
	FighterState.State.BLOCKSTUN: 4.0,
	FighterState.State.KNOCKDOWN: 5.0,
	FighterState.State.GRABBED: 4.0,
	FighterState.State.THROWING: 4.0,
	FighterState.State.KO_FALL: 15.0,
	FighterState.State.FALLING: 20.0,
}
## Entity caps: anything above means something leaks.
const MAX_PROJECTILES := 96
const MAX_PICKUPS := 12
const MAX_GADGETS := 12
## Arena box slack (m) for float error.
const BOUNDS_SLACK := 0.05
## Capsule penetration (m) that counts as fighters overlapping.
const OVERLAP_DEPTH := 0.10


static func check_tick(sim: CombatSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in sim.fighters.size():
		_check_fighter(sim, i, out)
	_check_entities(sim, out)
	return out


## Fighter pairs whose body capsules overlap deeper than OVERLAP_DEPTH (needs T-D29 pushboxes).
static func check_overlap(sim: CombatSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in sim.fighters.size():
		for j in range(i + 1, sim.fighters.size()):
			var a := sim.fighters[i]
			var b := sim.fighters[j]
			if not _solid(a) or not _solid(b) or a.grab_partner == j:
				continue
			var ha := a.hurtbox()
			var hb := b.hurtbox()
			var points := CombatSim._closest_points(ha.start, ha.end, hb.start, hb.end)
			var depth: float = ha.radius + hb.radius - points[0].distance_to(points[1])
			if depth > OVERLAP_DEPTH:
				out.append({"check": "fighter_overlap", "fighter": i, "value": depth, "limit": OVERLAP_DEPTH,
					"detail": "fighters %d and %d overlap %.2f m (%s vs %s)" % [i, j, depth,
					_state_name(a), _state_name(b)]})
	return out


## After a new round starts: everyone back at full health on the spawns, nothing left over.
static func check_round_reset(sim: CombatSim, spawns: Array[Vector3]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in sim.fighters.size():
		var f := sim.fighters[i]
		var full := f.stats.max_health * FighterState.METER_UNIT
		if f.health != full or f.is_ko_state():
			out.append(_v("round_reset", i, f.health, full, "fighter %d starts round with health %d/%d in %s" % [
				i, f.health, full, _state_name(f)]))
		if i < spawns.size() and Vector2(f.position.x - spawns[i].x, f.position.z - spawns[i].z).length() > 0.5:
			out.append(_v("round_reset", i, f.position.distance_to(spawns[i]), 0.5,
				"fighter %d starts round at %s, spawn %s" % [i, f.position.snapped(Vector3.ONE * 0.01), spawns[i]]))
	if not sim.projectiles.is_empty() or not sim.gadgets.is_empty():
		out.append(_v("round_reset", -1, sim.projectiles.size() + sim.gadgets.size(), 0,
			"projectiles/gadgets left over into the new round"))
	return out


static func _check_fighter(sim: CombatSim, i: int, out: Array[Dictionary]) -> void:
	var f := sim.fighters[i]
	if not _finite3(f.position) or not _finite3(f.velocity) or not is_finite(f.facing_yaw) \
			or not is_finite(f.aim_pitch):
		out.append(_v("nan", i, 0, 0, "non-finite fighter state: pos %s vel %s yaw %s" % [f.position, f.velocity, f.facing_yaw]))
		return
	var unit := FighterState.METER_UNIT
	var mt := sim.meter_tuning
	_range(out, i, "health", f.health, 0, f.stats.max_health * unit)
	_range(out, i, "grey_health", f.grey_health, 0, f.stats.max_health * unit)
	_range(out, i, "ki", f.ki, 0, mt.ki_max * unit)
	_range(out, i, "guard", f.guard, 0, f.stats.guard_max * unit)
	_range(out, i, "burst", f.burst, 0, mt.burst_max_stocks * mt.burst_stock_size * unit)
	if f.health + f.grey_health > f.stats.max_health * unit:
		out.append(_v("meter_range", i, f.health + f.grey_health, f.stats.max_health * unit,
			"health + grey health above max"))
	var limit: float = STUCK_SECONDS.get(f.state, INF)
	if f.state_ticks > limit * CombatSim.TICKS_PER_SECOND:
		out.append(_v("stuck_state", i, f.state_ticks / 60.0, limit,
			"%s for %.1f s (limit %.0f s)" % [_state_name(f), f.state_ticks / 60.0, limit]))
	var half := sim.tuning.arena_half_size + BOUNDS_SLACK
	var dx := absf(f.position.x - sim.arena_centre.x)
	var dz := absf(f.position.z - sim.arena_centre.y)
	var floor_y := f.stand_height - BOUNDS_SLACK
	if dx > half or dz > half or f.position.y > sim.tuning.arena_ceiling + BOUNDS_SLACK \
			or (f.position.y < floor_y and not f.is_ko_state()):
		out.append(_v("arena_bounds", i, maxf(dx, dz), half, "outside the arena at %s (stand %.2f, %s)" % [
			f.position.snapped(Vector3.ONE * 0.01), f.stand_height, _state_name(f)]))


static func _check_entities(sim: CombatSim, out: Array[Dictionary]) -> void:
	if sim.projectiles.size() > MAX_PROJECTILES:
		out.append(_v("entity_count", -1, sim.projectiles.size(), MAX_PROJECTILES, "projectiles"))
	if sim.pickups.size() > MAX_PICKUPS:
		out.append(_v("entity_count", -1, sim.pickups.size(), MAX_PICKUPS, "pickups"))
	if sim.gadgets.size() > MAX_GADGETS:
		out.append(_v("entity_count", -1, sim.gadgets.size(), MAX_GADGETS, "gadgets"))
	for p in sim.projectiles:
		if not _finite3(p.position) or not _finite3(p.velocity):
			out.append(_v("nan", -1, 0, 0, "non-finite projectile %d" % p.id))
	for p in sim.pickups:
		if not _finite3(p.position):
			out.append(_v("nan", -1, 0, 0, "non-finite pickup %d" % p.id))
	for g in sim.gadgets:
		if not _finite3(g.position):
			out.append(_v("nan", -1, 0, 0, "non-finite gadget %d" % g.id))


static func _range(out: Array[Dictionary], i: int, meter: String, value: int, low: int, high: int) -> void:
	if value < low or value > high:
		out.append(_v("meter_range", i, value, high, "%s %d outside [%d, %d]" % [meter, value, low, high]))


static func _solid(f: FighterState) -> bool:
	return f.state != FighterState.State.VANISHING and not f.is_ko_state()


static func _finite3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


static func _state_name(f: FighterState) -> String:
	return FighterState.State.find_key(f.state)


static func _v(check: String, fighter: int, value: Variant, limit: Variant, detail: String) -> Dictionary:
	return {"check": check, "fighter": fighter, "value": value, "limit": limit, "detail": detail}
