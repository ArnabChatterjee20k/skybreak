class_name SpecialMove
extends Resource
## One legend special (GAME_DESIGN §5.3, §6): which key, its frame data (a
## MoveData per direction variant) and what it does beyond a plain strike.
## Durations are move ticks (0 = first startup tick); end ticks are exclusive.

## What the special does on top of its MoveData hitboxes.
enum Effect {
	STRIKE, ## Just the move.
	RUSH, ## Travels toward the target over the travel window; stops on contact.
	COUNTER, ## A stance: a strike landing in the counter window is caught and answered with counter_move.
	LEAP, ## An arc toward the target over the travel window (rise, then drop).
	BLINK, ## Vanishes, then reappears behind the target on blink_tick.
	DECOY_STEP, ## Leaves an afterimage decoy where it started and slides away.
}
## How the AI thinks of it (SpecialRules.ai_pick, AISpecials).
enum AiRole {
	APPROACH, ## Closes distance from mid range.
	ANTI_GUARD, ## Breaks a turtle.
	COUNTER, ## Answers a seen strike.
	EVADE, ## Gets out of a seen attack.
	ENDER, ## Cancels a confirmed hit into it.
	MIXUP, ## Opens up a guard from an odd angle.
}

## Key 1, 2 or 3.
@export_range(1, 3) var slot: int = 1
@export var display_name: String = ""
## One line for the move list and training mode: what it beats.
@export var beats: String = ""
## Neutral version; ki_cost, frames and cancel_level (SPECIAL) live here.
@export var move: MoveData
## With ascend held, if set; otherwise the neutral move.
@export var rise_move: MoveData
## With descend held, if set; otherwise the neutral move.
@export var dive_move: MoveData
@export var effect: Effect = Effect.STRIKE

@export_group("Travel")
## Metres covered over [travel_start_tick, travel_end_tick).
@export var travel_distance: float = 0.0
@export var travel_start_tick: int = 0
@export var travel_end_tick: int = 0
## Climb of the rise variant and drop of the dive variant, radians from level.
@export var variant_pitch: float = 0.0
## LEAP: peak height above the start, metres.
@export var leap_height: float = 0.0
## Stops travelling once the move touches someone (hit or block).
@export var stop_on_contact: bool = true
## Move ticks at which the targets already hit may be hit again (multi-hit specials).
@export var rehit_ticks: PackedInt32Array = PackedInt32Array()

@export_group("Counter")
## The riposte performed when the stance catches a strike.
@export var counter_move: MoveData
@export var counter_start_tick: int = 0
@export var counter_end_tick: int = 0
## Extra ticks the caught attacker stays frozen, so the riposte connects.
@export var counter_freeze_ticks: int = 0

@export_group("Blink")
@export var blink_tick: int = 0
## Furthest the blink reaches; a target farther away is approached by this much instead.
@export var blink_range: float = 0.0
## Distance behind the target the blink lands.
@export var blink_behind: float = 1.3

@export_group("Look and sound")
## AudioDirector cue played on the tell (the first tick).
@export var tell_cue: StringName = &"power_up_burst"
## Energy colour of the tell and trail (view only).
@export var color: Color = Color(1.0, 0.65, 0.3)

@export_group("AI")
@export var ai_role: AiRole = AiRole.APPROACH
## Planar distance band (m) in which the AI uses it.
@export var ai_min_range: float = 0.0
@export var ai_max_range: float = 4.0
## Lowest AI level (1-5) that uses it.
@export_range(1, 5) var ai_min_level: int = 2


## The move for vertical input: >0 ascend, <0 descend.
func move_for(vertical: int) -> MoveData:
	if vertical > 0 and rise_move:
		return rise_move
	if vertical < 0 and dive_move:
		return dive_move
	return move


## True if move is this special's (any variant or its riposte).
func owns(other: MoveData) -> bool:
	return other != null and (other == move or other == rise_move or other == dive_move \
		or other == counter_move)


## +1 rise variant, -1 dive variant, 0 neutral (or the riposte).
func variant_of(other: MoveData) -> int:
	if other != null and other == rise_move:
		return 1
	if other != null and other == dive_move:
		return -1
	return 0


func ki_cost() -> int:
	return move.ki_cost if move else 0
