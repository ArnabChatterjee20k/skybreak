extends GutTest
## Pure Fight golden replays: recorded inputs must reproduce every recorded state hash.
## Intended sim changes re-bless with tools/diag/pure_fight_record_goldens.gd.

const DIR := "res://tests/combat/pure_fight/goldens"


func test_every_golden_replay_reproduces_its_hashes() -> void:
	var files := DirAccess.get_files_at(DIR)
	var count := 0
	for name in files:
		if not name.ends_with(".json"):
			continue
		var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(name)))
		var drift := PureFightGolden.first_drift(golden)
		assert_eq(drift, -1, "%s drifts first at tick %d" % [name, drift])
		count += 1
	assert_gte(count, 4, "four goldens")
