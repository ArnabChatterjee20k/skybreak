class_name PureFightNet
extends RefCounted
## Online Pure Fight 1v1 (GAME_DESIGN §16.10) over the Duo rollback core: both peers build
## the same PureFightSim from the lobby's seed and legends; peer 0 plays fighter 0 (left),
## peer 1 fighter 1. No AI and no extra rules: PureFightSim runs its own rounds.

const PEERS := 2


## The MatchConfig both peers launch for a Pure Fight room in the Duo lobby.
static func build_config(setup: Dictionary, seed_value: int) -> Dictionary:
	var list: Array[Dictionary] = [
		MatchRules.fighter(StringName(setup.get("host_legend", &"kael")), 0, false),
		MatchRules.fighter(StringName(setup.get("guest_legend", &"vexa")), 1, false),
	]
	var config := MatchRules.make(MatchRules.MODE_PURE_FIGHT_ONLINE,
		StringName(setup.get("zone", &"heartbloom_gardens")), list, PureFightSim.ROUNDS_TO_WIN * 2 - 1)
	config["seed"] = seed_value
	return config


static func new_sim(seed_value: int, legends: Array[StringName]) -> PureFightSim:
	return PureFightSim.new(seed_value, legends)


static func fighter_peers() -> Array[int]:
	return [0, 1] as Array[int]


## A session for this peer; clock in ms (tests pass a virtual one).
static func new_session(sim: PureFightSim, transport: NetTransport, local_peer: int,
		delay: int = 2, clock: Callable = Callable()) -> RollbackSession:
	return RollbackSession.new(sim, transport, local_peer, PEERS, fighter_peers(), [], delay, clock)
