class_name PureFighter
extends RefCounted
## One fighter's state in Pure Fight (GAME_DESIGN §16). Integers only: positions in mm along
## the fight line (x) and above the platform (y, the feet), velocities in mm per tick.
## No Dictionaries or Resources here, so SimSnapshot copies it exactly for rollback.

enum State {
	IDLE, CROUCH, WALK, PREJUMP, AIR, LANDING, DASH, BACKDASH, ATTACK, BLOCKSTUN, HITSTUN,
	JUGGLE, KNOCKDOWN, WAKEUP, ROLL, THROWING, THROWN, TECH, HELD, INTRO, VICTORY, DEFEAT,
}

## Buttons tracked by the press buffer, in this order.
enum Key { L, M, H, GRAB, TECH, FINISHER, DASH, BLOCK }

const HISTORY := 32

var legend: StringName = &"kael"
var slot := 0
var x := 0
var y := 0
var vx := 0
var vy := 0
## +1 faces +x (screen right), -1 faces -x.
var facing := 1
var health := 1000
var max_health := 1000
var meter := 0
var state: State = State.IDLE
var state_tick := 0
## Current move id (PureMoves) while ATTACK, THROWING or a finisher runs; &"" otherwise.
var move: StringName = &""
var move_tick := 0
## Ticks the move has already hit (rehits count down from rehit).
var move_hits := 0
var move_rehit_wait := 0
## The current move touched the opponent (hit or block): cancels open.
var move_contact := false
var move_contact_hit := false
var armor_left := 0
var hitstop := 0
var stun_left := 0
## Signed mm still to slide from pushback.
var push_left := 0
## Variant of the current stun or knockdown: 0 high, 1 low (picks the reaction pose).
var reaction := 0
var crouching := false
## Air normal already used this jump.
var air_attack_used := false
var jump_dir := 0
var landing_ticks := 0
## Combo bookkeeping, owned by the fighter being hit.
var combo_hits := 0
var combo_damage := 0
var juggle_points := 0
var wall_bounce_used := false
var ground_bounce_used := false
var wall_bounce_pending := false
var ground_bounce_pending := false
## JUGGLE ends on the feet (an air reset) instead of in a knockdown.
var juggle_reset := false
var juggle_gravity := 0
## Tick the guard (back or BLOCK) went on; -1000 while not guarding.
var guard_since := -1000
var guarding := false
var roll_dir := 0
## Throw tech window ticks left (THROWN) and the throw being taken.
var tech_window := 0
var throw_damage := 0
## No throws on this fighter for this many ticks (after stun, on wake-up).
var throw_protect := 0
var round_wins := 0
## Numpad directions, relative to facing, of the last HISTORY ticks (ring buffer).
var dirs := PackedInt32Array()
var dirs_head := 0
## Ticks since each Key was pressed (consumed presses jump to the buffer limit).
var press_ages := PackedInt32Array()
var held_buttons := 0
var last_dir := 5


func _init() -> void:
	dirs.resize(HISTORY)
	dirs.fill(5)
	press_ages.resize(Key.size())
	press_ages.fill(99)


func is_airborne() -> bool:
	return y > 0 or state in [State.AIR, State.JUGGLE]


func in_attack_recovery() -> bool:
	if state != State.ATTACK:
		return false
	var data := PureMoves.get_move(legend, move)
	return move_tick >= int(data.startup) - 1 + int(data.active)


func in_attack_startup() -> bool:
	if state != State.ATTACK:
		return false
	return move_tick < int(PureMoves.get_move(legend, move).startup) - 1


## Direction pressed n ticks ago (0 = this tick).
func dir_ago(n: int) -> int:
	return dirs[(dirs_head - n + HISTORY * 4) % HISTORY]


func push_dir(dir: int) -> void:
	dirs_head = (dirs_head + 1) % HISTORY
	dirs[dirs_head] = dir


func state_values() -> Array:
	return [legend, slot, x, y, vx, vy, facing, health, max_health, meter, state, state_tick, move,
		move_tick, move_hits, move_rehit_wait, move_contact, move_contact_hit, armor_left, hitstop,
		stun_left, push_left, reaction, crouching, air_attack_used, jump_dir, landing_ticks,
		combo_hits, combo_damage, juggle_points, wall_bounce_used, ground_bounce_used,
		wall_bounce_pending, ground_bounce_pending, juggle_reset, juggle_gravity, guard_since,
		guarding, roll_dir, tech_window, throw_damage, throw_protect, round_wins, dirs, dirs_head,
		press_ages, held_buttons, last_dir]
