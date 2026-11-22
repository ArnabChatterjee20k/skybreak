extends SceneTree
## Issue #150: AI vs AI pressure stats. Per matchup and seed: blocked hits, the longest
## run of blocked hits without the blocker acting, dodges out of blockstun, dodges
## punished, push-blocks, and hits landed.
##   godot --headless --path . -s res://tools/diag/pressure_bouts.gd -- [--ticks 3600]

const S := FighterState.State
const E := CombatSim.EventType
const MATCHUPS := [[&"kael", &"vexa"], [&"brann", &"lyra"], [&"vexa", &"brann"], [&"lyra", &"kael"]]
const SEEDS := [3, 7, 11]


func _initialize() -> void:
	var raw := OS.get_cmdline_user_args()
	var ticks := 3600
	var at := raw.find("--ticks")
	if at >= 0 and at + 1 < raw.size():
		ticks = int(raw[at + 1])
	var total := {}
	print("| matchup | seed | blocks | longest block run | dodge out of block | dodges punished | push-blocks | hits |")
	print("|---|---|---|---|---|---|---|---|")
	for pair: Array in MATCHUPS:
		for seed_value: int in SEEDS:
			var row := _bout(pair, seed_value, ticks)
			for key: String in row:
				total[key] = total.get(key, 0) + row[key] if key != "longest" else maxi(total.get(key, 0), row[key])
			print("| %s-%s | %d | %d | %d | %d | %d | %d | %d |" % [pair[0], pair[1], seed_value, row.blocks,
				row.longest, row.dodge_out, row.punished, row.push_blocks, row.hits])
	print("| all | | %d | %d | %d | %d | %d | %d |" % [total.blocks, total.longest, total.dodge_out,
		total.punished, total.push_blocks, total.hits])
	quit(0)


func _bout(pair: Array, seed_value: int, ticks: int) -> Dictionary:
	var bout := AIBout.new(seed_value, [5, 4], false, pair)
	var row := {"blocks": 0, "longest": 0, "dodge_out": 0, "punished": 0, "push_blocks": 0, "hits": 0}
	var run := [0, 0]
	var last_state: Array[int] = [S.IDLE, S.IDLE]
	for _t in ticks:
		if bout.sim.round_over:
			bout.sim.start_round()
		bout.step()
		for event: Dictionary in bout.sim.events:
			match event.type:
				E.BLOCK:
					row.blocks += 1
					var target: int = event.target
					run[target] += 1
					row.longest = maxi(row.longest, run[target])
				E.HIT, E.COUNTER:
					row.hits += 1
				E.PUSH_BLOCK:
					row.push_blocks += 1
				E.GRAB:
					if event.get("counter", false):
						row.punished += 1
				E.DODGE:
					if last_state[event.fighter as int] == S.BLOCKSTUN:
						row.dodge_out += 1
		for i in 2:
			var fighter := bout.sim.fighters[i]
			# Acting (anything but guarding or being stunned) ends a run of blocked hits.
			if fighter.state not in [S.BLOCKSTUN, S.BLOCKING, S.HITSTUN]:
				run[i] = 0
			last_state[i] = fighter.state
	return row
