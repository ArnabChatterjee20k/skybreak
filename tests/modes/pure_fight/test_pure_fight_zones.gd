extends GutTest
## A scripted bot-vs-bot Pure Fight match of 3 rounds in every zone: the platform is flat, the
## side camera frames both fighters every checked frame and never sits under the ground, the
## match ends, and across the zones every legend uses every move.

const ZONES: Array[StringName] = [&"heartbloom_gardens", &"skyhold_ruins", &"shattered_mesa",
	&"stormfall_city", &"frozen_peaks", &"verdant_falls", &"ember_rift"]
const PAIRS := [[&"kael", &"vexa"], [&"lyra", &"brann"], [&"vexa", &"lyra"], [&"brann", &"kael"],
	[&"kael", &"lyra"], [&"vexa", &"brann"], [&"lyra", &"kael"]]
const MAX_TICKS := 16000

var _used: Dictionary = {}


func _play(zone: StringName, index: int) -> Dictionary:
	var pair: Array = PAIRS[index]
	var level := PureFightMatch.new()
	level.configure({"zone": zone, "seed": 11 + index, "voxel_zone": false, "fighters": [
		{"character": pair[0], "is_ai": true, "ai_level": 5},
		{"character": pair[1], "is_ai": true, "ai_level": 5}]})
	add_child(level)
	for i in 2:
		(level.drivers[i] as PureFightAI).explore = 0.6
	var framed := 0
	var checked := 0
	var under := 0
	var rounds_seen := 0
	for t in MAX_TICKS:
		level.step_tick()
		for e in level.sim.events:
			if e.type == PureFightSim.Ev.ROUND_WIN or e.type == PureFightSim.Ev.TIME_UP:
				rounds_seen += 1
		if t % 3 == 0:
			level.present_frame(1.0, 3.0 / 60.0)
			if level.sim.phase == PureFightSim.Phase.FIGHT:
				checked += 1
				var a := level.views[0].position + Vector3.UP
				var b := level.views[1].position + Vector3.UP
				if level.camera.frames_point(a, 0.0) and level.camera.frames_point(b, 0.0):
					framed += 1
				var eye := level.camera.global_position
				if eye.y < level.ground.height_at(eye.x, eye.z, INF) + 0.3:
					under += 1
		if level.sim.is_match_over():
			break
	for i in 2:
		var legend: StringName = level.sim.pf[i].legend
		for id in (level.drivers[i] as PureFightAI).used:
			_used["%s:%s" % [legend, id]] = true
	var result := {"over": level.sim.is_match_over(), "framed": float(framed) / maxf(checked, 1),
		"under": under, "rough": level.stage.roughness, "rounds": rounds_seen,
		"floor": level.stage.floor_y, "ground": level.ground.height_at(level.stage.origin.x, level.stage.origin.z, INF)}
	level.queue_free()
	await get_tree().process_frame
	return result


func test_a_three_round_bot_match_plays_cleanly_in_every_zone() -> void:
	for i in ZONES.size():
		var zone := ZONES[i]
		var result: Dictionary = await _play(zone, i)
		assert_true(result.over, "%s: the match finished" % zone)
		assert_gte(int(result.rounds), 2, "%s: at least two rounds decided" % zone)
		assert_gte(float(result.framed), 0.99, "%s: both fighters framed (%.3f)" % [zone, result.framed])
		assert_eq(int(result.under), 0, "%s: camera above the ground" % zone)
		assert_lt(float(result.rough), 1.5, "%s: a flat spot (%.2f m spread)" % [zone, result.rough])
		assert_gte(float(result.floor), float(result.ground), "%s: the slab sits on the ground" % zone)
	var missing: Array[String] = []
	for legend in PureMoves.LEGENDS:
		for id in PureMoves.ids(legend):
			if not _used.has("%s:%s" % [legend, id]):
				missing.append("%s:%s" % [legend, id])
	assert_eq(missing, [] as Array[String], "every move used at least once")
