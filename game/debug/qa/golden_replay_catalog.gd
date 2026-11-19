class_name GoldenReplayCatalog
extends RefCounted
## The canonical golden replays: what each one covers and how it is set up.
## Change a spec here, then re-record with tools/qa/bless_goldens.sh --replays.

const DIRECTORY := "res://tests/qa/goldens/replays/"
const DUEL_STARTS: Array[Vector3] = [Vector3(0, 1, 6), Vector3(0, 1, -6)]
const AIR_STARTS: Array[Vector3] = [Vector3(0, 10, 8), Vector3(0, 14, -8)]
const FFA_STARTS: Array[Vector3] = [Vector3(0, 1, 6), Vector3(0, 1, -6), Vector3(6, 1, 0), Vector3(-6, 1, 0)]
const TEAM_STARTS: Array[Vector3] = [Vector3(3, 1, 6), Vector3(-3, 1, 6), Vector3(3, 1, -6), Vector3(-3, 1, -6)]


## Every canonical spec; "expect" lists events the recording must contain.
static func specs() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		_spec("duel_kael_mirror", "Kael vs Kael, level 3 vs 3, on the ground.", 11,
			[[&"kael", 3], [&"kael", 3]], DUEL_STARTS, 1200, ["HIT"]),
		_spec("duel_vexa_vs_lyra", "Vexa (level 4) vs Lyra (level 3).", 12,
			[[&"vexa", 4], [&"lyra", 3]], DUEL_STARTS, 1200, ["HIT"]),
		_spec("duel_brann_vs_kael", "Brann (level 3) vs Kael (level 4).", 13,
			[[&"brann", 3], [&"kael", 4]], DUEL_STARTS, 1200, ["HIT"]),
		_spec("duel_lyra_vs_brann_airborne", "Lyra vs Brann, level 4 each, starting in the air.", 14,
			[[&"lyra", 4], [&"brann", 4]], AIR_STARTS, 1200, ["HIT"]),
		_spec("duel_low_level_mirror", "Vexa vs Vexa at level 2: slow reactions, few combos.", 15,
			[[&"vexa", 2], [&"vexa", 2]], DUEL_STARTS, 900, []),
		_spec("combos_level5", "Kael vs Brann at level 5: combo routes, grabs and grab techs.", 16,
			[[&"kael", 5], [&"brann", 5]], DUEL_STARTS, 1500, ["HIT"]),
		_spec("ffa4_all_legends", "Free-for-all, all four legends, levels 2 to 5.", 17,
			[[&"kael", 2], [&"vexa", 3], [&"brann", 4], [&"lyra", 5]], FFA_STARTS, 1500, ["HIT"]),
		_spec("teams_2v2", "Kael + Lyra vs Vexa + Brann, levels 3 and 4: team targeting.", 18,
			[[&"kael", 4], [&"lyra", 3], [&"vexa", 4], [&"brann", 3]], TEAM_STARTS, 1500, ["HIT"],
			[0, 0, 1, 1]),
		_spec("ko_and_second_round", "Brann (level 5) KOs Lyra (level 2, 30% health), then start_round() and round 2.",
			19, [[&"brann", 5], [&"lyra", 2]], DUEL_STARTS, 1800, ["KO", "KO_REST"]),
	]
	var pickups := _spec("pickups_heartbloom", "Heartbloom Gardens with weapon and power drops every 4-6 s.",
		20, [[&"vexa", 4], [&"lyra", 4]], DUEL_STARTS, 1800, ["PICKUP_SPAWN", "PICKUP"])
	pickups.zone = &"heartbloom_gardens"
	pickups.pickups = true
	pickups.pickup_interval = [240, 360]
	list.append(pickups)
	# Lyra starts on 30% health so the KO lands early and round 2 gets real time.
	list[8].fighters[1].health_percent = 30
	list[8].expect_round_starts = 1
	return list


static func path_for(replay_name: String) -> String:
	return DIRECTORY + replay_name + ".json"


static func _spec(replay_name: String, description: String, seed_value: int, legends: Array,
		starts: Array[Vector3], ticks: int, expect: Array, teams: Array = []) -> Dictionary:
	var fighters: Array = []
	for slot in legends.size():
		fighters.append({"character": legends[slot][0], "ai_level": legends[slot][1],
			"team": teams[slot] if slot < teams.size() else slot, "start": starts[slot]})
	return {"name": replay_name, "description": description, "seed": seed_value, "zone": &"skyhold_ruins",
		"pickups": false, "fighters": fighters, "ticks": ticks, "expect": expect, "expect_round_starts": 0}


## What a fresh recording of spec misses from its "expect" list; empty when it covers all.
static func missing(spec: Dictionary, replay: GoldenReplay) -> Array[String]:
	var gaps: Array[String] = []
	for event_name: String in spec.get("expect", []):
		if not replay.coverage.has(event_name):
			gaps.append("no %s event" % event_name)
	if replay.round_starts.size() < int(spec.get("expect_round_starts", 0)):
		gaps.append("only %d round starts" % replay.round_starts.size())
	return gaps
