class_name Pushboxes
extends RefCounted
## Body collision (T-D29): fighters' vertical capsule pushboxes never overlap.
## CombatSim runs it each tick after movement and before hit detection. Pure
## and deterministic: pairs go in index order, and it keeps no state of its own.

## Overlap passes per tick; enough for a pile of four.
const ITERATIONS := 4
## Swept test step as a fraction of the pair's combined radius.
const SWEEP_STEP := 0.25
## Bisections that find the contact point of a fast approach.
const SWEEP_BISECTIONS := 8
## Overlap below this (m) counts as touching.
const EPSILON := 0.0005
## Mass of a fighter that is not moved (held in a grab).
const IMMOVABLE := 1.0e6


## One tick of body collision. before: positions at the tick start; solid_before:
## whether each fighter had a pushbox then; frozen: fighters in hitstop this tick.
static func resolve(sim: CombatSim, before: PackedVector3Array, solid_before: Array[bool],
		frozen: Array[bool]) -> void:
	_apply_pushback(sim, frozen)
	_stop_fast_approaches(sim, before, solid_before)
	for _pass in ITERATIONS:
		var moved := false
		for a in sim.fighters.size():
			for b in range(a + 1, sim.fighters.size()):
				if collide(sim, a, b) and _separate(sim, a, b):
					moved = true
		if not moved:
			return


## True if fighters a and b block each other: neither passes through, and they are not a grab pair.
static func collide(sim: CombatSim, a: int, b: int) -> bool:
	var first := sim.fighters[a]
	var second := sim.fighters[b]
	if first.ignores_pushbox() or second.ignores_pushbox():
		return false
	return first.grab_partner != b and second.grab_partner != a


## Distance between the two pushboxes' surfaces at the given positions; negative when overlapping.
static func gap(first: FighterState, first_at: Vector3, second: FighterState, second_at: Vector3) -> float:
	var one := first.pushbox_at(first_at)
	var two := second.pushbox_at(second_at)
	var points := CombatSim._closest_points(one.start, one.end, two.start, two.end)
	return points[0].distance_to(points[1]) - (one.radius + two.radius)


## Slides owed by hits and blocks; the part a wall stops moves the attacker back instead.
static func _apply_pushback(sim: CombatSim, frozen: Array[bool]) -> void:
	for index in sim.fighters.size():
		var fighter := sim.fighters[index]
		if fighter.pushback_ticks <= 0 or frozen[index]:
			continue
		var step := fighter.pushback_velocity * CombatSim.TICK_SECONDS
		var start := fighter.position
		fighter.position += step
		sim.settle(fighter)
		var direction := step.normalized()
		var lost := step.length() - (fighter.position - start).dot(direction)
		var attacker := fighter.pushback_from
		if lost > EPSILON and attacker >= 0 and not sim.fighters[attacker].ignores_pushbox():
			sim.fighters[attacker].position -= direction * lost
			sim.settle(sim.fighters[attacker])
		fighter.pushback_ticks -= 1
		if fighter.pushback_ticks <= 0:
			fighter.clear_pushback()


## A pair that closed in faster than the swept step this tick is put back
## where their paths first touched, so a rush or flight never tunnels through.
static func _stop_fast_approaches(sim: CombatSim, before: PackedVector3Array,
		solid_before: Array[bool]) -> void:
	for a in sim.fighters.size():
		for b in range(a + 1, sim.fighters.size()):
			if not solid_before[a] or not solid_before[b] or not collide(sim, a, b):
				continue
			var first := sim.fighters[a]
			var second := sim.fighters[b]
			var a0 := before[a]
			var b0 := before[b]
			var a1 := first.position
			var b1 := second.position
			var reach := first.stats.pushbox_radius + second.stats.pushbox_radius
			var closing := ((b1 - a1) - (b0 - a0)).length()
			if closing <= reach * SWEEP_STEP or gap(first, a0, second, b0) < 0.0:
				continue
			var steps := ceili(closing / (reach * SWEEP_STEP))
			var hit := -1
			for k in range(1, steps + 1):
				var t := float(k) / steps
				if gap(first, a0.lerp(a1, t), second, b0.lerp(b1, t)) < 0.0:
					hit = k
					break
			if hit < 0:
				continue
			var low := float(hit - 1) / steps
			var high := float(hit) / steps
			for _i in SWEEP_BISECTIONS:
				var middle := (low + high) * 0.5
				if gap(first, a0.lerp(a1, middle), second, b0.lerp(b1, middle)) < 0.0:
					high = middle
				else:
					low = middle
			first.position = a0.lerp(a1, low)
			second.position = b0.lerp(b1, low)
			sim.settle(first)
			sim.settle(second)
			var direction := _contact_direction(sim, first, second)
			_stop_closing(first, second, direction, _mass(first), _mass(second))


## Pushes one overlapping pair apart, the lighter one further. On the floor the
## push is planar; two airborne fighters can also part vertically. Whatever a
## wall stops goes to the other fighter. Returns true if anything moved.
static func _separate(sim: CombatSim, a: int, b: int) -> bool:
	var first := sim.fighters[a]
	var second := sim.fighters[b]
	var one := first.pushbox()
	var two := second.pushbox()
	var points := CombatSim._closest_points(one.start, one.end, two.start, two.end)
	var offset: Vector3 = points[1] - points[0]
	var reach: float = one.radius + two.radius
	if offset.length_squared() >= (reach - EPSILON) * (reach - EPSILON):
		return false
	var direction := _contact_direction(sim, first, second)
	var push := reach - offset.length()
	if _planar(sim, first, second):
		var height := absf(offset.y)
		push = sqrt(maxf(reach * reach - height * height, 0.0)) - Vector2(offset.x, offset.z).length()
	if push <= EPSILON:
		return false
	var first_mass := _mass(first)
	var second_mass := _mass(second)
	_stop_closing(first, second, direction, first_mass, second_mass)
	var first_share := push * second_mass / (first_mass + second_mass)
	var first_moved := _shift(sim, first, -direction * first_share)
	var second_moved := _shift(sim, second, direction * (push - first_moved))
	if second_moved < push - first_moved - EPSILON:
		# The second is pinned too: the first takes the rest, as far as it can go.
		_shift(sim, first, -direction * (push - first_moved - second_moved))
	return true


## Unit direction from first to second along which their bodies push: planar
## when either stands on the floor; in front of first if exactly on top.
static func _contact_direction(sim: CombatSim, first: FighterState, second: FighterState) -> Vector3:
	var one := first.pushbox()
	var two := second.pushbox()
	var points := CombatSim._closest_points(one.start, one.end, two.start, two.end)
	var direction: Vector3 = points[1] - points[0]
	if _planar(sim, first, second):
		direction.y = 0.0
	if direction.length_squared() < 1.0e-8:
		direction = Basis(Vector3.UP, first.facing_yaw) * Vector3.FORWARD
	return direction.normalized()


static func _planar(sim: CombatSim, first: FighterState, second: FighterState) -> bool:
	return sim.is_on_floor(first) or sim.is_on_floor(second)


## Bodies in contact stop closing in: the speed toward each other along
## direction is shared out by mass, like a dead stop between two bodies.
static func _stop_closing(first: FighterState, second: FighterState, direction: Vector3,
		first_mass: float, second_mass: float) -> void:
	var closing := (first.velocity - second.velocity).dot(direction)
	if closing <= 0.0:
		return
	var impulse := closing / (1.0 / first_mass + 1.0 / second_mass)
	first.velocity -= direction * (impulse / first_mass)
	second.velocity += direction * (impulse / second_mass)


## Moves the fighter by offset within the arena; returns how far it got along offset.
static func _shift(sim: CombatSim, fighter: FighterState, offset: Vector3) -> float:
	var length := offset.length()
	if length <= 0.0:
		return 0.0
	var start := fighter.position
	fighter.position += offset
	sim.settle(fighter)
	return (fighter.position - start).dot(offset / length)


static func _mass(fighter: FighterState) -> float:
	if fighter.state == FighterState.State.GRABBED or fighter.state == FighterState.State.THROWING:
		return IMMOVABLE
	return maxf(fighter.stats.mass, 0.01)
