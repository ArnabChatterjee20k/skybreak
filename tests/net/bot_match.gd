extends RefCounted
## Net test fixture (the first Duo prototype's match): 2 humans and 1-2 WeaponBot
## fighters, every fighter on its own team, round restarts as the rules. The
## rollback and snapshot tests keep it so their seeds keep their drops and shots.

const HUMAN_PEERS := 2
## Ticks between a KO and the next round.
const NEXT_ROUND_TICKS := 180
const MAX_AI := 2
const _HUMAN_SPAWNS: Array[Vector3] = [Vector3(-3, 1, 8), Vector3(3, 1, 8)]
const _AI_SPAWNS: Array[Vector3] = [Vector3(-3, 1, -8), Vector3(3, 1, -8)]


## Ticks since the round ended; part of the rolled-back state.
var ko_ticks: int = 0


## Match rules run after every tick by RollbackSession: restarts the round after a KO.
func after_tick(sim: CombatSim) -> void:
	if not sim.round_over:
		ko_ticks = 0
		return
	ko_ticks += 1
	if ko_ticks >= NEXT_ROUND_TICKS:
		ko_ticks = 0
		sim.start_round()


## A fresh sim for seed_value with 2 humans and ai_count (1-2) AI fighters, drops on.
static func new_sim(seed_value: int, ai_count: int) -> CombatSim:
	var sim := CombatSim.new(seed_value)
	sim.pickups_enabled = true
	for spawn in _HUMAN_SPAWNS:
		sim.add_fighter(spawn)
	for i in clampi(ai_count, 1, MAX_AI):
		sim.add_fighter(_AI_SPAWNS[i])
	# Humans face the AI team and the AI the humans.
	var count := sim.fighters.size()
	for i in count:
		var best := -1
		for j in count:
			if (i < HUMAN_PEERS) == (j < HUMAN_PEERS):
				continue
			if best < 0 or sim.fighters[i].position.distance_squared_to(sim.fighters[j].position) \
					< sim.fighters[i].position.distance_squared_to(sim.fighters[best].position):
				best = j
		sim.fighters[i].lock_on_target = best
	return sim


## Owning peer per fighter for RollbackSession (-1 = AI).
static func fighter_peers(sim: CombatSim) -> Array[int]:
	var owners: Array[int] = []
	for i in sim.fighters.size():
		owners.append(i if i < HUMAN_PEERS else -1)
	return owners


## Bots per fighter (null for humans); seeded from the match seed so both peers agree.
static func new_bots(sim: CombatSim, seed_value: int) -> Array:
	var bots: Array = []
	for i in sim.fighters.size():
		bots.append(WeaponBot.new(i, seed_value * 7 + i) if i >= HUMAN_PEERS else null)
	return bots
