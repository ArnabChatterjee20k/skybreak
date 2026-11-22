class_name MatchRules
extends RefCounted
## Builds and checks match configs:
## {zone, fighters: [{character, team, is_ai, ai_level}], rounds, mode}.

const MODE_VS_AI := &"vs_ai"
const MODE_FFA := &"ffa"
const MODE_TRAINING := &"training"
const MODE_DUO := &"duo"
## Pure Fight (GAME_DESIGN §16): 2.5D 1v1, P2 an AI or a second local player.
const MODE_PURE_FIGHT := &"pure_fight"
const MODE_PURE_FIGHT_TRAINING := &"pure_fight_training"

const MIN_AI_LEVEL := 1
const MAX_AI_LEVEL := 5
const DEFAULT_ROUNDS := 3
## Fighter count limits per mode (min, max).
const FIGHTER_LIMITS := {
	MODE_VS_AI: Vector2i(2, 4),
	MODE_FFA: Vector2i(2, 4),
	MODE_TRAINING: Vector2i(2, 2),
	MODE_DUO: Vector2i(3, 6),
	MODE_PURE_FIGHT: Vector2i(2, 2),
	MODE_PURE_FIGHT_TRAINING: Vector2i(2, 2),
}

## One fighter entry, clamped to the valid ranges.
static func fighter(character: StringName, team: int, is_ai: bool, ai_level: int = 3) -> Dictionary:
	return {
		"character": character,
		"team": maxi(team, 0),
		"is_ai": is_ai,
		"ai_level": clampi(ai_level, MIN_AI_LEVEL, MAX_AI_LEVEL),
	}


## Vs AI: one human against 1-3 AIs (each {character, ai_level}), each AI on its own team.
static func build_vs_ai(player: StringName, ais: Array, zone_id: StringName, round_count: int = DEFAULT_ROUNDS) -> Dictionary:
	var list: Array[Dictionary] = [fighter(player, 0, false)]
	for i in mini(ais.size(), 3):
		list.append(fighter(ais[i].character, i + 1, true, ais[i].get("ai_level", 3)))
	return make(MODE_VS_AI, zone_id, list, round_count)


## Free-for-all: 2-4 fighters, everyone on their own team unless a team is given.
static func build_ffa(entries: Array, zone_id: StringName, round_count: int = DEFAULT_ROUNDS) -> Dictionary:
	var list: Array[Dictionary] = []
	for i in mini(entries.size(), 4):
		var e: Dictionary = entries[i]
		list.append(fighter(e.character, e.get("team", i), e.get("is_ai", i > 0), e.get("ai_level", 3)))
	return make(MODE_FFA, zone_id, list, round_count)


static func is_pure_fight(mode_id: StringName) -> bool:
	return mode_id == MODE_PURE_FIGHT or mode_id == MODE_PURE_FIGHT_TRAINING


static func make(mode_id: StringName, zone_id: StringName, list: Array[Dictionary], round_count: int) -> Dictionary:
	return {"zone": zone_id, "fighters": list, "rounds": maxi(round_count, 1), "mode": mode_id}


## Empty when the config can start; otherwise why not.
static func problems(config: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var list: Array = config.get("fighters", [])
	var limits: Vector2i = FIGHTER_LIMITS.get(config.get("mode", &""), Vector2i(2, 4))
	if list.size() < limits.x or list.size() > limits.y:
		out.append("needs %d-%d fighters" % [limits.x, limits.y])
	var humans := 0
	var teams := {}
	for entry: Dictionary in list:
		if not entry.is_ai:
			humans += 1
		teams[entry.team] = true
	if humans == 0:
		out.append("needs a human player")
	if teams.size() < 2 and list.size() >= 2:
		out.append("needs at least two teams")
	if String(config.get("zone", "")).is_empty():
		out.append("needs a zone")
	return out
