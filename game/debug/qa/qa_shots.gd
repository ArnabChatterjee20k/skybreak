class_name QaShots
extends RefCounted
## Fixed camera shots for the visual goldens: each legend idle and mid-light-attack
## in Heartbloom Gardens, and one shot in each other zone. Scripted input only, so
## the sim reaches the same state every run.

const SHOT_TICK := 150
## The light lands its active frames about here after the press.
const ATTACK_PRESS_TICK := 142


static func all() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for legend in QaMatchSpec.LEGENDS:
		var spec := "7:heartbloom_gardens:1v1:%s,%s:33" % [legend, _rival(legend)]
		shots.append({"name": "heartbloom_%s_idle" % legend, "spec": spec, "tick": SHOT_TICK, "plan": idle})
		shots.append({"name": "heartbloom_%s_light" % legend, "spec": spec, "tick": SHOT_TICK, "plan": light})
	for zone in ZoneLayout.ZONE_IDS:
		if zone == &"heartbloom_gardens":
			continue
		shots.append({"name": "zone_%s" % zone, "spec": "7:%s:1v1:kael,brann:33" % zone,
			"tick": SHOT_TICK, "plan": idle})
	return shots


static func idle(_sim: CombatSim, _slot: int, _tick: int) -> FighterInput:
	return FighterInput.new()


## Slot 0 taps light once, shortly before the shot.
static func light(_sim: CombatSim, slot: int, tick: int) -> FighterInput:
	var input := FighterInput.new()
	if slot == 0 and tick == ATTACK_PRESS_TICK:
		input.held_actions = FighterInput.Action.LIGHT
		input.pressed_actions = FighterInput.Action.LIGHT
	return input


static func _rival(legend: StringName) -> StringName:
	return &"brann" if legend != &"brann" else &"kael"
