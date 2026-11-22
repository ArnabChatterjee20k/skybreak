extends SceneTree
## Prints GAME_DESIGN §16.6's frame tables from PureMoves (paste after a data change).
##   godot --headless --path . -s res://tools/diag/pure_fight_tables.gd


func _initialize() -> void:
	for legend in PureMoves.LEGENDS:
		print("\n#### %s\n" % Roster.character(legend).display_name)
		for line in PureFightFrameTable.header() + PureFightFrameTable.rows(legend):
			print(line)
	quit()
