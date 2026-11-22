class_name PureFightPoses
extends RefCounted
## Named poses of a legend for review sheets and pose tests: [label, pose, view yaw].

const SIDE := 90.0


## "strip": stance, three techniques at their active frame, the finisher, a victory pose.
## "all": every base pose and every move at windup, active and follow-through.
static func sheet(style: FightStyle, which: String) -> Array:
	var legend := style.legend
	var cells: Array = []
	cells.append(["stance", style.stance(0.3), 60.0])
	if which == "strip":
		for id in PureMoves.ids(legend):
			var data := PureMoves.get_move(legend, id)
			if data.kind == &"technique":
				cells.append([String(data.name), active_pose(style, id), SIDE])
		cells.append(["finisher", style.throwing(_finisher(legend), 40, 100), SIDE])
		cells.append(["victory", style.victory(0, 1.0), 60.0])
		return cells
	cells.append(["walk fwd", style.walk(0.2, true, 2.5), SIDE])
	cells.append(["walk back", style.walk(0.5, false, 2.0), SIDE])
	cells.append(["crouch", style.crouch(0.2), SIDE])
	cells.append(["dash", style.dash(0.5, true), SIDE])
	cells.append(["jump", style.jump(20.0, 1), SIDE])
	cells.append(["block high", style.block(0.0, false, 1.0), SIDE])
	cells.append(["block low", style.block(0.0, true, 1.0), SIDE])
	cells.append(["hit high", style.hit(0.0, false, 1.0), SIDE])
	cells.append(["hit low", style.hit(0.0, true, 1.0), SIDE])
	cells.append(["juggle", style.juggle(0.0, 0.5), SIDE])
	cells.append(["knockdown", style.knockdown(20), SIDE])
	cells.append(["get-up", style.wakeup(0.5), SIDE])
	cells.append(["intro", style.intro(1.0), 30.0])
	cells.append(["victory 1", style.victory(0, 1.0), 30.0])
	cells.append(["victory 2", style.victory(1, 1.0), 30.0])
	cells.append(["defeat", style.defeat(1.0), 30.0])
	cells.append(["throw", style.throwing(&"throw", 20, PureMoves.THROW_TICKS), SIDE])
	for id in PureMoves.ids(legend):
		var data := PureMoves.get_move(legend, id)
		if data.kind == &"throw":
			continue
		cells.append([String(id) + " active", active_pose(style, id), SIDE])
	return cells


static func _finisher(legend: StringName) -> StringName:
	for id in PureMoves.ids(legend):
		if PureMoves.get_move(legend, id).kind == &"finisher":
			return id
	return &""


static func base_for(style: FightStyle, data: Dictionary) -> Dictionary:
	if data.stance == &"crouch":
		return style.crouch(0.0)
	if data.stance == &"air":
		return style.jump(0.0, 1)
	return style.stance(0.0)


## The move's pose on its first active frame (counter stance: mid-window).
static func active_pose(style: FightStyle, id: StringName) -> Dictionary:
	var data := PureMoves.get_move(style.legend, id)
	var frame := float(data.startup)
	if not (data.counter as Array).is_empty():
		frame = float((data.counter as Array)[1]) + 5.0
	elif (data.box as Array).is_empty():
		frame = PureMoves.total(data) * 0.4
	return style.move_pose(id, frame, data, base_for(style, data))
