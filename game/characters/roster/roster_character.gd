class_name RosterCharacter
extends Resource
## One playable fighter: its model scene, its sim stats (moves included) and a
## team palette per player slot.

@export var id: StringName = &""
@export var display_name: String = ""
## A CharacterView scene: the classic model.
@export var scene: PackedScene
## The voxel CharacterView scene, drawn in the Voxel art style; null falls back to scene.
@export var voxel_scene: PackedScene
@export var stats: FighterStats
## Palette (part name -> Color) per slot, P1 first; slots past the end use the last.
@export var palettes: Array[Dictionary] = [{}]


## The CharacterView scene for an art style (default: the current one).
func scene_for(style: int = -1) -> PackedScene:
	var kind := ArtStyle.current() if style < 0 else style
	if kind == ArtStyle.Kind.VOXEL and voxel_scene != null:
		return voxel_scene
	return scene


func palette_for(slot: int) -> Dictionary:
	if palettes.is_empty():
		return {}
	return palettes[clampi(slot, 0, palettes.size() - 1)]
