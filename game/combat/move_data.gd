class_name MoveData
extends Resource
## Frame data and properties of one attack. Durations in ticks, counted from
## the move's first startup tick (tick 0); end ticks are exclusive. Distances
## in metres; offsets in the fighter's local space (-Z forward, +Y up, +X right).

## How a hit throws the target; T-D04 and T-D07 act on it.
enum KnockbackType { NONE, BLOWBACK, LAUNCH, SPIKE, WALL_SPLAT, SWEEP }

## Cancel hierarchy: a move can be cancelled only into a higher level.
enum CancelLevel { LIGHT = 1, HEAVY, SPECIAL, VANISH, ULTIMATE }

## Stable name used in the state hash, replays and the view.
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Timing")
@export var startup_ticks: int = 1
@export var active_ticks: int = 1
@export var recovery_ticks: int = 1
## Distance the fighter steps along its facing, spread evenly over startup; negative steps back.
@export var step_distance: float = 0.0

@export_group("Hitboxes")
## One entry per active tick; a shorter list holds its last entry. Sphere or capsule centre.
@export var hitbox_offsets: PackedVector3Array = PackedVector3Array()
@export var hitbox_radii: PackedFloat32Array = PackedFloat32Array()
## Capsule length per active tick; 0 or missing makes a sphere.
@export var hitbox_lengths: PackedFloat32Array = PackedFloat32Array()
## Capsule axis per active tick (unit, local space); missing means forward.
@export var hitbox_axes: PackedVector3Array = PackedVector3Array()

@export_group("On contact")
## Damage before scaling, in display units.
@export var damage: int = 0
@export var hitstun_ticks: int = 0
@export var blockstun_ticks: int = 0
@export var hitstop_ticks: int = 0
@export var knockback_type: KnockbackType = KnockbackType.NONE
## Knockback velocity in the attacker's local space, m/s.
@export var knockback: Vector3 = Vector3.ZERO
## Guard removed when blocked, in display units.
@export var guard_damage: int = 0
## On block, the guard breaks outright if it is below this (0 = never).
@export var guard_break_below: int = 0

@export_group("Meters")
## Ki spent to start the move; it does not start without it.
@export var ki_cost: int = 0
## Ki gained on hit on top of the shared per-hit gain.
@export var ki_gain: int = 0
## Burst gained on hit on top of the shared damage-based gain.
@export var burst_gain: int = 0

@export_group("Cancels")
@export var cancel_level: CancelLevel = CancelLevel.LIGHT
## Ticks in which a higher-level move may cancel this one, once it made contact.
@export var cancel_start_tick: int = 0
@export var cancel_end_tick: int = 0
@export var cancel_on_hit: bool = true
@export var cancel_on_block: bool = true
## Light string: the next light press must land in this window (clipped at the move's end).
@export var string_window_start_tick: int = 0
@export var string_window_ticks: int = 12

@export_group("Protection")
## Ticks in which hits do not interrupt the move.
@export var armor_start_tick: int = 0
@export var armor_end_tick: int = 0
## Ticks in which hits pass through the fighter.
@export var invincible_start_tick: int = 0
@export var invincible_end_tick: int = 0
## Invincibility covers only the upper body (anti-air).
@export var invincible_upper_body_only: bool = false

@export_group("Charge")
## Holding the button this many ticks from the press reaches each charge level.
## The move set says which move each level performs on release.
@export var charge_level_ticks: PackedInt32Array = PackedInt32Array()


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks


## First recovery tick: a queued string hit comes out here at the earliest.
func recovery_start_tick() -> int:
	return startup_ticks + active_ticks


func can_charge() -> bool:
	return not charge_level_ticks.is_empty()


## Hitboxes at a move tick in local space, as {start, end, radius}; empty outside active.
func hitboxes_at(move_tick: int) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var active_tick := move_tick - startup_ticks
	if active_tick < 0 or active_tick >= active_ticks or hitbox_offsets.is_empty():
		return shapes
	var centre := hitbox_offsets[mini(active_tick, hitbox_offsets.size() - 1)]
	var radius := hitbox_radii[mini(active_tick, hitbox_radii.size() - 1)]
	var length := 0.0
	if not hitbox_lengths.is_empty():
		length = hitbox_lengths[mini(active_tick, hitbox_lengths.size() - 1)]
	var axis := Vector3.FORWARD
	if not hitbox_axes.is_empty():
		axis = hitbox_axes[mini(active_tick, hitbox_axes.size() - 1)].normalized()
	var half := axis * (length * 0.5)
	shapes.append({"start": centre - half, "end": centre + half, "radius": radius})
	return shapes
