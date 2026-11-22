class_name PureFightFrameTable
extends RefCounted
## Markdown frame-data rows for GAME_DESIGN §16.6, generated from PureMoves so the doc and
## the data can be checked against each other (tests/combat/pure_fight).


static func header() -> Array[String]:
	return ["| Move | Input | Startup | Active | Recovery | On block | On hit | Damage | Guard | Notes |",
		"|---|---|---|---|---|---|---|---|---|---|"]


static func rows(legend: StringName) -> Array[String]:
	var out: Array[String] = []
	for id in PureMoves.ids(legend):
		var data := PureMoves.get_move(legend, id)
		var adv := PureMoves.advantage(data)
		var block := "-" if data.guard in [&"throw", &"none"] else "%+d" % adv.x
		var hit := "KD" if adv.y == 999 else "%+d" % adv.y
		if data.guard in [&"throw", &"none"]:
			hit = "KD" if data.guard == &"throw" else "-"
		if data.stance == &"air":
			block = "%+d (deep)" % adv.x
			hit = "%+d (deep)" % adv.y
		out.append("| %s | `%s` | %d | %d | %d | %s | %s | %d | %s | %s |" % [data.name, data.input,
			data.startup, data.active, data.recovery, block, hit, data.damage, data.guard, _notes(data)])
	return out


static func _notes(data: Dictionary) -> String:
	var notes: Array[String] = []
	var invuln: Array = data.invuln
	if not invuln.is_empty():
		notes.append("strike invuln %d-%d" % [invuln[0], invuln[1]])
	var armor: Array = data.armor
	if not armor.is_empty():
		notes.append("1-hit armour %d-%d" % [armor[0], armor[1]])
	if not (data.launch as Array).is_empty():
		notes.append("launcher")
	if data.knockdown:
		notes.append("knockdown")
	if data.wall_bounce:
		notes.append("wall bounce")
	if data.ground_bounce:
		notes.append("ground bounce")
	if int(data.hits) > 1:
		notes.append("%d hits" % data.hits)
	if int(data.cancel) >= 2:
		notes.append("chains")
	elif int(data.cancel) == 1:
		notes.append("cancels into techniques")
	if data.super_cancel:
		notes.append("finisher cancel on hit")
	if not (data.counter as Array).is_empty():
		notes.append("counters strikes %d-%d" % [data.counter[0], data.counter[1]])
	if data.evade:
		notes.append("passes through")
	if data.get("unbreakable", false):
		notes.append("unbreakable")
	if int(data.cinematic) > 0:
		notes.append("cinematic, needs full meter")
	return ", ".join(notes)
