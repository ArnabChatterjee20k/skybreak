class_name LayerMix
extends RefCounted
## Which stems of a battle theme are audible. Level changes wait for a bar line,
## then fade in over fade_beats so layers enter and leave on the grid.

const LAYER_COUNT := 3

var clock: BarClock
## Level the mix is at (or fading towards); a MusicIntensity.Level.
var level: int = MusicIntensity.Level.CALM
## Level asked for, committed on the next bar line.
var pending: int = MusicIntensity.Level.CALM
var fade_beats: float = 1.0
## Song time of the last commit, for tests and debugging.
var last_commit_time: float = -1.0

var _from: PackedFloat32Array = target_gains(MusicIntensity.Level.CALM)
var _to: PackedFloat32Array = target_gains(MusicIntensity.Level.CALM)
var _fade: float = 1.0


func _init(bar_clock: BarClock) -> void:
	clock = bar_clock


## Linear gain per layer (calm, combat, climax) at a level: layers stack upward.
static func target_gains(for_level: int) -> PackedFloat32Array:
	var gains := PackedFloat32Array()
	for layer in LAYER_COUNT:
		gains.append(1.0 if layer <= for_level else 0.0)
	return gains


func request(new_level: int) -> void:
	pending = new_level


## Jumps straight to a level, no fade (track start).
func reset(new_level: int) -> void:
	level = new_level
	pending = new_level
	_from = target_gains(new_level)
	_to = _from
	_fade = 1.0


## Moves the song clock from before to after; returns true if a change was committed on a bar line.
func advance(before: float, after: float) -> bool:
	var travelled := after - before
	if clock.loop_seconds > 0.0 and after < before:
		travelled += clock.loop_seconds
	var committed := false
	var since_bar := clock.overshoot_past_bar(before, after)
	if since_bar >= 0.0 and pending != level:
		_from = gains()
		_to = target_gains(pending)
		level = pending
		_fade = 0.0
		last_commit_time = after - since_bar
		travelled = since_bar
		committed = true
	if _fade < 1.0:
		_fade = minf(1.0, _fade + travelled / (fade_beats * clock.beat_seconds()))
	return committed


func gains() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var w := smoothstep(0.0, 1.0, _fade)
	for layer in LAYER_COUNT:
		out.append(lerpf(_from[layer], _to[layer], w))
	return out


func is_fading() -> bool:
	return _fade < 1.0
