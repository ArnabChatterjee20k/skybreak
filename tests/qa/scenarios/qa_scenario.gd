class_name QaScenario
extends GutTest
## Shared driving for the QA scenarios: a sim with legends, held actions per fighter, an event record.

const A := FighterInput.Action
const E := CombatSim.EventType
const S := FighterState.State
const K := Weapon.Kind
const P := Power.Kind
const UNIT := FighterState.METER_UNIT
const FORWARD := Vector2(0, 1)
const BACK := Vector2(0, -1)
## States a fighter can start an action from.
const FREE_STATES: Array[FighterState.State] = [
	FighterState.State.IDLE, FighterState.State.MOVING,
	FighterState.State.FLYING, FighterState.State.FALLING,
]

var sim: CombatSim
## What each fighter holds, its planar move and its vertical input on the coming ticks.
var held: Array[int] = []
var moves: Array[Vector2] = []
var verticals: Array[int] = []
## Every event since start() or forget_events(), in order.
var seen: Array[Dictionary] = []
var _previous: Array[FighterInput] = []


## Known issues go pending in CI; under SKYBREAK_QA_STRICT=1 the scenario runs and fails.
func known_issue(id: StringName, why: String) -> bool:
	if QaKnownIssues.strict():
		return false
	pending("%s — %s" % [QaKnownIssues.describe(id), why])
	return true


## A sim with one fighter per legend at the given positions, everyone locked onto the nearest opponent.
func start(legends: Array[StringName], positions: Array[Vector3], seed_value := 7) -> CombatSim:
	sim = CombatSim.new(seed_value)
	for index in positions.size():
		var legend: StringName = legends[index] if index < legends.size() else &"kael"
		sim.add_fighter(positions[index], Roster.character(legend).stats)
	sim.lock_everyone_onto_nearest()
	held = []
	moves = []
	verticals = []
	_previous = []
	for _i in positions.size():
		held.append(0)
		moves.append(Vector2.ZERO)
		verticals.append(0)
		_previous.append(FighterInput.new())
	seen = []
	return sim


func fighter(index: int) -> FighterState:
	return sim.fighters[index]


## Runs ticks with the current held actions; returns the events of just these ticks.
func tick(ticks := 1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		for index in sim.fighters.size():
			var input := FighterInput.from_held(held[index], _previous[index])
			input.move = moves[index]
			input.vertical = verticals[index]
			inputs.append(input)
		sim.tick(inputs)
		_previous = inputs
		events.append_array(sim.events)
	seen.append_array(events)
	return events


## Presses action for one tick on top of what the fighter holds, then lets it go.
func tap(index: int, action: int) -> Array[Dictionary]:
	held[index] |= action
	var events := tick()
	held[index] &= ~action
	return events


## Ticks until condition (no arguments) is true; false if limit ticks pass first.
func tick_until(condition: Callable, limit := 120) -> bool:
	for _i in limit:
		if condition.call():
			return true
		tick()
	return condition.call()


func forget_events() -> void:
	seen = []


func of(events: Array, type: CombatSim.EventType) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event.type == type)


## Events of a type where the given fighter is the target (or the fighter for item events).
func against(events: Array, type: CombatSim.EventType, target: int) -> Array:
	return of(events, type).filter(func(event: Dictionary) -> bool:
		return event.get("target", event.get("fighter", -1)) == target)


func move_ids(events: Array) -> Array:
	return events.map(func(event: Dictionary) -> StringName: return event.get("move_id", &""))


func is_free(index: int) -> bool:
	return fighter(index).state in FREE_STATES


func gap(a: int, b: int) -> float:
	return fighter(a).position.distance_to(fighter(b).position)


func planar_gap(a: int, b: int) -> float:
	var offset := fighter(a).position - fighter(b).position
	return Vector2(offset.x, offset.z).length()


## Gives fighter index the weapon kind in hand (picked up where it stands).
func arm(kind: Weapon.Kind, index := 0) -> void:
	var pickup := WeaponPickup.new()
	pickup.id = sim._new_entity_id()
	pickup.kind = kind
	pickup.ammo = Weapon.full_ammo(kind)
	pickup.position = fighter(index).position + Vector3(0, -0.4, 0)
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	sim.pickups.append(pickup)
	tap(index, A.PICKUP)
	tick(10)


## A grounded weapon drop of kind at position.
func place_weapon(kind: Weapon.Kind, at: Vector3) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.id = sim._new_entity_id()
	pickup.kind = kind
	pickup.ammo = Weapon.full_ammo(kind)
	pickup.position = at
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	sim.pickups.append(pickup)
	return pickup


## A grounded power or gadget drop of kind at position.
func place_power(kind: Power.Kind, at: Vector3) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.id = sim._new_entity_id()
	pickup.power = kind
	pickup.position = at
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	sim.pickups.append(pickup)
	return pickup


## True on the tick to press light so the string's next hit queues inside its window.
func in_string_window(index: int) -> bool:
	var me := fighter(index)
	return me.state == S.ATTACKING and me.string_index > 0 and not me.string_queued \
		and me.hitstop_ticks == 0 and me.move_tick == me.move.string_window_start_tick + 1
