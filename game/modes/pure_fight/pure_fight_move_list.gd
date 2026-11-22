class_name PureFightMoveList
extends RefCounted
## Move list rows per legend (pause menu, docs): name, input, frame data.


static func lines(legend: StringName) -> Array[String]:
	var roster := Roster.character(legend)
	var out: Array[String] = ["%s" % (roster.display_name.to_upper() if roster else String(legend).to_upper())]
	for id in PureMoves.ids(legend):
		var data := PureMoves.get_move(legend, id)
		var adv := PureMoves.advantage(data)
		var on_hit := "KD" if adv.y == 999 else "%+d" % adv.y
		var on_block := "%+d" % adv.x if data.guard not in [&"throw", &"none"] else "-"
		out.append("  %-24s %-22s %2d/%2d/%2d  dmg %3d  blk %3s  hit %3s  %s" % [data.name, data.input,
			data.startup, data.active, data.recovery, data.damage, on_block, on_hit, data.guard])
	return out
