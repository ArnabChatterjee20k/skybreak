extends GutTest
## The move list covers every move of every roster fighter.


func test_move_list_covers_every_move_of_every_fighter() -> void:
	for id in Roster.ids():
		var moves := Roster.character(id).stats.move_set
		var listed: Array = MoveList.rows_for(moves).map(func(row: Dictionary) -> MoveData: return row.move)
		var all := MoveList.all_moves(moves)
		assert_gt(all.size(), 10, "%s has a full move set" % id)
		for move in all:
			assert_has(listed, move, "%s lists %s" % [id, move.id])
		assert_eq(listed.size(), all.size(), "%s lists each move once" % id)


func test_every_row_has_input_frame_data_and_a_description() -> void:
	for id in Roster.ids():
		for row in MoveList.rows_for(Roster.character(id).stats.move_set):
			assert_ne(row.input, "", "%s input" % row.name)
			assert_ne(row.input, "?", "%s input" % row.name)
			assert_ne(row.description, "", "%s description" % row.name)
			assert_gt(row.startup, 0)
			assert_gt(row.active, 0)
			assert_gt(row.recovery, 0)


func test_rows_carry_the_move_data_numbers() -> void:
	var kael := Roster.character(&"kael").stats.move_set
	var rows := MoveList.rows_for(kael)
	var first := rows[0]
	assert_eq(first.input, "LMB")
	assert_eq(first.startup, 6)
	assert_eq(first.active, 2)
	assert_eq(first.recovery, 10)
	assert_eq(first.damage, 300)
	assert_eq(first.on_block, "-2")
	assert_eq(first.on_hit, "+5")
	var inputs: Array = rows.map(func(row: Dictionary) -> String: return row.input)
	assert_has(inputs, "LMB ×4")
	assert_has(inputs, "S + RMB")
	assert_has(inputs, "Hold RMB (Lv 3)")
	assert_has(inputs, "F")
