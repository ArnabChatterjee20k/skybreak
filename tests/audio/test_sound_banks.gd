extends GutTest

const DIRECTOR := preload("res://game/audio/audio_director.gd")
const MAX_TOTAL_BYTES := 25 * 1024 * 1024


func _all_cues() -> Dictionary:
	var out := {}
	for path in DIRECTOR.BANK_PATHS:
		var bank: SoundBank = load(path)
		assert_not_null(bank, "%s loads" % path)
		for cue in bank.cues:
			assert_false(out.has(cue.id), "cue %s is in one bank only" % cue.id)
			out[cue.id] = cue
	return out


func test_every_cue_the_mapper_asks_for_is_in_a_bank() -> void:
	var cues := _all_cues()
	for cue_id in CombatAudioMapper.referenced_cues():
		assert_true(cues.has(cue_id), "bank has %s" % cue_id)


func test_every_layer_and_the_thunder_are_in_a_bank() -> void:
	var cues := _all_cues()
	assert_true(cues.has(&"stormfall_thunder"))
	for cue: SoundCue in cues.values():
		for layer in cue.layers:
			assert_true(cues.has(layer), "%s layer %s exists" % [cue.id, layer])


func test_every_stream_loads_with_sound_in_it() -> void:
	var count := 0
	for cue: SoundCue in _all_cues().values():
		assert_gt(cue.streams.size(), 0, "%s has streams" % cue.id)
		for stream in cue.streams:
			assert_true(stream is AudioStreamOggVorbis, "%s is Ogg Vorbis" % cue.id)
			assert_gt(stream.get_length(), 0.03, "%s is not empty" % cue.id)
			count += 1
		assert_true(cue.bus in AudioBuses.ALL, "%s uses a known bus" % cue.id)
		assert_gt(cue.max_voices, 0)
		assert_true(cue.pitch_min <= cue.pitch_max)
	assert_gt(count, 100, "the banks hold the full set")


func test_loops_are_loops_and_ambience_is_2d() -> void:
	var cues := _all_cues()
	for cue_id in CombatAudioMapper.LOOP_CUES:
		assert_true((cues[cue_id] as SoundCue).loop, "%s loops" % cue_id)
	for zone_id in ZoneLayout.ZONE_IDS:
		var cue: SoundCue = cues[StringName("amb_%s" % zone_id)]
		assert_true(cue.loop and not cue.positional, "%s is a 2D loop" % cue.id)
		assert_eq(cue.bus, AudioBuses.AMBIENCE)


func test_all_audio_fits_the_web_budget() -> void:
	var total := 0
	for cue: SoundCue in _all_cues().values():
		for stream in cue.streams:
			total += FileAccess.get_file_as_bytes(stream.resource_path).size()
	assert_lt(total, MAX_TOTAL_BYTES)


func test_bus_layout_has_every_bus_and_a_master_limiter() -> void:
	for bus in AudioBuses.ALL:
		assert_gte(AudioServer.get_bus_index(bus), 0, "bus %s exists" % bus)
	var master := AudioServer.get_bus_index(AudioBuses.MASTER)
	var limited := false
	for i in AudioServer.get_bus_effect_count(master):
		limited = limited or AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter
	assert_true(limited, "Master has a limiter")
	assert_eq(ProjectSettings.get_setting("audio/buses/default_bus_layout"),
		"res://game/audio/default_bus_layout.tres")
