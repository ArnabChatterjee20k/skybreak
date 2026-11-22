class_name PureFightNet
extends RefCounted
## Online Pure Fight 1v1 (GAME_DESIGN §16.10) over the Duo rollback core: both peers build
## the same PureFightSim from the lobby's seed and legends; peer 0 plays fighter 0 (left),
## peer 1 fighter 1. No AI and no extra rules: PureFightSim runs its own rounds.

const PEERS := 2


static func new_sim(seed_value: int, legends: Array[StringName]) -> PureFightSim:
	return PureFightSim.new(seed_value, legends)


static func fighter_peers() -> Array[int]:
	return [0, 1] as Array[int]


## A session for this peer; clock in ms (tests pass a virtual one).
static func new_session(sim: PureFightSim, transport: NetTransport, local_peer: int,
		delay: int = 2, clock: Callable = Callable()) -> RollbackSession:
	return RollbackSession.new(sim, transport, local_peer, PEERS, fighter_peers(), [], delay, clock)
