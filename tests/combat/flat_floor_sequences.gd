class_name FlatFloorSequences
extends RefCounted
## Per-tick fighter fingerprints of the seeded flat-floor matches (T-D13 regression guard).

const GOLDEN_PATH := "res://tests/combat/data/flat_floor_golden.json"
const FREE_FOR_ALL_SEED := 10
const FREE_FOR_ALL_TICKS := 10_000
const BOT_MATCH_SEED := 4
const BOT_MATCH_TICKS := 3600


## Name -> per-tick fingerprints, as hex strings.
static func record() -> Dictionary:
	var free_for_all: Array[String] = []
	var combat := load("res://tests/combat/test_combat_sim.gd").new() as Node
	combat._run_match(FREE_FOR_ALL_SEED, FREE_FOR_ALL_TICKS, {}, 4,
		func(sim: CombatSim) -> void: free_for_all.append(fingerprint(sim)))
	combat.free()
	return {"free_for_all": free_for_all, "bot_match": _bot_match()}


## Two WeaponBots unarmed: T-D26 changed weapons and drops on purpose, so pickups stay off.
static func _bot_match() -> Array[String]:
	var sim := CombatSim.new(BOT_MATCH_SEED)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	sim.lock_everyone_onto_nearest()
	var bots: Array[WeaponBot] = [
		WeaponBot.new(0, BOT_MATCH_SEED * 3 + 1), WeaponBot.new(1, BOT_MATCH_SEED * 3 + 2)]
	var sequence: Array[String] = []
	for _tick in BOT_MATCH_TICKS:
		var inputs: Array[FighterInput] = []
		for bot in bots:
			inputs.append(bot.next_input(sim))
		sim.tick(inputs)
		sequence.append(fingerprint(sim))
		if sim.round_over:
			sim.start_round()
	return sequence


## Tick, then each fighter's position, velocity and state; nothing later PRs added on purpose.
static func fingerprint(sim: CombatSim) -> String:
	var parts: Array = [sim.current_tick]
	for fighter in sim.fighters:
		parts.append_array([fighter.position, fighter.velocity, fighter.state])
	return "%08x" % hash(var_to_bytes(parts))
