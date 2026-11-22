class_name EscapeRepro
extends RefCounted
## Issue #150: one attacker strings a defender (Kael) who tries to get out. Used by
## tools/diag/move_escape.gd (table + frame logs) and tests/combat/test_move_escape.gd.

const A := FighterInput.Action
const S := FighterState.State
const E := CombatSim.EventType
## Defender option -> {press, move (lock-on frame: +y toward, +x right), vertical}.
const OPTIONS := {
	"hold_back": {"move": Vector2(0, -1)},
	"hold_side": {"move": Vector2(1, 0)},
	"back_dash": {"press": A.DASH, "move": Vector2(0, -1)},
	"sidestep": {"press": A.DASH, "move": Vector2(1, 0)},
	"spot_dash": {"press": A.DASH},
	"vanish_side": {"press": A.DASH | A.BLOCK, "move": Vector2(1, 0)},
	"vanish_behind": {"press": A.DASH | A.BLOCK, "move": Vector2(0, 1)},
	"fly_up": {"vertical": 1},
}
## on_hit: press on each contact tick; gap: on the first actionable tick after a contact;
## buffered: three ticks before the stun ends.
const TIMINGS: Array[String] = ["on_hit", "gap", "buffered"]
const START_GAP := 1.8
## Out: past every legend's light reach (3.05 m, Lyra light_3), free to act. Behind: this far round its facing.
const OUT_DISTANCE := 3.2
const BEHIND_DEGREES := 100.0
const ATTACK_REACH := 2.6
const REPRESS_TICKS := 12
const ACTIONABLE: Array[FighterState.State] = [S.IDLE, S.MOVING, S.FLYING, S.FALLING, S.BLOCKING]
const ESCAPED: Array[FighterState.State] = [S.IDLE, S.MOVING, S.FLYING, S.FALLING, S.BLOCKING,
	S.DASHING, S.VANISHING, S.ESCAPING]

var sim: CombatSim
var attacker_legend: StringName
var option: String
var guard: bool
var timing: String
var use_ai: bool
var ai: FighterAI
var log_lines: PackedStringArray = []
var _previous: Array[FighterInput] = []
var _dash_age_before := CombatSim.INPUT_BUFFER_TICKS


func _init(attacker: StringName, option_name: String, hold_guard: bool, timing_name: String,
		with_ai := false, seed_value := 7) -> void:
	attacker_legend = attacker
	option = option_name
	guard = hold_guard
	timing = timing_name
	use_ai = with_ai
	sim = CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 0, START_GAP), Roster.character(attacker).stats)
	sim.add_fighter(Vector3.ZERO, Roster.character(&"kael").stats)
	sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	if with_ai:
		ai = FighterAI.new(0, 5, FighterAI.seed_for(seed_value, 0))


## Runs the scenario; {escaped_at (ticks after the first press, -1 never), hits, blocks, refused}.
func run(watch_ticks: int) -> Dictionary:
	var spec: Dictionary = OPTIONS[option]
	var first_contact := -1
	var first_press := -1
	var last_press := -1
	var escaped_at := -1
	var escaped_how := ""
	var hits := 0
	var blocks := 0
	var refused := {}
	var defender := sim.fighters[1]
	var attacker := sim.fighters[0]
	var contact_now := false
	log_lines.append("t | def state(ticks/stun) | def in held/press | def step m | dist m | round deg | ki | atk state move tick phase | events | note")
	for t in watch_ticks + 400:
		if first_press >= 0 and t - first_press > watch_ticks:
			break
		if first_contact < 0 and t > 400:
			break
		var a_input := _attacker_input()
		var d_held := A.BLOCK if guard else 0
		var d_press := 0
		var d_move := Vector2.ZERO
		var d_vertical := 0
		var active := first_contact >= 0
		var stunned := defender.state in [S.HITSTUN, S.BLOCKSTUN]
		var want := false
		if active and escaped_at < 0:
			match timing:
				"on_hit":
					want = contact_now
				"gap":
					want = defender.state in ACTIONABLE and (last_press < 0 or t - last_press >= REPRESS_TICKS)
				"buffered":
					want = stunned and defender.stun_ticks - defender.state_ticks == 3
		if want:
			d_press = spec.get("press", 0)
			last_press = t
			if first_press < 0:
				first_press = t
		if first_press >= 0:
			d_move = spec.get("move", Vector2.ZERO)
			d_vertical = spec.get("vertical", 0)
		# A plain dash press (Shift, not the Shift+E chord) lets go of the guard for good.
		if spec.get("press", 0) == A.DASH and first_press >= 0:
			d_held &= ~A.BLOCK
		var before := defender.position
		var d_input := FighterInput.from_held(d_held | d_press, _previous[1])
		d_input.move = d_move
		d_input.vertical = d_vertical
		var a_from := a_input
		var inputs: Array[FighterInput] = [a_from, d_input]
		var state_before := defender.state
		sim.tick(inputs)
		_previous = inputs
		contact_now = false
		var names := PackedStringArray()
		for event: Dictionary in sim.events:
			if event.get("target", -1) != 1:
				continue
			match event.type:
				E.HIT, E.COUNTER:
					hits += 1
					contact_now = true
					names.append("HIT")
				E.BLOCK, E.PERFECT_BLOCK:
					blocks += 1
					contact_now = true
					names.append("BLOCK")
				E.GUARD_BREAK:
					names.append("GUARD_BREAK")
		if contact_now and first_contact < 0:
			first_contact = t
		var note := _refusal(d_input, state_before) if first_press >= 0 else ""
		if note != "":
			refused[note] = true
		var distance := defender.position.distance_to(attacker.position)
		var around := _degrees_round(attacker, defender)
		if first_press >= 0 and escaped_at < 0 and defender.state in ESCAPED \
				and (distance >= OUT_DISTANCE or around >= BEHIND_DEGREES or _whiffed(attacker)):
			escaped_at = t - first_press
			var how := "out" if distance >= OUT_DISTANCE else ("behind" if around >= BEHIND_DEGREES else "whiffed")
			note = ("%s escaped (%s)" % [note, how]).strip_edges()
			escaped_how = how
		if first_contact >= 0:
			log_lines.append("%d | %s(%d/%d) | %s/%s | %.2f | %.2f | %.0f | %d | %s %s %d %s | %s | %s" % [
				t, S.keys()[defender.state], defender.state_ticks, defender.stun_ticks,
				_bits(d_input.held_actions), _bits(d_input.pressed_actions), before.distance_to(defender.position),
				distance, around, defender.ki / FighterState.METER_UNIT,
				S.keys()[attacker.state], attacker.move_id(), attacker.move_tick,
				FighterState.AttackPhase.keys()[attacker.attack_phase()], ",".join(names), note])
	if first_press < 0:
		refused["never actionable after a contact"] = true
	return {"escaped_at": escaped_at, "how": escaped_how, "hits": hits, "blocks": blocks, "refused": refused}


## The attacker's move missed and is recovering: the defender has the turn.
static func _whiffed(attacker: FighterState) -> bool:
	return attacker.state == S.ATTACKING and attacker.attack_phase() == FighterState.AttackPhase.RECOVERY \
		and not attacker.contact_hit and not attacker.contact_blocked and attacker.hit_targets == 0


## Degrees between the attacker's facing and the line to the defender (0 in front, 180 behind).
static func _degrees_round(attacker: FighterState, defender: FighterState) -> float:
	var to := defender.position - attacker.position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(DetMath.forward(attacker.facing_yaw).angle_to(to.normalized()))


## Max-pressure attacker: rushes in, then one light press per string window, looping.
func _attacker_input() -> FighterInput:
	if use_ai:
		return ai.next_input(sim)
	var me := sim.fighters[0]
	me.ki = 100 * FighterState.METER_UNIT
	var target := sim.fighters[1]
	var held := 0
	var move := Vector2.ZERO
	var distance := me.position.distance_to(target.position)
	var free := me.state in [S.IDLE, S.MOVING, S.FLYING, S.FALLING]
	if free and distance > ATTACK_REACH:
		held = A.DASH
		move = Vector2(0, 1)
	elif free and (_previous[0].held_actions & A.LIGHT) == 0:
		held = A.LIGHT
	elif me.state == S.ATTACKING and me.move != null and me.string_index > 0 \
			and me.move_tick == me.move.string_window_start_tick:
		held = A.LIGHT
	if (_previous[0].held_actions & held & A.DASH) != 0:
		held &= ~A.DASH
	var input := FighterInput.from_held(held, _previous[0])
	input.move = move
	if target.position.y - me.position.y > 0.5:
		input.vertical = 1
	return input


## Why the defender's dash press did nothing this tick, or "".
func _refusal(input: FighterInput, state_before: FighterState.State) -> String:
	var defender := sim.fighters[1]
	var dash_age: int = defender.press_ages[CombatSim._action_index(A.DASH)]
	var pending := dash_age < CombatSim.INPUT_BUFFER_TICKS and (defender.consumed_presses & A.DASH) == 0
	if defender.state in [S.DASHING, S.VANISHING] and state_before not in [S.DASHING, S.VANISHING]:
		_dash_age_before = dash_age
		return ""
	if not pending and not input.is_pressed(A.DASH):
		var expired := dash_age == CombatSim.INPUT_BUFFER_TICKS and _dash_age_before < dash_age
		_dash_age_before = dash_age
		if expired and (defender.consumed_presses & A.DASH) == 0 \
				and state_before not in [S.DASHING, S.VANISHING]:
			return "dash buffer expired in %s" % S.keys()[state_before]
		return ""
	_dash_age_before = dash_age
	if defender.state in [S.DASHING, S.VANISHING]:
		return ""
	match state_before:
		S.HITSTUN, S.BLOCKSTUN, S.GUARD_BROKEN:
			return "dash held in buffer: %s" % S.keys()[state_before]
		S.BLOCKING:
			if defender.ki < sim.meter_tuning.vanish_step_ki_cost * FighterState.METER_UNIT:
				return "vanish needs %d ki" % sim.meter_tuning.vanish_step_ki_cost
			return "dash with guard held"
	return "dash refused in %s" % S.keys()[state_before]


static func _bits(actions: int) -> String:
	var parts := PackedStringArray()
	for name: String in A.keys():
		if (actions & A[name]) != 0:
			parts.append(name.substr(0, 3))
	return "+".join(parts) if not parts.is_empty() else "-"
