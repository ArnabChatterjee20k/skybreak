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
	var bot_match: Array[String] = []
	var weapons := load("res://tests/combat/test_weapons.gd").new() as Node
	weapons._bot_match(BOT_MATCH_SEED, BOT_MATCH_TICKS, &"skyhold_ruins",
		func(sim: CombatSim) -> void: bot_match.append(fingerprint(sim)))
	weapons.free()
	return {"free_for_all": free_for_all, "bot_match": bot_match}


## Tick, then each fighter's position, velocity and state; nothing later PRs added on purpose.
static func fingerprint(sim: CombatSim) -> String:
	var parts: Array = [sim.current_tick]
	for fighter in sim.fighters:
		parts.append_array([fighter.position, fighter.velocity, fighter.state])
	return "%08x" % hash(var_to_bytes(parts))
