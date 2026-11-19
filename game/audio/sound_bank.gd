class_name SoundBank
extends Resource
## One category of sound cues (combat, movement, ki, weapons, pickups, ui, ambience).

@export var category: StringName = &""
@export var cues: Array[SoundCue] = []


func find(cue_id: StringName) -> SoundCue:
	for cue in cues:
		if cue.id == cue_id:
			return cue
	return null
