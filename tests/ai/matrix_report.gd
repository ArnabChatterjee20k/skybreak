extends SceneTree
## Prints the full AI level win-rate matrix (20 seeded bouts per pair, sides alternated).

func _init() -> void:
	var lines: Array[String] = ["row beats column, of 20"]
	for row in range(1, 6):
		var cells: Array[String] = []
		for column in range(1, 6):
			if row == column:
				cells.append("  -  ")
				continue
			var low := mini(row, column)
			var wins := 0
			for s in 20:
				var row_slot := s % 2
				var levels := [column, column]
				levels[row_slot] = row
				var winner := AIBout.new(9000 + 31 * s + low, levels).play(5400)
				if winner == row_slot:
					wins += 1
			cells.append("%2d/20" % wins)
		lines.append("L%d  %s" % [row, "  ".join(cells)])
	print("\n".join(lines))
	quit()
