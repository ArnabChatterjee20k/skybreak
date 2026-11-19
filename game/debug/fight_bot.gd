class_name FightBot
extends RefCounted
## Scripted-but-reactive bot pair for progress videos (not the game AI, T-D23):
## grabs weapons when unarmed, shoots from mid range with ranged ones, rushes in
## and strings attacks with melee or fists, blocks some strings, push-blocks.

const A := FighterInput.Action
const ROLE_TICKS := 300

var sim: CombatSim
var _previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
var _rng := RandomNumberGenerator.new()
var _combo_start: Array[int] = [-1000, -1000]
var _combo_count: Array[int] = [0, 0]


func _init(combat_sim: CombatSim, seed_value: int = 7) -> void:
	sim = combat_sim
	_rng.seed = seed_value


func input_for(index: int, tick: int) -> FighterInput:
	var me: FighterState = sim.fighters[index]
	var them: FighterState = sim.fighters[1 - index]
	var held := 0
	var move := Vector2.ZERO
	var vertical := 0
	var gap := me.position.distance_to(them.position)
	var kind := me.held_weapon()
	var ranged := Weapon.is_ranged(kind)
	var pickup := _wanted_pickup(index)
	if pickup != null:
		# Fly to the pickup (lock-on movement is relative to the opponent).
		var to := pickup.position - me.position
		move = _local_move(me, them, Vector3(to.x, 0, to.z))
		vertical = signi(int(signf(to.y))) if absf(to.y) > 0.8 else 0
		if Vector3(to.x, 0, to.z).length() > 12.0 and tick % 50 < 2:
			held |= A.DASH
		if to.length() < 2.0 and tick % 4 < 2:
			held |= A.PICKUP
	elif ranged and me.ammo[me.active_slot] > 0:
		# Keep 10-18 m away and hold fire.
		if gap < 10.0:
			move = Vector2(0.6, -1)
		elif gap > 18.0:
			move = Vector2(0.4, 1)
		else:
			move = Vector2(1 if (tick / 90) % 2 == 0 else -1, 0)
		if tick % 14 < 2 or kind == Weapon.Kind.STORM_REPEATER:
			held |= A.LIGHT
	else:
		held |= _melee(index, tick, me, them, gap)
		if gap > 1.5:
			move = Vector2(0, 1)
			if gap > 14.0 and tick % 40 < 2:
				held |= A.DASH
	if pickup == null:
		var dy := them.position.y - me.position.y
		if absf(dy) > 0.5:
			vertical = signi(int(signf(dy)))
	var input := FighterInput.from_held(held, _previous[index])
	input.move = move
	input.vertical = vertical
	_previous[index] = input
	return input


## Light strings, sometimes a launcher; defends some of the opponent's strings.
func _melee(index: int, tick: int, me: FighterState, them: FighterState, gap: float) -> int:
	var held := 0
	var attacker := (tick / ROLE_TICKS) % 2 == index or them.held_weapon() != Weapon.Kind.NONE
	if not attacker:
		if gap < 4.0 and _combo_count[1 - index] % 3 == 1:
			held |= A.BLOCK
			if me.state == FighterState.State.BLOCKSTUN and _rng.randf() < 0.1:
				held |= A.HEAVY
			return held
	if gap > 1.6:
		return held
	var phase := tick - _combo_start[index]
	if phase > 110:
		_combo_start[index] = tick
		_combo_count[index] += 1
		phase = 0
	if _combo_count[index] % 2 == 0:
		if phase < 48 and phase % 12 < 2:
			held |= A.LIGHT
	else:
		if phase < 24 and phase % 12 < 2:
			held |= A.LIGHT
		elif phase >= 22 and phase < 26:
			held |= A.HEAVY
	return held


## The nearest settled pickup while unarmed (or out of ammo), if any.
func _wanted_pickup(index: int) -> WeaponPickup:
	var me: FighterState = sim.fighters[index]
	var kind := me.held_weapon()
	if kind != Weapon.Kind.NONE and not (Weapon.is_ranged(kind) and me.ammo[me.active_slot] <= 0):
		return null
	var best: WeaponPickup = null
	var best_distance := 70.0
	for pickup in sim.pickups:
		if not pickup.can_be_picked_up():
			continue
		var distance := me.position.distance_to(pickup.position)
		if distance < best_distance:
			best = pickup
			best_distance = distance
	return best


## Stick input that moves the fighter along world direction (flat), given
## that locked movement is relative to the direction to the opponent.
static func _local_move(me: FighterState, them: FighterState, direction: Vector3) -> Vector2:
	if direction.length() < 0.01:
		return Vector2.ZERO
	var to_them := Vector3(them.position.x - me.position.x, 0, them.position.z - me.position.z)
	var forward := to_them.normalized() if to_them.length() > 0.01 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var d := direction.normalized()
	return Vector2(d.dot(right), d.dot(forward))
