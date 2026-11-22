class_name ExchangeCam
extends RefCounted
## When the fight camera swings to its side-on "exchange" angle (hybrid camera,
## owner's pick from the look mockups): a melee exchange (the followed fighter
## and their target within MELEE_RANGE with a strike, hit or block in progress)
## or a beam clash the followed fighter is in. View-only: reads sim state.

const MELEE_RANGE := 3.0
const _BUSY: Array[FighterState.State] = [
	FighterState.State.ATTACKING, FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN,
]


## [followed fighter index, other fighter index] of the exchange, or [] if none.
static func participants(sim: CombatSim, index: int) -> PackedInt32Array:
	if index < 0 or index >= sim.fighters.size():
		return PackedInt32Array()
	for clash: BeamClash in sim.beam_clashes:
		for side in 2:
			if clash.owners[side] == index:
				return PackedInt32Array([index, clash.owners[1 - side]])
	var me := sim.fighters[index]
	var other := me.lock_on_target
	if other < 0 or other >= sim.fighters.size():
		return PackedInt32Array()
	var them := sim.fighters[other]
	if me.is_ko_state() or them.is_ko_state():
		return PackedInt32Array()
	if me.position.distance_to(them.position) > MELEE_RANGE:
		return PackedInt32Array()
	if me.state in _BUSY or them.state in _BUSY:
		return PackedInt32Array([index, other])
	return PackedInt32Array()
