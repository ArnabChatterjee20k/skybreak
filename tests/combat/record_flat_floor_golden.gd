extends SceneTree
## Writes FlatFloorSequences.record() to the golden file; run on the pre-T-D13 commit.


func _init() -> void:
	var file := FileAccess.open(FlatFloorSequences.GOLDEN_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(FlatFloorSequences.record(), "\t"))
	file.close()
	quit()
