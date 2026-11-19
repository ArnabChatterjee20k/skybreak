extends GutTest

const CALM := MusicIntensity.Level.CALM
const COMBAT := MusicIntensity.Level.COMBAT
const CLIMAX := MusicIntensity.Level.CLIMAX
const FRAME := 1.0 / 60.0

var _clock: BarClock
var _mix: LayerMix
var _time: float


func before_each() -> void:
	# 150 bpm, 4/4: a bar is 1.6 s; 8 bars loop.
	_clock = BarClock.new(150.0, 4, 12.8)
	_mix = LayerMix.new(_clock)
	_time = 0.0


func _play(seconds: float, step: float = FRAME) -> void:
	var left := seconds
	while left > 1e-9:
		var d := minf(step, left)
		var before := _time
		_time = _clock.advanced(_time, d)
		_mix.advance(before, _time)
		left -= d


func test_bar_clock_finds_the_next_bar_line() -> void:
	assert_almost_eq(_clock.bar_seconds(), 1.6, 1e-6)
	assert_almost_eq(_clock.time_to_next_bar(0.5), 1.1, 1e-6)
	assert_eq(_clock.time_to_next_bar(3.2), 0.0)
	assert_eq(_clock.bar_at(3.3), 2)


func test_bar_clock_sees_a_bar_line_across_the_loop_seam() -> void:
	assert_almost_eq(_clock.overshoot_past_bar(12.7, 0.05), 0.05, 1e-6)
	assert_eq(_clock.overshoot_past_bar(0.1, 0.2), -1.0)


func test_the_mix_starts_with_only_the_calm_layer() -> void:
	assert_eq(_mix.gains(), PackedFloat32Array([1.0, 0.0, 0.0]))


func test_layers_stack_upward_with_the_level() -> void:
	assert_eq(LayerMix.target_gains(COMBAT), PackedFloat32Array([1.0, 1.0, 0.0]))
	assert_eq(LayerMix.target_gains(CLIMAX), PackedFloat32Array([1.0, 1.0, 1.0]))


func test_a_request_mid_bar_waits_for_the_bar_line() -> void:
	_play(0.5)
	_mix.request(COMBAT)
	_play(1.0)
	assert_eq(_mix.gains(), PackedFloat32Array([1.0, 0.0, 0.0]), "still inside bar 1")
	_play(0.2)
	assert_almost_eq(_mix.last_commit_time, 1.6, 1e-6, "committed on the bar line")


func test_the_new_layer_fades_in_over_one_beat_after_the_bar_line() -> void:
	_play(0.5)
	_mix.request(COMBAT)
	_play(1.1 + 0.2)
	var mid := _mix.gains()[1]
	assert_between(mid, 0.01, 0.99, "fading")
	_play(_clock.beat_seconds())
	assert_eq(_mix.gains(), PackedFloat32Array([1.0, 1.0, 0.0]))


func test_level_changes_only_ever_land_on_bar_lines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in 200:
		_mix.request(rng.randi_range(CALM, CLIMAX))
		var before := _time
		_time = _clock.advanced(_time, rng.randf_range(0.001, 0.4))
		if _mix.advance(before, _time):
			var bars := _mix.last_commit_time / _clock.bar_seconds()
			assert_almost_eq(bars, roundf(bars), 1e-6, "commit at %f" % _mix.last_commit_time)


func test_a_request_reverted_before_the_bar_line_changes_nothing() -> void:
	_play(0.3)
	_mix.request(CLIMAX)
	_play(0.3)
	_mix.request(CALM)
	_play(2.0)
	assert_eq(_mix.last_commit_time, -1.0)
	assert_eq(_mix.gains(), PackedFloat32Array([1.0, 0.0, 0.0]))


func test_a_commit_across_the_loop_seam_lands_on_bar_one() -> void:
	_play(12.7)
	_mix.request(COMBAT)
	_play(0.2)
	assert_almost_eq(_mix.last_commit_time, 0.0, 1e-6)


func test_a_bigger_frame_still_fades_from_the_bar_line() -> void:
	_play(1.5)
	_mix.request(COMBAT)
	_play(0.1 + _clock.beat_seconds(), 1.0)
	assert_eq(_mix.gains(), PackedFloat32Array([1.0, 1.0, 0.0]))
