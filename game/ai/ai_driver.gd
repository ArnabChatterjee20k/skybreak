class_name AIDriver
extends RefCounted
## Runs the AI fighters of a match. Built from the match's fighter list
## ({character, team, is_ai, ai_level} per slot, the menus' contract), it fills
## in the AI slots' inputs each tick and leaves the human slots alone.

## One FighterAI per slot, null for human slots.
var ais: Array[FighterAI] = []
## Single-slot use (ZoneMatch's driver contract: setup(), then next_input() each tick).
var _slot: int = -1
var _level: int = 3


## fighters: [{character, team, is_ai, ai_level}] in slot order; sim_seed: the match's CombatSim seed.
func _init(fighters: Array = [], sim_seed: int = 0) -> void:
	var teams := PackedInt32Array()
	for slot in fighters.size():
		var entry: Dictionary = fighters[slot]
		teams.append(int(entry.get("team", slot)))
		var ai: FighterAI = null
		if entry.get("is_ai", false):
			ai = FighterAI.new(slot, int(entry.get("ai_level", 3)), FighterAI.seed_for(sim_seed, slot))
		ais.append(ai)
	for ai in ais:
		if ai:
			ai.teams = teams


## A driver for sim, seeded from its rng seed.
static func for_sim(sim: CombatSim, fighters: Array) -> AIDriver:
	return AIDriver.new(fighters, sim.rng.seed)


## Makes this driver play only slot at level; its AI is built on the first next_input().
func setup(slot: int, level: int) -> void:
	_slot = slot
	_level = level


## The set-up slot's input this tick, seeded from the sim and teamed by the sim's teams.
func next_input(sim: CombatSim) -> FighterInput:
	if ais.is_empty():
		var teams := PackedInt32Array()
		for slot in sim.fighters.size():
			teams.append(sim.fighters[slot].team)
			ais.append(FighterAI.new(slot, _level, FighterAI.seed_for(sim.rng.seed, slot)) if slot == _slot else null)
		ais[_slot].teams = teams
	return input_for(sim, _slot)


func is_ai(slot: int) -> bool:
	return slot < ais.size() and ais[slot] != null


## The AI's input for slot this tick (neutral for a human slot). Once per slot per tick.
func input_for(sim: CombatSim, slot: int) -> FighterInput:
	return ais[slot].next_input(sim) if is_ai(slot) else FighterInput.new()


## slots: this tick's input per fighter (humans filled in, the rest anything); returns
## them with every AI slot replaced by its AI's input. Missing slots are padded.
func inputs_for(sim: CombatSim, slots: Array[FighterInput] = []) -> Array[FighterInput]:
	var inputs: Array[FighterInput] = []
	for slot in sim.fighters.size():
		if is_ai(slot):
			inputs.append(ais[slot].next_input(sim))
		elif slot < slots.size() and slots[slot] != null:
			inputs.append(slots[slot])
		else:
			inputs.append(FighterInput.new())
	return inputs
