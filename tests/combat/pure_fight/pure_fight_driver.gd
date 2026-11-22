class_name PureFightDriver
extends RefCounted
## Test helper: builds FighterInputs for Pure Fight from facing-relative numpad directions
## and button names, and steps a sim with them.

const A := FighterInput.Action
const BUTTONS := {"L": A.LIGHT, "M": A.SPECIAL_1, "H": A.HEAVY, "G": A.GRAB, "T": A.SPECIAL_2,
	"F": A.ULTIMATE, "D": A.DASH, "B": A.BLOCK}

var sim: PureFightSim
var _previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]


func _init(target: PureFightSim) -> void:
	sim = target


## A sim already in the FIGHT phase, fighters gap mm apart around the centre.
static func fighting(legends: Array[StringName] = [&"kael", &"vexa"], gap := 1200) -> PureFightSim:
	var sim := PureFightSim.new(1, legends)
	var driver := PureFightDriver.new(sim)
	while sim.phase != PureFightSim.Phase.FIGHT:
		driver.step()
	sim.pf[0].x = -gap / 2
	sim.pf[1].x = gap - gap / 2
	return sim


func input_for(index: int, dir: int, buttons := "") -> FighterInput:
	var held := 0
	for b in buttons:
		held |= int(BUTTONS[b])
	var input := FighterInput.from_held(held, _previous[index])
	var fighter := sim.pf[index]
	var fwd := ((dir - 1) % 3) - 1
	var up := 1 if dir >= 7 else (-1 if dir <= 3 else 0)
	input.move = Vector2(fwd * fighter.facing, up)
	_previous[index] = input
	return input


## One tick: [dir, buttons] per fighter.
func step(p1 := [5, ""], p2 := [5, ""]) -> void:
	var inputs: Array[FighterInput] = [input_for(0, p1[0], p1[1]), input_for(1, p2[0], p2[1])]
	sim.tick(inputs)


## Steps n ticks with the same inputs.
func hold(n: int, p1 := [5, ""], p2 := [5, ""]) -> void:
	for i in n:
		step(p1, p2)


## Feeds a sequence of [dir, buttons] for fighter 0 (fighter 1 holds p2).
func sequence(steps: Array, p2 := [5, ""]) -> void:
	for s in steps:
		step(s, p2)
