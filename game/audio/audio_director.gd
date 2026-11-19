extends Node
## Plays every sound effect. Autoloaded as AudioDirector.
## Pooled one-shots (3D for fighters, 2D for UI and stingers) with per-cue voice
## limits, priority stealing, cooldowns and no-repeat variations; named loops
## driven by an intensity; the Music/Ambience duck on big hits; zone ambience.
## Time is its own clock advanced in _process, so tests can step it.

const BANK_PATHS: Array[String] = [
	"res://game/audio/banks/combat_bank.tres",
	"res://game/audio/banks/movement_bank.tres",
	"res://game/audio/banks/ki_bank.tres",
	"res://game/audio/banks/weapons_bank.tres",
	"res://game/audio/banks/pickups_bank.tres",
	"res://game/audio/banks/ui_bank.tres",
	"res://game/audio/banks/ambience_bank.tres",
]
const POOL_3D := 24
const POOL_2D := 12
const DUCK_BUSES: Array[StringName] = [AudioBuses.MUSIC, AudioBuses.AMBIENCE]
## dB per second the duck moves down (attack) and back up (release).
const DUCK_ATTACK_DB_PER_SECOND := 300.0
const DUCK_RELEASE_DB_PER_SECOND := 15.0
## Loop volume (dB below the cue volume) at intensity 0.
const LOOP_FLOOR_DB := -18.0
## Loops fade in and out at this rate (dB per second); silent below LOOP_SILENT_DB.
const LOOP_FADE_DB_PER_SECOND := 60.0
const LOOP_SILENT_DB := -50.0
## Ambience crossfades between zones at this rate (dB per second).
const AMBIENCE_FADE_DB_PER_SECOND := 30.0
const AMBIENCE_KEY := &"ambience"
const THUNDER_ZONE := &"stormfall_city"
## Seconds between Stormfall thunder rolls (min, max).
const THUNDER_GAP := Vector2(9.0, 22.0)

## Cue id -> SoundCue, from every bank.
var cues: Dictionary = {}
var settings: AudioSettings
## Ambience follows this zone id; empty means none.
var current_zone: StringName = &""
## Variation and jitter choices; presentation only, never the sim's rng.
var rng := RandomNumberGenerator.new()
## Current duck offset (dB, <= 0) on the Music and Ambience buses.
var duck_offset_db := 0.0

var _now := 0.0
## Each voice: {player, cue (StringName), priority, started, ends_at}.
var _voices: Array[Dictionary] = []
var _last_played: Dictionary = {}
var _last_variation: Dictionary = {}
## key -> {player, cue, level_db (fade), target_db, pitch, stopping}.
var _loops: Dictionary = {}
var _duck_depth := 0.0
var _duck_until := 0.0
## Delayed layers: {time, cue, at, params}.
var _pending: Array[Dictionary] = []
var _next_thunder := 0.0


func _ready() -> void:
	AudioBuses.ensure()
	if cues.is_empty():
		for path in BANK_PATHS:
			add_bank(load(path))
	if settings == null:
		settings = AudioSettings.load_saved()
	_build_pools()
	_apply_bus_volumes()


func add_bank(bank: SoundBank) -> void:
	for cue in bank.cues:
		cues[cue.id] = cue


func now() -> float:
	return _now


## Plays a one-shot. `at` is a world position for positional cues (ignored by 2D
## cues). params: pitch_scale, volume_db, layer_delay (seconds before *_tail layers).
## Returns the player, or null when the cooldown, voice limit or priority refused it.
func play(cue_id: StringName, at: Variant = null, params: Dictionary = {}) -> Node:
	var cue: SoundCue = cues.get(cue_id)
	if cue == null or cue.streams.is_empty():
		push_warning("AudioDirector: unknown cue %s" % cue_id)
		return null
	if _now - float(_last_played.get(cue_id, -INF)) < cue.cooldown:
		return null
	var voice := _claim_voice(cue)
	if voice.is_empty():
		return null
	var index := pick_variation(cue)
	var stream := cue.streams[index]
	var pitch := rng.randf_range(cue.pitch_min, cue.pitch_max) * float(params.get("pitch_scale", 1.0))
	var volume := cue.volume_db + rng.randf_range(-cue.volume_jitter_db, cue.volume_jitter_db) \
		+ float(params.get("volume_db", 0.0))
	var player: Node = voice.player
	pitch = maxf(pitch, 0.05)
	player.set(&"stream", stream)
	player.set(&"bus", cue.bus)
	player.set(&"pitch_scale", pitch)
	player.set(&"volume_db", volume)
	if player is AudioStreamPlayer3D:
		var p3: AudioStreamPlayer3D = player
		p3.unit_size = cue.unit_size
		p3.max_distance = cue.max_distance
		if at is Vector3:
			p3.global_position = at
	voice.cue = cue_id
	voice.priority = cue.priority
	voice.started = _now
	voice.ends_at = _now + stream.get_length() / pitch
	if player.is_inside_tree():
		player.call(&"play")
	_last_played[cue_id] = _now
	if cue.duck_db < 0.0:
		duck(cue.duck_db, cue.duck_seconds)
	var delay := float(params.get("layer_delay", 0.0))
	for layer in cue.layers:
		var layer_params := {"pitch_scale": params.get("pitch_scale", 1.0)}
		if delay > 0.0 and String(layer).ends_with("_tail"):
			_pending.append({"time": _now + delay, "cue": layer, "at": at, "params": layer_params})
		else:
			play(layer, at, layer_params)
	return player


## Plays of cue_id still sounding.
func voices_playing(cue_id: StringName) -> int:
	var count := 0
	for voice in _voices:
		if voice.cue == cue_id and _busy(voice):
			count += 1
	return count


## Picks a variation index for cue, never the one it picked last time.
func pick_variation(cue: SoundCue) -> int:
	var count := cue.streams.size()
	if count <= 1:
		return 0
	var last: int = _last_variation.get(cue.id, -1)
	var index: int
	if last < 0:
		index = rng.randi_range(0, count - 1)
	else:
		index = rng.randi_range(0, count - 2)
		if index >= last:
			index += 1
	_last_variation[cue.id] = index
	return index


## Dips Music and Ambience by depth_db (negative) for hold seconds, then eases back.
func duck(depth_db: float, hold: float) -> void:
	_duck_depth = minf(_duck_depth, depth_db)
	_duck_until = maxf(_duck_until, _now + hold)


## Starts or updates a named loop. intensity 0..1 raises volume and sweeps pitch
## across the cue's range (flight wind by speed, ki charge rising, beam).
func set_loop(key: StringName, cue_id: StringName, intensity: float, at: Variant = null) -> void:
	var cue: SoundCue = cues.get(cue_id)
	if cue == null or cue.streams.is_empty():
		push_warning("AudioDirector: unknown loop cue %s" % cue_id)
		return
	var k := clampf(intensity, 0.0, 1.0)
	var entry: Dictionary = _loops.get(key, {})
	if entry.is_empty() or entry.cue != cue_id:
		if not entry.is_empty():
			_free_loop(key)
		entry = _start_loop(cue, LOOP_SILENT_DB)
		_loops[key] = entry
	entry.stopping = false
	entry.target_db = cue.volume_db + lerpf(LOOP_FLOOR_DB, 0.0, k)
	entry.player.pitch_scale = lerpf(cue.pitch_min, cue.pitch_max, k)
	if at is Vector3 and entry.player is AudioStreamPlayer3D:
		(entry.player as AudioStreamPlayer3D).global_position = at


## Fades a loop out and frees it.
func stop_loop(key: StringName) -> void:
	if _loops.has(key):
		_loops[key].stopping = true
		_loops[key].target_db = LOOP_SILENT_DB - 10.0


## True while the loop is running and not fading out.
func is_loop_active(key: StringName) -> bool:
	return _loops.has(key) and not _loops[key].stopping


func loop_cue(key: StringName) -> StringName:
	return _loops[key].cue if _loops.has(key) else &""


func loop_volume_db(key: StringName) -> float:
	return _loops[key].level_db if _loops.has(key) else -INF


func loop_pitch(key: StringName) -> float:
	return _loops[key].player.pitch_scale if _loops.has(key) else 0.0


## Switches the ambience bed to a zone's loop with a crossfade. Thunder only in Stormfall.
func set_zone(zone_id: StringName) -> void:
	if zone_id == current_zone:
		return
	current_zone = zone_id
	var old_key := StringName("%s:old" % AMBIENCE_KEY)
	if _loops.has(old_key):
		_free_loop(old_key)
	if _loops.has(AMBIENCE_KEY):
		_loops[old_key] = _loops[AMBIENCE_KEY]
		_loops.erase(AMBIENCE_KEY)
		stop_loop(old_key)
	var cue_id := ambience_cue(zone_id)
	if zone_id != &"" and cues.has(cue_id):
		set_loop(AMBIENCE_KEY, cue_id, 1.0)
	_next_thunder = _now + rng.randf_range(THUNDER_GAP.x * 0.3, THUNDER_GAP.y * 0.5)


static func ambience_cue(zone_id: StringName) -> StringName:
	return StringName("amb_%s" % zone_id)


## Player volume for a bus (linear 0..1), applied now and saved when asked.
func set_bus_volume(bus: StringName, linear: float, save := true) -> void:
	settings.set_volume(bus, linear)
	_apply_bus_volumes()
	if save:
		settings.save()


## Bus volume the player chose, without the duck (dB).
func base_bus_volume_db(bus: StringName) -> float:
	return settings.volume_db(bus)


func _process(delta: float) -> void:
	advance(delta)


## Steps the director clock: pending layers, the duck, loop fades and thunder.
func advance(delta: float) -> void:
	_now += delta
	var due: Array[Dictionary] = []
	for item in _pending:
		if item.time <= _now:
			due.append(item)
	for item in due:
		_pending.erase(item)
		play(item.cue, item.at, item.params)
	_update_duck(delta)
	_update_loops(delta)
	if current_zone == THUNDER_ZONE and _now >= _next_thunder:
		play(&"stormfall_thunder")
		_next_thunder = _now + rng.randf_range(THUNDER_GAP.x, THUNDER_GAP.y)


func _update_duck(delta: float) -> void:
	if _now >= _duck_until:
		_duck_depth = 0.0
	if duck_offset_db > _duck_depth:
		duck_offset_db = maxf(duck_offset_db - DUCK_ATTACK_DB_PER_SECOND * delta, _duck_depth)
	else:
		duck_offset_db = minf(duck_offset_db + DUCK_RELEASE_DB_PER_SECOND * delta, _duck_depth)
	_apply_bus_volumes()


func _update_loops(delta: float) -> void:
	for key: StringName in _loops.keys():
		var entry: Dictionary = _loops[key]
		var rate := AMBIENCE_FADE_DB_PER_SECOND if String(key).begins_with(AMBIENCE_KEY) else LOOP_FADE_DB_PER_SECOND
		entry.level_db = move_toward(entry.level_db, entry.target_db, rate * delta)
		entry.player.volume_db = entry.level_db
		if entry.stopping and entry.level_db <= LOOP_SILENT_DB:
			_free_loop(key)


func _apply_bus_volumes() -> void:
	if settings == null:
		return
	for bus in AudioBuses.ALL:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var db := settings.volume_db(bus)
		if bus in DUCK_BUSES:
			db += duck_offset_db
		AudioServer.set_bus_volume_db(index, db)


func _build_pools() -> void:
	if not _voices.is_empty():
		return
	for i in POOL_3D + POOL_2D:
		var player: Node
		if i < POOL_3D:
			var p3 := AudioStreamPlayer3D.new()
			p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			player = p3
		else:
			player = AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_voices.append({"player": player, "cue": &"", "priority": -1, "started": -INF, "ends_at": -INF})


func _busy(voice: Dictionary) -> bool:
	return _now < float(voice.ends_at)


func _claim_voice(cue: SoundCue) -> Dictionary:
	var want_3d := cue.positional
	var same: Array[Dictionary] = []
	var free: Dictionary = {}
	var weakest: Dictionary = {}
	for voice in _voices:
		if (voice.player is AudioStreamPlayer3D) != want_3d:
			continue
		if not _busy(voice):
			if free.is_empty():
				free = voice
			continue
		if voice.cue == cue.id:
			same.append(voice)
		if weakest.is_empty() or voice.priority < weakest.priority \
				or (voice.priority == weakest.priority and voice.started < weakest.started):
			weakest = voice
	if same.size() >= cue.max_voices:
		var oldest := same[0]
		for voice in same:
			if voice.started < oldest.started:
				oldest = voice
		return _stop(oldest)
	if not free.is_empty():
		return free
	if not weakest.is_empty() and weakest.priority <= cue.priority:
		return _stop(weakest)
	return {}


func _stop(voice: Dictionary) -> Dictionary:
	voice.player.stop()
	voice.ends_at = -INF
	return voice


func _start_loop(cue: SoundCue, level_db: float) -> Dictionary:
	var player: Node
	if cue.positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p3.unit_size = cue.unit_size
		p3.max_distance = cue.max_distance
		player = p3
	else:
		player = AudioStreamPlayer.new()
	var stream := cue.streams[0]
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.set(&"stream", stream)
	player.set(&"bus", cue.bus)
	player.set(&"volume_db", level_db)
	add_child(player)
	player.call(&"play")
	return {"player": player, "cue": cue.id, "level_db": level_db, "target_db": level_db, "stopping": false}


func _free_loop(key: StringName) -> void:
	var entry: Dictionary = _loops[key]
	entry.player.stop()
	entry.player.queue_free()
	_loops.erase(key)
