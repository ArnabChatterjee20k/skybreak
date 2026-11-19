class_name ClipSet
extends Resource
## Which clip of a humanoid AnimationLibrary each fighter state and move plays.
## One per character; characters on the same humanoid rig share the library.

## Clips retargeted to SkeletonProfileHumanoid (tracks on %GeneralSkeleton).
@export var library: AnimationLibrary
## FighterState.State name (e.g. "IDLE", "HITSTUN") -> clip. Names, so states
## added later map without code changes; unmapped states fall back to idle.
@export var state_clips: Dictionary[StringName, StringName] = {}
## State name -> clip used instead of state_clips while airborne (e.g. a dash
## in the air plays an air dash; on the ground the state_clips one).
@export var air_state_clips: Dictionary[StringName, StringName] = {}
## Looping clip -> a short clip played first when a state enters it.
@export var intro_clips: Dictionary[StringName, StringName] = {}
## MoveData.id -> clip.
@export var move_clips: Dictionary[StringName, StringName] = {}
## Weapon move slots without an unarmed twin, played as this unarmed move's clip.
const WEAPON_SLOT_CLIPS := {&"bash": &"breaker", &"throw": &"light_2", &"shot": &"light_1", &"pickup": &"light_1"}
## Clip played when a move has no entry.
@export var fallback_move_clip: StringName = &"cross"
## Clip held while charging a chargeable move (attack phase HOLD).
@export var charge_hold_clip: StringName = &"charge"
## Clip played while blocking on the ground or in the air.
@export var block_clip: StringName = &"block"
## Clip for the second half of a knockdown.
@export var get_up_clip: StringName = &"get_up"
## Clip for fast flight; hovering uses state_clips["FLYING"].
@export var fly_fast_clip: StringName = &"fly"
## Clip -> Vector2(start, end) in seconds: the part of the strike shown during
## the move's ACTIVE ticks. Written by tools/build_clip_library.gd.
@export var impact_windows: Dictionary[StringName, Vector2] = {}
## Crossfade between looping clips, seconds.
@export var blend_time: float = 0.12
## Mocap clips (T-D22). When set, CharacterView plays these for every slot MotionSlots maps and
## falls back to the clips above, per slot, where the motion library has no clip.
@export var motion: MotionLibrary
## Move id -> motion clip, overriding MotionSlots.MOVES for this character. "-" plays the posed
## clip; "fit" (or "fit:<take>") retimes the take onto the character's own move (MotionClips.fit_strike).
@export var motion_moves: Dictionary[StringName, StringName] = {}
## The character's motion personality (springs, lean, stride, timing); null uses the defaults.
@export var motion_profile: MotionProfile


func clip_for_state(state_name: StringName, airborne := false) -> StringName:
	if airborne and air_state_clips.has(state_name):
		return air_state_clips[state_name]
	return state_clips.get(state_name, state_clips.get(&"IDLE", &"idle"))


func clip_for_move(move_id: StringName) -> StringName:
	var clip: StringName = move_clips.get(move_id, &"")
	if clip == &"" and String(move_id).contains("/"):
		# Weapon moves ("blade/light_1") play the clip of their slot.
		var slot := StringName(String(move_id).get_slice("/", 1))
		clip = move_clips.get(WEAPON_SLOT_CLIPS.get(slot, slot), &"")
	if clip == &"":
		clip = fallback_move_clip
	return clip if library and library.has_animation(clip) else fallback_move_clip


## Every clip this set refers to.
func mapped_clips() -> Array[StringName]:
	var clips: Array[StringName] = []
	for clip: StringName in state_clips.values() + air_state_clips.values() \
			+ intro_clips.values() + move_clips.values() \
			+ [fallback_move_clip, charge_hold_clip, block_clip, fly_fast_clip, get_up_clip]:
		if not clips.has(clip):
			clips.append(clip)
	return clips


## Clip time for a move tick (fractional ticks allowed): startup plays up to the
## impact window, ACTIVE spans it, recovery plays the rest of the clip.
func attack_clip_time(clip: StringName, move: MoveData, tick: float) -> float:
	var length := library.get_animation(clip).length
	return phase_clip_time(length, impact_windows.get(clip, Vector2(length * 0.4, length * 0.5)), move, tick)


## attack_clip_time for any clip: its length and impact window (seconds).
static func phase_clip_time(length: float, window: Vector2, move: MoveData, tick: float) -> float:
	var active_start := float(move.startup_ticks)
	var active_end := float(move.recovery_start_tick())
	if tick < active_start:
		return window.x * tick / active_start
	if tick < active_end:
		return lerpf(window.x, window.y, (tick - active_start) / float(move.active_ticks))
	var recovery := clampf((tick - active_end) / float(move.recovery_ticks), 0.0, 1.0)
	return lerpf(window.y, length, recovery)
