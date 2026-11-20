class_name DodgeTrail
extends RefCounted
## When a dodge leaves an afterimage and in what colour (T-DEF2): a dense, clean trail while
## it travels, bright on its invulnerable frames and plain after, so the i-frames read.

## A ghost every this many ticks while the dodge travels (and on its first tick).
const EVERY := 2
const INVULNERABLE_WHITE := 0.45
const STALE_GREY := Color(0.55, 0.55, 0.6)


static func wants_ghost(fighter: FighterState) -> bool:
	if fighter.state != FighterState.State.DASHING or fighter.dash_kind != FighterState.DashKind.DODGE:
		return false
	var dodge := fighter.dodge
	var travelling := fighter.state_ticks <= maxi(dodge.travel_ticks, dodge.invuln_first)
	return travelling and (fighter.state_ticks <= 1 or fighter.state_ticks % EVERY == 0)


## The fighter's energy colour, whitened on i-frames; a stale dodge (no i-frames) goes grey.
static func ghost_color(fighter: FighterState, energy: Color) -> Color:
	var dodge := fighter.dodge
	if dodge.invuln_last < dodge.invuln_first:
		return energy.lerp(STALE_GREY, 0.7)
	if DodgeRules.is_invulnerable(fighter):
		return energy.lerp(Color.WHITE, INVULNERABLE_WHITE)
	return energy
