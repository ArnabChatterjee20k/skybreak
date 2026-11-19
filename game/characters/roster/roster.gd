class_name Roster
extends RefCounted
## Every playable fighter by id.

const CHARACTERS := {
	&"kael": "res://game/characters/roster/kael.tres",
	&"vexa": "res://game/characters/roster/vexa.tres",
	&"lyra": "res://game/characters/roster/lyra.tres",
	&"brann": "res://game/characters/roster/brann.tres",
}


static func ids() -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(CHARACTERS.keys())
	return list


## The character with this id, or null.
static func character(id: StringName) -> RosterCharacter:
	if not CHARACTERS.has(id):
		return null
	return load(CHARACTERS[id]) as RosterCharacter
