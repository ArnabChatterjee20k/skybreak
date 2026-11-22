class_name DuoMatch
extends RefCounted
## Builds a Duo match (GAME_DESIGN §8.2) the same way on both devices: the host
## flies fighter 0, the guest fighter 1, AI fighters follow on team 1, driven by
## AIDriver on both peers (seeded from the match seed, so they cost no traffic).

const HUMAN_PEERS := 2
const INPUT_DELAY := 2
const MIN_AI := 1
const MAX_AI := 3
const DEFAULT_AI_LEVEL := 3
const LIVES_CHOICES: Array[int] = [3, 6, 9]
const MINUTE_CHOICES: Array[int] = [3, 5, 8]
const _HUMAN_SPAWNS: Array[Vector3] = [Vector3(-3, 1, 8), Vector3(3, 1, 8)]
const _AI_SPAWNS: Array[Vector3] = [Vector3(-3, 1, -8), Vector3(3, 1, -8), Vector3(0, 1, -12)]


## The MatchConfig dictionary both peers launch. setup: {host_legend, guest_legend,
## zone, ai_count, ai_level, lives, minutes}; AI legends come from the seed.
static func build_config(setup: Dictionary, seed_value: int) -> Dictionary:
	var list: Array[Dictionary] = [
		MatchRules.fighter(StringName(setup.get("host_legend", &"kael")), DuoFlow.HUMAN_TEAM, false),
		MatchRules.fighter(StringName(setup.get("guest_legend", &"vexa")), DuoFlow.HUMAN_TEAM, false),
	]
	var legends := LegendCatalog.ids()
	var level := clampi(int(setup.get("ai_level", DEFAULT_AI_LEVEL)), MatchRules.MIN_AI_LEVEL, MatchRules.MAX_AI_LEVEL)
	for i in clampi(int(setup.get("ai_count", 1)), MIN_AI, MAX_AI):
		var legend: StringName = legends[(seed_value + i * 3) % legends.size()] if not legends.is_empty() else &"kael"
		list.append(MatchRules.fighter(legend, DuoFlow.AI_TEAM, true, level))
	var config := MatchRules.make(MatchRules.MODE_DUO, StringName(setup.get("zone", &"heartbloom_gardens")), list, 1)
	config["seed"] = seed_value
	config["lives"] = int(setup.get("lives", DuoFlow.DEFAULT_LIVES))
	config["minutes"] = int(setup.get("minutes", DuoFlow.DEFAULT_MINUTES))
	return config


## Team per fighter from a config's fighter list.
static func teams_of(config: Dictionary) -> Array[int]:
	var teams: Array[int] = []
	for entry: Dictionary in config.get("fighters", []):
		teams.append(int(entry.get("team", 0)))
	return teams


## Owning peer per fighter for RollbackSession (-1 = AI).
static func fighter_peers(fighter_count: int) -> Array[int]:
	var owners: Array[int] = []
	for i in fighter_count:
		owners.append(i if i < HUMAN_PEERS else -1)
	return owners


## The match rules for a config.
static func new_flow(config: Dictionary) -> DuoFlow:
	return DuoFlow.new(teams_of(config), int(config.get("lives", DuoFlow.DEFAULT_LIVES)),
		int(config.get("minutes", DuoFlow.DEFAULT_MINUTES)))


## A flat-floor sim for a config (tests and tools; the zone match builds its own on the zone).
static func new_sim(config: Dictionary) -> CombatSim:
	var sim := CombatSim.new(int(config.get("seed", 0)))
	sim.pickups_enabled = true
	var teams := teams_of(config)
	var ai := 0
	for i in teams.size():
		var start := _HUMAN_SPAWNS[i] if i < HUMAN_PEERS else _AI_SPAWNS[mini(ai, _AI_SPAWNS.size() - 1)]
		if i >= HUMAN_PEERS:
			ai += 1
		var fighter := sim.add_fighter(start)
		fighter.team = teams[i]
	sim.lock_everyone_onto_nearest()
	return sim


## AI drivers per fighter (null for humans), as the zone match makes them.
static func new_bots(config: Dictionary) -> Array:
	var bots: Array = []
	var list: Array = config.get("fighters", [])
	for i in list.size():
		var entry: Dictionary = list[i]
		if entry.get("is_ai", false):
			var driver := AIDriver.new()
			driver.setup(i, int(entry.get("ai_level", DEFAULT_AI_LEVEL)))
			bots.append(driver)
		else:
			bots.append(null)
	return bots
