class_name FighterPowers
extends RefCounted
## One fighter's active powers and held gadget (T-D26). Sim state: only
## CombatSim writes it; FighterState.state_values() includes state_values().

var overdrive_ticks: int = 0
var haste_ticks: int = 0
## Aegis is up: the next hit is absorbed completely.
var aegis: bool = false
## Gadget in the gadget slot (Power.Kind), NONE when empty.
var gadget: Power.Kind = Power.Kind.NONE
## Id of the last move this fighter started, for the Mirror Decoy.
var last_move: StringName = &""


func state_values() -> Array:
	return [overdrive_ticks, haste_ticks, aegis, gadget, last_move]


## Powers that show as an aura now (Power.Kind), for the view.
func active_auras() -> Array[Power.Kind]:
	var auras: Array[Power.Kind] = []
	if overdrive_ticks > 0:
		auras.append(Power.Kind.OVERDRIVE_ORB)
	if haste_ticks > 0:
		auras.append(Power.Kind.HASTE)
	if aegis:
		auras.append(Power.Kind.AEGIS)
	return auras
