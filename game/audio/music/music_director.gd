extends Node
## Autoload that plays the score: menus, adaptive battle themes, stingers, pause.
## All timing runs on the song's bar grid; the rules live in BarClock,
## LayerMix and MusicIntensity, so this node only applies them to players.

signal track_started(track: StringName)
signal stinger_finished(stinger: StringName)

const BUS := &"Music"
## Pause: the music goes muffled and quieter.
const PAUSE_CUTOFF_HZ := 900.0
const PAUSE_DUCK_DB := -8.0
## Fade applied when a stinger cuts the loop, short enough to stay on the beat.
const CUT_SECONDS := 0.06
## Fade back in after a stinger.
const RESTORE_SECONDS := 0.5
## Track-to-track crossfade, in bars of the outgoing track.
const CROSSFADE_BARS := 1.0
const SILENT_DB := -80.0
## Song clock drift tolerated before re-syncing to the player.
const DRIFT_SECONDS := 0.03

## Track playing (or about to): a zone id from MusicCatalog.BATTLE or a key of SINGLE.
var current_track: StringName = &""
## Track waiting for the next bar line of the current one.
var pending_track: StringName = &""
var stinger: StringName = &""
var paused: bool = false
var intensity := MusicIntensity.new()

var _decks: Array[Deck] = []
var _stinger_player: AudioStreamPlayer
var _stinger_left: float = 0.0
var _restore_track: StringName = &""
var _duck: float = 1.0
var _lowpass: AudioEffectLowPassFilter
var _streams: Dictionary = {}


## One playing track: its player, bar grid, layers and fade.
class Deck:
	extends RefCounted
	var player: AudioStreamPlayer
	var track: StringName = &""
	var clock: BarClock
	var layers: LayerMix
	var time: float = 0.0
	var gain: float = 0.0
	var fade_to: float = 0.0
	var fade_rate: float = 0.0
	var looping: bool = true

	func stop() -> void:
		player.stop()
		track = &""
		gain = 0.0
		fade_to = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	for i in 2:
		var deck := Deck.new()
		deck.player = AudioStreamPlayer.new()
		deck.player.bus = BUS
		add_child(deck.player)
		_decks.append(deck)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.bus = BUS
	add_child(_stinger_player)


func _exit_tree() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus, i) == _lowpass:
			AudioServer.remove_bus_effect(bus, i)


func _process(delta: float) -> void:
	advance(delta)
	_follow_audio_clock()


# ------------------------------------------------------------------ public API

func play_menu() -> void:
	play(&"menu")


func play_character_select() -> void:
	play(&"character_select")


## Starts or switches to a zone's battle theme, calm, on the next bar line.
func start_battle(zone: StringName) -> void:
	intensity = MusicIntensity.new()
	play(zone)


## The fight moved into another zone: crossfade to its theme on a bar line, keeping the level.
func set_zone(zone: StringName) -> void:
	play(zone)


## Switches tracks on the next bar line of what's playing (at once if nothing is).
func play(track: StringName) -> void:
	assert(MusicCatalog.BATTLE.has(track) or MusicCatalog.SINGLE.has(track), "unknown track %s" % track)
	if stinger != &"":
		_restore_track = track
		return
	var live := _live_deck()
	if live == null:
		_start_deck(track, 0.0, 0.0)
		return
	# Asking for what already plays cancels a pending switch.
	pending_track = &"" if live.track == track else track


## Feed once per sim tick; final_round forces the climax layer.
func observe_sim(sim: CombatSim, final_round: bool = false) -> void:
	set_level(intensity.observe(sim, final_round))


## Asks for a layer level; it lands on the next bar line.
func set_level(level: int) -> void:
	var live := _live_deck()
	if live != null and live.layers != null:
		live.layers.request(level)


func round_started() -> void:
	intensity = MusicIntensity.new()
	var live := _live_deck()
	if live != null and live.layers != null:
		live.layers.request(MusicIntensity.Level.CALM)


## KO or match end: cuts the loop for the right stinger; the loop comes back afterwards.
func round_ended(match_over: bool, player_won: bool) -> void:
	play_stinger(&"victory" if match_over and player_won else &"defeat")


func play_stinger(name: StringName) -> void:
	assert(MusicCatalog.SINGLE.has(name))
	var live := _live_deck()
	_restore_track = pending_track if pending_track != &"" else (live.track if live != null else &"")
	pending_track = &""
	for deck in _decks:
		if deck.track != &"":
			_fade(deck, 0.0, CUT_SECONDS)
	stinger = name
	_stinger_left = float(MusicCatalog.SINGLE[name].samples) / 44100.0
	_stinger_player.stream = _stream(MusicCatalog.SINGLE[name].path, false)
	_stinger_player.volume_db = linear_to_db(_duck)
	_stinger_player.play()


## Low-pass and duck while the game is paused.
func set_paused(on: bool) -> void:
	paused = on
	_duck = db_to_linear(PAUSE_DUCK_DB) if on else 1.0
	_lowpass.cutoff_hz = PAUSE_CUTOFF_HZ
	var bus := AudioServer.get_bus_index(BUS)
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _lowpass:
			AudioServer.set_bus_effect_enabled(bus, i, on)
	_apply_volumes()


func stop_all() -> void:
	for deck in _decks:
		deck.stop()
	_stinger_player.stop()
	stinger = &""
	current_track = &""
	pending_track = &""


## Linear gain per layer of the live battle deck (calm, combat, climax), times the deck fade.
func layer_gains() -> PackedFloat32Array:
	var live := _live_deck()
	if live == null or live.layers == null:
		return PackedFloat32Array()
	var out := live.layers.gains()
	for i in out.size():
		out[i] *= live.gain
	return out


## Gain of the deck playing a track (0 if none).
func track_gain(track: StringName) -> float:
	for deck in _decks:
		if deck.track == track:
			return deck.gain
	return 0.0


## Song time of the live deck, seconds from its loop start.
func song_time() -> float:
	var live := _live_deck()
	return live.time if live != null else 0.0


func live_layers() -> LayerMix:
	var live := _live_deck()
	return live.layers if live != null else null


# ------------------------------------------------------------------ clock

## Moves the music forward by delta seconds. _process calls it; tests call it directly.
func advance(delta: float) -> void:
	var live := _live_deck()
	var switch_past := -1.0
	for deck in _decks:
		if deck.track == &"":
			continue
		var before := deck.time
		deck.time = deck.clock.advanced(deck.time, delta)
		if deck.layers != null:
			deck.layers.advance(before, deck.time)
		if deck == live and pending_track != &"" and stinger == &"":
			switch_past = deck.clock.overshoot_past_bar(before, deck.time)
		if deck.gain != deck.fade_to:
			deck.gain = move_toward(deck.gain, deck.fade_to, deck.fade_rate * delta)
		if deck.gain <= 0.0 and deck.fade_to <= 0.0 and stinger == &"":
			deck.stop()
	if switch_past >= 0.0:
		# The new track starts on the bar line, already switch_past seconds in.
		var track := pending_track
		pending_track = &""
		var fade := live.clock.bar_seconds() * CROSSFADE_BARS
		_fade(live, 0.0, fade)
		_start_deck(track, switch_past, fade)
	if stinger != &"":
		_stinger_left -= delta
		if _stinger_left <= 0.0:
			_end_stinger()
	_apply_volumes()


# ------------------------------------------------------------------ internals

func _live_deck() -> Deck:
	for deck in _decks:
		if deck.track != &"" and deck.track == current_track:
			return deck
	return null


func _start_deck(track: StringName, offset: float, fade_seconds: float) -> void:
	var live := _live_deck()
	var deck: Deck = _decks[1] if _decks[0] == live else _decks[0]
	if deck.track != &"":
		deck.stop()
	var level: int = MusicIntensity.Level.CALM
	if live != null and live.layers != null:
		level = live.layers.pending
	deck.track = track
	deck.time = offset
	if MusicCatalog.BATTLE.has(track):
		var info: Dictionary = MusicCatalog.BATTLE[track]
		deck.clock = BarClock.new(info.bpm, info.beats_per_bar, float(info.loop_samples) / 44100.0)
		deck.layers = LayerMix.new(deck.clock)
		deck.layers.reset(level)
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = info.stems.size()
		for i in info.stems.size():
			sync.set_sync_stream(i, _stream(info.stems[i], true))
		deck.player.stream = sync
		deck.looping = true
	else:
		var single: Dictionary = MusicCatalog.SINGLE[track]
		var loop_seconds := float(single.samples) / 44100.0 if single.loop else 0.0
		deck.clock = BarClock.new(single.bpm, single.beats_per_bar, loop_seconds)
		deck.layers = null
		deck.player.stream = _stream(single.path, single.loop)
		deck.looping = single.loop
	deck.gain = 0.0 if fade_seconds > 0.0 else 1.0
	_fade(deck, 1.0, fade_seconds)
	current_track = track
	_apply_volumes()
	deck.player.play(offset)
	track_started.emit(track)


## Re-syncs the song clocks to the players when they drift (frame time vs the audio clock).
func _follow_audio_clock() -> void:
	for deck in _decks:
		if deck.track == &"" or not deck.player.playing:
			continue
		var heard := deck.player.get_playback_position() + AudioServer.get_time_since_last_mix()
		if heard > 0.0 and absf(heard - deck.time) > DRIFT_SECONDS and absf(heard - deck.time) < 1.0:
			deck.time = deck.clock.advanced(heard, 0.0)


func _fade(deck: Deck, to: float, seconds: float) -> void:
	deck.fade_to = to
	deck.fade_rate = INF if seconds <= 0.0 else absf(to - deck.gain) / seconds
	if seconds <= 0.0:
		deck.gain = to


func _end_stinger() -> void:
	var finished := stinger
	stinger = &""
	_stinger_player.stop()
	for deck in _decks:
		deck.stop()
	var back := _restore_track
	_restore_track = &""
	current_track = &""
	if back != &"":
		_start_deck(back, 0.0, RESTORE_SECONDS)
	stinger_finished.emit(finished)


func _apply_volumes() -> void:
	for deck in _decks:
		if deck.track == &"":
			continue
		var gain := deck.gain * _duck
		deck.player.volume_db = SILENT_DB if gain <= 0.0001 else linear_to_db(gain)
		if deck.layers != null and deck.player.stream is AudioStreamSynchronized:
			var sync := deck.player.stream as AudioStreamSynchronized
			var gains := deck.layers.gains()
			for i in gains.size():
				sync.set_sync_stream_volume(i, SILENT_DB if gains[i] <= 0.0001 else linear_to_db(gains[i]))
	if _stinger_player != null:
		_stinger_player.volume_db = linear_to_db(_duck)


func _stream(path: String, looping: bool) -> AudioStream:
	if not _streams.has(path):
		var stream := load(path) as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = looping
		_streams[path] = stream
	return _streams[path]


## Uses the Music bus from the bus layout, or adds a minimal one (sending to Master) if it's missing.
func _ensure_bus() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUS)
		AudioServer.set_bus_send(bus, &"Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = PAUSE_CUTOFF_HZ
	AudioServer.add_bus_effect(bus, _lowpass)
	AudioServer.set_bus_effect_enabled(bus, AudioServer.get_bus_effect_count(bus) - 1, false)
