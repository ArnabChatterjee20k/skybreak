class_name MoveList
extends RefCounted
## A fighter's move list, generated from its MoveSet: every move with its
## input, frame data and a short description. Rows are dictionaries:
## {move, input, name, startup, active, recovery, damage, on_hit, on_block, description}.

## What each MoveSet slot does, in a line.
const SLOT_TEXT := {
	&"light_string": "Light string hit. Press again in rhythm for the next hit.",
	&"smash": "Big blowback that sends the target flying. Hold to charge.",
	&"charged_smash": "Charged smash. Higher levels hit harder and push further.",
	&"breaker": "Slow guard crusher: double guard damage.",
	&"launcher": "Pops the target up for an air combo.",
	&"rising": "Anti-air with upper-body invincibility.",
	&"spike": "Slams the target down to bounce off the floor.",
	&"sweep": "Wide arc that catches sidesteps.",
	&"push_block": "Shoves an attacker out to mid range. Costs guard.",
	&"grab": "Beats block, loses to strikes. The target can tech with F.",
}

## The input for each slot, with the default bindings.
const SLOT_INPUT := {
	&"smash": "RMB",
	&"breaker": "W + RMB",
	&"launcher": "S + RMB",
	&"rising": "Space + RMB",
	&"spike": "Ctrl + RMB",
	&"sweep": "A/D + RMB",
	&"push_block": "Block + RMB",
	&"grab": "F",
}

## MoveSet slots in move-list order.
const SLOT_ORDER: Array[StringName] = [
	&"light_string", &"smash", &"charged_smash", &"breaker", &"launcher",
	&"rising", &"spike", &"sweep", &"push_block", &"grab",
]


static func rows_for(move_set: MoveSet) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if move_set == null:
		return rows
	for slot in SLOT_ORDER:
		var value: Variant = move_set.get(slot)
		if value is MoveData:
			rows.append(_row(value, SLOT_INPUT.get(slot, "?"), slot))
		elif value is Array:
			var moves: Array = value
			for i in moves.size():
				var input := ""
				if slot == &"light_string":
					input = "LMB" if i == 0 else "LMB ×%d" % (i + 1)
				else:
					input = "Hold RMB (Lv %d)" % (i + 1)
				var row := _row(moves[i], input, slot, i)
				if slot == &"light_string" and i == moves.size() - 1 and i > 0:
					row.description = "String ender: knocks the target back."
				rows.append(row)
	return rows


## Every MoveData a MoveSet holds, from its exported properties; the coverage reference.
static func all_moves(move_set: MoveSet) -> Array[MoveData]:
	var moves: Array[MoveData] = []
	for property in move_set.get_property_list():
		if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = move_set.get(property.name)
		if value is MoveData:
			moves.append(value)
		elif value is Array:
			for item: Variant in value:
				if item is MoveData:
					moves.append(item)
	return moves


static func _row(move: MoveData, input: String, slot: StringName, index: int = 0) -> Dictionary:
	var description: String = SLOT_TEXT.get(slot, "")
	if slot == &"light_string" and index == 0:
		description = "Fast jab that starts the light string."
	if move.knockback_type == MoveData.KnockbackType.WALL_SPLAT:
		description += " Wall-splats."
	if move.guard_break_below > 0:
		description += " Breaks a guard under %d." % move.guard_break_below
	if move.ki_cost > 0:
		description += " Costs %d ki." % move.ki_cost
	return {
		"move": move,
		"input": input,
		"name": move.display_name if move.display_name != "" else String(move.id).capitalize(),
		"startup": move.startup_ticks,
		"active": move.active_ticks,
		"recovery": move.recovery_ticks,
		"damage": move.damage,
		"on_hit": FrameMeter.on_hit_text(move),
		"on_block": FrameMeter.on_block_text(move),
		"description": description,
	}
