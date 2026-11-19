extends GutTest
## QA-15: an AI never hovers over or under an air juggle, its own or someone else's.

const ATTACKS := FighterInput.Action.LIGHT | FighterInput.Action.HEAVY | FighterInput.Action.GRAB
const S := FighterState.State


## AI in slot 0 on the ground; fighter 1 in hitstun at juggle_at; fighter 2 far away.
func _setup(juggle_at: Vector3) -> CombatSim:
	var sim := CombatSim.new(9)
	sim.add_fighter(Vector3(0, 0, 0))
	sim.add_fighter(juggle_at)
	sim.add_fighter(Vector3(40, 0, 40))
	sim.lock_everyone_onto_nearest()
	var juggled := sim.fighters[1]
	juggled.enter_state(S.HITSTUN)
	juggled.stun_ticks = 600
	return sim


## Inputs of a level-5 AI over ticks, with hitter credited for the hit that started the juggle.
func _inputs(sim: CombatSim, hitter: int, ticks := 40) -> Array[FighterInput]:
	var ai := FighterAI.new(0, 5, 3)
	var out: Array[FighterInput] = []
	for t in ticks:
		var events: Array[Dictionary] = []
		if t == 0:
			events.append({"type": CombatSim.EventType.HIT, "attacker": hitter, "target": 1})
		sim.events = events
		out.append(ai.next_input(sim))
	return out


func test_a_third_party_holds_off_someone_elses_air_juggle() -> void:
	var sim := _setup(Vector3(0, 3.2, -3.0))
	for input in _inputs(sim, 2):
		assert_eq(input.held_actions & ATTACKS, 0, "no attack on someone else's juggle")
		assert_lte(input.move.y, 0.0, "never closes in under it")


func test_the_juggler_does_not_start_a_hit_from_under_its_own_juggle() -> void:
	var sim := _setup(Vector3(0, 2.6, -1.2))
	for input in _inputs(sim, 0):
		assert_eq(input.held_actions & ATTACKS, 0, "no hit from straight under")
		assert_lte(input.move.y, 0.0, "steps out from under")
