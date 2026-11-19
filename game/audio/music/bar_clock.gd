class_name BarClock
extends RefCounted
## Bar grid of one looping track: where bar lines fall, in seconds from the loop start.

var bpm: float
var beats_per_bar: int
## Loop length in seconds; 0 for a track that plays once.
var loop_seconds: float


func _init(tempo: float = 120.0, beats: int = 4, loop_length: float = 0.0) -> void:
	bpm = tempo
	beats_per_bar = beats
	loop_seconds = loop_length


func beat_seconds() -> float:
	return 60.0 / bpm


func bar_seconds() -> float:
	return beat_seconds() * beats_per_bar


## Index of the bar that contains time t.
func bar_at(t: float) -> int:
	return int(floor(t / bar_seconds() + 1e-9))


## Seconds from t to the next bar line (0 when t sits on one).
func time_to_next_bar(t: float) -> float:
	var into := fposmod(t, bar_seconds())
	if into < 1e-6 or bar_seconds() - into < 1e-6:
		return 0.0
	return bar_seconds() - into


## Moves t forward by delta, wrapping at the loop end.
func advanced(t: float, delta: float) -> float:
	var next := t + delta
	if loop_seconds > 0.0:
		next = fposmod(next, loop_seconds)
	return next


## Seconds past the first bar line crossed going from before to after (wrap-aware), or -1 if none was crossed.
func overshoot_past_bar(before: float, after: float) -> float:
	var travelled := after - before
	if loop_seconds > 0.0 and after < before:
		travelled += loop_seconds
	if travelled <= 0.0:
		return -1.0
	var to_bar := time_to_next_bar(before)
	if to_bar == 0.0 and fposmod(before, bar_seconds()) < 1e-6:
		# Sitting exactly on a bar line counts as crossing it now.
		return travelled
	if to_bar <= travelled:
		return travelled - to_bar
	return -1.0
