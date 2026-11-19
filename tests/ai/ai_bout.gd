class_name AIBout
extends RefCounted
## One seeded round between AI fighters, for the AI tests: runs until a KO or
## the time limit and reports who won (the higher health at time-out).

const STARTS: Array[Vector3] = [Vector3(0, 1, 6), Vector3(0, 1, -6), Vector3(6, 1, 0), Vector3(-6, 1, 0)]

var sim: CombatSim
var driver: AIDriver
## Winning slot, or -1 for a draw.
var winner: int = -1
var ticks: int = 0


## levels: AI level per slot (0 = an idle dummy); characters: legend id per slot (default Kael).
func _init(seed_value: int, levels: Array, pickups := false, characters: Array = []) -> void:
	sim = CombatSim.new(seed_value)
	sim.pickups_enabled = pickups
	var fighters: Array = []
	for slot in levels.size():
		var character: StringName = characters[slot] if slot < characters.size() else &"kael"
		sim.add_fighter(STARTS[slot], EngagementBand.stats_for(character))
		fighters.append({"character": character, "team": slot, "is_ai": levels[slot] > 0,
			"ai_level": levels[slot]})
	sim.lock_everyone_onto_nearest()
	driver = AIDriver.for_sim(sim, fighters)


## Steps one tick with the AIs' inputs; returns them.
func step() -> Array[FighterInput]:
	var inputs := driver.inputs_for(sim)
	sim.tick(inputs)
	ticks += 1
	return inputs


## Plays until the round ends or max_ticks pass; returns the winner (-1 draw).
func play(max_ticks: int) -> int:
	while ticks < max_ticks and not sim.round_over:
		step()
	if sim.round_over:
		winner = sim.round_winner
	else:
		var best := -1
		var best_health := -1
		for i in sim.fighters.size():
			var health := sim.fighters[i].health
			if health > best_health:
				best = i
				best_health = health
			elif health == best_health:
				best = -1
		winner = best
	return winner
