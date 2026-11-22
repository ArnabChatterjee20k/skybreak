class_name PureFightGolden
extends RefCounted
## Pure Fight golden replays: recorded inputs (InputCodec, base64) and a state hash every
## HASH_EVERY ticks. Replaying the inputs must reproduce every hash.

const HASH_EVERY := 10


## Records an AI-vs-AI match: {seed, legends, inputs: [[p1, p2] per tick], hashes: {tick: hash}}.
static func record(seed_value: int, legends: Array[StringName], ticks: int) -> Dictionary:
	var sim := PureFightSim.new(seed_value, legends)
	var ais: Array[PureFightAI] = []
	for i in 2:
		var ai := PureFightAI.new()
		ai.setup(i, 4, seed_value)
		ai.explore = 0.35
		ais.append(ai)
	var inputs: Array = []
	var hashes := {}
	for t in ticks:
		var pair: Array[FighterInput] = [ais[0].next_input(sim), ais[1].next_input(sim)]
		inputs.append([Marshalls.raw_to_base64(InputCodec.encode(pair[0])),
			Marshalls.raw_to_base64(InputCodec.encode(pair[1]))])
		sim.tick(pair)
		if (t + 1) % HASH_EVERY == 0:
			hashes[str(t + 1)] = str(sim.state_hash())
	return {"seed": seed_value, "legends": legends.map(func(l: StringName) -> String: return String(l)),
		"inputs": inputs, "hashes": hashes}


## Replays a golden; returns the first tick whose hash differs, or -1.
static func first_drift(golden: Dictionary) -> int:
	var legends: Array[StringName] = []
	for l in golden.legends:
		legends.append(StringName(l))
	var sim := PureFightSim.new(int(golden.seed), legends)
	var inputs: Array = golden.inputs
	for t in inputs.size():
		var pair: Array[FighterInput] = [InputCodec.decode(Marshalls.base64_to_raw(inputs[t][0])),
			InputCodec.decode(Marshalls.base64_to_raw(inputs[t][1]))]
		sim.tick(pair)
		var key := str(t + 1)
		if golden.hashes.has(key) and str(sim.state_hash()) != String(golden.hashes[key]):
			return t + 1
	return -1
