class_name SoundCue
extends Resource
## One sound effect: its variations and how the AudioDirector plays them.

@export var id: StringName = &""
## Variations; one is picked at random, never the same twice in a row.
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export var volume_db := 0.0
## Random pitch range for one-shots; for loops, intensity 0..1 sweeps across it.
@export var pitch_min := 1.0
@export var pitch_max := 1.0
## Random volume offset (+/- dB) per play.
@export var volume_jitter_db := 0.0
## Plays of this cue at once; one more steals its oldest voice.
@export var max_voices := 4
## Higher wins a voice when the pool is full.
@export var priority := 50
## Seconds before the cue may start again, so it never machine-guns.
@export var cooldown := 0.0
## Played in 3D at a world position; otherwise 2D (UI, stingers, ambience).
@export var positional := true
@export var unit_size := 12.0
@export var max_distance := 250.0
@export var loop := false
## Cues started together with this one (heavy impacts: thump and tail).
@export var layers: Array[StringName] = []
## Music and Ambience dip by this much (dB, negative) for duck_seconds.
@export var duck_db := 0.0
@export var duck_seconds := 0.0
