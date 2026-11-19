class_name FighterState
extends RefCounted
## Simulation state of one fighter. Presentation reads it; only CombatSim
## writes it. Add new fields to state_values() so the state hash covers them.

## What the fighter is doing.
enum State {
	IDLE, ## Standing on the ground.
	MOVING, ## Running or sliding on the ground.
	FALLING, ## Airborne without flying; gravity applies.
	FLYING, ## Free flight, including hovering.
	DASHING, ## Any dash; dash_kind says which.
	VANISHING, ## Vanish step: teleported, briefly unable to act.
	CHARGING, ## Charging ki in place; any other action or a hit ends it.
	GUARD_BROKEN, ## Stunned after the guard meter ran out.
	ATTACKING, ## Performing a move; attack_phase() says which part.
	HITSTUN, ## Hit: unable to act for stun_ticks, flying with the knockback (a juggle when airborne).
	BLOCKSTUN, ## Blocked a hit, or pushed (push-block, grab tech): unable to act for stun_ticks, sliding with velocity.
	KNOCKDOWN, ## On the floor after a spike bounce, for stun_ticks; cannot be hit.
	BLOCKING, ## Holding block: guard up, slow drift only, no attacks except push-block.
	GRABBED, ## Held by grab_partner until the throw or a tech.
	THROWING, ## Holding grab_partner before throwing it.
	KO_FALL, ## Knocked out: no flight, falls with its knockback and bounces off the floor once.
	KO_DOWN, ## Knocked out and lying on the floor until the next round; cannot be hit.
}

## Part of the current move, derived from move_tick.
enum AttackPhase {
	NONE, ## Not attacking.
	HOLD, ## Holding the button to charge (Charged Smash).
	STARTUP,
	ACTIVE,
	RECOVERY,
}

## Stored meter units per display unit: meters are integers in sixtieths.
const METER_UNIT := 60

enum DashKind {
	NONE,
	STEP, ## Tapped dash: fixed short distance.
	SUSTAINED, ## Dash held past the step: steerable flight-dash.
	RUSH, ## Dash toward the lock-on target: homes in on it.
}

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Index of the locked-on opponent in CombatSim.fighters, or -1 for none.
var lock_on_target: int = -1
## Side the fighter is on; the round ends when one team is left. Defaults to the slot index.
var team: int = 0
var state: State = State.IDLE
## Ticks spent in the current state, counting the tick it was entered.
var state_ticks: int = 0
## Heading in radians, same convention as FighterInput.view_yaw.
var facing_yaw: float = 0.0
var dash_kind: DashKind = DashKind.NONE
## Unit direction of the current dash, zero when not dashing.
var dash_direction: Vector3 = Vector3.ZERO
## Index of the fighter a vanish step is anchored to, or -1; the step keeps vanish_offset from it.
var vanish_anchor: int = -1
## Where a vanished fighter sits relative to its anchor until it reappears.
var vanish_offset: Vector3 = Vector3.ZERO
## Ticks since each action was last pressed, indexed by Action bit; capped at the buffer length.
var press_ages: Array[int] = []
## Action bits whose latest press was already consumed from the input buffer.
var consumed_presses: int = 0

# Meters, all in sixtieths (display value x METER_UNIT).
## Meter numbers for this fighter. Configuration, so not in the state hash.
var stats: FighterStats
var health: int = 0
## Recoverable damage on top of health; regenerates after a quiet spell.
var grey_health: int = 0
var ki: int = 0
var guard: int = 0
var burst: int = 0
## Ticks since the last hit, counted up to the grey regen delay.
var ticks_since_hit: int = 0
## Ticks since the last block or guard damage, counted up to the guard regen delay.
var ticks_since_block: int = 0
## True while the guard is up: BLOCKING, blockstun from a block, and push-block.
## Blocking pauses guard regeneration.
var blocking: bool = false
## Last Stand gives its free burst once per match.
var last_stand_used: bool = false

# Perfect block.
## A block press is live: a strike landing now is perfect-blocked.
var perfect_block_armed: bool = false
## Ticks since the live block press, 0 on the press tick.
var perfect_block_ticks: int = 0
## Ticks left in which a block press cannot perfect-block (anti-mash).
var perfect_block_lockout: int = 0

# Grab.
## The fighter held (THROWING) or holding this one (GRABBED), or -1.
var grab_partner: int = -1

# Attack, all reset when the fighter leaves ATTACKING.
## The move being performed, or null.
var move: MoveData
## Tick of the move being performed, 0 on its first startup tick. Stays 0 while holding.
var move_tick: int = 0
## True while holding the button to charge a chargeable move.
var holding_charge: bool = false
## Ticks the charge button has been held since the press.
var charge_ticks: int = 0
## Charge level reached, 0 when not charged.
var charge_level: int = 0
## Position in the light string (1 = first light), 0 when not in one.
var string_index: int = 0
## A light press came outside the timing window: this hit ends the string.
var string_dropped: bool = false
## A light press came inside the window: the next hit comes out at recovery start.
var string_queued: bool = false
## The current move touched an opponent (set through CombatSim.register_contact).
var contact_hit: bool = false
var contact_blocked: bool = false
## Bit i is set once the current move hit, or was blocked by, fighter i.
var hit_targets: int = 0
## Hitbox pitch in radians (up is positive), captured when the attack starts; 0 when not attacking.
var aim_pitch: float = 0.0
## Side a SWEEP pushes the target to: 1 right, -1 left, from the move input at attack start.
var aim_side: int = 1
## Recovery added to the current move (a perfect block against it).
var extra_recovery_ticks: int = 0

# Being hit.
## Length of the current HITSTUN, BLOCKSTUN or KNOCKDOWN in ticks.
var stun_ticks: int = 0
## Ticks left frozen in hitstop; nothing advances for this fighter until it is 0.
var hitstop_ticks: int = 0
## How the last hit threw this fighter; drives its flight in HITSTUN.
var knockback_type: MoveData.KnockbackType = MoveData.KnockbackType.NONE
## A spiked fighter already bounced off the floor; the next landing knocks it down.
var spike_bounced: bool = false
## A knocked-out fighter already bounced off the floor; the next landing lays it down.
var ko_bounced: bool = false
## Hits and scaled damage (display units) of the combo being taken; 0 outside HITSTUN.
var combo_hits: int = 0
var combo_damage: int = 0

# Weapons (T-D14).
## Weapon in each inventory slot (Weapon.Kind, NONE = empty).
var weapons := PackedInt32Array([0, 0, 0])
## Ammo left per slot; kept per weapon so a swap keeps it.
var ammo := PackedInt32Array([0, 0, 0])
## Slot in hand, or -1 for unarmed.
var active_slot: int = -1
## Ticks left in which a weapon switch blocks attacks.
var switch_lockout: int = 0
## Ticks left reloading (revolver cylinder).
var reload_ticks: int = 0
## Ticks left Smitten (Heartstring Bow): drifts toward smitten_by, cannot attack.
var smitten_ticks: int = 0
var smitten_by: int = -1
## Ticks since Smitten last started, capped; a repeat inside the window lasts half as long.
var ticks_since_smitten: int = 1 << 20
## Height of the origin when standing at the current (x, z); the sim sets it each tick.
var stand_height: float = 1.0
## Slot in hand before the last switch (-1 unarmed), for the C quick-swap.
var last_slot: int = -1
## Storm Repeater heat: rises while firing, cools otherwise; overheated locks firing until cool.
var heat: int = 0
var overheated: bool = false
## Ticks the bow is held at full draw past the shot's startup; sets the draw level.
var draw_ticks: int = 0
## Ki Bow level-3 pin: ticks a wall can still catch this fighter, and whether one has.
var pin_ticks: int = 0
var pinned: bool = false
## Heartstring Tether: the fighter on the other end (-1 none), ticks left, string length.
var tether_partner: int = -1
var tether_ticks: int = 0
var tether_length: float = 0.0
## Damage percent of the combo being taken: 80 when a ranged hit started it.
var combo_starter_percent: int = 100

# Powers and gadgets (T-D26).
var powers := FighterPowers.new()

# Pushback (T-D29): a hit or block slides the target apart from its attacker.
## Slide per second still owed, zero when none.
var pushback_velocity: Vector3 = Vector3.ZERO
var pushback_ticks: int = 0
## Attacker that takes whatever part of the slide a wall stops, or -1.
var pushback_from: int = -1

## States whose body other fighters pass through: vanished, or lying knocked out.
const PUSHBOX_FREE_STATES: Array[State] = [State.VANISHING, State.KO_DOWN]


## Switches to new_state and restarts the tick counter, even if it is the same state.
## Leaving ATTACKING clears the attack; leaving HITSTUN ends the combo. Any change drops the vanish anchor.
func enter_state(new_state: State) -> void:
	state = new_state
	state_ticks = 0
	stun_ticks = 0
	vanish_anchor = -1
	vanish_offset = Vector3.ZERO
	if new_state != State.ATTACKING:
		_clear_attack()
		aim_pitch = 0.0
		aim_side = 1
	if new_state != State.HITSTUN:
		knockback_type = MoveData.KnockbackType.NONE
		spike_bounced = false
		combo_hits = 0
		combo_damage = 0
		combo_starter_percent = 100
	if new_state != State.KO_FALL and new_state != State.KO_DOWN:
		ko_bounced = false
	clear_pushback()


func clear_pushback() -> void:
	pushback_velocity = Vector3.ZERO
	pushback_ticks = 0
	pushback_from = -1


## Starts performing new_move from its first startup tick.
func begin_move(new_move: MoveData) -> void:
	enter_state(State.ATTACKING)
	_clear_attack()
	move = new_move


## Id of the move being performed, empty when not attacking.
func move_id() -> StringName:
	return move.id if move else &""


func attack_phase() -> AttackPhase:
	if move == null:
		return AttackPhase.NONE
	if holding_charge:
		return AttackPhase.HOLD
	if move_tick < move.startup_ticks:
		return AttackPhase.STARTUP
	if move_tick < move.recovery_start_tick():
		return AttackPhase.ACTIVE
	return AttackPhase.RECOVERY


## Ticks the current move lasts, extra recovery included; 0 when not attacking.
func move_total_ticks() -> int:
	return move.total_ticks() + extra_recovery_ticks if move else 0


## Ticks into the current attack phase, 0 on its first tick. HOLD counts from the button press.
func phase_tick() -> int:
	match attack_phase():
		AttackPhase.HOLD:
			return charge_ticks - 1
		AttackPhase.STARTUP:
			return move_tick
		AttackPhase.ACTIVE:
			return move_tick - move.startup_ticks
		AttackPhase.RECOVERY:
			return move_tick - move.recovery_start_tick()
	return 0


## This tick's hitboxes in world space, as {start, end, radius}; start == end is a sphere.
func active_hitboxes() -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	if move == null or holding_charge:
		return shapes
	var to_world := Transform3D(aim_basis(), position)
	for shape in move.hitboxes_at(move_tick):
		shapes.append({
			"start": to_world * (shape.start as Vector3),
			"end": to_world * (shape.end as Vector3),
			"radius": shape.radius,
		})
	return shapes


## Rotation of the hitboxes: facing yaw, then the aim pitch.
func aim_basis() -> Basis:
	return DetMath.axis_angle(Vector3.UP, facing_yaw) * DetMath.axis_angle(Vector3.RIGHT, aim_pitch)


## The body as a vertical capsule centred on position, as {start, end, radius}.
func hurtbox() -> Dictionary:
	var half := Vector3.UP * maxf(stats.hurtbox_height * 0.5 - stats.hurtbox_radius, 0.0)
	return {"start": position - half, "end": position + half, "radius": stats.hurtbox_radius}


## The solid body as a vertical capsule centred on position, as {start, end, radius}.
func pushbox() -> Dictionary:
	return pushbox_at(position)


func pushbox_at(at: Vector3) -> Dictionary:
	var half := Vector3.UP * maxf(stats.pushbox_height * 0.5 - stats.pushbox_radius, 0.0)
	return {"start": at - half, "end": at + half, "radius": stats.pushbox_radius}


## True while other fighters pass through this one: vanish, KO on the floor, or a move's pass-through step.
func ignores_pushbox() -> bool:
	if state in PUSHBOX_FREE_STATES:
		return true
	return move != null and move.ignores_pushbox and attack_phase() == AttackPhase.STARTUP


## True if a hitbox centred at point hits the upper body (above mid-height).
func is_upper_body(point: Vector3) -> bool:
	return point.y > position.y


## False while knocked down, knocked out or vanished: hits pass through.
func can_be_hit() -> bool:
	return state != State.KNOCKDOWN and state != State.VANISHING and not is_knocked_out()


## True while hits do not interrupt the current move (armor).
func is_armored() -> bool:
	return move != null and not holding_charge \
		and move_tick >= move.armor_start_tick and move_tick < move.armor_end_tick


## True while a hit on the given body part passes through (invincibility).
func is_invincible_to(upper_body_hit: bool) -> bool:
	if move == null or holding_charge \
			or move_tick < move.invincible_start_tick or move_tick >= move.invincible_end_tick:
		return false
	return upper_body_hit or not move.invincible_upper_body_only


func is_grounded() -> bool:
	return state == State.IDLE or state == State.MOVING


func is_knocked_out() -> bool:
	return health <= 0


## In KO_FALL or KO_DOWN: the KO physics own this fighter until the next round.
func is_ko_state() -> bool:
	return state == State.KO_FALL or state == State.KO_DOWN


# Display values for the HUD.

func health_display() -> float:
	return float(health) / METER_UNIT


func grey_health_display() -> float:
	return float(grey_health) / METER_UNIT


func ki_display() -> float:
	return float(ki) / METER_UNIT


func guard_display() -> float:
	return float(guard) / METER_UNIT


func burst_display() -> float:
	return float(burst) / METER_UNIT


## Every value that defines this fighter, for CombatSim.state_hash().
func state_values() -> Array:
	return [
		position, velocity, lock_on_target, state, state_ticks, facing_yaw,
		dash_kind, dash_direction, vanish_anchor, vanish_offset, press_ages, consumed_presses,
		health, grey_health, ki, guard, burst, ticks_since_hit, ticks_since_block,
		blocking, last_stand_used,
		move_id(), move_tick, holding_charge, charge_ticks, charge_level,
		string_index, string_dropped, string_queued, contact_hit, contact_blocked,
		hit_targets, aim_pitch, aim_side, stun_ticks, hitstop_ticks, knockback_type, spike_bounced,
		combo_hits, combo_damage,
		perfect_block_armed, perfect_block_ticks, perfect_block_lockout, grab_partner,
		extra_recovery_ticks,
		weapons, ammo, active_slot, switch_lockout, reload_ticks,
		smitten_ticks, smitten_by, ticks_since_smitten,
		team, ko_bounced,
		pushback_velocity, pushback_ticks, pushback_from,
		last_slot, heat, overheated, draw_ticks, pin_ticks, pinned,
		tether_partner, tether_ticks, tether_length, combo_starter_percent,
	] + powers.state_values()


## Weapon in hand (Weapon.Kind), NONE when unarmed.
func held_weapon() -> Weapon.Kind:
	return weapons[active_slot] as Weapon.Kind if active_slot >= 0 else Weapon.Kind.NONE


## Ammo of the weapon in hand for the HUD, or -1 when unarmed or melee.
func held_ammo() -> int:
	var kind := held_weapon()
	return ammo[active_slot] if Weapon.is_ranged(kind) else -1


## Draw level of a bow shot being held (1-3), 0 when not drawing.
func draw_level() -> int:
	if move == null or not WeaponMoves.is_shot(move) or move_tick < move.startup_ticks - 1:
		return 0
	return WeaponMoves.draw_level(draw_ticks)


## Number of filled weapon slots.
func weapon_count() -> int:
	var count := 0
	for kind in weapons:
		if kind != Weapon.Kind.NONE:
			count += 1
	return count


func _clear_attack() -> void:
	move = null
	move_tick = 0
	holding_charge = false
	charge_ticks = 0
	charge_level = 0
	string_index = 0
	string_dropped = false
	string_queued = false
	contact_hit = false
	contact_blocked = false
	hit_targets = 0
	extra_recovery_ticks = 0
