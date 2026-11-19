extends GutTest

const DIRECTOR := preload("res://game/audio/music/music_director.gd")
const FRAME := 1.0 / 60.0
const CALM := MusicIntensity.Level.CALM
const COMBAT := MusicIntensity.Level.COMBAT
const CLIMAX := MusicIntensity.Level.CLIMAX

var _music: Node


func before_each() -> void:
	_music = DIRECTOR.new()
	add_child_autofree(_music)
	_music.set_process(false)


func _play(seconds: float) -> void:
	var left := seconds
	while left > 1e-9:
		_music.advance(minf(FRAME, left))
		left -= FRAME


func _bar(track: StringName) -> float:
	var info: Dictionary = MusicCatalog.BATTLE[track] if MusicCatalog.BATTLE.has(track) else MusicCatalog.SINGLE[track]
	return 60.0 / info.bpm * info.beats_per_bar


func test_it_routes_to_a_music_bus() -> void:
	assert_ne(AudioServer.get_bus_index(&"Music"), -1)


func test_the_menu_starts_at_once_when_nothing_plays() -> void:
	_music.play_menu()
	assert_eq(_music.current_track, &"menu")
	assert_eq(_music.track_gain(&"menu"), 1.0)


func test_a_battle_starts_calm() -> void:
	_music.start_battle(&"stormfall_city")
	assert_eq(_music.layer_gains(), PackedFloat32Array([1.0, 0.0, 0.0]))


func test_intensity_raises_layers_on_the_next_bar_line() -> void:
	_music.start_battle(&"stormfall_city")
	_play(_bar(&"stormfall_city") * 0.5)
	_music.set_level(CLIMAX)
	_play(_bar(&"stormfall_city") * 0.4)
	assert_eq(_music.layer_gains(), PackedFloat32Array([1.0, 0.0, 0.0]), "waits for the bar")
	_play(_bar(&"stormfall_city") * 0.6)
	assert_eq(_music.layer_gains(), PackedFloat32Array([1.0, 1.0, 1.0]))
	var bars: float = _music.live_layers().last_commit_time / _bar(&"stormfall_city")
	assert_almost_eq(bars, 1.0, 1e-6)


func test_the_sim_drives_the_layers() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -6))
	_music.start_battle(&"frozen_peaks")
	_music.observe_sim(sim)
	_play(_bar(&"frozen_peaks") * 1.5)
	assert_eq(_music.layer_gains(), PackedFloat32Array([1.0, 1.0, 0.0]))


func test_a_zone_change_crossfades_from_the_next_bar_line() -> void:
	_music.start_battle(&"shattered_mesa")
	_play(_bar(&"shattered_mesa") * 0.3)
	_music.set_zone(&"ember_rift")
	assert_eq(_music.current_track, &"shattered_mesa", "waits for the bar line")
	_play(_bar(&"shattered_mesa") * 0.71)
	assert_eq(_music.current_track, &"ember_rift")
	assert_lt(_music.song_time(), 0.05, "the new theme starts on its own bar 1")
	_play(_bar(&"shattered_mesa") * 0.5)
	assert_between(_music.track_gain(&"shattered_mesa"), 0.01, 0.99, "old theme fading out")
	assert_between(_music.track_gain(&"ember_rift"), 0.01, 0.99, "new theme fading in")
	_play(_bar(&"shattered_mesa") * 0.6)
	assert_eq(_music.track_gain(&"shattered_mesa"), 0.0)
	assert_eq(_music.track_gain(&"ember_rift"), 1.0)


func test_a_zone_change_keeps_the_intensity_level() -> void:
	_music.start_battle(&"verdant_falls")
	_music.set_level(COMBAT)
	_play(_bar(&"verdant_falls") * 1.1)
	_music.set_zone(&"heartbloom_gardens")
	_play(_bar(&"verdant_falls") * 1.1)
	assert_eq(_music.current_track, &"heartbloom_gardens")
	assert_eq(_music.live_layers().level, COMBAT)


func test_a_ko_stinger_cuts_the_loop_and_then_restores_it() -> void:
	_music.start_battle(&"skyhold_ruins")
	_play(2.0)
	_music.round_ended(false, false)
	assert_eq(_music.stinger, &"defeat")
	_play(0.1)
	assert_eq(_music.track_gain(&"skyhold_ruins"), 0.0, "loop cut")
	var length: float = MusicCatalog.SINGLE[&"defeat"].samples / 44100.0
	_play(length)
	assert_eq(_music.stinger, &"", "stinger over")
	assert_eq(_music.current_track, &"skyhold_ruins", "loop restored")
	assert_lt(_music.song_time(), 0.5, "from its start")
	_play(1.0)
	assert_eq(_music.track_gain(&"skyhold_ruins"), 1.0)


func test_the_match_win_plays_the_victory_jingle() -> void:
	_music.start_battle(&"skyhold_ruins")
	_music.round_ended(true, true)
	assert_eq(_music.stinger, &"victory")


func test_a_track_asked_for_during_a_stinger_plays_after_it() -> void:
	_music.start_battle(&"skyhold_ruins")
	_music.round_ended(true, true)
	_music.play_menu()
	_play(MusicCatalog.SINGLE[&"victory"].samples / 44100.0 + 0.1)
	assert_eq(_music.current_track, &"menu")


func test_a_new_round_returns_to_calm() -> void:
	_music.start_battle(&"stormfall_city")
	_music.set_level(CLIMAX)
	_play(_bar(&"stormfall_city") * 1.5)
	_music.round_started()
	_play(_bar(&"stormfall_city") * 1.5)
	assert_eq(_music.layer_gains(), PackedFloat32Array([1.0, 0.0, 0.0]))


func test_pause_low_passes_and_ducks() -> void:
	_music.play_menu()
	_music.set_paused(true)
	_music.advance(FRAME)
	var bus := AudioServer.get_bus_index(&"Music")
	var enabled := false
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter and AudioServer.is_bus_effect_enabled(bus, i):
			enabled = true
	assert_true(enabled, "low-pass on")
	assert_lt(_music.get_children()[0].volume_db, -6.0, "ducked")
	_music.set_paused(false)
	_music.advance(FRAME)
	assert_almost_eq(_music.get_children()[0].volume_db, 0.0, 0.01)


func test_menus_switch_on_a_bar_line() -> void:
	_music.play_menu()
	_play(0.2)
	_music.play_character_select()
	assert_eq(_music.current_track, &"menu")
	_play(_bar(&"menu"))
	assert_eq(_music.current_track, &"character_select")


func test_crossing_back_before_the_bar_line_keeps_the_theme_playing() -> void:
	_music.start_battle(&"frozen_peaks")
	_play(0.3)
	_music.set_zone(&"ember_rift")
	_music.set_zone(&"frozen_peaks")
	var before: float = _music.song_time()
	_play(_bar(&"frozen_peaks"))
	assert_eq(_music.current_track, &"frozen_peaks")
	assert_almost_eq(_music.song_time(), before + _bar(&"frozen_peaks"), 0.02, "no restart")
	assert_eq(_music.track_gain(&"frozen_peaks"), 1.0)
