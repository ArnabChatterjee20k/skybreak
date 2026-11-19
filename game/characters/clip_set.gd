class_name ClipSet
extends Resource
## Which clip of a humanoid AnimationLibrary each fighter state and move plays.
## One per character; characters on the same humanoid rig share the library.

## Clips retargeted to SkeletonProfileHumanoid (tracks on %GeneralSkeleton).
@export var library: AnimationLibrary
## FighterState.State name (e.g. "IDLE", "HITSTUN") -> clip. Names, so states
## added later map without code changes; unmapped states fall back to idle.
@export var state_clips: Dictionary[StringName, StringName] = {}
## MoveData.id -> clip.
@export var move_clips: Dictionary[StringName, StringName] = {}
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


func clip_for_state(state_name: StringName) -> StringName:
	return state_clips.get(state_name, state_clips.get(&"IDLE", &"idle"))


func clip_for_move(move_id: StringName) -> StringName:
	var clip: StringName = move_clips.get(move_id, fallback_move_clip)
	return clip if library and library.has_animation(clip) else fallback_move_clip


## Every clip this set refers to.
func mapped_clips() -> Array[StringName]:
	var clips: Array[StringName] = []
	for clip: StringName in state_clips.values() + move_clips.values() \
			+ [fallback_move_clip, charge_hold_clip, block_clip, fly_fast_clip, get_up_clip]:
		if not clips.has(clip):
			clips.append(clip)
	return clips


## Clip time for a move tick (fractional ticks allowed): startup plays up to the
## impact window, ACTIVE spans it, recovery plays the rest of the clip.
func attack_clip_time(clip: StringName, move: MoveData, tick: float) -> float:
	var length := library.get_animation(clip).length
	var window: Vector2 = impact_windows.get(clip, Vector2(length * 0.4, length * 0.5))
	var active_start := float(move.startup_ticks)
	var active_end := float(move.recovery_start_tick())
	if tick < active_start:
		return window.x * tick / active_start
	if tick < active_end:
		return lerpf(window.x, window.y, (tick - active_start) / float(move.active_ticks))
	var recovery := clampf((tick - active_end) / float(move.recovery_ticks), 0.0, 1.0)
	return lerpf(window.y, length, recovery)
