class_name WeaponBot
extends RefCounted
## A simple scripted opponent that reads sim state and produces FighterInput:
## it flies to weapon drops and grabs them, fights at its weapon's range,
## fires, strings lights and heavies, blocks some attacks, switches and throws
## now and then. Its own seeded rng keeps recorded bot fights repeatable.

const _A := FighterInput.Action
## Goes for drops within this distance while it has a free slot.
const PICKUP_SEARCH_RANGE := 140.0
## Attack range per weapon (metres, centre to centre); unarmed when missing.
const MELEE_RANGE := {
	Weapon.Kind.NONE: 2.0, Weapon.Kind.KI_GAUNTLETS: 1.8, Weapon.Kind.STORM_BLADE: 2.4,
	Weapon.Kind.SKY_LANCE: 3.6, Weapon.Kind.TITAN_HAMMER: 2.6, Weapon.Kind.ORBIT_CHAKRAM: 4.5,
	Weapon.Kind.EMBER_SCYTHE: 2.8,
}
## Preferred distance band for ranged weapons: [near, far].
const RANGED_BAND := {
	Weapon.Kind.KI_BOW: Vector2(10, 24), Weapon.Kind.ARC_REVOLVER: Vector2(7, 18),
	Weapon.Kind.STORM_REPEATER: Vector2(6, 16), Weapon.Kind.SCATTER_CANNON: Vector2(2.5, 7),
	Weapon.Kind.HEARTSTRING_BOW: Vector2(8, 20),
}

var fighter_index: int
var rng := RandomNumberGenerator.new()
var _previous := FighterInput.new()
var _strafe := 1.0
var _strafe_ticks := 0


func _init(index: int, seed_value: int) -> void:
	fighter_index = index
	rng.seed = seed_value


## This tick's input for the bot's fighter.
func next_input(sim: CombatSim) -> FighterInput:
	var me := sim.fighters[fighter_index]
	var opponent_index := me.lock_on_target if me.lock_on_target >= 0 else _other(sim)
	var opponent := sim.fighters[opponent_index]
	var plan := FighterInput.new()
	_strafe_ticks -= 1
	if _strafe_ticks <= 0:
		_strafe = -1.0 if rng.randf() < 0.5 else 1.0
		_strafe_ticks = rng.randi_range(30, 120)
	var goal := _pickup_goal(sim, me, opponent)
	if goal >= 0:
		_go_for_pickup(sim, me, sim.pickups[goal], plan)
	else:
		_fight(me, opponent, plan)
	var input := FighterInput.from_held(plan.held_actions, _previous)
	input.move = plan.move
	input.vertical = plan.vertical
	input.view_yaw = plan.view_yaw
	_previous = input
	return input


func _other(sim: CombatSim) -> int:
	return 1 if fighter_index == 0 else 0


## Index of the drop worth going for, or -1: a free slot (or unarmed) and the opponent not on top of us.
func _pickup_goal(sim: CombatSim, me: FighterState, opponent: FighterState) -> int:
	if me.weapon_count() >= 2 and me.held_weapon() != Weapon.Kind.NONE:
		return -1
	if me.held_weapon() != Weapon.Kind.NONE and me.position.distance_to(opponent.position) < 4.0:
		return -1
	var best := -1
	var best_distance := PICKUP_SEARCH_RANGE
	for i in sim.pickups.size():
		var pickup := sim.pickups[i]
		if not pickup.can_be_picked_up():
			continue
		var distance := me.position.distance_to(pickup.position)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best


func _go_for_pickup(sim: CombatSim, me: FighterState, pickup: WeaponPickup, plan: FighterInput) -> void:
	if me.lock_on_target >= 0:
		_tap(plan, _A.LOCK_TOGGLE)
	var to_pickup := pickup.position - me.position
	plan.view_yaw = atan2(-to_pickup.x, -to_pickup.z)
	var planar := Vector2(to_pickup.x, to_pickup.z).length()
	plan.move = Vector2(0, 1) if planar > 0.6 else Vector2.ZERO
	if to_pickup.y > 0.8:
		plan.vertical = 1
	elif to_pickup.y < -0.8:
		plan.vertical = -1
	if me.position.distance_to(pickup.position) < sim.pickup_tuning.pickup_reach - 0.4:
		_tap(plan, _A.PICKUP)


func _fight(me: FighterState, opponent: FighterState, plan: FighterInput) -> void:
	if me.lock_on_target < 0:
		_tap(plan, _A.LOCK_TOGGLE)
		return
	var distance := me.position.distance_to(opponent.position)
	var dy := opponent.position.y - me.position.y
	if dy > 1.0:
		plan.vertical = 1
	elif dy < -1.0:
		plan.vertical = -1
	var held := me.held_weapon()
	if me.weapon_count() > 1 and rng.randf() < 1.0 / 300.0:
		_tap(plan, _A.WEAPON_NEXT)
		return
	if held != Weapon.Kind.NONE and distance < 14.0 and rng.randf() < 1.0 / 700.0:
		_tap(plan, _A.THROW)
		return
	if Weapon.is_ranged(held):
		_fight_ranged(held, distance, plan)
	else:
		_fight_melee(held, me, opponent, distance, plan)


func _fight_ranged(held: Weapon.Kind, distance: float, plan: FighterInput) -> void:
	var band: Vector2 = RANGED_BAND[held]
	if distance > band.y:
		plan.move = Vector2(0, 1)
	elif distance < band.x:
		plan.move = Vector2(_strafe * 0.5, -1)
	else:
		plan.move = Vector2(_strafe, 0)
	if distance <= band.y * 1.3:
		if held == Weapon.Kind.STORM_REPEATER:
			plan.held_actions |= _A.LIGHT
		elif rng.randf() < 0.25:
			_tap(plan, _A.LIGHT)


func _fight_melee(held: Weapon.Kind, me: FighterState, opponent: FighterState, distance: float,
		plan: FighterInput) -> void:
	var reach: float = MELEE_RANGE.get(held, 2.0)
	var opponent_attacking := opponent.state == FighterState.State.ATTACKING \
		and opponent.attack_phase() == FighterState.AttackPhase.STARTUP
	if opponent_attacking and distance < 5.0 and rng.randf() < 0.3:
		plan.held_actions |= _A.BLOCK
		return
	if distance > reach:
		plan.move = Vector2(_strafe * 0.2, 1)
		if distance > 18.0 and rng.randf() < 0.03:
			_tap(plan, _A.DASH)
		return
	plan.move = Vector2(_strafe * 0.3, 0)
	if me.state == FighterState.State.ATTACKING and rng.randf() < 0.5:
		_tap(plan, _A.LIGHT)
		return
	var roll := rng.randf()
	if roll < 0.12:
		plan.move = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2.ZERO][rng.randi_range(0, 3)]
		_tap(plan, _A.HEAVY)
	elif roll < 0.55:
		_tap(plan, _A.LIGHT)


## Holds action this tick only if it was not held last tick, so every tap is a fresh press.
func _tap(plan: FighterInput, action: int) -> void:
	if (_previous.held_actions & action) == 0:
		plan.held_actions |= action
