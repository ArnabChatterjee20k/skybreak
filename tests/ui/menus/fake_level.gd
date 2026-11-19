extends Node3D
## Stand-in match level for menu tests: a configure() method, a match flow and
## the match_finished signal.

signal match_finished(winner: int)

var match_flow := MatchFlow.new()
var config: Dictionary = {}


func configure(new_config: Dictionary) -> void:
	config = new_config
