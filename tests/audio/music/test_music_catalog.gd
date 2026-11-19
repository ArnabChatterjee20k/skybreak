extends GutTest

const SAMPLE_RATE := 44100


func test_every_zone_has_a_battle_theme() -> void:
	for zone in ZoneLayout.ZONE_IDS:
		assert_true(MusicCatalog.BATTLE.has(zone), "theme for %s" % zone)


func test_every_battle_theme_has_three_stems() -> void:
	for zone in MusicCatalog.BATTLE:
		assert_eq(MusicCatalog.BATTLE[zone].stems.size(), MusicCatalog.LAYERS.size(), str(zone))


func test_every_loop_is_a_whole_number_of_bars() -> void:
	for zone in MusicCatalog.BATTLE:
		var info: Dictionary = MusicCatalog.BATTLE[zone]
		var bar_samples: float = 60.0 / info.bpm * info.beats_per_bar * SAMPLE_RATE
		assert_almost_eq(info.loop_samples / bar_samples, float(info.bars), 1e-6, str(zone))


func test_stems_of_a_theme_have_exactly_equal_length() -> void:
	for zone in MusicCatalog.BATTLE:
		var info: Dictionary = MusicCatalog.BATTLE[zone]
		for path in info.stems:
			var stream := load(path) as AudioStreamOggVorbis
			assert_not_null(stream, path)
			if stream:
				assert_almost_eq(stream.get_length() * SAMPLE_RATE, float(info.loop_samples), 0.5, path)


func test_every_stream_loads_as_ogg_vorbis() -> void:
	var paths: Array[String] = []
	for zone in MusicCatalog.BATTLE:
		paths.append_array(MusicCatalog.BATTLE[zone].stems)
	for key in MusicCatalog.SINGLE:
		paths.append(MusicCatalog.SINGLE[key].path)
	assert_eq(paths.size(), 7 * 3 + 4)
	for path in paths:
		var stream := load(path)
		assert_true(stream is AudioStreamOggVorbis, path)


func test_battle_stems_and_menus_are_imported_looping() -> void:
	for zone in MusicCatalog.BATTLE:
		for path in MusicCatalog.BATTLE[zone].stems:
			assert_true((load(path) as AudioStreamOggVorbis).loop, path)
	for key in [&"menu", &"character_select"]:
		assert_true((load(MusicCatalog.SINGLE[key].path) as AudioStreamOggVorbis).loop, str(key))
	for key in [&"victory", &"defeat"]:
		assert_false((load(MusicCatalog.SINGLE[key].path) as AudioStreamOggVorbis).loop, str(key))


func test_stingers_are_short() -> void:
	assert_between(MusicCatalog.SINGLE[&"victory"].samples / float(SAMPLE_RATE), 4.0, 6.5)
	assert_between(MusicCatalog.SINGLE[&"defeat"].samples / float(SAMPLE_RATE), 2.0, 5.0)


func test_every_battle_theme_opens_a_synchronized_playback() -> void:
	for zone in MusicCatalog.BATTLE:
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = 3
		for i in 3:
			sync.set_sync_stream(i, load(MusicCatalog.BATTLE[zone].stems[i]))
		assert_not_null(sync.instantiate_playback(), str(zone))
