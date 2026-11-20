class_name LookStyle
extends Node
## Style A: the game as it ships. Subclasses override the view only (never the sim).

var match_node: ZoneMatch
var moment := ""
## Wide establishing shot requested.
var wide := false


func _init() -> void:
	process_priority = 1000


func setup(zone_match: ZoneMatch) -> void:
	match_node = zone_match


## The melee hit about to be captured.
func on_hit(_event: Dictionary) -> void:
	pass


func camera() -> FighterCamera:
	return match_node.camera


func centre() -> Vector3:
	var sum := Vector3.ZERO
	for v in match_node.fighter_views:
		sum += v.position
	return sum / float(match_node.fighter_views.size())
