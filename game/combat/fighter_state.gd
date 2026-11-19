class_name FighterState
extends RefCounted
## Simulation state of one fighter. Presentation reads it; only CombatSim
## writes it. Milestone 1 adds movement fields, milestone 2+ combat fields.

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Index of the locked-on opponent in CombatSim.fighters, or -1 for none.
var lock_on_target: int = -1
