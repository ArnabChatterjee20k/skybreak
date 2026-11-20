class_name AISpecials
extends RefCounted
## When the AI uses its legend's specials (T-SP1). Reads the SpecialKit's AI hooks
## (role, range band, lowest level) through SpecialRules.ai_pick; the levels set how
## often. Pure decisions over the AI's own rng, so AI rollback stays deterministic.

const _ROLE := SpecialMove.AiRole
## Per level 1..5: chance to answer a seen close strike with a counter or evade special.
const ANSWER_CHANCE: Array[float] = [0.0, 0.1, 0.22, 0.32, 0.4]
## Per level: chance per neutral tick to open with an approach, anti-guard or mix-up special.
const NEUTRAL_CHANCE: Array[float] = [0.0, 0.01, 0.02, 0.03, 0.04]
## Per level: chance to cancel a confirmed heavy into a special.
const ENDER_CHANCE: Array[float] = [0.0, 0.15, 0.35, 0.55, 0.7]
## Ticks before a seen strike lands that a counter stance still catches it.
const ANSWER_TICKS := 10


## Key (1-3) to answer a strike seen threat ticks away, or 0.
static func answer(sim: CombatSim, index: int, distance: float, threat: int, level: int,
		rng: RandomNumberGenerator) -> int:
	if SpecialRules.kit_of(sim.fighters[index]) == null or threat > ANSWER_TICKS:
		return 0
	var slot := SpecialRules.ai_pick(sim, index, _ROLE.COUNTER, distance, level)
	if slot == 0:
		slot = SpecialRules.ai_pick(sim, index, _ROLE.EVADE, distance, level)
	if slot == 0 or rng.randf() >= ANSWER_CHANCE[clampi(level, 1, 5) - 1]:
		return 0
	return slot


## Key to open with in neutral (approach from mid range, crack a guard), or 0.
static func neutral(sim: CombatSim, index: int, target: FighterState, distance: float, level: int,
		rng: RandomNumberGenerator) -> int:
	if SpecialRules.kit_of(sim.fighters[index]) == null:
		return 0
	var slot := 0
	if target.blocking:
		slot = SpecialRules.ai_pick(sim, index, _ROLE.ANTI_GUARD, distance, level)
		if slot == 0:
			slot = SpecialRules.ai_pick(sim, index, _ROLE.MIXUP, distance, level)
	if slot == 0:
		slot = SpecialRules.ai_pick(sim, index, _ROLE.APPROACH, distance, level)
	if slot == 0:
		slot = SpecialRules.ai_pick(sim, index, _ROLE.MIXUP, distance, level)
	# Rolls only with a usable special, so levels and legends without one keep their rng stream.
	if slot == 0 or rng.randf() >= NEUTRAL_CHANCE[clampi(level, 1, 5) - 1]:
		return 0
	return slot


## Key to cancel a confirmed hit into (an ender, else an approach that chases), or 0.
static func ender(sim: CombatSim, index: int, distance: float, level: int, rng: RandomNumberGenerator) -> int:
	if SpecialRules.kit_of(sim.fighters[index]) == null \
			or not sim.can_cancel_into(index, MoveData.CancelLevel.SPECIAL):
		return 0
	var slot := SpecialRules.ai_pick(sim, index, _ROLE.ENDER, distance, level)
	if slot == 0:
		slot = SpecialRules.ai_pick(sim, index, _ROLE.APPROACH, maxf(distance, 4.5), level)
	if slot == 0 or rng.randf() >= ENDER_CHANCE[clampi(level, 1, 5) - 1]:
		return 0
	return slot


static func action_for(slot: int) -> int:
	return SpecialRules.SLOT_ACTIONS[slot - 1] if slot >= 1 and slot <= 3 else 0
