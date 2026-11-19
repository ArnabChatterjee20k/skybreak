class_name RosterCharacter
extends Resource
## One playable fighter: its model scene, its sim stats (moves included) and a
## team palette per player slot.

@export var id: StringName = &""
@export var display_name: String = ""
## A CharacterView scene.
@export var scene: PackedScene
@export var stats: FighterStats
## Palette (part name -> Color) per slot, P1 first; slots past the end use the last.
@export var palettes: Array[Dictionary] = [{}]


func palette_for(slot: int) -> Dictionary:
	if palettes.is_empty():
		return {}
	return palettes[clampi(slot, 0, palettes.size() - 1)]
