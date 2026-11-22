extends SceneTree
## Re-blesses the Pure Fight golden replays (after an intended sim change; say why in the PR).
##   godot --headless --path . -s res://tools/diag/pure_fight_record_goldens.gd

const DIR := "res://tests/combat/pure_fight/goldens"
const MATCHES := [[11, &"kael", &"vexa"], [12, &"lyra", &"brann"], [13, &"vexa", &"kael"], [14, &"brann", &"lyra"]]
const TICKS := 3000


func _initialize() -> void:
	for m in MATCHES:
		var legends: Array[StringName] = [m[1], m[2]]
		var golden := PureFightGolden.record(int(m[0]), legends, TICKS)
		var path := "%s/%s_v_%s.json" % [DIR, m[1], m[2]]
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(golden))
		print("[golden] %s (%d ticks)" % [path, TICKS])
	quit()
