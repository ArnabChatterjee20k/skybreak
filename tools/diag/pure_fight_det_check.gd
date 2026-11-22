extends SceneTree
## Pure Fight determinism check: a seeded AI-vs-AI match per legend pair, printing a hash every
## 600 ticks and a total. Compare across runs and platforms; DetCheck (det_check.gd) covers the
## other modes and is untouched by Pure Fight.
##   godot --headless --path . -s res://tools/diag/pure_fight_det_check.gd

const PAIRS := [[&"kael", &"vexa"], [&"lyra", &"brann"]]
const TICKS := 6000


func _initialize() -> void:
	var total := HashingContext.new()
	total.start(HashingContext.HASH_SHA256)
	for pair in PAIRS:
		var legends: Array[StringName] = [pair[0], pair[1]]
		var sim := PureFightSim.new(7, legends)
		var ais: Array[PureFightAI] = []
		for i in 2:
			var ai := PureFightAI.new()
			ai.setup(i, 4, 7)
			ai.explore = 0.3
			ais.append(ai)
		var chain := HashingContext.new()
		chain.start(HashingContext.HASH_SHA256)
		for t in TICKS:
			sim.tick([ais[0].next_input(sim), ais[1].next_input(sim)] as Array[FighterInput])
			chain.update(var_to_bytes(sim.state_hash()))
			if (t + 1) % 600 == 0:
				print("pure_fight %s_v_%s t%d %x" % [pair[0], pair[1], t + 1, sim.state_hash()])
		var digest := chain.finish()
		total.update(digest)
		print("pure_fight %s_v_%s chain %s" % [pair[0], pair[1], digest.hex_encode().substr(0, 16)])
	print("pure_fight total %s" % total.finish().hex_encode().substr(0, 16))
	quit()
