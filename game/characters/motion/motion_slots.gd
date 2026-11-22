class_name MotionSlots
extends RefCounted
## Which MotionLibrary clip each fighter situation plays. Pure: a function of FighterState and
## the previous pick, so the view stays a reader of the sim. Empty means "no mocap for this slot":
## CharacterView then plays the character's own ClipSet clip.

## Move id -> motion clip (weapon moves use their slot's clip, see ClipSet.WEAPON_SLOT_CLIPS).
const MOVES := {
	&"light_1": &"light_1", &"light_2": &"light_2", &"light_3": &"light_3", &"light_4": &"light_4",
	&"light_5": &"push_block", &"smash": &"smash", &"breaker": &"breaker", &"launcher": &"launcher_up",
	&"rising": &"rising", &"spike": &"spike", &"sweep": &"sweep_low", &"push_block": &"push_block",
	&"charged_smash_1": &"charged_smash_1", &"charged_smash_2": &"charged_smash_2",
	&"charged_smash_3": &"charged_smash_3", &"grab": &"grab",
	# Ki (T-KI1): the two-handed palm thrust reads as pushing energy out; beams hold it.
	&"ki_blast": &"push_block", &"charged_blast": &"push_block", &"beam": &"push_block",
	&"beam_ultimate": &"push_block",
	# Specials (T-SP1): each borrows the take whose silhouette reads as its tell, retimed onto its phases.
	&"kael_comet_drive": &"charged_smash_2", &"kael_comet_drive_rise": &"rising",
	&"kael_comet_drive_dive": &"spike", &"kael_gale_counter": &"push_block", &"kael_gale_riposte": &"smash",
	&"kael_skyfall": &"spike", &"vexa_shade_flicker": &"breaker", &"vexa_mirage_step": &"sweep_low",
	&"vexa_razor_waltz": &"charged_smash_1",
}
## Ground speed (m/s) between walking and running; below IDLE_SPEED the fighter stands.
const WALK_RUN_SPEED := 5.5
const IDLE_SPEED := 0.4
## Half-angles (radians) of the forward and backward cones; the rest strafes. The current pick's
## cone is widened by HYSTERESIS so it doesn't flicker on the boundary.
const FORWARD_CONE := deg_to_rad(50.0)
const BACK_CONE := deg_to_rad(130.0)
const HYSTERESIS := deg_to_rad(15.0)
## A fall faster than this (m/s) lands heavily.
const HEAVY_LANDING_SPEED := 16.0
## Hit stun at or above this many ticks (or any knockback) staggers instead of flinching.
const STAGGER_STUN_TICKS := 20
const LOCOMOTION := [&"walk", &"run", &"strafe_left", &"strafe_right", &"walk_back"]


## The move's motion clip, or &"" if it has none.
static func move_clip(move_id: StringName, overrides: Dictionary) -> StringName:
	var id := move_id
	if String(id).contains("/"):
		var slot := StringName(String(id).get_slice("/", 1))
		id = ClipSet.WEAPON_SLOT_CLIPS.get(slot, slot)
	return overrides.get(id, MOVES.get(id, &""))


## The clip for a non-attacking fighter. local_velocity is in the model's space (+Z forward).
## landing: the landing clip still playing, or &"".
static func state_clip(fighter: FighterState, local_velocity: Vector3, airborne: bool,
		previous: StringName, landing: StringName) -> StringName:
	var name := String(FighterState.State.find_key(fighter.state))
	var knocked_out := fighter.stats != null and fighter.is_knocked_out()
	if name.begins_with("KO") or (knocked_out and fighter.state in [FighterState.State.HITSTUN,
			FighterState.State.KNOCKDOWN, FighterState.State.FALLING, FighterState.State.IDLE]):
		return &"ko_fall"
	if fighter.blocking and fighter.state in [FighterState.State.IDLE, FighterState.State.MOVING,
			FighterState.State.FLYING, FighterState.State.BLOCKING]:
		return &"guard"
	match fighter.state:
		FighterState.State.IDLE:
			return landing if landing != &"" else &"fight_idle"
		FighterState.State.MOVING:
			return locomotion(local_velocity, previous)
		FighterState.State.FALLING:
			return &"jump"
		FighterState.State.FLYING:
			return flight(local_velocity)
		FighterState.State.DASHING, FighterState.State.VANISHING:
			# In the air the upright hover base: MotionLayers pitches it and adds the dash burst.
			return &"hover" if airborne else &"dash_start"
		FighterState.State.BLOCKING:
			return &"guard"
		FighterState.State.BLOCKSTUN:
			return &"block_hit"
		FighterState.State.HITSTUN, FighterState.State.GUARD_BROKEN:
			return &"hit_stagger" if staggers(fighter) else &"hit_light"
		FighterState.State.GRABBED:
			return &"hit_light"
		FighterState.State.THROWING:
			return &"throw"
		FighterState.State.KNOCKDOWN:
			return &"ko_fall"
		FighterState.State.ESCAPING:
			return escape_clip(fighter.escapes.kind)
	return &""


## Pose for an escape (T-DEF3): the breaker shoves out, techs flip, a blown-away attacker reels.
static func escape_clip(kind: FighterEscapes.Kind) -> StringName:
	match kind:
		FighterEscapes.Kind.BREAKER:
			return &"push_block"
		FighterEscapes.Kind.BLOWN_AWAY:
			return &"hit_heavy"
		FighterEscapes.Kind.AIR_TECH, FighterEscapes.Kind.TECH_ROLL:
			return &"tech"
		FighterEscapes.Kind.CHASE_MISS:
			return &"dash_stop"
	return &"hit_light"


static func staggers(fighter: FighterState) -> bool:
	return fighter.state == FighterState.State.GUARD_BROKEN \
		or fighter.knockback_type != MoveData.KnockbackType.NONE \
		or fighter.stun_ticks >= STAGGER_STUN_TICKS


static func locomotion(local_velocity: Vector3, previous: StringName) -> StringName:
	var flat := Vector2(local_velocity.x, local_velocity.z)
	var speed := flat.length()
	if speed < IDLE_SPEED:
		return &"fight_idle"
	var angle := absf(atan2(flat.x, flat.y))
	var forward_cone := FORWARD_CONE + (HYSTERESIS if previous in [&"walk", &"run"] else 0.0)
	var back_cone := BACK_CONE - (HYSTERESIS if previous == &"walk_back" else 0.0)
	if angle < forward_cone:
		var run_at := WALK_RUN_SPEED - (0.8 if previous == &"run" else 0.0)
		return &"run" if speed >= run_at else &"walk"
	if angle > back_cone:
		return &"walk_back"
	return &"strafe_left" if flat.x > 0.0 else &"strafe_right"


## Flight always plays the upright hover take: MotionLayers pitches, banks and shapes the body
## from velocity (the fly/dive takes have their own pitch baked in, which doubled it).
static func flight(_local_velocity: Vector3) -> StringName:
	return &"hover"
