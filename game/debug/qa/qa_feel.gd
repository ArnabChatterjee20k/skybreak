class_name QaFeel
extends RefCounted
## Feel probes on a bare sim: ticks from a button press to the move's first active
## frame, per legend and attack input, standing and airborne.

const PROBES := {
	"light": FighterInput.Action.LIGHT,
	"heavy": FighterInput.Action.HEAVY,
	"grab": FighterInput.Action.GRAB,
}
const MAX_TICKS := 120


## legend -> "input@ground|air" -> {move, ticks} (ticks -1: never went active).
static func latencies() -> Dictionary:
	var out := {}
	for legend in QaMatchSpec.LEGENDS:
		var per := {}
		for probe: String in PROBES:
			for airborne in [false, true]:
				per["%s@%s" % [probe, "air" if airborne else "ground"]] = _latency(legend, PROBES[probe], airborne)
		out[String(legend)] = per
	return out


static func _latency(legend: StringName, action: int, airborne: bool) -> Dictionary:
	var sim := CombatSim.new(3)
	var height := 8.0 if airborne else 0.0
	sim.add_fighter(Vector3(0, height, 0), Roster.character(legend).stats)
	sim.add_fighter(Vector3(0, height, -30), Roster.character(&"kael").stats)
	sim.lock_everyone_onto_nearest()
	var previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	for _settle in 10:
		previous = [FighterInput.new(), FighterInput.new()]
		sim.tick(previous)
	for t in MAX_TICKS:
		var held := action if t == 0 else 0
		var inputs: Array[FighterInput] = [FighterInput.from_held(held, previous[0]), FighterInput.new()]
		sim.tick(inputs)
		previous = inputs
		var f := sim.fighters[0]
		if f.attack_phase() == FighterState.AttackPhase.ACTIVE:
			return {"move": String(f.move_id()), "ticks": t + 1}
	return {"move": String(sim.fighters[0].move_id()), "ticks": -1}
