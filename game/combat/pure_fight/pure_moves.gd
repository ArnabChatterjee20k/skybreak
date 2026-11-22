class_name PureMoves
extends RefCounted
## Pure Fight move data (GAME_DESIGN §16.6): every move of every legend, all physical.
## Frames are 1-based like a fighting-game frame chart: startup 5 = the 5th frame is the
## first active one. Boxes are mm: [front start, front end, height start, height end],
## measured forward from the fighter's centre and up from its feet.
## On-block/on-hit come from advantage(), which the sim measures in tests.

const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"lyra", &"brann"]
## Hitstop per strength (light, medium, heavy, technique/finisher).
const HITSTOP: Array[int] = [7, 10, 13, 16]
const BLOCKSTOP: Array[int] = [5, 7, 9, 11]
## Meter gained by the attacker on hit per strength; half on block.
const METER_GAIN: Array[int] = [40, 60, 80, 110]
const METER_MAX := 1000
const THROW_RANGE := 950
const THROW_TECH_WINDOW := 10
const THROW_TICKS := 42
const TECH_TICKS := 20

## Per legend: body (pushbox half width, mm), hurt (hurtbox half width), health, walk forward/back (mm/tick), dash ticks/speed, backdash ticks/speed,
## jump vy, gravity, jump vx, pose style.
const STATS := {
	&"kael": {"body": 280, "hurt": 260, "health": 1000, "walk_f": 42, "walk_b": 32, "dash_ticks": 16, "dash_speed": 115,
		"back_ticks": 20, "back_speed": 85, "jump_vy": 150, "gravity": 8, "jump_vx": 48},
	&"vexa": {"body": 270, "hurt": 250, "health": 950, "walk_f": 46, "walk_b": 38, "dash_ticks": 14, "dash_speed": 135,
		"back_ticks": 18, "back_speed": 100, "jump_vy": 160, "gravity": 8, "jump_vx": 54},
	&"lyra": {"body": 270, "hurt": 250, "health": 980, "walk_f": 44, "walk_b": 34, "dash_ticks": 16, "dash_speed": 120,
		"back_ticks": 20, "back_speed": 95, "jump_vy": 152, "gravity": 8, "jump_vx": 50},
	&"brann": {"body": 390, "hurt": 330, "health": 1100, "walk_f": 34, "walk_b": 26, "dash_ticks": 20, "dash_speed": 95,
		"back_ticks": 22, "back_speed": 70, "jump_vy": 140, "gravity": 9, "jump_vx": 42},
}

static var _tables: Dictionary = {}


## The move table of a legend: move id -> move Dictionary (see _m for the fields).
static func table(legend: StringName) -> Dictionary:
	if _tables.is_empty():
		_tables = {&"kael": _kael(), &"vexa": _vexa(), &"lyra": _lyra(), &"brann": _brann()}
	return _tables.get(legend, _tables[&"kael"])


static func get_move(legend: StringName, id: StringName) -> Dictionary:
	return table(legend).get(id, {})


static func stats(legend: StringName) -> Dictionary:
	return STATS.get(legend, STATS[&"kael"])


## Move ids in list order (for the move list, docs and the bot coverage check).
static func ids(legend: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(table(legend).keys())
	return out


## Total frames of a move.
static func total(data: Dictionary) -> int:
	return int(data.startup) - 1 + int(data.active) + int(data.recovery)


## [on block, on hit] when the first active frame connects (999 on hit: knockdown or launch).
## The sim counts stun from the tick after hitstop, so this is stun - (active + recovery).
static func advantage(data: Dictionary) -> Vector2i:
	var after := int(data.active) + int(data.recovery)
	if data.stance == &"air":
		after = int(data.landing)
	var on_hit := int(data.hitstun) - after
	if data.knockdown or not (data.launch as Array).is_empty() or data.wall_bounce \
			or data.ground_bounce or int(data.cinematic) > 0:
		on_hit = 999
	return Vector2i(int(data.blockstun) - after, on_hit)


static func _m(name: String, kind: StringName, input: String, frames: Array, damage: int,
		stuns: Array, guard: StringName, box: Array, extra := {}) -> Dictionary:
	var data := {
		"name": name, "kind": kind, "input": input, "startup": frames[0], "active": frames[1],
		"recovery": frames[2], "damage": damage, "hitstun": stuns[0], "blockstun": stuns[1],
		"guard": guard, "box": box, "stance": &"stand", "button": &"", "dir": 0, "motion": &"",
		"chain_from": &"", "push": 400, "launch": [], "knockdown": false, "wall_bounce": false,
		"ground_bounce": false, "cancel": 0, "super_cancel": false, "invuln": [], "throw_invuln": [],
		"armor": [], "airborne": [], "low_profile": [], "vel": [], "rehit": 0, "hits": 1,
		"juggle": 1, "strength": 0, "limb": &"rhand", "landing": 3, "counter": [], "grab": false,
		"range": 0, "cinematic": 0, "pass_through": [], "evade": false, "tracks_land": false,
	}
	data.merge(extra, true)
	return data


## Normals shared by shape (the legend decides the look, reach and numbers).
static func _light(name: String, input: String, button: StringName, stance: StringName,
		box: Array, limb: StringName, extra := {}) -> Dictionary:
	var e := {"button": button, "stance": stance, "limb": limb, "cancel": 2, "push": 300, "strength": 0}
	e.merge(extra, true)
	return _m(name, &"normal", input, [4, 2, 7], 30, [12, 9], &"mid", box, e)


static func _kael() -> Dictionary:
	return {
		&"5L": _light("Snap Jab", "5L", &"L", &"stand", [180, 820, 1180, 1460], &"lhand"),
		&"5M": _m("Reverse Punch", &"normal", "5M", [6, 3, 12], 55, [17, 12], &"mid",
			[180, 732, 1100, 1450], {"button": &"M", "cancel": 2, "strength": 1, "push": 450}),
		&"5H": _m("Front Snap Kick", &"normal", "5H", [9, 3, 20], 85, [26, 18], &"mid",
			[200, 947, 820, 1300], {"button": &"H", "cancel": 1, "strength": 2, "push": 700,
			"limb": &"rfoot", "vel": [[1, 8, 18, 0]]}),
		&"2L": _light("Shin Kick", "2L", &"L", &"crouch", [160, 820, 0, 420], &"lfoot",
			{"guard": &"low", "startup": 5, "recovery": 8, "damage": 25, "hitstun": 11, "blockstun": 8}),
		&"2M": _m("Low Straight", &"normal", "2M", [6, 3, 11], 50, [16, 11], &"mid",
			[180, 789, 640, 1040], {"button": &"M", "stance": &"crouch", "cancel": 2, "strength": 1}),
		&"2H": _m("Crane Uppercut", &"normal", "2H", [7, 4, 24], 70, [20, 12], &"mid",
			[60, 450, 900, 1950], {"button": &"H", "stance": &"crouch", "cancel": 1, "strength": 2,
			"launch": [25, 132]}),
		&"3H": _m("Leg Sweep", &"command", "3H", [8, 3, 23], 75, [20, 14], &"low",
			[150, 967, 0, 300], {"button": &"H", "dir": 3, "stance": &"crouch", "strength": 2,
			"knockdown": true, "limb": &"rfoot", "push": 500}),
		&"6M": _m("Hammer Fist", &"command", "6M", [17, 2, 14], 55, [18, 12], &"overhead",
			[200, 860, 1000, 1750], {"button": &"M", "dir": 6, "strength": 1, "vel": [[3, 14, 22, 0]]}),
		&"6H": _m("Driving Side Kick", &"command", "6H", [14, 3, 18], 80, [22, 17], &"mid",
			[200, 1023, 850, 1350], {"button": &"H", "dir": 6, "strength": 2, "wall_bounce": true,
			"limb": &"rfoot", "push": 900, "vel": [[4, 13, 40, 0]]}),
		&"j.L": _m("Air Knee", &"normal", "j.L", [4, 8, 0], 30, [12, 9], &"high",
			[60, 560, 300, 950], {"button": &"L", "stance": &"air", "limb": &"lknee", "cancel": 0}),
		&"j.M": _m("Air Chop", &"normal", "j.M", [6, 6, 0], 50, [16, 12], &"high",
			[150, 760, 600, 1350], {"button": &"M", "stance": &"air", "strength": 1}),
		&"j.H": _m("Flying Side Kick", &"normal", "j.H", [8, 6, 0], 80, [20, 15], &"high",
			[-150, 950, 80, 700], {"button": &"H", "stance": &"air", "strength": 2, "limb": &"rfoot"}),
		&"5L>M": _m("Kiai Elbow", &"target", "5L > M", [5, 2, 14], 45, [18, 12], &"mid",
			[150, 450, 1100, 1450], {"button": &"M", "chain_from": &"5L", "cancel": 1, "strength": 1,
			"vel": [[1, 5, 30, 0]]}),
		&"5M>H": _m("Kiai Front Kick", &"target", "5M > H", [7, 3, 20], 80, [22, 16], &"mid",
			[200, 949, 800, 1350], {"button": &"H", "chain_from": &"5M", "strength": 2,
			"launch": [70, 70], "limb": &"rfoot", "push": 800, "juggle": 2}),
		&"iron_lunge": _m("Iron Lunge", &"technique", "236 + attack", [12, 4, 18], 100, [24, 16],
			&"mid", [150, 520, 1000, 1450], {"motion": &"236", "strength": 3, "super_cancel": true,
			"vel": [[4, 15, 110, 0]], "push": 800}),
		&"skyward_fist": _m("Skyward Fist", &"technique", "623 + attack", [3, 10, 29], 120, [24, 15],
			&"mid", [0, 450, 800, 2100], {"motion": &"623", "strength": 3, "invuln": [1, 8],
			"throw_invuln": [1, 8], "airborne": [4, 38], "vel": [[3, 10, 25, 95]], "rehit": 5,
			"hits": 2, "launch": [30, 125], "super_cancel": true, "landing": 0}),
		&"ridgeback_kick": _m("Ridgeback Kick", &"technique", "214 + attack", [20, 3, 16], 90,
			[20, 14], &"overhead", [150, 743, 700, 1800], {"motion": &"214", "strength": 3,
			"airborne": [4, 19], "vel": [[3, 19, 50, 0]], "ground_bounce": true, "limb": &"rfoot"}),
		&"thousand_petal": _m("Thousand Petal Breaker", &"finisher", "236236 + attack / finisher key",
			[6, 6, 40], 320, [40, 20], &"mid", [100, 900, 700, 1600], {"motion": &"236236",
			"strength": 3, "invuln": [1, 12], "throw_invuln": [1, 12], "vel": [[4, 11, 150, 0]],
			"cinematic": 96}),
		&"throw": _m("Shoulder Throw", &"throw", "throw (close)", [5, 2, 23], 110, [0, 0], &"throw",
			[0, THROW_RANGE, 0, 1800], {"grab": true, "range": THROW_RANGE, "strength": 2,
			"limb": &"lhand"}),
	}


static func _vexa() -> Dictionary:
	return {
		&"5L": _light("Backfist Flick", "5L", &"L", &"stand", [180, 629, 1150, 1450], &"lhand"),
		&"5M": _m("Chapa Push Kick", &"normal", "5M", [7, 3, 12], 55, [17, 12], &"mid",
			[200, 1050, 700, 1250], {"button": &"M", "cancel": 2, "strength": 1, "limb": &"rfoot",
			"push": 550}),
		&"5H": _m("Armada Spin Kick", &"normal", "5H", [10, 4, 19], 85, [26, 18], &"mid",
			[150, 861, 1050, 1650], {"button": &"H", "cancel": 1, "strength": 2, "limb": &"rfoot",
			"push": 750}),
		&"2L": _light("Rasteira Tap", "2L", &"L", &"crouch", [150, 860, 0, 380], &"rfoot",
			{"guard": &"low", "startup": 5, "recovery": 8, "damage": 25, "hitstun": 11, "blockstun": 8}),
		&"2M": _m("Low Ponteira", &"normal", "2M", [6, 3, 12], 50, [16, 11], &"mid",
			[150, 855, 500, 900], {"button": &"M", "stance": &"crouch", "cancel": 2, "strength": 1,
			"limb": &"lfoot"}),
		&"2H": _m("Bananeira Upkick", &"normal", "2H", [8, 4, 24], 70, [20, 12], &"mid",
			[0, 450, 800, 2000], {"button": &"H", "stance": &"crouch", "cancel": 1, "strength": 2,
			"launch": [20, 135], "limb": &"rfoot", "low_profile": [1, 10]}),
		&"3H": _m("Half-Moon Sweep", &"command", "3H", [9, 4, 22], 75, [20, 14], &"low",
			[150, 983, 0, 320], {"button": &"H", "dir": 3, "stance": &"crouch", "strength": 2,
			"knockdown": true, "limb": &"rfoot", "push": 500}),
		&"6M": _m("Flip Heel", &"command", "6M", [18, 2, 13], 55, [18, 12], &"overhead",
			[150, 850, 900, 1800], {"button": &"M", "dir": 6, "strength": 1, "limb": &"rfoot",
			"airborne": [5, 17], "vel": [[4, 17, 25, 0]]}),
		&"6H": _m("Hooking Heel", &"command", "6H", [13, 3, 19], 80, [22, 16], &"mid",
			[200, 941, 1000, 1600], {"button": &"H", "dir": 6, "strength": 2, "wall_bounce": true,
			"limb": &"rfoot", "push": 900, "vel": [[2, 10, 30, 0]]}),
		&"j.L": _m("Air Toe Flick", &"normal", "j.L", [4, 8, 0], 30, [12, 9], &"high",
			[60, 620, 200, 800], {"button": &"L", "stance": &"air", "limb": &"lfoot"}),
		&"j.M": _m("Air Scissor", &"normal", "j.M", [6, 6, 0], 50, [16, 12], &"high",
			[-120, 800, 200, 900], {"button": &"M", "stance": &"air", "strength": 1, "limb": &"rfoot"}),
		&"j.H": _m("Air Spin Kick", &"normal", "j.H", [8, 6, 0], 80, [20, 15], &"high",
			[-200, 1000, 300, 1000], {"button": &"H", "stance": &"air", "strength": 2, "limb": &"rfoot"}),
		&"5L>M": _m("Tornado Step", &"target", "5L > M", [6, 3, 13], 45, [17, 12], &"mid",
			[150, 950, 900, 1500], {"button": &"M", "chain_from": &"5L", "cancel": 1, "strength": 1,
			"limb": &"lfoot"}),
		&"2M>H": _m("Spin to Sweep", &"target", "2M > H", [9, 3, 22], 75, [20, 13], &"low",
			[150, 983, 0, 320], {"button": &"H", "chain_from": &"2M", "stance": &"crouch",
			"strength": 2, "knockdown": true, "limb": &"rfoot"}),
		&"crescent_wheel": _m("Crescent Wheel", &"technique", "236 + attack", [11, 8, 18], 105,
			[22, 15], &"mid", [100, 911, 700, 1600], {"motion": &"236", "strength": 3,
			"vel": [[3, 18, 75, 0]], "rehit": 5, "hits": 2, "limb": &"rfoot", "super_cancel": true}),
		&"flip_kick": _m("Flip Kick", &"technique", "623 + attack", [4, 8, 30], 115, [24, 15],
			&"mid", [-100, 459, 700, 2100], {"motion": &"623", "strength": 3, "invuln": [1, 8],
			"throw_invuln": [1, 8], "airborne": [3, 41], "vel": [[3, 10, -10, 95]],
			"launch": [20, 120], "limb": &"rfoot", "super_cancel": true, "landing": 0}),
		&"cartwheel": _m("Cartwheel Evade", &"technique", "214 + attack", [0, 0, 26], 0, [0, 0],
			&"none", [], {"motion": &"214", "evade": true, "invuln": [3, 18], "vel": [[2, 20, 95, 0]],
			"pass_through": [2, 22], "strength": 0, "startup": 1}),
		&"dive_kick": _m("Tumbling Dive Kick", &"technique", "j.2 + H (air)", [6, 30, 0], 70,
			[16, 9], &"high", [0, 491, -100, 500], {"stance": &"air", "button": &"H", "dir": 2,
			"strength": 2, "vel": [[6, 60, 95, -130]], "landing": 10, "limb": &"rfoot",
			"tracks_land": true}),
		&"hurricane_ginga": _m("Hurricane Ginga", &"finisher", "236236 + attack / finisher key", [5, 6, 42],
			310, [40, 20], &"mid", [100, 916, 500, 1700], {"motion": &"236236", "strength": 3,
			"invuln": [1, 11], "throw_invuln": [1, 11], "vel": [[3, 10, 160, 0]], "cinematic": 100,
			"limb": &"rfoot"}),
		&"throw": _m("Scissor Takedown", &"throw", "throw (close)", [5, 2, 23], 110, [0, 0], &"throw",
			[0, THROW_RANGE, 0, 1800], {"grab": true, "range": THROW_RANGE, "strength": 2,
			"limb": &"lhand"}),
	}


static func _lyra() -> Dictionary:
	return {
		&"5L": _light("Lead Jab", "5L", &"L", &"stand", [180, 800, 1200, 1480], &"lhand"),
		&"5M": _m("Fouetté", &"normal", "5M", [7, 3, 12], 55, [17, 12], &"mid",
			[220, 1040, 900, 1450], {"button": &"M", "cancel": 2, "strength": 1, "limb": &"rfoot"}),
		&"5H": _m("Chassé", &"normal", "5H", [10, 3, 20], 85, [26, 18], &"mid",
			[220, 1088, 850, 1300], {"button": &"H", "cancel": 1, "strength": 2, "limb": &"rfoot",
			"push": 850}),
		&"2L": _light("Low Coup de Pied", "2L", &"L", &"crouch", [160, 950, 0, 360], &"lfoot",
			{"guard": &"low", "startup": 5, "recovery": 9, "damage": 25, "hitstun": 12, "blockstun": 9}),
		&"2M": _m("Low Fouetté", &"normal", "2M", [7, 3, 12], 50, [16, 11], &"mid",
			[180, 943, 450, 850], {"button": &"M", "stance": &"crouch", "cancel": 2, "strength": 1,
			"limb": &"rfoot"}),
		&"2H": _m("Fan Kick Launcher", &"normal", "2H", [8, 4, 24], 70, [20, 12], &"mid",
			[60, 450, 900, 2050], {"button": &"H", "stance": &"crouch", "cancel": 1, "strength": 2,
			"launch": [25, 132], "limb": &"rfoot"}),
		&"3H": _m("Revers Sweep", &"command", "3H", [9, 3, 23], 75, [20, 14], &"low",
			[150, 1055, 0, 300], {"button": &"H", "dir": 3, "stance": &"crouch", "strength": 2,
			"knockdown": true, "limb": &"lfoot", "push": 500}),
		&"6M": _m("Hopping Axe", &"command", "6M", [18, 2, 14], 55, [18, 12], &"overhead",
			[200, 950, 900, 1900], {"button": &"M", "dir": 6, "strength": 1, "limb": &"rfoot",
			"airborne": [4, 17], "vel": [[3, 17, 20, 0]]}),
		&"4H": _m("Spinning Back Kick", &"command", "4H", [13, 3, 19], 85, [22, 16], &"mid",
			[200, 953, 850, 1400], {"button": &"H", "dir": 4, "strength": 2, "wall_bounce": true,
			"limb": &"rfoot", "push": 900}),
		&"j.L": _m("Air Snap Kick", &"normal", "j.L", [4, 8, 0], 30, [12, 9], &"high",
			[60, 640, 300, 900], {"button": &"L", "stance": &"air", "limb": &"lfoot"}),
		&"j.M": _m("Air Crescent", &"normal", "j.M", [6, 6, 0], 50, [16, 12], &"high",
			[100, 880, 400, 1200], {"button": &"M", "stance": &"air", "strength": 1, "limb": &"rfoot"}),
		&"j.H": _m("Air Thrust Kick", &"normal", "j.H", [8, 6, 0], 80, [20, 15], &"high",
			[100, 1050, 100, 700], {"button": &"H", "stance": &"air", "strength": 2, "limb": &"rfoot"}),
		&"5M>M": _m("Double Fouetté", &"target", "5M > M", [6, 3, 15], 50, [17, 11], &"mid",
			[220, 956, 1200, 1700], {"button": &"M", "chain_from": &"5M", "cancel": 1, "strength": 1,
			"limb": &"rfoot"}),
		&"5L>H": _m("Jab-Chassé", &"target", "5L > H", [8, 3, 20], 80, [22, 16], &"mid",
			[220, 1086, 850, 1300], {"button": &"H", "chain_from": &"5L", "strength": 2,
			"limb": &"rfoot", "launch": [75, 65], "juggle": 2}),
		&"vaulting_axe": _m("Vaulting Axe", &"technique", "236 + attack", [21, 3, 16], 95, [22, 14],
			&"overhead", [100, 749, 600, 2000], {"motion": &"236", "strength": 3, "airborne": [4, 20],
			"vel": [[3, 20, 85, 0]], "limb": &"rfoot", "ground_bounce": true}),
		&"rising_crescent": _m("Rising Crescent", &"technique", "623 + attack", [4, 8, 30], 115,
			[24, 15], &"mid", [0, 452, 800, 2150], {"motion": &"623", "strength": 3, "invuln": [1, 8],
			"throw_invuln": [1, 8], "airborne": [3, 39], "vel": [[3, 10, 20, 95]],
			"launch": [25, 122], "limb": &"rfoot", "super_cancel": true, "landing": 0}),
		&"starguard": _m("Starguard Counter", &"technique", "214 + attack", [3, 0, 24], 110, [30, 0],
			&"none", [], {"motion": &"214", "strength": 3, "counter": [3, 22], "limb": &"rfoot",
			"startup": 1, "active": 0}),
		&"constellation": _m("Constellation Rush", &"finisher", "236236 + attack / finisher key", [6, 6, 40],
			315, [40, 20], &"mid", [100, 1027, 700, 1700], {"motion": &"236236", "strength": 3,
			"invuln": [1, 12], "throw_invuln": [1, 12], "vel": [[3, 10, 155, 0]], "cinematic": 96,
			"limb": &"rfoot"}),
		&"throw": _m("Savate Hip Toss", &"throw", "throw (close)", [5, 2, 23], 110, [0, 0], &"throw",
			[0, THROW_RANGE, 0, 1800], {"grab": true, "range": THROW_RANGE, "strength": 2,
			"limb": &"lhand"}),
	}


static func _brann() -> Dictionary:
	return {
		&"5L": _light("Gauntlet Jab", "5L", &"L", &"stand", [180, 860, 1150, 1450], &"lhand",
			{"startup": 5, "recovery": 8, "damage": 35, "hitstun": 13, "blockstun": 9}),
		&"5M": _m("Body Hook", &"normal", "5M", [8, 3, 13], 65, [18, 12], &"mid",
			[150, 900, 900, 1350], {"button": &"M", "cancel": 2, "strength": 1, "push": 500}),
		&"5H": _m("Haymaker", &"normal", "5H", [13, 4, 21], 100, [28, 18], &"mid",
			[200, 1080, 1100, 1650], {"button": &"H", "cancel": 1, "strength": 2, "push": 800,
			"vel": [[2, 12, 20, 0]]}),
		&"2L": _light("Toe Stomp", "2L", &"L", &"crouch", [150, 760, 0, 380], &"rfoot",
			{"guard": &"low", "startup": 6, "recovery": 9, "damage": 30, "hitstun": 12, "blockstun": 8}),
		&"2M": _m("Gut Uppercut", &"normal", "2M", [7, 3, 13], 60, [17, 11], &"mid",
			[150, 576, 700, 1250], {"button": &"M", "stance": &"crouch", "cancel": 2, "strength": 1}),
		&"2H": _m("Lifting Uppercut", &"normal", "2H", [9, 4, 25], 80, [21, 12], &"mid",
			[60, 512, 900, 2000], {"button": &"H", "stance": &"crouch", "cancel": 1, "strength": 2,
			"launch": [25, 128]}),
		&"3H": _m("Trip Hook", &"command", "3H", [10, 3, 24], 85, [20, 14], &"low",
			[150, 1050, 0, 350], {"button": &"H", "dir": 3, "stance": &"crouch", "strength": 2,
			"knockdown": true, "limb": &"rfoot", "push": 500}),
		&"6M": _m("Hammer Drop", &"command", "6M", [20, 3, 15], 70, [19, 12], &"overhead",
			[150, 670, 1000, 1900], {"button": &"M", "dir": 6, "strength": 1, "vel": [[3, 18, 18, 0]]}),
		&"6H": _m("Armoured Shoulder", &"command", "6H", [16, 4, 18], 90, [22, 16], &"mid",
			[150, 850, 900, 1600], {"button": &"H", "dir": 6, "strength": 2, "armor": [5, 16],
			"wall_bounce": true, "push": 900, "vel": [[4, 18, 45, 0]], "limb": &"rshoulder"}),
		&"j.L": _m("Air Elbow", &"normal", "j.L", [5, 7, 0], 35, [12, 9], &"high",
			[60, 450, 500, 1100], {"button": &"L", "stance": &"air", "limb": &"lhand"}),
		&"j.M": _m("Air Hammer", &"normal", "j.M", [7, 6, 0], 60, [16, 12], &"high",
			[100, 760, 400, 1300], {"button": &"M", "stance": &"air", "strength": 1}),
		&"j.H": _m("Body Splash", &"normal", "j.H", [9, 8, 0], 90, [20, 15], &"high",
			[-200, 800, -100, 800], {"button": &"H", "stance": &"air", "strength": 2,
			"limb": &"rshoulder"}),
		&"5L>M": _m("One-Two Hook", &"target", "5L > M", [7, 3, 14], 55, [18, 12], &"mid",
			[150, 880, 1050, 1450], {"button": &"M", "chain_from": &"5L", "cancel": 1, "strength": 1}),
		&"5M>H": _m("Hook-Haymaker", &"target", "5M > H", [11, 4, 22], 95, [24, 15], &"mid",
			[200, 1050, 1100, 1650], {"button": &"H", "chain_from": &"5M", "strength": 2,
			"launch": [80, 60], "push": 900, "juggle": 2}),
		&"bull_charge": _m("Bull Charge", &"technique", "236 + attack", [14, 6, 18], 105, [24, 16],
			&"mid", [100, 800, 800, 1600], {"motion": &"236", "strength": 3, "armor": [4, 19],
			"vel": [[4, 19, 120, 0]], "push": 900, "limb": &"rshoulder", "super_cancel": true}),
		&"gauntlet_uppercut": _m("Gauntlet Uppercut", &"technique", "623 + attack", [5, 7, 31], 125,
			[24, 15], &"mid", [0, 505, 800, 2050], {"motion": &"623", "strength": 3, "invuln": [1, 8],
			"throw_invuln": [1, 8], "airborne": [5, 30], "vel": [[4, 10, 20, 90]],
			"launch": [25, 118], "super_cancel": true, "landing": 0}),
		&"iron_suplex": _m("Iron Suplex", &"technique", "214 + attack", [6, 3, 32], 160, [0, 0],
			&"throw", [0, 1050, 0, 1800], {"motion": &"214", "strength": 3, "grab": true,
			"range": 1050, "limb": &"lhand", "unbreakable": true}),
		&"mountain_drop": _m("Mountain Drop", &"finisher", "236236 + attack / finisher key", [5, 3, 42], 330,
			[0, 0], &"throw", [0, 1150, 0, 1800], {"motion": &"236236", "strength": 3,
			"invuln": [1, 8], "throw_invuln": [1, 8], "grab": true, "range": 1150,
			"unbreakable": true, "cinematic": 104, "limb": &"lhand"}),
		&"throw": _m("Bear Hug Toss", &"throw", "throw (close)", [5, 2, 23], 130, [0, 0], &"throw",
			[0, THROW_RANGE, 0, 1800], {"grab": true, "range": THROW_RANGE, "strength": 2,
			"limb": &"lhand"}),
	}
