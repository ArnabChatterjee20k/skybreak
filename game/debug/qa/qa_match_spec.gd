class_name QaMatchSpec
extends RefCounted
## One soak match: seed, zone, mode and the legends with their AI levels. Encodes to a
## short id (`seed:zone:mode:legends:levels`) that the repro command takes back.

const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]
const MODES: Array[StringName] = [&"1v1", &"ffa4", &"2v2"]
const MIN_LEVEL := 2
const MAX_LEVEL := 5

var seed_value: int = 1
var zone: StringName = &"heartbloom_gardens"
var mode: StringName = &"1v1"
var legends: Array[StringName] = []
var levels: Array[int] = []


func fighter_count() -> int:
	return 2 if mode == &"1v1" else 4


## Team per slot: 1v1 and FFA everyone alone, 2v2 slots 0-1 against 2-3.
func team_of(slot: int) -> int:
	return slot / 2 if mode == &"2v2" else slot


## The ZoneMatch / AIDriver fighter list.
func fighters() -> Array:
	var out: Array = []
	for slot in fighter_count():
		out.append({"character": legends[slot], "team": team_of(slot), "is_ai": true, "ai_level": levels[slot]})
	return out


func id() -> String:
	var level_text := PackedStringArray()
	for level in levels:
		level_text.append(str(level))
	return "%d:%s:%s:%s:%s" % [seed_value, zone, mode, ",".join(PackedStringArray(legends)), "".join(level_text)]


static func parse(text: String) -> QaMatchSpec:
	var parts := text.split(":")
	var spec := QaMatchSpec.new()
	spec.seed_value = int(parts[0])
	spec.zone = StringName(parts[1])
	spec.mode = StringName(parts[2])
	for legend in parts[3].split(","):
		spec.legends.append(StringName(legend))
	for digit in parts[4]:
		spec.levels.append(int(digit))
	return spec


## A seeded spec for one (zone, mode, first legend) cell; the others rotate.
static func make(seed_value: int, zone_id: StringName, mode_id: StringName, first_legend: int) -> QaMatchSpec:
	var spec := QaMatchSpec.new()
	spec.seed_value = seed_value
	spec.zone = zone_id
	spec.mode = mode_id
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	for slot in spec.fighter_count():
		spec.legends.append(LEGENDS[(first_legend + slot) % LEGENDS.size()])
		spec.levels.append(rng.randi_range(MIN_LEVEL, MAX_LEVEL))
	return spec


## Every legend x zone x mode cell, `repeats` seeds each (the --full matrix).
static func full_matrix(repeats: int = 3) -> Array[QaMatchSpec]:
	var out: Array[QaMatchSpec] = []
	var zones := ZoneLayout.ZONE_IDS
	for repeat in repeats:
		for z in zones.size():
			for m in MODES.size():
				for l in LEGENDS.size():
					var seed_value := 1000 + repeat * 1000 + z * 100 + m * 10 + l
					out.append(make(seed_value, zones[z], MODES[m], l))
	return out


## About 20 matches covering every legend, zone and mode (the --quick matrix).
static func quick_matrix() -> Array[QaMatchSpec]:
	var out: Array[QaMatchSpec] = []
	var zones := ZoneLayout.ZONE_IDS
	for i in 21:
		var z := i % zones.size()
		var m := i % MODES.size()
		var l := (i / 3) % LEGENDS.size()
		out.append(make(100 + i, zones[z], MODES[m], l))
	return out
