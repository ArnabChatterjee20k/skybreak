extends GutTest
## Golden replays: every canonical recorded AI match replays with the same
## state hash on every tick, the recorder round-trips through JSON, and drift
## is caught and explained.

const A := FighterInput.Action
const BLESS_HINT := "If this change is intended, re-record in the PR that intends the change: " \
	+ "tools/qa/bless_goldens.sh --replays, commit the goldens and explain why in the PR."
const SHORT_SPEC := {
	"name": "short_pickups", "seed": 7, "zone": &"heartbloom_gardens", "pickups": true,
	"pickup_interval": [120, 180], "ticks": 360,
	"fighters": [
		{"character": &"lyra", "team": 0, "ai_level": 4, "start": Vector3(0, 1, 6)},
		{"character": &"brann", "team": 1, "ai_level": 3, "start": Vector3(0, 6, -6)},
	],
}


func _short_replay() -> GoldenReplay:
	return GoldenReplay.from_json(GoldenReplay.record(SHORT_SPEC).to_json())


func test_every_canonical_golden_replays_without_drift() -> void:
	for spec in GoldenReplayCatalog.specs():
		var path := GoldenReplayCatalog.path_for(spec.name)
		if not FileAccess.file_exists(path):
			fail_test("%s is missing. Record it: tools/qa/bless_goldens.sh --replays" % path)
			continue
		var result := GoldenReplay.load_file(path).play()
		assert_true(result.ok, "%s\n%s" % [result.message, BLESS_HINT])


func test_every_golden_file_has_a_spec_in_the_catalog() -> void:
	var names: Array = GoldenReplayCatalog.specs().map(func(spec: Dictionary) -> String: return spec.name)
	for file in DirAccess.get_files_at(GoldenReplayCatalog.DIRECTORY):
		if file.ends_with(".json"):
			assert_has(names, file.get_basename(), "%s has no spec in GoldenReplayCatalog" % file)


func test_the_goldens_cover_what_their_specs_expect() -> void:
	for spec in GoldenReplayCatalog.specs():
		var path := GoldenReplayCatalog.path_for(spec.name)
		if FileAccess.file_exists(path):
			var gaps := GoldenReplayCatalog.missing(spec, GoldenReplay.load_file(path))
			assert_true(gaps.is_empty(), "%s: %s" % [spec.name, ", ".join(gaps)])


func test_the_goldens_cover_every_legend() -> void:
	var legends := {}
	for spec in GoldenReplayCatalog.specs():
		for entry: Dictionary in spec.fighters:
			legends[entry.character] = true
	for id in Roster.ids():
		assert_true(legends.has(id), "no golden replay plays %s" % id)


func test_a_recording_round_trips_through_a_saved_file() -> void:
	var recorded := GoldenReplay.record(SHORT_SPEC)
	var path := "user://golden_replay_round_trip.json"
	assert_eq(recorded.save(path), OK)
	var loaded := GoldenReplay.load_file(path)
	DirAccess.remove_absolute(path)
	assert_eq(loaded.hashes, recorded.hashes)
	assert_eq(loaded.digests, recorded.digests)
	assert_eq(loaded.inputs.size(), recorded.inputs.size())
	var mismatches := 0
	for tick_index in recorded.inputs.size():
		for slot in recorded.fighters.size():
			if GoldenReplay._input_words(loaded.inputs[tick_index][slot]) \
					!= GoldenReplay._input_words(recorded.inputs[tick_index][slot]):
				mismatches += 1
	assert_eq(mismatches, 0, "inputs reload bit-identical")
	var result := loaded.play()
	assert_true(result.ok, result.message)


func test_input_floats_reload_bit_identical_including_negative_zero() -> void:
	var replay := _short_replay()
	var input: FighterInput = replay.inputs[10][0]
	input.move = Vector2(-0.0, 0.1)
	input.view_yaw = PI / 7.0 + 1e-15
	input.camera_offset = Vector2(-1e-300, 3.4e38)
	var reloaded := GoldenReplay.from_json(replay.to_json())
	var back: FighterInput = reloaded.inputs[10][0]
	assert_eq(back.view_yaw, PI / 7.0 + 1e-15)
	assert_eq(back.move, input.move)
	assert_lt(1.0 / back.move.x, 0.0, "-0.0 keeps its sign")
	assert_eq(back.camera_offset, input.camera_offset)


func test_a_perturbed_input_is_caught_as_drift_on_the_next_tick() -> void:
	var replay := _short_replay()
	var input: FighterInput = replay.inputs[120][0]
	input.held_actions ^= A.HEAVY
	input.pressed_actions ^= A.HEAVY
	var result := replay.play()
	assert_false(result.ok, "a changed input must drift")
	assert_eq(result.tick, 121, "drift shows right after the changed tick: %s" % result.message)
	assert_string_contains(result.message, "fighter 0 (lyra)")
	assert_string_contains(result.message, "after tick 120")


func test_drift_names_the_field_that_differs() -> void:
	var replay := _short_replay()
	replay.fighters[1].health_percent = 99
	var result := replay.play()
	assert_false(result.ok)
	assert_eq(result.tick, 0, "a setup change drifts before the first tick")
	assert_string_contains(result.message, "fighter 1 (brann) health (now")
	assert_false(result.message.contains("grey_health"), "only the changed field is named: %s" % result.message)


func test_a_changed_hashed_field_list_is_reported_as_such() -> void:
	var replay := _short_replay()
	(replay.fields.fighter as Array).append("future_field")
	var result := replay.play()
	assert_false(result.ok)
	assert_string_contains(result.message, "fighter removed [\"future_field\"]")
