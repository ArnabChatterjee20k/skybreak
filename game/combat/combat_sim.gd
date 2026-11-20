class_name CombatSim
extends RefCounted
## Deterministic combat simulation, advanced in fixed ticks.
## Rules: no Node, Input, scene tree or delta access in here. Time is counted
## in ticks; use TICK_SECONDS when a duration in seconds is needed. All
## randomness comes from rng, so a seed plus the inputs replays a match exactly.

const TICKS_PER_SECOND := 60
const TICK_SECONDS := 1.0 / TICKS_PER_SECOND
## A press stays buffered for this many ticks, counting the tick it happened.
const INPUT_BUFFER_TICKS := 6
const DEFAULT_TUNING := preload("res://game/combat/default_movement_tuning.tres")
const DEFAULT_METER_TUNING := preload("res://game/combat/default_meter_tuning.tres")
const DEFAULT_FIGHTER_STATS := preload("res://game/combat/default_fighter_stats.tres")
const DEFAULT_HIT_TUNING := preload("res://game/combat/default_hit_tuning.tres")
const DEFAULT_ESCAPE_TUNING := preload("res://game/combat/escapes/default_escape_tuning.tres")

## What an entry in events reports.
enum EventType {
	HIT, ## A hit landed.
	COUNTER, ## A hit landed during the target's startup (or charge hold).
	ARMOR, ## A hit landed on armor: damage, but no stun or knockback.
	BLOCK, ## A hit was blocked.
	GUARD_BREAK, ## A blocked hit broke the guard.
	KO, ## A hit knocked the target out.
	PERFECT_BLOCK, ## A strike was perfect-blocked: no guard damage, the attacker recovers longer.
	GRAB, ## A grab connected; the target is held until the throw or a tech.
	THROW, ## A held target was thrown: damage and blowback.
	GRAB_TECH, ## A grab was teched, or two grabs clashed: both pushed apart, no damage.
	PUSH_BLOCK, ## A push-block shoved the target out to mid range.
	# Weapons (T-D14). Entries: {type, fighter (or -1), position, weapon (Weapon.Kind), id (pickup/projectile)}.
	PICKUP_SPAWN, ## A weapon drop was telegraphed (light pillar at position).
	PICKUP, ## fighter picked up the weapon; id is the pickup.
	PICKUP_DESPAWN, ## A pickup timed out.
	WEAPON_SWITCH, ## fighter switched to weapon (NONE = unarmed).
	WEAPON_THROW, ## fighter threw weapon; id is the projectile.
	WEAPON_DROP, ## fighter dropped weapon (KO, guard break, knockdown, replaced); id is the pickup.
	FIRE, ## fighter fired weapon; id is the first projectile, count how many.
	PROJECTILE_HIT, ## Projectile id touched target: blocked/reflected flags; HIT/BLOCK/KO follow as usual.
	# Knockout (T-D16). Entries: {type, fighter, position}.
	KO_BOUNCE, ## A knocked-out fighter hit the floor and bounced.
	KO_REST, ## A knocked-out fighter landed after its bounce and lies down.
	# Powers, gadgets and weapon extras (T-D26). Same entries, plus power (Power.Kind) for items.
	POWER_PICKUP, ## fighter took a power or gadget drop (power); id is the pickup.
	POWER_END, ## fighter's timed power (power) ran out.
	AEGIS_BREAK, ## Aegis on fighter absorbed a hit from attacker (move_id).
	GADGET_THROW, ## fighter threw or placed gadget id (power).
	GADGET_EXPLODE, ## Spike Bomb id went off at position; HIT/BLOCK follow for each fighter in the blast.
	MINE_TRIGGER, ## Gravity Mine id started pulling.
	DECOY_POP, ## Mirror Decoy id was struck and popped.
	GADGET_END, ## Gadget id fizzled or ran out.
	BOW_DRAW, ## fighter's bow reached draw level (level 2 or 3).
	ARROW_PIN, ## fighter was pinned to a wall by a level-3 arrow.
	TETHER, ## Heartstring Tether tied fighter and target (length).
	TETHER_YANK, ## fighter yanked target in along the tether.
	TETHER_END, ## The tether between fighter and target ran out or broke.
	OVERHEAT, ## fighter's Storm Repeater overheated.
	BULLET_ABSORB, ## fighter's dash absorbed repeater bullet id (+2 ki).
	SWAP_CANCEL, ## fighter swap-cancelled into weapon for 10 ki.
	DISC_CATCH, ## fighter caught its Orbit Chakram disc id.
	# Escapes (T-DEF3). Entries: {type, fighter, attacker (= fighter), target, position, way, caught}.
	COMBO_BREAKER, ## fighter burst out of a combo; target is the first opponent blown away (or -1).
	AIR_TECH, ## fighter teched out of knockback (way); caught: a chaser (target) read it.
	CHASE, ## fighter chased its knocked-back target (way: over, under, straight).
	TECH_ROLL, ## fighter rolled out of a knockdown.
	WAKEUP, ## fighter got up from a knockdown; delayed: it held descend.
}

const _DASH := FighterInput.Action.DASH
const _BLOCK := FighterInput.Action.BLOCK
const _CHARGE := FighterInput.Action.CHARGE
const _LIGHT := FighterInput.Action.LIGHT
const _HEAVY := FighterInput.Action.HEAVY
const _GRAB := FighterInput.Action.GRAB
const _PICKUP := FighterInput.Action.PICKUP
const _THROW := FighterInput.Action.THROW
const _WEAPON_NEXT := FighterInput.Action.WEAPON_NEXT
const _WEAPON_PREVIOUS := FighterInput.Action.WEAPON_PREVIOUS
const _QUICK_SWAP := FighterInput.Action.QUICK_SWAP
## Projectiles spawn this far in front of the fighter's centre, and this high.
const _MUZZLE_FORWARD := 0.8
const _MUZZLE_UP := 0.3
const _UNIT := FighterState.METER_UNIT
## Presses that do not interrupt charging.
const _CHARGE_SAFE_ACTIONS := FighterInput.Action.CHARGE | FighterInput.Action.LOCK_TOGGLE
## A rush dash counts as arrived within this many metres of its stop distance.
const _RUSH_ARRIVAL_MARGIN := 0.01
## States whose motion circles the lock-on target: strafing keeps the planar distance.
const _ORBIT_STATES: Array[FighterState.State] = [
	FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
	FighterState.State.BLOCKING, FighterState.State.DASHING,
]
## Closer than this (planar, metres) to the target, motion is in straight lines.
const _MIN_ORBIT_RADIUS := 0.5
## Hitbox pitch toward a locked target is clamped to this, in radians (45 degrees).
const _MAX_AIM_PITCH := PI / 4.0
## States in which the facing stays where it was.
const _FACING_LOCKED_STATES: Array[FighterState.State] = [
	FighterState.State.ATTACKING, FighterState.State.HITSTUN,
	FighterState.State.BLOCKSTUN, FighterState.State.KNOCKDOWN,
	FighterState.State.GRABBED, FighterState.State.THROWING,
	FighterState.State.KO_FALL, FighterState.State.KO_DOWN, FighterState.State.ESCAPING,
]
## States that cannot block even with blocking set.
const _NO_BLOCK_STATES: Array[FighterState.State] = [
	FighterState.State.HITSTUN, FighterState.State.KNOCKDOWN, FighterState.State.GUARD_BROKEN,
	FighterState.State.GRABBED, FighterState.State.THROWING,
]
## States in which holding block raises the guard; charging is ended by the press.
const _BLOCK_START_STATES: Array[FighterState.State] = [
	FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FALLING,
	FighterState.State.FLYING, FighterState.State.CHARGING,
]
## States in which a block press arms a perfect block, and a strike can be perfect-blocked.
const _PERFECT_BLOCK_STATES: Array[FighterState.State] = [
	FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FALLING,
	FighterState.State.FLYING, FighterState.State.BLOCKING,
]
## States a grab cannot take hold in.
const _UNGRABBABLE_STATES: Array[FighterState.State] = [
	FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN, FighterState.State.KNOCKDOWN,
	FighterState.State.GRABBED, FighterState.State.THROWING,
]
## States a push-block does not shove.
const _UNPUSHABLE_STATES: Array[FighterState.State] = [
	FighterState.State.HITSTUN, FighterState.State.KNOCKDOWN, FighterState.State.GRABBED,
]
## Planar move input shorter than this makes a neutral heavy.
const _HEAVY_DEADZONE := 0.5
## Move input within 45 degrees of toward/away from the target picks Breaker/Launcher.
const _HEAVY_CONE := 0.7071
## States an attack can start from; charging is ended first by the attack press.
const _ATTACK_START_STATES: Array[FighterState.State] = [
	FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
]

var current_tick: int = 0
var fighters: Array[FighterState] = []
var rng := RandomNumberGenerator.new()
## True once a fighter is knocked out; inputs are ignored until start_round().
var round_over: bool = false
## Index of the fighter who won the round, or -1 while it is undecided.
## With teams it is the winning team's first fighter still standing.
var round_winner: int = -1
## Team that won the round, or -1 while undecided or on a double KO.
var winning_team: int = -1
## Where each fighter starts a round when start_round() gets no spawn points:
## the add_fighter() positions. Configuration, like tuning.
var spawn_points: Array[Vector3] = []
## Movement constants. Not part of the state hash: it is configuration.
var tuning: MovementTuning
## Meter constants shared by all fighters. Configuration, like tuning.
var meter_tuning: MeterTuning
## Hit constants (scaling, stun, hitstop, knockback). Configuration, like tuning.
var hit_tuning: HitTuning
## Escape tools (combo breaker, air tech, chase, wakeups). Configuration, not hashed.
var escape_tuning: EscapeTuning = DEFAULT_ESCAPE_TUNING as EscapeTuning
## What happened this tick, for the view (every EventType), in the order it was
## resolved. Each entry: {type: EventType, attacker, target, position (contact
## point), move_id, damage (display units), hitstop, knockback_type, counter}.
## Replaced by a new array at the start of every tick.
var events: Array[Dictionary] = []
## Weapon spawner constants and zone tables. Configuration, like tuning.
var pickup_tuning := PickupTuning.new()
## Zone the match is in; picks the spawn table. Set before the first tick.
var zone: StringName = &"skyhold_ruins"
## Floor height under (x, z) for something at height y: func(x, z, y) -> float (T-D13).
## Unset is the flat floor at 0; a zone sets its quantised ground before the first tick.
var ground_height: Callable
## Centre (x, z) of the arena box; a zone moves it off the world origin.
var arena_centre := Vector2.ZERO
## True to drop weapons from the sky; off by default (a "pure duel"), on in the arena.
var pickups_enabled: bool = false
## Weapons in the world, and shots/thrown weapons in flight.
var pickups: Array[WeaponPickup] = []
var projectiles: Array[Projectile] = []
## Next pickup/projectile id.
var next_entity_id: int = 1
## Tick of the next drop; -1 until the first tick schedules it.
var next_spawn_tick: int = -1
var last_spawn_kind: Weapon.Kind = Weapon.Kind.NONE
## Sky drops so far; odd ones are powers or gadgets when pickup_tuning.powers_enabled.
var spawn_count: int = 0
## Thrown and placed gadgets (bombs, mines, decoys), T-D26.
var gadgets: Array[Gadget] = []


func _init(seed_value: int = 0, movement_tuning: MovementTuning = null,
		meters: MeterTuning = null, hits: HitTuning = null) -> void:
	rng.seed = seed_value
	tuning = movement_tuning if movement_tuning else DEFAULT_TUNING as MovementTuning
	meter_tuning = meters if meters else DEFAULT_METER_TUNING as MeterTuning
	hit_tuning = hits if hits else DEFAULT_HIT_TUNING as HitTuning


## Adds a fighter with round-start meters; above the floor it hovers, otherwise stands.
func add_fighter(start_position: Vector3, stats: FighterStats = null) -> FighterState:
	var fighter := FighterState.new()
	fighter.stats = stats if stats else DEFAULT_FIGHTER_STATS as FighterStats
	fighter.team = fighters.size()
	_reset_round_meters(fighter)
	for _action in FighterInput.Action.size():
		fighter.press_ages.append(INPUT_BUFFER_TICKS)
	_place(fighter, start_position)
	fighters.append(fighter)
	spawn_points.append(start_position)
	return fighter


## Locks every fighter onto its nearest opponent; a 1v1 match starts this way.
func lock_everyone_onto_nearest() -> void:
	for index in fighters.size():
		fighters[index].lock_on_target = _nearest_opponent(index)


## Advances the sim by one tick. inputs[i] belongs to fighters[i].
func tick(inputs: Array[FighterInput]) -> void:
	assert(inputs.size() == fighters.size(), "one input per fighter")
	events = []
	_knock_out_fallen()
	var frozen: Array[bool] = []
	var before := PackedVector3Array()
	var solid_before: Array[bool] = []
	for i in fighters.size():
		before.append(fighters[i].position)
		solid_before.append(not fighters[i].ignores_pushbox())
		frozen.append(fighters[i].hitstop_ticks > 0)
		# After the round is decided everyone, and a KO'd fighter always, gets neutral input.
		var neutral := round_over or fighters[i].is_knocked_out()
		_step_fighter(i, FighterInput.new() if neutral else inputs[i])
	_follow_vanish_anchors()
	Pushboxes.resolve(self, before, solid_before, frozen)
	if not round_over:
		_resolve_hits(frozen)
	_step_projectiles()
	WeaponEffects.step_pins(self)
	WeaponEffects.step_tethers(self)
	PowerRules.step(self)
	_knock_out_fallen()
	_step_pickups()
	_canonicalize_zeros()
	current_tick += 1


## Starts a new round. Each fighter goes back to its spawn point (spawn_points[i],
## or the add_fighter() position when the list is empty or short), standing
## still and facing its nearest opponent, with health, ki and guard full,
## nothing buffered and weapons cleared. Burst and Last Stand carry over
## (comeback rule, GAME_DESIGN §5.2). Projectiles and pickups are cleared.
func start_round(round_spawn_points: Array[Vector3] = []) -> void:
	round_over = false
	round_winner = -1
	winning_team = -1
	projectiles = []
	gadgets = []
	pickups = []
	next_spawn_tick = -1
	last_spawn_kind = Weapon.Kind.NONE
	for index in fighters.size():
		var start := spawn_points[index]
		if index < round_spawn_points.size():
			start = round_spawn_points[index]
		_reset_fighter(fighters[index], start)
	for index in fighters.size():
		var fighter := fighters[index]
		if fighter.lock_on_target >= 0:
			fighter.lock_on_target = _nearest_opponent(index)
		var nearest := _nearest_opponent(index)
		if nearest >= 0:
			var look := fighters[nearest].position - fighter.position
			if Vector2(look.x, look.z).length_squared() > 0.0001:
				fighter.facing_yaw = DetMath.atan2(-look.x, -look.z)
	_canonicalize_zeros()


## Turns -0.0 into +0.0 in every stored float, so equal states hash and serialise equally on every platform.
func _canonicalize_zeros() -> void:
	for fighter in fighters:
		fighter.position = DetMath.canon(fighter.position)
		fighter.velocity = DetMath.canon(fighter.velocity)
		fighter.dash_direction = DetMath.canon(fighter.dash_direction)
		fighter.vanish_offset = DetMath.canon(fighter.vanish_offset)
		fighter.pushback_velocity = DetMath.canon(fighter.pushback_velocity)
		fighter.ko_origin = DetMath.canon(fighter.ko_origin)
		fighter.facing_yaw += 0.0
		fighter.aim_pitch += 0.0
		fighter.tether_length += 0.0
	for projectile in projectiles:
		projectile.position = DetMath.canon(projectile.position)
		projectile.velocity = DetMath.canon(projectile.velocity)
		projectile.gravity += 0.0
	for gadget in gadgets:
		gadget.position = DetMath.canon(gadget.position)
		gadget.velocity = DetMath.canon(gadget.velocity)
		gadget.facing_yaw += 0.0
	for pickup in pickups:
		pickup.position = DetMath.canon(pickup.position)
		pickup.fall_speed += 0.0


## Hash of everything that defines the sim state; equal hashes mean equal states.
func state_hash() -> int:
	# Events are this tick's output, but cheap to cover, so replays can compare them too.
	var parts: Array = [current_tick, rng.state, round_over, round_winner, winning_team, events,
		zone, pickups_enabled, next_entity_id, next_spawn_tick, last_spawn_kind, spawn_count]
	for fighter in fighters:
		parts.append_array(fighter.state_values())
	for pickup in pickups:
		parts.append_array(pickup.state_values())
	for projectile in projectiles:
		parts.append_array(projectile.state_values())
	for gadget in gadgets:
		parts.append_array(gadget.state_values())
	return hash(var_to_bytes(parts))


## Copy of the whole sim state (fighters, pickups, projectiles, rng) for rollback.
func snapshot() -> SimSnapshot:
	return SimSnapshot.capture(self)


## Puts a snapshot() back; fighters keep their object identity for the view.
func restore(saved: SimSnapshot) -> void:
	saved.restore_into(self)


## True while a press of action is inside the buffer window and not yet consumed.
func is_buffered(fighter_index: int, action: FighterInput.Action) -> bool:
	var fighter := fighters[fighter_index]
	return fighter.press_ages[_action_index(action)] < INPUT_BUFFER_TICKS \
		and (fighter.consumed_presses & action) == 0


## Uses up a buffered press so it acts only once. False if none is buffered.
func consume_buffered(fighter_index: int, action: FighterInput.Action) -> bool:
	if not is_buffered(fighter_index, action):
		return false
	fighters[fighter_index].consumed_presses |= action
	return true


## True when DASH and BLOCK were both pressed within the buffer window, in
## either order, even if one press already started something; or when one is
## pressed (buffered, unused) while the other is held in held_actions (vanish input).
func has_vanish_input(fighter_index: int, held_actions: int = 0) -> bool:
	var ages := fighters[fighter_index].press_ages
	if ages[_action_index(_DASH)] < INPUT_BUFFER_TICKS and ages[_action_index(_BLOCK)] < INPUT_BUFFER_TICKS:
		return true
	return (is_buffered(fighter_index, _DASH) and (held_actions & _BLOCK) != 0) \
		or (is_buffered(fighter_index, _BLOCK) and (held_actions & _DASH) != 0)


## Spends amount ki (display units) if the fighter has that much. False otherwise.
func try_spend_ki(fighter_index: int, amount: int) -> bool:
	return _spend_ki(fighters[fighter_index], amount)


## Ki gain for landing a hit; a landed hit calls it for the attacker.
func add_landed_hit_ki(fighter_index: int) -> void:
	_add_ki(fighters[fighter_index], meter_tuning.ki_per_landed_hit * _UNIT)


## Ki gain for a blocked hit; a blocked hit calls it for the attacker.
func add_blocked_hit_ki(fighter_index: int) -> void:
	_add_ki(fighters[fighter_index], meter_tuning.ki_per_blocked_hit * _UNIT)


## Burst gain for a perfect block; a perfect block calls it for the blocker.
func add_perfect_block_burst(fighter_index: int) -> void:
	_add_burst(fighters[fighter_index], meter_tuning.burst_per_perfect_block * _UNIT)


## True if a projectile arriving now from from_position would be reflected
## (a perfect block); for ki blasts and bullets.
func reflects_projectiles(fighter_index: int, from_position: Vector3) -> bool:
	return _perfect_blocks(fighters[fighter_index], from_position)


## Spends whole burst stocks if the fighter has them. False otherwise.
func try_spend_burst(fighter_index: int, stocks: int) -> bool:
	var fighter := fighters[fighter_index]
	var cost := stocks * meter_tuning.burst_stock_size * _UNIT
	if fighter.burst < cost:
		return false
	fighter.burst -= cost
	return true


## Applies already-scaled damage (display units); attacker -1 means no attacker.
## Grey health builds up while the target is in HITSTUN (one combo); damage
## outside hitstun starts a new combo and loses the earlier grey part.
func apply_damage(target_index: int, attacker_index: int, amount: int) -> void:
	var target := fighters[target_index]
	if round_over or amount <= 0 or target.is_knocked_out():
		return
	var dealt := mini(amount * _UNIT, target.health)
	target.health -= dealt
	var grey := dealt * meter_tuning.grey_percent / 100
	if target.state == FighterState.State.HITSTUN:
		grey += target.grey_health
	target.grey_health = 0 if target.is_knocked_out() else grey
	target.ticks_since_hit = 0
	if target.state == FighterState.State.CHARGING:
		_enter_free_state(target)
	_add_burst(target, dealt * meter_tuning.burst_per_1000_damage_taken / 1000)
	if attacker_index >= 0:
		_add_burst(fighters[attacker_index], dealt * meter_tuning.burst_per_1000_damage_dealt / 1000)
	if target.is_knocked_out():
		_drop_all_weapons(target_index)
		_end_round_if_decided()
	elif not target.last_stand_used and target.health * 100 \
			< target.stats.max_health * _UNIT * meter_tuning.last_stand_health_percent:
		target.last_stand_used = true
		_add_burst(target, meter_tuning.last_stand_burst_stocks * meter_tuning.burst_stock_size * _UNIT)


## Removes guard (display units); at 0 the fighter is stunned in GUARD_BROKEN.
func apply_guard_damage(fighter_index: int, amount: int) -> void:
	var fighter := fighters[fighter_index]
	if round_over or amount <= 0:
		return
	fighter.guard = maxi(fighter.guard - amount * _UNIT, 0)
	fighter.ticks_since_block = 0
	if fighter.guard == 0:
		_drop_held_weapon(fighter_index)
		fighter.blocking = false
		fighter.velocity = Vector3.ZERO
		fighter.dash_kind = FighterState.DashKind.NONE
		fighter.dash_direction = Vector3.ZERO
		fighter.enter_state(FighterState.State.GUARD_BROKEN)


## Records that the fighter's current move touched an opponent, which opens
## its cancel window. Hits and blocks call it; ignored when not attacking.
func register_contact(fighter_index: int, blocked: bool) -> void:
	var fighter := fighters[fighter_index]
	if fighter.state != FighterState.State.ATTACKING or fighter.holding_charge:
		return
	if blocked:
		fighter.contact_blocked = true
	else:
		fighter.contact_hit = true


## True if the current move may be cancelled into a move of this level right
## now: higher level only, inside the cancel window, after contact.
func can_cancel_into(fighter_index: int, level: MoveData.CancelLevel) -> bool:
	var fighter := fighters[fighter_index]
	var move := fighter.move
	if fighter.state != FighterState.State.ATTACKING or fighter.holding_charge \
			or level <= move.cancel_level \
			or fighter.move_tick < move.cancel_start_tick or fighter.move_tick >= move.cancel_end_tick:
		return false
	return (fighter.contact_hit and move.cancel_on_hit) \
		or (fighter.contact_blocked and move.cancel_on_block)


## Damage (display units) of a move as hit number combo_hit (1-based) of a combo.
func scaled_damage(move: MoveData, combo_hit: int) -> int:
	var floor_percent := hit_tuning.scaling_floor_percent
	if move.cancel_level == MoveData.CancelLevel.ULTIMATE:
		floor_percent = hit_tuning.ultimate_scaling_floor_percent
	var percent := maxi(floor_percent, 100 - hit_tuning.scaling_step_percent * (combo_hit - 1))
	return move.damage * percent / 100


## Hitstun of a move as hit number combo_hit of a combo, after hitstun decay.
func decayed_hitstun(move: MoveData, combo_hit: int) -> int:
	var base := move.hitstun_ticks
	var decay := maxi(combo_hit - hit_tuning.hitstun_decay_after_hit, 0) * hit_tuning.hitstun_decay_per_hit
	return maxi(mini(base, hit_tuning.min_hitstun_ticks), base - decay)


## Uses up a vanish input (both presses). False if there is none.
func consume_vanish_input(fighter_index: int, held_actions: int = 0) -> bool:
	if not has_vanish_input(fighter_index, held_actions):
		return false
	var fighter := fighters[fighter_index]
	fighter.press_ages[_action_index(_DASH)] = INPUT_BUFFER_TICKS
	fighter.press_ages[_action_index(_BLOCK)] = INPUT_BUFFER_TICKS
	fighter.consumed_presses &= ~(_DASH | _BLOCK)
	return true


func _step_fighter(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	if fighter.hitstop_ticks > 0:
		# Frozen: new presses still buffer, but nothing else moves on.
		fighter.hitstop_ticks -= 1
		_record_presses(fighter, input, false)
		return
	var state_before := fighter.state
	var start_y := fighter.position.y
	EscapeRules.count(fighter)
	_record_presses(fighter, input)
	_update_lock_on(index, input)
	_count_weapon_timers(fighter)
	var wish := _wish_direction(index, input)
	_finish_timed_action(index, input)
	if not round_over and not fighter.is_knocked_out():
		_handle_weapon_inputs(index)
		_start_buffered_action(index, input, wish)
		_start_block(index, input)
		_start_grab(index)
		_start_attack(index, input, wish)
		_start_charging(index)
	_track_block_press(index, input, state_before)
	match fighter.state:
		FighterState.State.IDLE, FighterState.State.MOVING:
			_move_on_ground(fighter, input, wish)
		FighterState.State.FALLING:
			_move_falling(fighter, input, wish)
		FighterState.State.FLYING:
			_move_flying(fighter, input, wish)
		FighterState.State.DASHING:
			_move_dashing(index, input, wish)
		FighterState.State.ATTACKING:
			_move_attacking(fighter)
			WeaponEffects.move_while_firing(self, fighter, wish)
		FighterState.State.HITSTUN:
			_move_in_hitstun(fighter)
		FighterState.State.BLOCKING:
			_move_blocking(fighter, wish)
		FighterState.State.GRABBED:
			fighter.velocity = Vector3.ZERO
			fighter.position = _hold_position(fighters[fighter.grab_partner])
		FighterState.State.BLOCKSTUN:
			pass # Keeps the slide a push gave it; a plain block stands still.
		FighterState.State.VANISHING, FighterState.State.CHARGING, FighterState.State.GUARD_BROKEN, \
				FighterState.State.KNOCKDOWN, FighterState.State.THROWING:
			fighter.velocity = Vector3.ZERO
		FighterState.State.KO_FALL:
			_move_ko_falling(fighter)
		FighterState.State.KO_DOWN:
			_move_ko_down(fighter)
		FighterState.State.ESCAPING:
			EscapeRules.move(self, fighter)
	# Haste stretches this tick's travel without changing the stored velocity.
	var speed := PowerRules.speed_percent(fighter) / 100.0
	var from := fighter.position
	var on_floor := ground_height.is_valid() and _is_on_floor(fighter)
	fighter.velocity *= speed
	_integrate(index)
	fighter.velocity /= speed
	_stop_on_skipped_island(fighter, start_y)
	if on_floor:
		_stop_at_cliff(fighter, from)
	_drift_if_smitten(fighter)
	if fighter.state == FighterState.State.HITSTUN:
		_bounce_or_knock_down(fighter)
	elif fighter.state == FighterState.State.KO_FALL:
		_bounce_or_rest(index)
	if fighter.is_ko_state():
		_bounce_off_arena_walls(fighter)
	_clamp_to_arena(fighter)
	_land_if_on_floor(fighter)
	fighter.stand_height = _stand_height(fighter)
	# Attacks and stuns keep the facing they started with; an unlocked guard holds its facing.
	if fighter.state not in _FACING_LOCKED_STATES \
			and (fighter.state != FighterState.State.BLOCKING or fighter.lock_on_target >= 0):
		_update_facing(index)
	_update_blocking(fighter)
	if not round_over and not fighter.is_knocked_out():
		_update_meters(fighter)
	fighter.state_ticks += 1


## Buffers this tick's presses; with age false (hitstop) older presses keep their age.
func _record_presses(fighter: FighterState, input: FighterInput, age: bool = true) -> void:
	for index in fighter.press_ages.size():
		var bit := 1 << index
		if (input.pressed_actions & bit) != 0:
			fighter.press_ages[index] = 0
			fighter.consumed_presses &= ~bit
		elif age and fighter.press_ages[index] < INPUT_BUFFER_TICKS:
			fighter.press_ages[index] += 1
			if fighter.press_ages[index] == INPUT_BUFFER_TICKS:
				fighter.consumed_presses &= ~bit


func _update_lock_on(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	# A knocked-out target is dropped for the nearest opponent still fighting (FFA).
	if not round_over and fighter.lock_on_target >= 0 \
			and fighters[fighter.lock_on_target].is_knocked_out():
		fighter.lock_on_target = _nearest_opponent(index)
	if input.is_pressed(FighterInput.Action.LOCK_TOGGLE):
		fighter.lock_on_target = -1 if fighter.lock_on_target >= 0 else _nearest_opponent(index)
	elif fighter.lock_on_target >= 0 and input.target_switch != 0:
		fighter.lock_on_target = _next_opponent(index, fighter.lock_on_target, input.target_switch)


## Ends dashes, vanishes, charging, guard breaks, stuns and attacks that are over, before new actions.
func _finish_timed_action(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	match fighter.state:
		FighterState.State.ATTACKING:
			_advance_attack(index, input)
			return
		FighterState.State.HITSTUN, FighterState.State.KNOCKDOWN, FighterState.State.ESCAPING:
			if EscapeRules.step(self, index, input):
				return
			if fighter.state_ticks >= fighter.stun_ticks:
				_enter_free_state(fighter)
			return
		FighterState.State.BLOCKSTUN:
			if fighter.state_ticks >= fighter.stun_ticks:
				fighter.velocity = Vector3.ZERO
				_enter_free_state(fighter)
			return
		FighterState.State.BLOCKING:
			if not input.is_held(_BLOCK):
				_enter_free_state(fighter)
			return
		FighterState.State.GRABBED:
			if fighter.state_ticks < hit_tuning.grab_tech_ticks and consume_buffered(index, _GRAB):
				_tech_grab(index)
			return
		FighterState.State.THROWING:
			if fighter.state_ticks >= hit_tuning.grab_hold_ticks and not round_over:
				_throw(index)
			return
		FighterState.State.VANISHING:
			if fighter.state_ticks >= tuning.vanish_step_ticks:
				_enter_free_state(fighter)
			return
		FighterState.State.GUARD_BROKEN:
			if fighter.state_ticks >= meter_tuning.guard_break_ticks:
				_enter_free_state(fighter)
			return
		FighterState.State.CHARGING:
			if not input.is_held(_CHARGE) or (input.pressed_actions & ~_CHARGE_SAFE_ACTIONS) != 0:
				_enter_free_state(fighter)
			return
	if fighter.state != FighterState.State.DASHING:
		return
	match fighter.dash_kind:
		FighterState.DashKind.STEP:
			if fighter.state_ticks >= tuning.dash_step_ticks:
				if input.is_held(_DASH):
					fighter.dash_kind = FighterState.DashKind.SUSTAINED
				else:
					_end_dash(fighter)
		FighterState.DashKind.SUSTAINED:
			if not input.is_held(_DASH):
				_end_dash(fighter)
		FighterState.DashKind.RUSH:
			var target := fighter.lock_on_target
			if target < 0 or fighter.state_ticks >= tuning.rush_max_ticks \
					or (fighter.position.distance_to(fighters[target].position) \
					<= tuning.rush_stop_distance + _RUSH_ARRIVAL_MARGIN and not EscapeRules.tailing(self, fighter)):
				# Braked to its stop point in front of the target, ready for a follow-up.
				fighter.velocity = Vector3.ZERO
				_end_dash(fighter)
	# Sustained dashing costs ki every tick; a per-second rate is the per-tick cost in sixtieths.
	if fighter.dash_kind == FighterState.DashKind.SUSTAINED \
			and not _spend_ki_units(fighter, meter_tuning.sustained_dash_ki_per_second):
		_end_dash(fighter)


## Starts a buffered vanish step or dash if affordable; a vanish never falls back to a dash.
func _start_buffered_action(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	if EscapeRules.try_chase(self, index, input):
		return
	var free := _is_free(fighter)
	var can_vanish := free or fighter.state == FighterState.State.DASHING \
		or fighter.state == FighterState.State.BLOCKING \
		or can_cancel_into(index, MoveData.CancelLevel.VANISH)
	if can_vanish and has_vanish_input(index, input.held_actions):
		# Without the ki nothing happens; with block held the guard stays up.
		if _spend_ki(fighter, meter_tuning.vanish_step_ki_cost):
			consume_vanish_input(index, input.held_actions)
			_start_vanish(index, input, wish)
	elif free and is_buffered(index, _DASH) and not input.is_held(_BLOCK):
		_start_dash(index, input, wish)


## Holding block raises the guard; a hit lands on it this same tick.
func _start_block(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	if fighter.state in _BLOCK_START_STATES and input.is_held(_BLOCK):
		fighter.enter_state(FighterState.State.BLOCKING)


## A buffered GRAB press starts the grab from a free state.
func _start_grab(index: int) -> void:
	var fighter := fighters[index]
	var grab := _move_set(fighter).grab
	if grab == null or fighter.state not in _ATTACK_START_STATES or not _may_attack(fighter) \
			or not consume_buffered(index, _GRAB):
		return
	_update_facing(index)
	_aim_at_target(index)
	fighter.begin_move(grab)


## A block press arms a perfect block for the window; a window that passes
## unused, or a second press inside it, starts the lockout. A press while an
## opponent is vanishing is Sense (T-D06) and leaves all of this alone.
func _track_block_press(index: int, input: FighterInput, state_before: FighterState.State) -> void:
	var fighter := fighters[index]
	fighter.perfect_block_lockout = maxi(fighter.perfect_block_lockout - 1, 0)
	if fighter.perfect_block_armed:
		fighter.perfect_block_ticks += 1
		# A fresh press covers exactly the window, counting its own tick (S3: no early held press).
		if fighter.perfect_block_ticks >= hit_tuning.perfect_block_window_ticks:
			_miss_perfect_block(fighter)
	if not input.is_pressed(_BLOCK) or fighter.state == FighterState.State.VANISHING \
			or state_before not in _PERFECT_BLOCK_STATES or _opponent_vanishing(index):
		return
	if fighter.perfect_block_armed:
		_miss_perfect_block(fighter)
	elif fighter.perfect_block_lockout == 0:
		fighter.perfect_block_armed = true
		fighter.perfect_block_ticks = 0


func _miss_perfect_block(fighter: FighterState) -> void:
	fighter.perfect_block_armed = false
	fighter.perfect_block_lockout = hit_tuning.perfect_block_lockout_ticks


func _opponent_vanishing(index: int) -> bool:
	for other in fighters.size():
		if other != index and fighters[other].state == FighterState.State.VANISHING:
			return true
	return false


## The guard is up in BLOCKING and through a push-block; blockstun keeps it as it was.
func _update_blocking(fighter: FighterState) -> void:
	match fighter.state:
		FighterState.State.BLOCKING:
			fighter.blocking = true
		FighterState.State.BLOCKSTUN:
			pass
		FighterState.State.ATTACKING:
			if fighter.move.kind != MoveData.Kind.PUSH_BLOCK:
				fighter.blocking = false
		_:
			fighter.blocking = false


## A buffered CHARGE press starts charging on the ground or in flight, not while falling.
func _start_charging(index: int) -> void:
	var fighter := fighters[index]
	if fighter.state == FighterState.State.FALLING or not _is_free(fighter):
		return
	if consume_buffered(index, _CHARGE):
		fighter.velocity = Vector3.ZERO
		fighter.enter_state(FighterState.State.CHARGING)


## Starts a buffered attack from a free state, or a heavy that cancels the current move.
func _start_attack(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	if WeaponEffects.try_yank(self, index):
		return
	if _can_push_block(fighter):
		if is_buffered(index, _HEAVY):
			_begin_push_block(index)
		return
	if fighter.state == FighterState.State.ATTACKING:
		if is_buffered(index, _HEAVY) and can_cancel_into(index, MoveData.CancelLevel.HEAVY):
			_begin_heavy(index, input, wish)
		return
	if fighter.state not in _ATTACK_START_STATES or not _may_attack(fighter):
		return
	if is_buffered(index, _HEAVY):
		_begin_heavy(index, input, wish)
	elif is_buffered(index, _LIGHT) \
			or (fighter.held_weapon() == Weapon.Kind.STORM_REPEATER and input.is_held(_LIGHT)):
		_begin_light(index, 1)


## Starts light number (1-based) of the string. False if the fighter lacks the move or its ki.
func _begin_light(index: int, number: int) -> bool:
	var fighter := fighters[index]
	var lights := _move_set(fighter).light_string
	if number > lights.size():
		return false
	if WeaponMoves.is_shot(lights[number - 1]) and not _can_fire(index):
		return false
	if not _spend_ki(fighter, lights[number - 1].ki_cost):
		return false
	consume_buffered(index, _LIGHT)
	_update_facing(index)
	_aim_at_target(index)
	fighter.begin_move(lights[number - 1])
	fighter.string_index = number
	fighter.draw_ticks = 0
	return true


## Blocking, or late in a blockstun from a block, with more guard than the cost.
func _can_push_block(fighter: FighterState) -> bool:
	var guarding := fighter.state == FighterState.State.BLOCKING \
		or (fighter.state == FighterState.State.BLOCKSTUN and fighter.blocking
			and fighter.state_ticks >= hit_tuning.push_block_from_blockstun_tick)
	return guarding and _move_set(fighter).push_block != null \
		and fighter.guard > hit_tuning.push_block_guard_cost * _UNIT


func _begin_push_block(index: int) -> void:
	var fighter := fighters[index]
	consume_buffered(index, _HEAVY)
	fighter.guard -= hit_tuning.push_block_guard_cost * _UNIT
	fighter.ticks_since_block = 0
	fighter.velocity = Vector3.ZERO
	_update_facing(index)
	_aim_at_target(index)
	fighter.begin_move(_move_set(fighter).push_block)


func _begin_heavy(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	var move := _heavy_for(index, input, wish)
	if WeaponMoves.is_disc_throw(move) and WeaponEffects.disc_out(self, index):
		return
	if move == null or not _spend_ki(fighter, move.ki_cost):
		return
	consume_buffered(index, _HEAVY)
	_update_facing(index)
	_aim_at_target(index)
	var right := _attack_forward(index).cross(Vector3.UP)
	fighter.aim_side = -1 if wish.dot(right) < 0.0 else 1
	fighter.begin_move(move)
	if move.can_charge() and input.is_held(_HEAVY):
		fighter.charge_ticks = 1


## Ascend/descend, then direction relative to the target.
func _heavy_for(index: int, input: FighterInput, wish: Vector3) -> MoveData:
	var moves := _move_set(fighters[index])
	if input.vertical > 0:
		return moves.rising
	if input.vertical < 0:
		return moves.spike
	var planar := Vector3(wish.x, 0.0, wish.z)
	if planar.length() < _HEAVY_DEADZONE:
		return moves.smash
	var along := planar.normalized().dot(_attack_forward(index))
	if along >= _HEAVY_CONE:
		return moves.breaker
	if along <= -_HEAVY_CONE:
		return moves.launcher
	return moves.sweep


## Planar unit direction toward the lock-on target, or the facing when unlocked.
func _attack_forward(index: int) -> Vector3:
	var fighter := fighters[index]
	if fighter.lock_on_target >= 0:
		var to_target := fighters[fighter.lock_on_target].position - fighter.position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	return DetMath.forward(fighter.facing_yaw)


## Pitches the coming attack's hitboxes toward the locked target, clamped; level when unlocked.
func _aim_at_target(index: int) -> void:
	var fighter := fighters[index]
	fighter.aim_pitch = 0.0
	if fighter.lock_on_target < 0:
		return
	var to_target := fighters[fighter.lock_on_target].position - fighter.position
	var planar := Vector2(to_target.x, to_target.z).length()
	if planar > 0.0001 or absf(to_target.y) > 0.0001:
		fighter.aim_pitch = clampf(DetMath.atan2(to_target.y, planar), -_MAX_AIM_PITCH, _MAX_AIM_PITCH)


## Moves the attack on by one tick: charge, string, end of the move.
func _advance_attack(index: int, input: FighterInput) -> void:
	var fighter := fighters[index]
	if fighter.holding_charge:
		_hold_charge(fighter, input)
		return
	fighter.move_tick += 1
	var move := fighter.move
	if fighter.move_tick >= fighter.move_total_ticks():
		_enter_free_state(fighter)
		return
	if WeaponMoves.is_shot(move) and fighter.move_tick == move.startup_ticks:
		if _hold_draw(index, input):
			return
		_fire(index)
	if WeaponMoves.is_disc_throw(move) and fighter.move_tick == move.startup_ticks:
		WeaponEffects.throw_disc(self, index)
	if move.can_charge() and fighter.move_tick < move.startup_ticks:
		# Charge counts only while the button stays held since the press.
		if input.is_held(_HEAVY) and fighter.charge_ticks == fighter.move_tick:
			fighter.charge_ticks += 1
			if fighter.charge_ticks >= move.charge_level_ticks[0]:
				fighter.holding_charge = true
				fighter.move_tick = 0
				_hold_charge(fighter, input, false)
		return
	_advance_string(index)


## Raises the charge level while held; release or the top level performs it.
func _hold_charge(fighter: FighterState, input: FighterInput, count_tick: bool = true) -> void:
	var levels := _move_set(fighter).charged_smash
	if input.is_held(_HEAVY):
		if count_tick:
			fighter.charge_ticks += 1
		var level := 0
		for threshold in fighter.move.charge_level_ticks:
			if fighter.charge_ticks >= threshold:
				level += 1
		fighter.charge_level = mini(level, levels.size())
		if fighter.charge_level < levels.size():
			return
	var reached := fighter.charge_level
	fighter.begin_move(levels[reached - 1])
	fighter.charge_level = reached


## Light string: one press inside the window queues the next hit; any press
## outside it drops the string, and later presses are ignored (no mashing).
func _advance_string(index: int) -> void:
	var fighter := fighters[index]
	var move := fighter.move
	if fighter.string_index == 0 or fighter.string_index >= _move_set(fighter).light_string.size():
		return
	if consume_buffered(index, _LIGHT) and not fighter.string_dropped and not fighter.string_queued:
		var opens := move.string_window_start_tick
		if fighter.move_tick >= opens and fighter.move_tick < opens + move.string_window_ticks:
			fighter.string_queued = true
		else:
			fighter.string_dropped = true
	if fighter.string_queued and fighter.move_tick >= move.recovery_start_tick():
		_begin_light(index, fighter.string_index + 1)


func _start_dash(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	var direction := _steer_direction(fighter, input, wish)
	if direction == Vector3.ZERO:
		direction = _neutral_dash_direction(index, input)
	var rush := _points_at_target(index, direction)
	if not _spend_ki(fighter, meter_tuning.rush_dash_ki_cost if rush else meter_tuning.dash_ki_cost):
		return
	consume_buffered(index, _DASH)
	fighter.dash_kind = FighterState.DashKind.RUSH if rush else FighterState.DashKind.STEP
	fighter.dash_direction = direction
	fighter.enter_state(FighterState.State.DASHING)


## Locked on, the step is in the target's frame: a held direction moves the
## vanish distance (around it, toward/away, up/down), none stays put; either
## way the fighter keeps that offset to the target while vanished.
## Unlocked, a neutral vanish steps straight back from where the fighter faces.
func _start_vanish(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	var direction := _steer_direction(fighter, input, wish)
	var target := fighter.lock_on_target
	if target < 0 and direction == Vector3.ZERO:
		direction = -DetMath.forward(fighter.facing_yaw)
	var step := direction * tuning.vanish_step_distance
	if not _move_around_target(index, step):
		fighter.position += step
	_clamp_to_arena(fighter)
	fighter.velocity = Vector3.ZERO
	fighter.dash_kind = FighterState.DashKind.NONE
	fighter.dash_direction = Vector3.ZERO
	# The block press went into the vanish, not a perfect block.
	fighter.perfect_block_armed = false
	fighter.enter_state(FighterState.State.VANISHING)
	if target >= 0:
		fighter.vanish_anchor = target
		fighter.vanish_offset = fighter.position - fighters[target].position


func _end_dash(fighter: FighterState) -> void:
	fighter.dash_kind = FighterState.DashKind.NONE
	fighter.dash_direction = Vector3.ZERO
	_enter_free_state(fighter)


## Back to standing on the floor, or flying above it, keeping capped momentum.
func _enter_free_state(fighter: FighterState) -> void:
	if _is_on_floor(fighter):
		fighter.position.y = _stand_height(fighter)
		fighter.velocity.y = 0.0
		fighter.velocity = fighter.velocity.limit_length(tuning.ground_speed)
		fighter.enter_state(FighterState.State.IDLE)
	else:
		fighter.velocity = fighter.velocity.limit_length(tuning.fly_speed)
		fighter.enter_state(FighterState.State.FLYING)


func _move_on_ground(fighter: FighterState, input: FighterInput, wish: Vector3) -> void:
	if input.vertical > 0:
		# Ascend on the ground jumps straight into flight.
		fighter.velocity.y = tuning.takeoff_speed
		fighter.enter_state(FighterState.State.FLYING)
		return
	var rate := tuning.ground_acceleration if wish != Vector3.ZERO else tuning.ground_deceleration
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z)
	fighter.velocity = planar.move_toward(wish * tuning.ground_speed, rate * TICK_SECONDS)
	if ground_height.is_valid() and fighter.position.y > _stand_height(fighter) + _LEDGE_DROP:
		# Walked off a ledge (an island rim): fall.
		fighter.enter_state(FighterState.State.FALLING)
		return
	fighter.position.y = _stand_height(fighter)
	var next_state := FighterState.State.IDLE
	if fighter.velocity != Vector3.ZERO:
		next_state = FighterState.State.MOVING
	if fighter.state != next_state:
		fighter.enter_state(next_state)


func _move_falling(fighter: FighterState, input: FighterInput, wish: Vector3) -> void:
	if input.vertical > 0:
		# Ascend while falling takes back control in flight.
		fighter.enter_state(FighterState.State.FLYING)
		_move_flying(fighter, input, wish)
		return
	fighter.velocity.y = maxf(fighter.velocity.y - tuning.gravity * TICK_SECONDS, -tuning.max_fall_speed)


## Planar and vertical speed change separately; letting go of ascend/descend eases out.
func _move_flying(fighter: FighterState, input: FighterInput, wish: Vector3) -> void:
	var planar_target := wish * tuning.fly_speed
	var rate := tuning.fly_acceleration if planar_target != Vector3.ZERO else tuning.fly_deceleration
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z) \
		.move_toward(planar_target, rate * TICK_SECONDS)
	var vertical := fighter.velocity.y
	if input.vertical != 0:
		var climb := tuning.ascend_speed if input.vertical > 0 else tuning.descend_speed
		vertical = move_toward(vertical, input.vertical * climb, tuning.fly_acceleration * TICK_SECONDS)
	else:
		vertical = _ease_out_vertical(vertical)
	fighter.velocity = planar + Vector3.UP * vertical


func _move_dashing(index: int, input: FighterInput, wish: Vector3) -> void:
	var fighter := fighters[index]
	match fighter.dash_kind:
		FighterState.DashKind.STEP:
			var step_speed := tuning.dash_step_distance / (tuning.dash_step_ticks * TICK_SECONDS)
			fighter.velocity = fighter.dash_direction * step_speed
		FighterState.DashKind.SUSTAINED:
			var steer := _steer_direction(fighter, input, wish)
			if steer != Vector3.ZERO:
				fighter.dash_direction = steer
			fighter.velocity = fighter.dash_direction * tuning.sustained_dash_speed
		FighterState.DashKind.RUSH:
			var to_target := fighters[fighter.lock_on_target].position + EscapeRules.chase_offset(self, fighter) \
				- fighter.position
			if to_target != Vector3.ZERO:
				fighter.dash_direction = to_target.normalized()
			var room := maxf(to_target.length() - tuning.rush_stop_distance, 0.0)
			fighter.velocity = fighter.dash_direction * _rush_speed_for(room)


## Rush speed with room metres left to the stop point: full speed, then an even
## brake that loses rush_speed / rush_brake_ticks a tick and ends exactly at the
## stop point (the fastest speed whose brake sequence still fits in room).
func _rush_speed_for(room: float) -> float:
	var speed := minf(tuning.rush_speed, room / TICK_SECONDS)
	if tuning.rush_brake_ticks > 0:
		var step := tuning.rush_speed / tuning.rush_brake_ticks
		# Braking from v covers (v + step) * v / (2 * step) * TICK_SECONDS metres.
		speed = minf(speed, (sqrt(step * step + 8.0 * step * room / TICK_SECONDS) - step) * 0.5)
	return speed


## One tick of a released climb or dive easing to a hover: the slowdown shrinks
## with the speed, so a full-speed climb settles in climb_ease_out_ticks.
func _ease_out_vertical(vertical: float) -> float:
	if vertical == 0.0 or tuning.climb_ease_out_ticks <= 0:
		return 0.0
	var reference := tuning.ascend_speed if vertical > 0.0 else tuning.descend_speed
	var slowdown := 2.0 * sqrt(reference * absf(vertical)) / tuning.climb_ease_out_ticks
	return move_toward(vertical, 0.0, slowdown)


## Guard drift: slow planar movement, no climbing, hovering in the air.
func _move_blocking(fighter: FighterState, wish: Vector3) -> void:
	var rate := tuning.ground_deceleration * TICK_SECONDS
	var target := Vector3(wish.x, 0.0, wish.z) * tuning.guard_drift_speed
	fighter.velocity = fighter.velocity.move_toward(target, rate)
	if _is_on_floor(fighter):
		fighter.velocity.y = 0.0
		fighter.position.y = _stand_height(fighter)


## Where a grabber holds its target: in front along its aim.
func _hold_position(holder: FighterState) -> Vector3:
	return holder.position + holder.aim_basis() * Vector3(0, 0, -hit_tuning.grab_hold_distance)


## Attacks hold position except the move's step, spread over its startup.
func _move_attacking(fighter: FighterState) -> void:
	var move := fighter.move
	fighter.velocity = Vector3.ZERO
	if fighter.holding_charge or fighter.move_tick >= move.startup_ticks:
		return
	var forward := DetMath.forward(fighter.facing_yaw)
	fighter.velocity = forward * (move.step_distance / (move.startup_ticks * TICK_SECONDS))


## Flight while in hitstun: drag, plus gravity for launches, sweeps and bounced spikes.
func _move_in_hitstun(fighter: FighterState) -> void:
	var drag := hit_tuning.knockback_drag * TICK_SECONDS
	var falls := false
	match fighter.knockback_type:
		MoveData.KnockbackType.LAUNCH, MoveData.KnockbackType.SWEEP:
			falls = true
		MoveData.KnockbackType.SPIKE:
			falls = fighter.spike_bounced
		_:
			fighter.velocity = fighter.velocity.move_toward(Vector3.ZERO, drag)
			return
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z).move_toward(Vector3.ZERO, drag)
	var vertical := fighter.velocity.y
	if falls:
		vertical = maxf(vertical - hit_tuning.juggle_gravity * TICK_SECONDS, -tuning.max_fall_speed)
	fighter.velocity = planar + Vector3.UP * vertical


## A spiked fighter bounces off the floor once; landing after the bounce knocks it down.
func _bounce_or_knock_down(fighter: FighterState) -> void:
	if fighter.knockback_type != MoveData.KnockbackType.SPIKE or not _is_on_floor(fighter) \
			or fighter.velocity.y >= 0.0:
		return
	fighter.position.y = _stand_height(fighter)
	if not fighter.spike_bounced:
		fighter.spike_bounced = true
		fighter.velocity.y = hit_tuning.spike_bounce_speed
		return
	fighter.velocity = Vector3.ZERO
	fighter.enter_state(FighterState.State.KNOCKDOWN)
	fighter.stun_ticks = hit_tuning.knockdown_ticks
	_drop_held_weapon(fighters.find(fighter))


## Puts every newly knocked-out fighter into KO_FALL, keeping the knockback it was given.
func _knock_out_fallen() -> void:
	for index in fighters.size():
		var fighter := fighters[index]
		if fighter.is_knocked_out() and not fighter.is_ko_state():
			_knock_out(index)


## Flight ends and any grab breaks; the fighter falls with its current velocity.
func _knock_out(index: int) -> void:
	var fighter := fighters[index]
	if fighter.grab_partner >= 0:
		var partner := fighters[fighter.grab_partner]
		partner.grab_partner = -1
		fighter.grab_partner = -1
		if partner.state == FighterState.State.GRABBED or partner.state == FighterState.State.THROWING:
			partner.velocity = Vector3.ZERO
			_enter_free_state(partner)
	_drop_all_weapons(index)
	PowerRules.end_all(self, index)
	WeaponEffects.untie(self, index)
	fighter.pin_ticks = 0
	fighter.pinned = false
	fighter.dash_kind = FighterState.DashKind.NONE
	fighter.dash_direction = Vector3.ZERO
	fighter.blocking = false
	fighter.perfect_block_armed = false
	fighter.smitten_ticks = 0
	fighter.smitten_by = -1
	fighter.enter_state(FighterState.State.KO_FALL)
	fighter.ko_origin = fighter.position
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z).limit_length(hit_tuning.ko_max_launch_speed)
	fighter.velocity = planar + Vector3.UP * minf(fighter.velocity.y, hit_tuning.ko_max_rise_speed)


## Gravity without flight, light air drag on the planar part.
func _move_ko_falling(fighter: FighterState) -> void:
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z) \
		.move_toward(Vector3.ZERO, hit_tuning.ko_air_drag * TICK_SECONDS)
	var vertical := maxf(fighter.velocity.y - hit_tuning.ko_gravity * TICK_SECONDS, -tuning.max_fall_speed)
	var apex := maxf(_stand_height(fighter) + hit_tuning.ko_max_apex, fighter.ko_origin.y)
	if vertical > 0.0 and fighter.position.y + vertical * TICK_SECONDS > apex:
		vertical = maxf(apex - fighter.position.y, 0.0) / TICK_SECONDS
	fighter.velocity = _ko_travel_capped(fighter, planar) + Vector3.UP * vertical


## Drops the outward part of a KO slide that would carry it past ko_max_travel.
func _ko_travel_capped(fighter: FighterState, planar: Vector3) -> Vector3:
	var from_origin := fighter.position + planar * TICK_SECONDS - fighter.ko_origin
	from_origin.y = 0.0
	var limit := hit_tuning.ko_max_travel
	if from_origin.length_squared() <= limit * limit:
		return planar
	var outward := from_origin.normalized()
	var along := planar.dot(outward)
	return planar - outward * maxf(along, 0.0) if along > 0.0 else planar


## A knocked-out fighter flung into an arena wall bounces back off it instead of sticking.
func _bounce_off_arena_walls(fighter: FighterState) -> void:
	var half := tuning.arena_half_size
	var centre := Vector3(arena_centre.x, 0.0, arena_centre.y)
	for axis: int in [0, 2]:
		var offset := fighter.position[axis] - centre[axis]
		if absf(offset) >= half and fighter.velocity[axis] * offset > 0.0:
			fighter.position[axis] = centre[axis] + signf(offset) * half
			fighter.velocity[axis] *= -hit_tuning.ko_wall_restitution


## Lying on the floor: the slide slows to a stop.
func _move_ko_down(fighter: FighterState) -> void:
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z)
	planar = planar.move_toward(Vector3.ZERO, hit_tuning.ko_slide_deceleration * TICK_SECONDS)
	var vertical := 0.0
	var stand := _stand_height(fighter)
	if fighter.position.y > stand + _floor_epsilon():
		# Slid off a ledge: falls to the ground below instead of snapping down.
		vertical = maxf(fighter.velocity.y - hit_tuning.ko_gravity * TICK_SECONDS, -tuning.max_fall_speed)
	else:
		fighter.position.y = stand
	fighter.velocity = _ko_travel_capped(fighter, planar) + Vector3.UP * vertical


## The first floor contact bounces (damped, keeping part of the slide); the next lays it down.
func _bounce_or_rest(index: int) -> void:
	var fighter := fighters[index]
	if not _is_on_floor(fighter) or fighter.velocity.y > 0.0:
		return
	fighter.position.y = _stand_height(fighter)
	var planar := Vector3(fighter.velocity.x, 0.0, fighter.velocity.z)
	if not fighter.ko_bounced:
		fighter.ko_bounced = true
		var bounce := clampf(-fighter.velocity.y * hit_tuning.ko_bounce_restitution,
			hit_tuning.ko_min_bounce_speed, hit_tuning.ko_max_bounce_speed)
		fighter.velocity = planar * hit_tuning.ko_bounce_slide + Vector3.UP * bounce
		events.append(_ko_event(EventType.KO_BOUNCE, index))
		return
	fighter.velocity = planar
	fighter.enter_state(FighterState.State.KO_DOWN)
	events.append(_ko_event(EventType.KO_REST, index))


func _ko_event(type: EventType, index: int) -> Dictionary:
	return {"type": type, "fighter": index, "position": fighters[index].position}


## Puts a fighter at start: hovering above the floor, standing on it otherwise.
func _place(fighter: FighterState, start: Vector3) -> void:
	fighter.position = start
	fighter.velocity = Vector3.ZERO
	# Terrain-aware (T-D13): the zone's ground sampler decides where "standing" is.
	var stand := _stand_height(fighter)
	if start.y > stand + _floor_epsilon():
		fighter.enter_state(FighterState.State.FLYING)
	else:
		fighter.position.y = stand
		fighter.enter_state(FighterState.State.IDLE)
	fighter.stand_height = stand


## Round-start values for everything but burst, Last Stand, team and lock-on.
func _reset_fighter(fighter: FighterState, start: Vector3) -> void:
	_reset_round_meters(fighter)
	_place(fighter, start)
	fighter.dash_kind = FighterState.DashKind.NONE
	fighter.dash_direction = Vector3.ZERO
	for action in fighter.press_ages.size():
		fighter.press_ages[action] = INPUT_BUFFER_TICKS
	fighter.consumed_presses = 0
	fighter.hitstop_ticks = 0
	fighter.grab_partner = -1
	fighter.clear_pushback()
	fighter.perfect_block_armed = false
	fighter.perfect_block_ticks = 0
	fighter.perfect_block_lockout = 0
	fighter.weapons = PackedInt32Array([0, 0, 0])
	fighter.ammo = PackedInt32Array([0, 0, 0])
	fighter.active_slot = -1
	fighter.switch_lockout = 0
	fighter.reload_ticks = 0
	fighter.smitten_ticks = 0
	fighter.smitten_by = -1
	fighter.ticks_since_smitten = 1 << 20
	fighter.last_slot = -1
	fighter.heat = 0
	fighter.overheated = false
	fighter.draw_ticks = 0
	fighter.pin_ticks = 0
	fighter.pinned = false
	fighter.tether_partner = -1
	fighter.tether_ticks = 0
	fighter.tether_length = 0.0
	fighter.combo_starter_percent = 100
	fighter.powers = FighterPowers.new()
	fighter.escapes.reset()


## Finds every hitbox touching an opponent this tick, then applies them in
## fighter index order. All hits are found first, so trades happen. Fighters
## frozen in hitstop this tick do not hit. A grab fails if its grabber or its
## target is struck on the same tick (strike beats grab).
func _resolve_hits(frozen: Array[bool]) -> void:
	var contacts: Array[Dictionary] = []
	for attacker_index in fighters.size():
		var attacker := fighters[attacker_index]
		if frozen[attacker_index] or attacker.state != FighterState.State.ATTACKING:
			continue
		var shapes := attacker.active_hitboxes()
		if shapes.is_empty():
			continue
		for target_index in fighters.size():
			var bit := 1 << target_index
			if target_index == attacker_index \
					or ((attacker.hit_targets & bit) != 0 and not attacker.move.multi_hit):
				continue
			var contact := _find_contact(attacker_index, target_index, shapes)
			if not contact.is_empty():
				attacker.hit_targets |= bit
				contacts.append(contact)
	var struck := 0
	for contact in contacts:
		if contact.type != EventType.GRAB:
			struck |= 1 << (contact.target as int)
	for contact in contacts:
		# Nothing more lands once the round is decided, or on a fighter already knocked out.
		if round_over:
			return
		if fighters[contact.target as int].is_knocked_out():
			continue
		match contact.type:
			EventType.BLOCK:
				_apply_block(contact)
			EventType.PERFECT_BLOCK:
				_apply_perfect_block(contact)
			EventType.GRAB:
				_apply_grab(contact, contacts, struck)
			EventType.PUSH_BLOCK:
				_apply_push_block(contact)
			_:
				_apply_hit(contact)


## The first hitbox touching the target's hurtbox, as a contact with everything
## about both fighters the hit needs before any hit this tick changes them; empty if none.
func _find_contact(attacker_index: int, target_index: int, shapes: Array[Dictionary]) -> Dictionary:
	var attacker := fighters[attacker_index]
	var target := fighters[target_index]
	if not target.can_be_hit() or target.team == attacker.team:
		return {}
	var body := target.hurtbox()
	for shape in shapes:
		var points := _closest_points(shape.start, shape.end, body.start, body.end)
		var reach: float = shape.radius + body.radius
		if points[0].distance_squared_to(points[1]) > reach * reach:
			continue
		var centre: Vector3 = (shape.start + shape.end) * 0.5
		if target.is_invincible_to(target.is_upper_body(centre)):
			return {}
		var type := EventType.HIT
		match attacker.move.kind:
			MoveData.Kind.GRAB:
				if target.state in _UNGRABBABLE_STATES:
					return {}
				type = EventType.GRAB
			MoveData.Kind.PUSH_BLOCK:
				if target.state in _UNPUSHABLE_STATES:
					return {}
				type = EventType.PUSH_BLOCK
			_:
				if _perfect_blocks(target, attacker.position):
					type = EventType.PERFECT_BLOCK
				elif _blocks(target, attacker.position):
					type = EventType.BLOCK
				elif target.is_armored():
					type = EventType.ARMOR
				elif target.attack_phase() in [FighterState.AttackPhase.STARTUP, FighterState.AttackPhase.HOLD]:
					type = EventType.COUNTER
		return {
			"type": type, "attacker": attacker_index, "target": target_index,
			"move": attacker.move, "yaw": attacker.facing_yaw, "pitch": attacker.aim_pitch,
			"side": attacker.aim_side,
			# Contact point: on the hurtbox surface toward the hitbox, or the hitbox centre line inside it.
			"position": points[1] + (points[0] - points[1]).limit_length(body.radius),
		}
	return {}


## Blocking stops a hit from the front 180 degrees, unless stunned.
func _blocks(target: FighterState, from: Vector3) -> bool:
	if not target.blocking or target.state in _NO_BLOCK_STATES:
		return false
	return _faces(target, from)


## An armed block press perfect-blocks from the front 180 degrees, even after letting go.
func _perfect_blocks(target: FighterState, from: Vector3) -> bool:
	return target.perfect_block_armed and target.state in _PERFECT_BLOCK_STATES and _faces(target, from)


## True if from is in the fighter's front 180 degrees (planar).
func _faces(fighter: FighterState, from: Vector3) -> bool:
	var to_other := from - fighter.position
	to_other.y = 0.0
	var forward := DetMath.forward(fighter.facing_yaw)
	return to_other.dot(forward) >= 0.0


## Damage with combo scaling, then hitstun and knockback unless armored; KO ends it.
## A projectile hit (from_projectile) freezes only the target and opens no cancel window.
func _apply_hit(contact: Dictionary, from_projectile: bool = false) -> void:
	var attacker_index: int = contact.attacker
	var target_index: int = contact.target
	var attacker := fighters[attacker_index]
	var target := fighters[target_index]
	var move: MoveData = contact.move
	var type: EventType = contact.type
	if PowerRules.absorbs_hit(self, contact, from_projectile):
		return
	var continuing := target.state == FighterState.State.HITSTUN
	var combo_hit := target.combo_hits + 1 if continuing else 1
	# Ranged hits start combos at 80% damage, kept for the whole combo.
	var percent := Weapon.RANGED_COMBO_PERCENT if from_projectile else 100
	if continuing:
		percent = target.combo_starter_percent
	var damage := scaled_damage(move, combo_hit) * percent / 100
	var combo_damage := target.combo_damage if continuing else 0
	apply_damage(target_index, attacker_index, damage)
	if not from_projectile:
		register_contact(attacker_index, false)
	add_landed_hit_ki(attacker_index)
	_add_ki(attacker, move.ki_gain * _UNIT)
	_add_burst(attacker, move.burst_gain * _UNIT)
	var hitstop := move.hitstop_ticks
	var knockback := MoveData.KnockbackType.NONE
	if type != EventType.ARMOR:
		if type == EventType.COUNTER:
			hitstop += hit_tuning.counter_hit_extra_hitstop_ticks
		knockback = move.knockback_type
		_enter_stun(target, FighterState.State.HITSTUN, decayed_hitstun(move, combo_hit))
		target.knockback_type = knockback
		target.spike_bounced = false
		EscapeRules.on_hit(self, attacker_index, target_index, knockback, from_projectile)
		target.velocity = _air_knockback_guarded(attacker, target, move, _knockback_velocity(contact))
		if not from_projectile:
			_start_pushback(target_index, attacker_index, hit_tuning.hit_pushback_distance)
		target.combo_hits = combo_hit
		target.combo_damage = combo_damage + damage
		target.combo_starter_percent = percent
		# A counter-hit heavy knocks the weapon out of the target's hand.
		if type == EventType.COUNTER and not from_projectile and move.cancel_level == MoveData.CancelLevel.HEAVY:
			_drop_held_weapon(target_index)
	var knocked_out := target.is_knocked_out()
	if knocked_out:
		hitstop = maxi(hitstop, hit_tuning.knockout_hitstop_ticks)
	_freeze(target if from_projectile else attacker, target, hitstop)
	events.append(_event(type, contact, damage, hitstop, knockback))
	if knocked_out:
		events.append(_event(EventType.KO, contact, damage, hitstop, knockback))


## Guard damage and blockstun; a guard broken by this block stuns instead.
func _apply_block(contact: Dictionary, from_projectile: bool = false) -> void:
	var attacker_index: int = contact.attacker
	var target_index: int = contact.target
	var target := fighters[target_index]
	var move: MoveData = contact.move
	var guard_damage := move.guard_damage
	if target.guard < move.guard_break_below * _UNIT:
		guard_damage = maxi(guard_damage, ceili(float(target.guard) / _UNIT))
	apply_guard_damage(target_index, guard_damage)
	if not from_projectile:
		register_contact(attacker_index, true)
	add_blocked_hit_ki(attacker_index)
	var hitstop := move.hitstop_ticks * hit_tuning.blocked_hitstop_percent / 100
	var broken := target.state == FighterState.State.GUARD_BROKEN
	if broken:
		hitstop = maxi(hitstop, hit_tuning.guard_break_hitstop_ticks)
	else:
		_enter_stun(target, FighterState.State.BLOCKSTUN, move.blockstun_ticks)
		if not from_projectile:
			_start_pushback(target_index, attacker_index, hit_tuning.block_pushback_distance)
	_freeze(target if from_projectile else fighters[attacker_index], target, hitstop)
	events.append(_event(EventType.BLOCK, contact, 0, hitstop, MoveData.KnockbackType.NONE))
	if broken:
		events.append(_event(EventType.GUARD_BREAK, contact, 0, hitstop, MoveData.KnockbackType.NONE))


## No guard damage or stun; the attacker's move gets extra recovery and its string ends.
func _apply_perfect_block(contact: Dictionary) -> void:
	var attacker := fighters[contact.attacker as int]
	var target := fighters[contact.target as int]
	target.perfect_block_armed = false
	if attacker.state == FighterState.State.ATTACKING and attacker.move == contact.move:
		attacker.extra_recovery_ticks = hit_tuning.perfect_block_extra_recovery_ticks
		attacker.string_queued = false
		attacker.string_dropped = true
	add_perfect_block_burst(contact.target)
	var hitstop := hit_tuning.perfect_block_hitstop_ticks
	_freeze(attacker, target, hitstop)
	events.append(_event(EventType.PERFECT_BLOCK, contact, 0, hitstop, MoveData.KnockbackType.NONE))


## The target is held in front of the grabber until the throw. Two grabs on each
## other clash; a grab whose grabber was grabbed earlier this tick does nothing.
func _apply_grab(contact: Dictionary, contacts: Array[Dictionary], struck: int) -> void:
	var attacker_index: int = contact.attacker
	var target_index: int = contact.target
	var attacker := fighters[attacker_index]
	var target := fighters[target_index]
	if (struck & ((1 << attacker_index) | (1 << target_index))) != 0 \
			or attacker.state != FighterState.State.ATTACKING or attacker.move != contact.move \
			or target.state in _UNGRABBABLE_STATES:
		return
	for other in contacts:
		var mutual: bool = other.type == EventType.GRAB and other.attacker == target_index \
			and other.target == attacker_index
		if mutual and target.state == FighterState.State.ATTACKING and target.move == other.move:
			_push_apart(attacker_index, target_index)
			events.append(_event(EventType.GRAB_TECH, contact, 0, 0, MoveData.KnockbackType.NONE))
			return
	var pitch := attacker.aim_pitch
	attacker.enter_state(FighterState.State.THROWING)
	attacker.aim_pitch = pitch
	attacker.grab_partner = target_index
	_enter_stun(target, FighterState.State.GRABBED, 0)
	target.grab_partner = attacker_index
	target.position = _hold_position(attacker)
	settle(target)
	var to_holder := attacker.position - target.position
	if Vector2(to_holder.x, to_holder.z).length_squared() > 0.0001:
		target.facing_yaw = DetMath.atan2(-to_holder.x, -to_holder.z)
	events.append(_event(EventType.GRAB, contact, 0, 0, MoveData.KnockbackType.NONE))


## Ends a hold with the throw: damage as combo hit 1, then blowback along the grabber's aim.
func _throw(index: int) -> void:
	var thrower := fighters[index]
	var target_index := thrower.grab_partner
	var target := fighters[target_index]
	var move := _move_set(thrower).grab
	thrower.grab_partner = -1
	target.grab_partner = -1
	var contact := {
		"type": EventType.THROW, "attacker": index, "target": target_index, "move": move,
		"yaw": thrower.facing_yaw, "pitch": thrower.aim_pitch, "side": 1, "position": target.position,
	}
	var damage := scaled_damage(move, 1)
	apply_damage(target_index, index, damage)
	add_landed_hit_ki(index)
	_enter_stun(target, FighterState.State.HITSTUN, decayed_hitstun(move, 1))
	target.knockback_type = move.knockback_type
	target.velocity = _knockback_velocity(contact)
	target.combo_hits = 1
	target.combo_damage = damage
	_enter_free_state(thrower)
	var hitstop := move.hitstop_ticks
	var knocked_out := target.is_knocked_out()
	if knocked_out:
		hitstop = maxi(hitstop, hit_tuning.knockout_hitstop_ticks)
	_freeze(thrower, target, hitstop)
	events.append(_event(EventType.THROW, contact, damage, hitstop, move.knockback_type))
	if knocked_out:
		events.append(_event(EventType.KO, contact, damage, hitstop, move.knockback_type))


## The grabbed fighter breaks free: both are pushed apart, nobody takes damage.
func _tech_grab(index: int) -> void:
	var holder_index := fighters[index].grab_partner
	var contact := {
		"type": EventType.GRAB_TECH, "attacker": holder_index, "target": index,
		"move": _move_set(fighters[holder_index]).grab,
		"position": (fighters[index].position + fighters[holder_index].position) * 0.5,
	}
	_push_apart(holder_index, index)
	events.append(_event(EventType.GRAB_TECH, contact, 0, 0, MoveData.KnockbackType.NONE))


## Slides two fighters apart to the tech distance, both unable to act meanwhile.
func _push_apart(first_index: int, second_index: int) -> void:
	var first := fighters[first_index]
	var second := fighters[second_index]
	first.grab_partner = -1
	second.grab_partner = -1
	var centre := (first.position + second.position) * 0.5
	var apart := second.position - first.position
	if apart.length_squared() < 0.0001:
		apart = -DetMath.forward(first.facing_yaw)
	var half := apart.normalized() * (hit_tuning.grab_tech_distance * 0.5)
	_slide_to(first, centre - half, hit_tuning.grab_tech_push_ticks)
	_slide_to(second, centre + half, hit_tuning.grab_tech_push_ticks)


## Shoves the target straight away from the push-blocker out to the push distance.
func _apply_push_block(contact: Dictionary) -> void:
	var pusher := fighters[contact.attacker as int]
	var target := fighters[contact.target as int]
	var away := target.position - pusher.position
	if away.length_squared() < 0.0001:
		away = DetMath.forward(pusher.facing_yaw)
	var reach := maxf(away.length(), hit_tuning.push_block_distance)
	_slide_to(target, pusher.position + away.normalized() * reach, hit_tuning.push_block_stun_ticks)
	events.append(_event(EventType.PUSH_BLOCK, contact, 0, 0, MoveData.KnockbackType.NONE))


## Slides the target distance metres straight away from the attacker over the
## pushback ticks, after hitstop; a wall passes the rest to the attacker (Pushboxes).
func _start_pushback(target_index: int, attacker_index: int, distance: float) -> void:
	var target := fighters[target_index]
	var attacker := fighters[attacker_index]
	if distance <= 0.0 or hit_tuning.pushback_ticks <= 0:
		return
	var away := target.position - attacker.position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = DetMath.forward(attacker.facing_yaw)
	target.pushback_velocity = away.normalized() * (distance / (hit_tuning.pushback_ticks * TICK_SECONDS))
	target.pushback_ticks = hit_tuning.pushback_ticks
	target.pushback_from = attacker_index


## BLOCKSTUN for ticks, sliding at constant speed so it ends exactly at destination.
func _slide_to(fighter: FighterState, destination: Vector3, ticks: int) -> void:
	_enter_stun(fighter, FighterState.State.BLOCKSTUN, ticks)
	fighter.velocity = (destination - fighter.position) / (ticks * TICK_SECONDS)


## Puts the fighter in a stun state for ticks; it stops dashing and stands still.
## A grab it was part of breaks, freeing the partner.
func _enter_stun(fighter: FighterState, stun: FighterState.State, ticks: int) -> void:
	if fighter.grab_partner >= 0:
		var partner := fighters[fighter.grab_partner]
		fighter.grab_partner = -1
		partner.grab_partner = -1
		partner.velocity = Vector3.ZERO
		_enter_free_state(partner)
	fighter.dash_kind = FighterState.DashKind.NONE
	fighter.dash_direction = Vector3.ZERO
	fighter.velocity = Vector3.ZERO
	fighter.enter_state(stun)
	fighter.stun_ticks = ticks


## Target velocity from the move's knockback. LAUNCH and SPIKE turn by yaw only,
## so up stays up and down stays down; SWEEP pushes to the attacker's aim side.
func _knockback_velocity(contact: Dictionary) -> Vector3:
	var move: MoveData = contact.move
	var knockback := move.knockback
	var yaw: float = contact.yaw
	match move.knockback_type:
		MoveData.KnockbackType.LAUNCH, MoveData.KnockbackType.SPIKE:
			return DetMath.rotate_y(knockback, yaw)
		MoveData.KnockbackType.SWEEP:
			var side: int = contact.side
			return DetMath.rotate_y(Vector3.RIGHT, yaw) * (side * Vector2(knockback.x, knockback.z).length()) \
				+ Vector3.UP * knockback.y
	return DetMath.rotate_y(DetMath.rotate_x(knockback, contact.pitch), yaw)


## With either fighter off the floor and the pair closer than air_knockback_separation, drives
## the target away from the attacker and, for blowback-like hits, level or up to 45 degrees:
## never under or over it. Lights push less, so air strings still connect.
func _air_knockback_guarded(attacker: FighterState, target: FighterState, move: MoveData,
		velocity: Vector3) -> Vector3:
	var target_airborne := not _is_on_floor(target)
	if not target_airborne and _is_on_floor(attacker):
		return velocity
	var out := target.position - attacker.position
	out.y = 0.0
	var separation := hit_tuning.air_knockback_separation
	if out.length_squared() >= separation * separation:
		return velocity
	if out.length_squared() < 0.0001:
		out = DetMath.forward(attacker.facing_yaw)
	out = out.normalized()
	var min_out := hit_tuning.air_knockback_min_out
	if move.cancel_level == MoveData.CancelLevel.LIGHT:
		min_out = hit_tuning.air_light_knockback_min_out
	if move.air_knockback_min_out >= 0.0:
		min_out = move.air_knockback_min_out
	var along := velocity.dot(out)
	if along < min_out:
		velocity += out * (min_out - along)
		along = min_out
	# Spikes still drive down and launches still go up; the outward push above separates them.
	if not target_airborne or move.knockback_type in [MoveData.KnockbackType.SPIKE, MoveData.KnockbackType.LAUNCH]:
		return velocity
	var rise := move.air_knockback_rise if move.air_knockback_rise >= 0.0 \
		else hit_tuning.air_knockback_rise
	velocity.y = clampf(velocity.y, 0.0, along * rise)
	return velocity


## Freezes both fighters of an exchange for at least ticks.
func _freeze(attacker: FighterState, target: FighterState, ticks: int) -> void:
	attacker.hitstop_ticks = maxi(attacker.hitstop_ticks, ticks)
	target.hitstop_ticks = maxi(target.hitstop_ticks, ticks)


func _event(type: EventType, contact: Dictionary, damage: int, hitstop: int,
		knockback: MoveData.KnockbackType) -> Dictionary:
	return {
		"type": type, "attacker": contact.attacker, "target": contact.target,
		"position": contact.position, "move_id": (contact.move as MoveData).id,
		"damage": damage, "hitstop": hitstop, "knockback_type": knockback,
		"counter": contact.type == EventType.COUNTER,
	}


## Closest points [on segment p1-q1, on segment p2-q2] (Ericson, Real-Time Collision Detection 5.1.9).
static func _closest_points(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> PackedVector3Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	const EPSILON := 0.000001
	if a <= EPSILON and e > EPSILON:
		t = clampf(f / e, 0.0, 1.0)
	elif a > EPSILON:
		var c := d1.dot(r)
		if e <= EPSILON:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denominator := a * e - b * b
			if denominator > EPSILON:
				s = clampf((b * f - c * e) / denominator, 0.0, 1.0)
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return PackedVector3Array([p1 + d1 * s, p2 + d2 * t])


## Keeps fighters inside the arena box and stops motion into its walls.
func _clamp_to_arena(fighter: FighterState) -> void:
	var half := tuning.arena_half_size
	var low := Vector3(arena_centre.x - half, _stand_height(fighter), arena_centre.y - half)
	var high := Vector3(arena_centre.x + half, tuning.arena_ceiling, arena_centre.y + half)
	var clamped := fighter.position.clamp(low, high)
	var velocity := fighter.velocity
	for axis in 3:
		if clamped[axis] != fighter.position[axis]:
			velocity[axis] = 0.0
	fighter.velocity = velocity
	fighter.position = clamped


## A fighter on the floor walks up slopes up to _MAX_CLIMB_SLOPE; a steeper face
## (a cliff, which the 2 m ground grid bakes as a ramp) stops it like a wall
## instead of lifting it up the face (QA-12c).
func _stop_at_cliff(fighter: FighterState, from: Vector3) -> void:
	var stand := _stand_height(fighter)
	var climb := stand - from.y
	if climb <= _STEP_UP or fighter.position.y >= stand:
		return
	var planar_sq := (fighter.position.x - from.x) * (fighter.position.x - from.x) \
		+ (fighter.position.z - from.z) * (fighter.position.z - from.z)
	if climb * climb <= planar_sq * _MAX_CLIMB_SLOPE * _MAX_CLIMB_SLOPE:
		return
	fighter.position.x = from.x
	fighter.position.z = from.z
	fighter.velocity.x = 0.0
	fighter.velocity.z = 0.0


## Puts a fighter moved from outside its own step (a pushbox) back inside the
## arena and above the floor, and refreshes its stand height.
func settle(fighter: FighterState) -> void:
	_clamp_to_arena(fighter)
	if fighter.is_grounded():
		fighter.position.y = _stand_height(fighter)
	fighter.stand_height = _stand_height(fighter)


func is_on_floor(fighter: FighterState) -> bool:
	return _is_on_floor(fighter)


func _land_if_on_floor(fighter: FighterState) -> void:
	var airborne := fighter.state == FighterState.State.FLYING \
		or fighter.state == FighterState.State.FALLING
	if airborne and _is_on_floor(fighter) and fighter.velocity.y <= 0.0:
		fighter.position.y = _stand_height(fighter)
		fighter.velocity.y = 0.0
		fighter.enter_state(FighterState.State.IDLE)


## Faces the lock-on target, otherwise the direction of travel.
func _update_facing(index: int) -> void:
	var fighter := fighters[index]
	var look := fighter.velocity
	if fighter.lock_on_target >= 0:
		look = fighters[fighter.lock_on_target].position - fighter.position
	look.y = 0.0
	if look.length_squared() > 0.0001:
		fighter.facing_yaw = DetMath.atan2(-look.x, -look.z)


## Planar direction from the move input, length up to 1: relative to the line
## to the lock-on target when locked (W toward, A/D around), else to the camera.
func _wish_direction(index: int, input: FighterInput) -> Vector3:
	var planar := Vector3(input.move.x, 0.0, -input.move.y).limit_length(1.0)
	var yaw := input.view_yaw
	var to_target := _planar_to_target(index)
	if to_target != Vector3.ZERO:
		yaw = DetMath.atan2(-to_target.x, -to_target.z)
	return DetMath.rotate_y(planar, yaw)


## Planar offset from the fighter to its lock-on target; zero when unlocked or right above/below it.
func _planar_to_target(index: int) -> Vector3:
	var fighter := fighters[index]
	if fighter.lock_on_target < 0:
		return Vector3.ZERO
	var to_target := fighters[fighter.lock_on_target].position - fighter.position
	to_target.y = 0.0
	return to_target if to_target.length() >= _MIN_ORBIT_RADIUS else Vector3.ZERO


## Moves the fighter by this tick's velocity; locked-on movement goes around the target.
func _integrate(index: int) -> void:
	var fighter := fighters[index]
	var step := fighter.velocity * TICK_SECONDS
	if step == Vector3.ZERO:
		return
	if fighter.state in _ORBIT_STATES and fighter.dash_kind != FighterState.DashKind.RUSH \
			and _move_around_target(index, step):
		return
	fighter.position += step


## Moves by step in the lock-on frame: its part toward the target changes the
## planar distance, its sideways part travels along the circle around the
## target, and height adds as usual. Velocity and dash direction turn with the
## frame, so a strafe stays a strafe. False, moving nothing, when unlocked or
## the move would come within _MIN_ORBIT_RADIUS of the target.
func _move_around_target(index: int, step: Vector3) -> bool:
	var fighter := fighters[index]
	var to_target := _planar_to_target(index)
	if to_target == Vector3.ZERO:
		return false
	var radius := to_target.length()
	var out := -to_target / radius
	var new_radius := radius + step.dot(out)
	if new_radius < _MIN_ORBIT_RADIUS:
		return false
	var max_turn := deg_to_rad(tuning.max_orbit_turn_speed) * TICK_SECONDS
	var turn := DetMath.axis_angle(Vector3.UP, clampf(step.dot(Vector3.UP.cross(out)) / radius, -max_turn, max_turn))
	var centre := fighters[fighter.lock_on_target].position
	var planar := turn * out * new_radius
	fighter.position = Vector3(centre.x + planar.x, fighter.position.y + step.y, centre.z + planar.z)
	fighter.velocity = turn * fighter.velocity
	fighter.dash_direction = turn * fighter.dash_direction
	return true


## Vanished fighters keep their offset to the target they vanished around, once everyone has moved.
func _follow_vanish_anchors() -> void:
	for fighter in fighters:
		if fighter.state == FighterState.State.VANISHING and fighter.vanish_anchor >= 0:
			var from_y := fighter.position.y
			fighter.position = fighters[fighter.vanish_anchor].position + fighter.vanish_offset
			_stop_on_skipped_island(fighter, from_y)
			settle(fighter)


## Unit direction from move plus ascend/descend, or zero. Never into the floor.
func _steer_direction(fighter: FighterState, input: FighterInput, wish: Vector3) -> Vector3:
	var direction := wish + Vector3.UP * input.vertical
	if direction.y < 0.0 and _is_on_floor(fighter):
		direction.y = 0.0
	return direction.normalized()


## A dash with no direction goes toward the target, or forward along the view.
func _neutral_dash_direction(index: int, input: FighterInput) -> Vector3:
	var fighter := fighters[index]
	if fighter.lock_on_target >= 0:
		var to_target := fighters[fighter.lock_on_target].position - fighter.position
		if to_target != Vector3.ZERO:
			return to_target.normalized()
	return DetMath.forward(input.view_yaw)


func _points_at_target(index: int, direction: Vector3) -> bool:
	var fighter := fighters[index]
	if fighter.lock_on_target < 0:
		return false
	var to_target := fighters[fighter.lock_on_target].position - fighter.position
	if to_target == Vector3.ZERO:
		return false
	return direction.dot(to_target.normalized()) >= tuning.rush_alignment


## A move that went from above an island top to more than its step-up below it (a fast
## fall or dive, a vanish following its anchor) stops on the top instead of passing through.
func _stop_on_skipped_island(fighter: FighterState, from_y: float) -> void:
	if not ground_height.is_valid() or from_y <= fighter.position.y:
		return
	var at := fighter.position
	var swept := _ground_at(Vector3(at.x, from_y - _FIGHTER_HALF_HEIGHT, at.z))
	if swept > _ground_at(at - Vector3.UP * _FIGHTER_HALF_HEIGHT) and at.y < swept + tuning.ground_height:
		fighter.position.y = swept + tuning.ground_height


func _is_on_floor(fighter: FighterState) -> bool:
	return fighter.position.y <= _stand_height(fighter) + _floor_epsilon()


## Touching tolerance: only terrain needs one; the flat floor compares exactly, as before T-D13.
func _floor_epsilon() -> float:
	return _FLOOR_EPSILON if ground_height.is_valid() else 0.0


## Height of a standing fighter's origin at its (x, z).
func _stand_height(fighter: FighterState) -> float:
	return tuning.ground_height + _ground_at(fighter.position - Vector3.UP * _FIGHTER_HALF_HEIGHT)


## Floor height under a point; flat 0 without a zone's ground.
func _ground_at(at: Vector3) -> float:
	return ground_height.call(at.x, at.z, at.y) if ground_height.is_valid() else 0.0


## Nearest fighter of another team still standing, or -1.
func _nearest_opponent(index: int) -> int:
	var nearest := -1
	var best := INF
	for other in fighters.size():
		if not _is_opponent(index, other):
			continue
		var distance := fighters[index].position.distance_squared_to(fighters[other].position)
		if distance < best:
			best = distance
			nearest = other
	return nearest


func _next_opponent(index: int, current: int, step: int) -> int:
	var candidate := current
	for _i in fighters.size():
		candidate = posmod(candidate + step, fighters.size())
		if _is_opponent(index, candidate):
			return candidate
	return current


## True if other is on another team than index and still standing.
func _is_opponent(index: int, other: int) -> bool:
	return other != index and fighters[other].team != fighters[index].team \
		and not fighters[other].is_knocked_out()


## Passive ki or charging, grey health and guard regeneration, once per tick.
func _update_meters(fighter: FighterState) -> void:
	var ki_rate := meter_tuning.ki_passive_per_second
	if fighter.state == FighterState.State.CHARGING:
		ki_rate = meter_tuning.ki_charge_per_second
	_add_ki(fighter, ki_rate)
	if fighter.ticks_since_hit >= meter_tuning.grey_regen_delay_ticks:
		var regen := mini(meter_tuning.grey_regen_per_second, fighter.grey_health)
		fighter.health += regen
		fighter.grey_health -= regen
	else:
		fighter.ticks_since_hit += 1
	if fighter.blocking:
		fighter.ticks_since_block = 0
	elif fighter.ticks_since_block >= meter_tuning.guard_regen_delay_ticks:
		fighter.guard = mini(fighter.guard + meter_tuning.guard_regen_per_second,
			fighter.stats.guard_max * _UNIT)
	else:
		fighter.ticks_since_block += 1


func _reset_round_meters(fighter: FighterState) -> void:
	fighter.health = fighter.stats.max_health * _UNIT
	fighter.grey_health = 0
	fighter.ki = meter_tuning.round_start_ki * _UNIT
	fighter.guard = fighter.stats.guard_max * _UNIT
	fighter.ticks_since_hit = 0
	fighter.ticks_since_block = 0
	fighter.blocking = false


## The round ends when at most one team has a fighter still standing (FFA:
## every fighter is its own team, so the last one standing wins).
func _end_round_if_decided() -> void:
	var first_standing := -1
	for index in fighters.size():
		if fighters[index].is_knocked_out():
			continue
		if first_standing < 0:
			first_standing = index
		elif fighters[index].team != fighters[first_standing].team:
			return
	round_over = true
	round_winner = first_standing
	winning_team = fighters[first_standing].team if first_standing >= 0 else -1


## Spends cost ki in display units. False, spending nothing, if there is too little.
func _spend_ki(fighter: FighterState, cost: int) -> bool:
	return _spend_ki_units(fighter, cost * _UNIT)


func _spend_ki_units(fighter: FighterState, units: int) -> bool:
	if fighter.ki < units:
		return false
	fighter.ki -= units
	return true


func _add_ki(fighter: FighterState, units: int) -> void:
	fighter.ki = mini(fighter.ki + units, meter_tuning.ki_max * _UNIT)


func _add_burst(fighter: FighterState, units: int) -> void:
	var cap := meter_tuning.burst_max_stocks * meter_tuning.burst_stock_size * _UNIT
	fighter.burst = mini(fighter.burst + units, cap)


func _move_set(fighter: FighterState) -> MoveSet:
	var unarmed := fighter.stats.move_set
	if unarmed == null:
		unarmed = (DEFAULT_FIGHTER_STATS as FighterStats).move_set
	var held := fighter.held_weapon()
	return unarmed if held == Weapon.Kind.NONE else WeaponMoves.move_set(held, unarmed)


## Standing, moving, falling or flying: able to start a new action.
func _is_free(fighter: FighterState) -> bool:
	return fighter.state in [
		FighterState.State.IDLE, FighterState.State.MOVING,
		FighterState.State.FALLING, FighterState.State.FLYING,
	]


static func _action_index(action: int) -> int:
	for index in 32:
		if (1 << index) == action:
			return index
	assert(false, "action must be a single FighterInput.Action bit")
	return -1


# Weapons (T-D14): pickups, inventory, firing, projectiles, the spawner.

## A standing fighter's origin sits this far above the floor (capsule centre).
const _FIGHTER_HALF_HEIGHT := 1.0
## A grounded fighter whose floor drops by more than this in a tick falls instead.
const _LEDGE_DROP := 0.75
## Rise per tick a grounded fighter always takes (small steps, quantised ground).
const _STEP_UP := 0.05
## Steepest ground a fighter walks up, as rise over run (tan 60 degrees).
const _MAX_CLIMB_SLOPE := 1.7320508
## Positions are 32-bit; a floor this close counts as touching.
const _FLOOR_EPSILON := 0.001
## States a smitten fighter drifts in.
const _NO_DRIFT_STATES: Array[FighterState.State] = [
	FighterState.State.GRABBED, FighterState.State.THROWING,
	FighterState.State.VANISHING, FighterState.State.KNOCKDOWN,
	FighterState.State.KO_FALL, FighterState.State.KO_DOWN,
]


## Height of the floor fighters stand on.
func floor_height() -> float:
	return tuning.ground_height - _FIGHTER_HALF_HEIGHT


## Index in pickups of the nearest pickup the fighter can grab, or -1.
func pickup_in_reach(fighter_index: int) -> int:
	var fighter := fighters[fighter_index]
	var best := -1
	var best_distance := pickup_tuning.pickup_reach * pickup_tuning.pickup_reach
	for i in pickups.size():
		if not pickups[i].can_be_picked_up():
			continue
		var distance := fighter.position.distance_squared_to(pickups[i].position)
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


func _count_weapon_timers(fighter: FighterState) -> void:
	WeaponEffects.count_heat(self, fighters.find(fighter))
	fighter.switch_lockout = maxi(fighter.switch_lockout - 1, 0)
	fighter.reload_ticks = maxi(fighter.reload_ticks - 1, 0)
	if fighter.smitten_ticks > 0:
		fighter.smitten_ticks -= 1
		if fighter.smitten_ticks == 0:
			fighter.smitten_by = -1
	fighter.ticks_since_smitten = mini(fighter.ticks_since_smitten + 1,
		pickup_tuning.smitten_repeat_window_ticks)


## Not switching weapons and not Smitten.
func _may_attack(fighter: FighterState) -> bool:
	return fighter.switch_lockout == 0 and fighter.smitten_ticks == 0


## G picks up (or throws with nothing in reach), THROW throws, next/previous switch. Free states only.
func _handle_weapon_inputs(index: int) -> void:
	var fighter := fighters[index]
	if fighter.state == FighterState.State.ATTACKING:
		_try_swap_cancel(index)
		return
	if not _is_free(fighter):
		return
	if consume_buffered(index, _PICKUP):
		var in_reach := pickup_in_reach(index)
		if in_reach >= 0:
			_pick_up(index, in_reach)
			return
		# A held gadget goes first; then the weapon in hand.
		if fighter.powers.gadget != Power.Kind.NONE and _may_attack(fighter):
			PowerRules.use_gadget(self, index)
			return
		if fighter.held_weapon() != Weapon.Kind.NONE and _may_attack(fighter):
			_throw_weapon(index)
			return
	if consume_buffered(index, _THROW):
		if fighter.held_weapon() != Weapon.Kind.NONE and _may_attack(fighter):
			_throw_weapon(index)
			return
	if consume_buffered(index, _QUICK_SWAP):
		_set_active_slot(index, _quick_swap_slot(fighter), pickup_tuning.switch_lockout_ticks)
	elif consume_buffered(index, _WEAPON_NEXT):
		_switch_weapon(index, 1)
	elif consume_buffered(index, _WEAPON_PREVIOUS):
		_switch_weapon(index, -1)


## Takes pickups[pickup_index] into the inventory and into the hand. With all
## slots full it replaces the weapon in hand (slot 1 when unarmed), which drops.
func _pick_up(index: int, pickup_index: int) -> void:
	var fighter := fighters[index]
	var pickup := pickups[pickup_index]
	pickups.remove_at(pickup_index)
	if pickup.is_power():
		PowerRules.pick_up(self, index, pickup)
		fighter.begin_move(WeaponMoves.pickup_move())
		return
	var slot := -1
	for i in fighter.weapons.size():
		if fighter.weapons[i] == Weapon.Kind.NONE:
			slot = i
			break
	if slot < 0:
		slot = maxi(fighter.active_slot, 0)
		_drop_slot(index, slot)
	fighter.weapons[slot] = pickup.kind
	fighter.ammo[slot] = pickup.ammo
	if fighter.active_slot != slot:
		fighter.last_slot = fighter.active_slot
	fighter.active_slot = slot
	fighter.reload_ticks = 0
	fighter.begin_move(WeaponMoves.pickup_move())
	events.append(_weapon_event(EventType.PICKUP, index, pickup.position, pickup.kind, pickup.id))


## Cycles Unarmed and the filled slots; attacks wait out the switch lockout.
func _switch_weapon(index: int, step: int) -> void:
	var fighter := fighters[index]
	var options: Array[int] = [-1]
	for i in fighter.weapons.size():
		if fighter.weapons[i] != Weapon.Kind.NONE:
			options.append(i)
	var next: int = options[posmod(options.find(fighter.active_slot) + step, options.size())]
	_set_active_slot(index, next, pickup_tuning.switch_lockout_ticks)


## Puts slot in hand (-1 unarmed) with a lockout, remembering the last one for C. False if unchanged.
func _set_active_slot(index: int, slot: int, lockout: int) -> bool:
	var fighter := fighters[index]
	if slot == fighter.active_slot:
		return false
	fighter.last_slot = fighter.active_slot
	fighter.active_slot = slot
	fighter.switch_lockout = lockout
	fighter.reload_ticks = 0 if fighter.held_weapon() != Weapon.Kind.ARC_REVOLVER else fighter.reload_ticks
	events.append(_weapon_event(EventType.WEAPON_SWITCH, index, fighter.position, fighter.held_weapon(), -1))
	return true


## Slot C swaps to: the last one used if it still holds a weapon, else unarmed (or the first weapon when unarmed).
func _quick_swap_slot(fighter: FighterState) -> int:
	var last := fighter.last_slot
	if last != fighter.active_slot and (last < 0 or fighter.weapons[last] != Weapon.Kind.NONE):
		return last
	if fighter.active_slot >= 0:
		return -1
	for slot in fighter.weapons.size():
		if fighter.weapons[slot] != Weapon.Kind.NONE:
			return slot
	return -1


## Swap-cancel: a switch press in the cancel window after contact swaps for 10 ki
## and frees the fighter, so a buffered attack comes out with the new weapon this tick.
func _try_swap_cancel(index: int) -> void:
	var fighter := fighters[index]
	var press := 0
	var slot := fighter.active_slot
	if is_buffered(index, _QUICK_SWAP):
		press = _QUICK_SWAP
		slot = _quick_swap_slot(fighter)
	elif is_buffered(index, _WEAPON_NEXT) or is_buffered(index, _WEAPON_PREVIOUS):
		press = _WEAPON_NEXT if is_buffered(index, _WEAPON_NEXT) else _WEAPON_PREVIOUS
		var options: Array[int] = [-1]
		for i in fighter.weapons.size():
			if fighter.weapons[i] != Weapon.Kind.NONE:
				options.append(i)
		var step := 1 if press == _WEAPON_NEXT else -1
		slot = options[posmod(options.find(fighter.active_slot) + step, options.size())]
	if press == 0 or slot == fighter.active_slot \
			or not can_cancel_into(index, MoveData.CancelLevel.SPECIAL) \
			or not _spend_ki(fighter, Weapon.SWAP_CANCEL_KI):
		return
	consume_buffered(index, press)
	# A light press the string already queued becomes the new weapon's first light.
	var queued_light := fighter.string_queued
	_set_active_slot(index, slot, 0)
	_enter_free_state(fighter)
	events.append(_weapon_event(EventType.SWAP_CANCEL, index, fighter.position, fighter.held_weapon(), -1))
	if queued_light:
		_begin_light(index, 1)


## Throws the weapon in hand at the target as a projectile; it lands as a pickup.
func _throw_weapon(index: int) -> void:
	var fighter := fighters[index]
	var slot := fighter.active_slot
	var kind := fighter.held_weapon()
	var ammo := fighter.ammo[slot]
	fighter.weapons[slot] = Weapon.Kind.NONE
	fighter.ammo[slot] = 0
	fighter.active_slot = -1
	fighter.last_slot = -1
	fighter.reload_ticks = 0
	_update_facing(index)
	var stats := Weapon.THROWN_STATS
	var projectile := _spawn_projectile(index, kind, _aim_direction(index) * float(stats.speed),
		stats.gravity, stats.radius, stats.lifetime, WeaponMoves.thrown_move(), Weapon.Effect.NONE)
	projectile.thrown = true
	projectile.ammo = ammo
	fighter.begin_move(WeaponMoves.throw_move())
	events.append(_weapon_event(EventType.WEAPON_THROW, index, projectile.position, kind, projectile.id))


func _drop_held_weapon(index: int) -> void:
	if index >= 0 and fighters[index].active_slot >= 0:
		_drop_slot(index, fighters[index].active_slot)


func _drop_all_weapons(index: int) -> void:
	for slot in fighters[index].weapons.size():
		if fighters[index].weapons[slot] != Weapon.Kind.NONE:
			_drop_slot(index, slot)


## Empties a slot; the weapon falls from the fighter as a pickup (an empty gun just vanishes).
func _drop_slot(index: int, slot: int) -> void:
	var fighter := fighters[index]
	var kind := fighter.weapons[slot] as Weapon.Kind
	var ammo := fighter.ammo[slot]
	fighter.weapons[slot] = Weapon.Kind.NONE
	fighter.ammo[slot] = 0
	if fighter.active_slot == slot:
		fighter.active_slot = -1
		fighter.reload_ticks = 0
	var pickup := _drop_pickup(kind, ammo, fighter.position)
	events.append(_weapon_event(EventType.WEAPON_DROP, index, fighter.position, kind,
		pickup.id if pickup else -1))


## A dropped or landed weapon falling from position; null for an empty ranged weapon.
func _drop_pickup(kind: Weapon.Kind, ammo: int, at: Vector3) -> WeaponPickup:
	if kind == Weapon.Kind.NONE or (Weapon.is_ranged(kind) and ammo <= 0):
		return null
	var pickup := WeaponPickup.new()
	pickup.id = _new_entity_id()
	pickup.kind = kind
	pickup.ammo = ammo
	pickup.position = _inside_arena(at)
	pickup.position.y = maxf(pickup.position.y, _ground_at(pickup.position) + pickup_tuning.rest_height)
	pickup.phase = WeaponPickup.Phase.FALLING
	pickup.ticks_left = pickup_tuning.dropped_lifetime_ticks
	pickup.dropped = true
	pickups.append(pickup)
	return pickup


## True if the ranged weapon in hand can shoot now. An empty one is thrown instead.
func _can_fire(index: int) -> bool:
	var fighter := fighters[index]
	if fighter.ammo[fighter.active_slot] <= 0:
		_throw_weapon(index)
		return false
	if fighter.overheated and fighter.held_weapon() == Weapon.Kind.STORM_REPEATER:
		return false
	return fighter.reload_ticks == 0


## Holding LMB on a bow keeps it at full draw, raising the draw level; true while held.
func _hold_draw(index: int, input: FighterInput) -> bool:
	var fighter := fighters[index]
	if not Weapon.is_bow(fighter.held_weapon()) or not input.is_held(_LIGHT) \
			or fighter.draw_ticks >= Weapon.DRAW_MAX_TICKS:
		return false
	fighter.move_tick -= 1
	fighter.draw_ticks += 1
	if fighter.draw_ticks in Weapon.DRAW_LEVEL_TICKS:
		var drawn := _weapon_event(EventType.BOW_DRAW, index, fighter.position, fighter.held_weapon(), -1)
		drawn["level"] = WeaponMoves.draw_level(fighter.draw_ticks)
		events.append(drawn)
	return true


## Spends one ammo and fires the weapon's pellets along the aim, with seeded spread.
func _fire(index: int) -> void:
	var fighter := fighters[index]
	var kind := fighter.held_weapon()
	if not Weapon.is_ranged(kind) or fighter.ammo[fighter.active_slot] <= 0:
		return
	var stats: Dictionary = Weapon.RANGED_STATS[kind]
	if kind == Weapon.Kind.STORM_REPEATER and fighter.overheated:
		return
	var left := fighter.ammo[fighter.active_slot] - 1
	fighter.ammo[fighter.active_slot] = left
	if stats.magazine > 0 and left > 0 and left % stats.magazine == 0:
		fighter.reload_ticks = stats.reload
	var aim := _aim_direction(index)
	var first_id := next_entity_id
	var muzzle := Vector3.ZERO
	var level := WeaponMoves.draw_level(fighter.draw_ticks) if Weapon.is_bow(kind) else 0
	var hit_move := WeaponMoves.projectile_move(kind)
	var effect: Weapon.Effect = stats.effect
	var speed: float = stats.speed
	if kind == Weapon.Kind.KI_BOW:
		hit_move = WeaponMoves.bow_move(level)
		speed *= Weapon.DRAW_SPEED_SCALE[level - 1]
		effect = Weapon.Effect.PIN if level >= 3 else Weapon.Effect.NONE
	elif kind == Weapon.Kind.HEARTSTRING_BOW and level >= 3:
		hit_move = WeaponMoves.tether_move()
		effect = Weapon.Effect.TETHER
	fighter.draw_ticks = 0
	for _pellet in stats.pellets:
		var direction := _spread(aim, stats.spread)
		var projectile := _spawn_projectile(index, kind, direction * speed, stats.gravity,
			stats.radius, stats.lifetime, hit_move, effect)
		projectile.level = level
		muzzle = projectile.position
	var event := _weapon_event(EventType.FIRE, index, muzzle, kind, first_id)
	event["count"] = stats.pellets
	event["level"] = level
	events.append(event)


## Unit aim from the muzzle: at the locked target's centre, else straight along the facing.
func _aim_direction(index: int) -> Vector3:
	var fighter := fighters[index]
	var forward := DetMath.forward(fighter.facing_yaw)
	if fighter.lock_on_target >= 0:
		var to_target := fighters[fighter.lock_on_target].position - _muzzle(fighter)
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	return forward


func _muzzle(fighter: FighterState) -> Vector3:
	var forward := DetMath.forward(fighter.facing_yaw)
	return fighter.position + forward * _MUZZLE_FORWARD + Vector3.UP * _MUZZLE_UP


## Turns direction by a random yaw and half as much pitch, up to spread radians.
func _spread(direction: Vector3, spread: float) -> Vector3:
	if spread <= 0.0:
		return direction
	var yaw := rng.randf_range(-spread, spread)
	var pitch := rng.randf_range(-spread, spread) * 0.5
	var right := direction.cross(Vector3.UP)
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	return (DetMath.axis_angle(Vector3.UP, yaw) * DetMath.axis_angle(right, pitch) * direction).normalized()


func _spawn_projectile(owner: int, weapon: Weapon.Kind, velocity: Vector3, gravity: float,
		radius: float, lifetime: int, move: MoveData, effect: Weapon.Effect) -> Projectile:
	var projectile := Projectile.new()
	projectile.id = _new_entity_id()
	projectile.owner = owner
	projectile.weapon = weapon
	projectile.position = _muzzle(fighters[owner])
	projectile.velocity = velocity
	projectile.gravity = gravity
	projectile.radius = radius
	projectile.ticks_left = lifetime
	projectile.move = move
	projectile.effect = effect
	projectiles.append(projectile)
	return projectile


## Moves every projectile along its path, hitting the first body it sweeps through.
## Thrown weapons land as pickups when they stop.
func _step_projectiles() -> void:
	var kept: Array[Projectile] = []
	for projectile in projectiles:
		var from := projectile.position
		projectile.age += 1
		if projectile.effect == Weapon.Effect.DISC and WeaponEffects.steer_disc(self, projectile):
			continue
		projectile.velocity.y -= projectile.gravity * TICK_SECONDS
		projectile.position += projectile.velocity * TICK_SECONDS
		projectile.ticks_left -= 1
		var spent := false
		if not round_over:
			spent = _projectile_contact(projectile, from)
		var outside := projectile.position != _inside_arena(projectile.position) \
			or projectile.position.y <= _ground_at(projectile.position)
		if not spent and projectile.ticks_left > 0 and not outside:
			kept.append(projectile)
		elif projectile.thrown:
			_drop_pickup(projectile.weapon, projectile.ammo, projectile.position)
	projectiles = kept


## Applies the first hit along this tick's path from from. True if the projectile is used up.
func _projectile_contact(projectile: Projectile, from: Vector3) -> bool:
	for target_index in fighters.size():
		var target := fighters[target_index]
		if target_index == projectile.owner or not target.can_be_hit() \
				or (projectile.hit_mask & (1 << target_index)) != 0 \
				or (projectile.owner >= 0 and target.team == fighters[projectile.owner].team):
			continue
		var body := target.hurtbox()
		var points := _closest_points(from, projectile.position, body.start, body.end)
		var reach: float = projectile.radius + body.radius
		if points[0].distance_squared_to(points[1]) > reach * reach:
			continue
		if target.is_invincible_to(target.is_upper_body(points[0])):
			continue
		# A dash soaks up repeater bullets for ki, like tap blasts.
		if projectile.weapon == Weapon.Kind.STORM_REPEATER and not projectile.thrown \
				and target.state == FighterState.State.DASHING:
			_add_ki(target, Weapon.DASH_ABSORB_KI * _UNIT)
			events.append(_weapon_event(EventType.BULLET_ABSORB, target_index, points[1], projectile.weapon,
				projectile.id))
			return true
		var travel := projectile.velocity
		var contact := {
			"type": EventType.HIT, "attacker": projectile.owner, "target": target_index,
			"move": projectile.move, "yaw": DetMath.atan2(-travel.x, -travel.z), "pitch": 0.0, "side": 1,
			"position": points[1] + (points[0] - points[1]).limit_length(body.radius),
		}
		var event := _weapon_event(EventType.PROJECTILE_HIT, target_index, contact.position,
			projectile.weapon, projectile.id)
		event["attacker"] = projectile.owner
		event["blocked"] = false
		event["reflected"] = false
		if _perfect_blocks(target, from):
			target.perfect_block_armed = false
			add_perfect_block_burst(target_index)
			event["reflected"] = true
			events.append(event)
			if projectile.thrown:
				return true
			if projectile.effect == Weapon.Effect.DISC:
				projectile.returning = true
				projectile.hit_mask |= 1 << target_index
				return false
			projectile.owner = target_index
			projectile.velocity = -projectile.velocity
			projectile.position = from
			return false
		if _blocks(target, from):
			event["blocked"] = true
			events.append(event)
			_apply_block(contact, true)
			if projectile.effect == Weapon.Effect.DISC:
				# A blocked disc bounces straight back to its thrower.
				projectile.returning = true
				projectile.hit_mask |= 1 << target_index
				return false
			return true
		if target.is_armored():
			contact.type = EventType.ARMOR
		elif target.attack_phase() in [FighterState.AttackPhase.STARTUP, FighterState.AttackPhase.HOLD]:
			contact.type = EventType.COUNTER
		events.append(event)
		_apply_hit(contact, true)
		if target.is_knocked_out():
			return true
		match projectile.effect:
			Weapon.Effect.SMITTEN:
				_make_smitten(target_index, projectile.owner)
			Weapon.Effect.TETHER:
				WeaponEffects.tie(self, projectile.owner, target_index)
			Weapon.Effect.PIN, Weapon.Effect.DISC:
				# Pierces (arrow) or flies on (disc): each fighter is hit once per pass.
				if projectile.effect == Weapon.Effect.PIN:
					target.pin_ticks = Weapon.PIN_WINDOW_TICKS
				projectile.hit_mask |= 1 << target_index
				return false
		return true
	return false


## Smitten: drifts toward the shooter and cannot attack; a repeat soon after lasts half as long.
func _make_smitten(target_index: int, shooter: int) -> void:
	var target := fighters[target_index]
	var ticks := pickup_tuning.smitten_ticks
	if target.ticks_since_smitten < pickup_tuning.smitten_repeat_window_ticks:
		ticks /= 2
	target.smitten_ticks = ticks
	target.smitten_by = shooter
	target.ticks_since_smitten = 0


func _drift_if_smitten(fighter: FighterState) -> void:
	if fighter.smitten_ticks <= 0 or fighter.smitten_by < 0 or fighter.state in _NO_DRIFT_STATES:
		return
	var to_shooter := fighters[fighter.smitten_by].position - fighter.position
	if to_shooter.length() > tuning.rush_stop_distance:
		fighter.position += to_shooter.normalized() * pickup_tuning.smitten_drift_speed * TICK_SECONDS


## Schedules and spawns drops, then moves pickups through telegraph, fall and rest, and despawns old ones.
func _step_pickups() -> void:
	if next_spawn_tick < 0:
		next_spawn_tick = current_tick + pickup_tuning.first_spawn_ticks
	if pickups_enabled and not round_over and current_tick >= next_spawn_tick and not fighters.is_empty():
		next_spawn_tick = current_tick + rng.randi_range(pickup_tuning.spawn_interval_min_ticks,
			pickup_tuning.spawn_interval_max_ticks)
		var spawned := 0
		for pickup in pickups:
			if not pickup.dropped:
				spawned += 1
		if spawned < pickup_tuning.max_pickups:
			_spawn_pickup()
	var kept: Array[WeaponPickup] = []
	for pickup in pickups:
		pickup.phase_ticks += 1
		pickup.ticks_left -= 1
		match pickup.phase:
			WeaponPickup.Phase.TELEGRAPH:
				if pickup.phase_ticks >= pickup_tuning.telegraph_ticks:
					pickup.phase = WeaponPickup.Phase.FALLING
					pickup.phase_ticks = 0
			WeaponPickup.Phase.FALLING:
				pickup.fall_speed = maxf(pickup.fall_speed - pickup_tuning.drop_gravity * TICK_SECONDS,
					-pickup_tuning.drop_max_speed)
				pickup.position.y += pickup.fall_speed * TICK_SECONDS
				var rest := _ground_at(pickup.position) + pickup_tuning.rest_height
				if pickup.position.y <= rest:
					pickup.position.y = rest
					pickup.fall_speed = 0.0
					pickup.phase = WeaponPickup.Phase.GROUNDED
					pickup.phase_ticks = 0
		if pickup.ticks_left <= 0:
			events.append(_weapon_event(EventType.PICKUP_DESPAWN, -1, pickup.position, pickup.kind, pickup.id))
			continue
		kept.append(pickup)
	pickups = kept


## A sky drop from the zone's table, 25-60 m from the fighters' midpoint (8-16 m in a 1v1).
func _spawn_pickup() -> void:
	var middle := Vector3.ZERO
	for fighter in fighters:
		middle += fighter.position / fighters.size()
	var angle := rng.randf() * TAU
	var duel := fighters.size() == 2
	var distance := rng.randf_range(
		pickup_tuning.duel_spawn_distance_min if duel else pickup_tuning.spawn_distance_min,
		pickup_tuning.duel_spawn_distance_max if duel else pickup_tuning.spawn_distance_max)
	var pickup := WeaponPickup.new()
	pickup.id = _new_entity_id()
	if pickup_tuning.powers_enabled and spawn_count % 2 == 1:
		pickup.power = _pick_power(pickup_tuning.power_table)
	else:
		pickup.kind = _pick_kind(pickup_tuning.table_for(zone))
		pickup.ammo = Weapon.full_ammo(pickup.kind)
	spawn_count += 1
	pickup.position = _inside_arena(middle + Vector3(DetMath.sin(angle), 0.0, DetMath.cos(angle)) * distance)
	pickup.position.y = _ground_at(Vector3(pickup.position.x, middle.y, pickup.position.z)) \
		+ pickup_tuning.drop_height
	pickup.phase = WeaponPickup.Phase.TELEGRAPH
	pickup.ticks_left = pickup_tuning.spawn_lifetime_ticks
	pickups.append(pickup)
	if not pickup.is_power():
		last_spawn_kind = pickup.kind
	var spawned := _weapon_event(EventType.PICKUP_SPAWN, -1, pickup.position, pickup.kind, pickup.id)
	spawned["power"] = pickup.power
	events.append(spawned)


## Weighted pick of a power or gadget drop.
func _pick_power(table: Dictionary) -> Power.Kind:
	var total := 0
	for kind: int in table:
		total += table[kind]
	var roll := rng.randi_range(0, total - 1)
	for kind: int in table:
		roll -= table[kind]
		if roll < 0:
			return kind as Power.Kind
	return table.keys()[0] as Power.Kind


## Weighted pick from a spawn table, never the same kind twice in a row.
func _pick_kind(table: Dictionary) -> Weapon.Kind:
	var total := 0
	for kind: int in table:
		if kind != last_spawn_kind or table.size() == 1:
			total += table[kind]
	var roll := rng.randi_range(0, total - 1)
	for kind: int in table:
		if kind == last_spawn_kind and table.size() > 1:
			continue
		roll -= table[kind]
		if roll < 0:
			return kind as Weapon.Kind
	return table.keys()[0] as Weapon.Kind


## Planar position kept a little inside the arena walls.
func _inside_arena(at: Vector3) -> Vector3:
	var half := tuning.arena_half_size - 1.0
	return Vector3(clampf(at.x, arena_centre.x - half, arena_centre.x + half), at.y,
		clampf(at.z, arena_centre.y - half, arena_centre.y + half))


func _new_entity_id() -> int:
	next_entity_id += 1
	return next_entity_id - 1


func _weapon_event(type: EventType, fighter_index: int, at: Vector3, weapon: int, id: int) -> Dictionary:
	return {"type": type, "fighter": fighter_index, "position": at, "weapon": weapon, "id": id}
