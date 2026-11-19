class_name Projectile
extends RefCounted
## A shot, pellet or thrown weapon in flight. Sim state: only CombatSim writes
## it. Moves in a straight line plus gravity; hits are swept along each tick's
## path so fast bullets never tunnel through a body.

var id: int = 0
## Index of the fighter who fired or threw it (changes when perfect-blocked back).
var owner: int = 0
## Weapon that fired it, or the weapon thrown.
var weapon: Weapon.Kind = Weapon.Kind.NONE
## True for a thrown weapon: it lands as a pickup when it stops.
var thrown: bool = false
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 0.0
var radius: float = 0.2
var ticks_left: int = 0
## Hit numbers (damage, stun, knockback, guard damage) as a MoveData.
var move: MoveData
var effect: Weapon.Effect = Weapon.Effect.NONE
## Ammo a thrown ranged weapon still carries.
var ammo: int = 0
## Ticks since it was fired.
var age: int = 0
## Bow draw level it was fired at (1-3), 0 for other shots.
var level: int = 0
## Bit i set once it hit fighter i (piercing arrows and discs hit each fighter once per pass).
var hit_mask: int = 0
## Orbit Chakram disc on its way back to the thrower.
var returning: bool = false


func state_values() -> Array:
	return [id, owner, weapon, thrown, position, velocity, gravity, radius, ticks_left,
		move.id if move else &"", effect, ammo, age, level, hit_mask, returning]
