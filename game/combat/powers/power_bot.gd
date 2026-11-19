class_name PowerBot
extends WeaponBot
## A WeaponBot that also goes for power drops and uses its gadget: G at mid
## range when no pickup is in reach. Seeded like WeaponBot, so bot fights replay.

## Throws or places a held gadget at the target within this distance.
const GADGET_RANGE := 16.0


func next_input(sim: CombatSim) -> FighterInput:
	var input := super.next_input(sim)
	var me := sim.fighters[fighter_index]
	if me.powers.gadget == Power.Kind.NONE or sim.pickup_in_reach(fighter_index) >= 0:
		return input
	var distance := me.position.distance_to(sim.fighters[_other(sim)].position)
	if distance < GADGET_RANGE and rng.randf() < 1.0 / 40.0 and (input.held_actions & _A.PICKUP) == 0:
		input.held_actions |= _A.PICKUP
		input.pressed_actions |= _A.PICKUP
		if me.lock_on_target < 0:
			# Lock on in the same tick so the gadget goes at the opponent.
			input.held_actions |= _A.LOCK_TOGGLE
			input.pressed_actions |= _A.LOCK_TOGGLE
	return input
