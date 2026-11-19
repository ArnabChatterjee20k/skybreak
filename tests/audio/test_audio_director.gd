extends GutTest

const DIRECTOR := preload("res://game/audio/audio_director.gd")

var _director: Node


func before_each() -> void:
	_director = DIRECTOR.new()
	_director.settings = AudioSettings.new()
	_director.rng.seed = 5
	add_child_autofree(_director)
	_director.set_process(false)


func after_each() -> void:
	_director.duck_offset_db = 0.0
	_director.set_bus_volume(AudioBuses.MUSIC, 1.0, false)


func test_a_cue_never_plays_more_voices_than_its_limit() -> void:
	var cue: SoundCue = _director.cues[&"hit_heavy"]
	for i in cue.max_voices + 3:
		_director.advance(cue.cooldown + 0.01)
		assert_not_null(_director.play(&"hit_heavy", Vector3.ZERO), "play %d starts, stealing if needed" % i)
		assert_lte(_director.voices_playing(&"hit_heavy"), cue.max_voices)
	assert_eq(_director.voices_playing(&"hit_heavy"), cue.max_voices)


func test_the_cooldown_stops_a_cue_machine_gunning() -> void:
	assert_not_null(_director.play(&"land_light", Vector3.ZERO))
	assert_null(_director.play(&"land_light", Vector3.ZERO), "refused inside the cooldown")
	_director.advance((_director.cues[&"land_light"] as SoundCue).cooldown + 0.01)
	assert_not_null(_director.play(&"land_light", Vector3.ZERO))


func test_variations_never_repeat_back_to_back() -> void:
	var cue: SoundCue = _director.cues[&"hit_light"]
	var last := -1
	var seen := {}
	for _i in 200:
		var index: int = _director.pick_variation(cue)
		assert_ne(index, last)
		last = index
		seen[index] = true
	assert_eq(seen.size(), cue.streams.size(), "every variation comes up")


func _test_cue(cue_id: StringName, priority: int) -> SoundCue:
	var cue := SoundCue.new()
	cue.id = cue_id
	cue.streams = (_director.cues[&"ko_tail"] as SoundCue).streams
	cue.priority = priority
	cue.max_voices = 100
	_director.cues[cue_id] = cue
	return cue


func test_a_full_pool_gives_way_to_a_higher_priority_cue_only() -> void:
	_test_cue(&"test_loud", 80)
	_test_cue(&"test_quiet", 10)
	_test_cue(&"test_top", 100)
	for i in DIRECTOR.POOL_3D:
		_director.advance(0.001)
		assert_not_null(_director.play(&"test_loud", Vector3.ZERO))
	assert_null(_director.play(&"test_quiet", Vector3.ZERO), "a quieter cue is dropped")
	assert_not_null(_director.play(&"test_top", Vector3.ZERO), "a more important cue steals")
	assert_eq(_director.voices_playing(&"test_loud"), DIRECTOR.POOL_3D - 1, "the oldest loud voice went")


func test_the_duck_dips_music_and_ambience_then_restores_them() -> void:
	_director.set_bus_volume(AudioBuses.MUSIC, 0.5, false)
	var music := AudioServer.get_bus_index(AudioBuses.MUSIC)
	var ambience := AudioServer.get_bus_index(AudioBuses.AMBIENCE)
	var base_music := AudioServer.get_bus_volume_db(music)
	assert_almost_eq(base_music, linear_to_db(0.5), 0.01)
	_director.play(&"ko", Vector3.ZERO)
	_director.advance(0.1)
	assert_lt(AudioServer.get_bus_volume_db(music), base_music - 6.0, "music ducks under the KO")
	assert_lt(AudioServer.get_bus_volume_db(ambience), -6.0, "ambience ducks too")
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioBuses.SFX)), 0.0, 0.01,
		"sound effects never duck")
	# KO duck: hold, then release at DUCK_RELEASE_DB_PER_SECOND (T-127: ~3.5 s).
	for _i in 100:
		_director.advance(0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), base_music, 0.01, "music is back")
	assert_almost_eq(AudioServer.get_bus_volume_db(ambience), 0.0, 0.01, "ambience is back")


func test_heavy_hits_layer_a_thump_now_and_the_tail_after_the_hitstop() -> void:
	_director.play(&"hit_heavy", Vector3.ZERO, {"layer_delay": 0.2})
	assert_eq(_director.voices_playing(&"impact_thump"), 1)
	assert_eq(_director.voices_playing(&"impact_tail"), 0)
	_director.advance(0.25)
	assert_eq(_director.voices_playing(&"impact_tail"), 1)


func test_loops_follow_intensity_and_fade_out_when_stopped() -> void:
	_director.set_loop(&"charge_0", &"ki_charge_loop", 0.0, Vector3.ZERO)
	var low_pitch: float = _director.loop_pitch(&"charge_0")
	_director.set_loop(&"charge_0", &"ki_charge_loop", 1.0, Vector3.ZERO)
	assert_gt(_director.loop_pitch(&"charge_0"), low_pitch, "the charge rises in pitch")
	for _i in 30:
		_director.advance(0.05)
	assert_almost_eq(_director.loop_volume_db(&"charge_0"), (_director.cues[&"ki_charge_loop"] as SoundCue).volume_db, 0.5)
	_director.stop_loop(&"charge_0")
	assert_false(_director.is_loop_active(&"charge_0"))
	for _i in 40:
		_director.advance(0.05)
	assert_eq(_director.loop_cue(&"charge_0"), &"", "faded out and freed")


func test_switching_zone_crossfades_to_that_zones_ambience() -> void:
	_director.set_zone(&"stormfall_city")
	assert_eq(_director.loop_cue(DIRECTOR.AMBIENCE_KEY), &"amb_stormfall_city")
	_director.set_zone(&"heartbloom_gardens")
	assert_eq(_director.loop_cue(DIRECTOR.AMBIENCE_KEY), &"amb_heartbloom_gardens")
	assert_eq(_director.loop_cue(&"ambience:old"), &"amb_stormfall_city", "rain fades out underneath")
	for _i in 100:
		_director.advance(0.1)
	assert_eq(_director.loop_cue(&"ambience:old"), &"", "and is gone")
	assert_eq(_director.voices_playing(&"stormfall_thunder"), 0, "no thunder outside Stormfall")


func test_thunder_rolls_only_in_stormfall() -> void:
	_director.set_zone(&"stormfall_city")
	var rolled := false
	for _i in 300:
		_director.advance(0.1)
		rolled = rolled or _director.voices_playing(&"stormfall_thunder") > 0
	assert_true(rolled)


func test_bus_volumes_are_saved_and_loaded() -> void:
	var path := "user://test_audio_settings.cfg"
	var settings := AudioSettings.new()
	settings.set_volume(AudioBuses.SFX, 0.25)
	settings.set_volume(AudioBuses.MUSIC, 0.0)
	assert_eq(settings.save(path), OK)
	var loaded := AudioSettings.load_saved(path)
	assert_almost_eq(loaded.volume(AudioBuses.SFX), 0.25, 0.0001)
	assert_eq(loaded.volume_db(AudioBuses.MUSIC), -80.0, "zero is silent")
	assert_almost_eq(loaded.volume(AudioBuses.UI), 1.0, 0.0001)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
