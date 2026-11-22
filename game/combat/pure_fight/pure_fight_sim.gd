class_name PureFightSim
extends CombatSim
## Pure Fight (GAME_DESIGN §16): a 2.5D 1v1 rule set. Both fighters stay on one fight line
## laid across a platform; no flight, ki, specials, weapons or pickups. Positions are integer
## mm along the line (x) and above the platform (y). A CombatSim subclass so rollback
## (RollbackSession) and the match tools take it as is; CombatSim's own tick never runs, so
## every other mode stays bit-identical. Same seed + same inputs = same match.

enum Phase { INTRO, FIGHT, ROUND_END, MATCH_OVER }
## What an entry in events reports. Entries: {type, a (attacker), t (target), move, strength, x, y}.
enum Ev {
	MOVE, HIT, COUNTER, PUNISH, BLOCK, JUST_DEFEND, ARMOR, THROW, THROW_TECH, WALL_BOUNCE,
	GROUND_BOUNCE, KNOCKDOWN, KO, FINISHER, FINISHER_HIT, COUNTER_STANCE, ROUND_START, FIGHT,
	TIME_UP, ROUND_WIN, MATCH_WIN, DASH, LAND, JUMP, WHIFF_THROW,
}

const ROUNDS_TO_WIN := 2
const MAX_ROUNDS := 5
const ROUND_SECONDS := 99
const INTRO_TICKS := 120
const NEXT_ROUND_INTRO_TICKS := 70
const ROUND_END_TICKS := 210
const VICTORY_AT := 80
## Centre x limit (walls at the platform ends) and the most two fighters can be apart.
const WALL := 7400
const MAX_SEPARATION := 6600
const START_GAP := 2400
const STAND_HEIGHT := 1750
const CROUCH_HEIGHT := 1100
const PREJUMP_TICKS := 4
const LANDING_TICKS := 3
const KNOCKDOWN_TICKS := 38
const WAKEUP_TICKS := 22
const ROLL_TICKS := 26
const ROLL_SPEED := 56
const BACKDASH_INVULN := 8
const JUST_DEFEND_WINDOW := 4
const JUGGLE_LIMIT := 4
const BUFFER := 6
## A move cancels on contact until this many frames after its last active frame.
const CANCEL_WINDOW := 8
const POST_STUN_THROW_PROTECT := 3
const WAKE_THROW_PROTECT := 4

const _B := PureFighter.Key
const _BUTTON_ACTIONS: Array[int] = [
	FighterInput.Action.LIGHT, FighterInput.Action.SPECIAL_1, FighterInput.Action.HEAVY,
	FighterInput.Action.GRAB, FighterInput.Action.SPECIAL_2, FighterInput.Action.ULTIMATE,
	FighterInput.Action.DASH, FighterInput.Action.BLOCK,
]
const _S := PureFighter.State
const _BLOCK_STATES: Array[int] = [_S.IDLE, _S.CROUCH, _S.WALK, _S.BLOCKSTUN, _S.AIR, _S.LANDING]
const _NO_THROW_STATES: Array[int] = [_S.HITSTUN, _S.BLOCKSTUN, _S.KNOCKDOWN, _S.WAKEUP,
	_S.ROLL, _S.THROWN, _S.THROWING, _S.TECH, _S.JUGGLE, _S.HELD, _S.INTRO, _S.VICTORY,
	_S.DEFEAT, _S.AIR, _S.PREJUMP]
const _INVULN_STATES: Array[int] = [_S.KNOCKDOWN, _S.WAKEUP, _S.ROLL, _S.HELD, _S.THROWN,
	_S.THROWING, _S.TECH, _S.INTRO, _S.VICTORY, _S.DEFEAT]

var pf: Array[PureFighter] = []
var phase: Phase = Phase.INTRO
var phase_tick := 0
var round_number := 1
var timer_ticks := ROUND_SECONDS * TICKS_PER_SECOND
var match_winner := -1
## Fighter whose finisher cinematic is running, or -1.
var finisher_owner := -1
## Where the fight line sits in the world (the view's business; the sim never reads them).
var line_origin := Vector3.ZERO
var line_dir := Vector3.RIGHT


func _init(seed_value: int = 0, legends: Array[StringName] = [&"kael", &"vexa"]) -> void:
	super(seed_value)
	pickups_enabled = false
	for i in 2:
		var fighter := PureFighter.new()
		fighter.legend = legends[i] if i < legends.size() else &"kael"
		fighter.slot = i
		pf.append(fighter)
	start_round()


## Puts both fighters at their marks for the next round (health full, meter kept).
func start_round(_spawns: Array[Vector3] = []) -> void:
	phase = Phase.INTRO
	phase_tick = 0
	timer_ticks = ROUND_SECONDS * TICKS_PER_SECOND
	round_over = false
	round_winner = -1
	finisher_owner = -1
	for i in 2:
		var fighter := pf[i]
		var stats := PureMoves.stats(fighter.legend)
		fighter.max_health = int(stats.health)
		fighter.health = fighter.max_health
		fighter.x = -START_GAP / 2 if i == 0 else START_GAP / 2
		fighter.y = 0
		fighter.vx = 0
		fighter.vy = 0
		fighter.facing = 1 if i == 0 else -1
		_set_state(fighter, _S.INTRO)
		fighter.hitstop = 0
		fighter.push_left = 0
		fighter.throw_protect = 0
		_reset_combo(fighter)
	events = [{"type": Ev.ROUND_START, "a": -1, "t": -1, "move": &"", "strength": round_number,
		"x": 0, "y": 0}]


func intro_ticks() -> int:
	return INTRO_TICKS if round_number == 1 else NEXT_ROUND_INTRO_TICKS


## Advances the match one tick. inputs[i] belongs to pf[i].
func tick(inputs: Array[FighterInput]) -> void:
	events = []
	phase_tick += 1
	if phase == Phase.INTRO and phase_tick >= intro_ticks():
		phase = Phase.FIGHT
		phase_tick = 0
		for fighter in pf:
			_set_state(fighter, _S.IDLE)
		_emit(Ev.FIGHT, -1, -1)
	elif phase == Phase.FIGHT and finisher_owner < 0:
		timer_ticks = maxi(timer_ticks - 1, 0)
	for i in 2:
		var neutral := phase != Phase.FIGHT or i >= inputs.size()
		_read_input(pf[i], FighterInput.new() if neutral else inputs[i])
	for i in 2:
		_step(i)
	_resolve_bodies()
	if phase == Phase.FIGHT:
		_resolve_strikes()
		_check_round_end()
	_step_phase()
	current_tick += 1


func state_hash() -> int:
	var parts: Array = [current_tick, rng.state, phase, phase_tick, round_number, timer_ticks,
		match_winner, round_over, round_winner, finisher_owner, events]
	for fighter in pf:
		parts.append_array(fighter.state_values())
	return hash(var_to_bytes(parts))


func opponent(index: int) -> PureFighter:
	return pf[1 - index]


## World position of a fighter's feet (the view's helper): along the line, y above the platform.
func world_feet(index: int) -> Vector3:
	var fighter := pf[index]
	return line_origin + line_dir * (fighter.x / 1000.0) + Vector3.UP * (fighter.y / 1000.0)


## Hurtbox of a fighter: [x0, x1, y0, y1] in mm, world line coordinates.
func hurtbox(fighter: PureFighter) -> Array[int]:
	var bottom := 0
	var top := STAND_HEIGHT
	if fighter.state == _S.CROUCH or fighter.crouching:
		top = CROUCH_HEIGHT
	if fighter.state in [_S.AIR, _S.JUGGLE] or fighter.y > 0:
		bottom = 250
		top = 1550
	if fighter.state == _S.ATTACK:
		var data := PureMoves.get_move(fighter.legend, fighter.move)
		if data.stance == &"crouch":
			top = CROUCH_HEIGHT
		if _in_frames(data.low_profile, fighter.move_tick + 1):
			top = 900
	var half := int(PureMoves.stats(fighter.legend).hurt)
	return [fighter.x - half, fighter.x + half, fighter.y + bottom, fighter.y + top]


## Active hitbox of a fighter this tick, or [] when it has none.
func hitbox(fighter: PureFighter) -> Array[int]:
	if fighter.state != _S.ATTACK:
		return []
	var data := PureMoves.get_move(fighter.legend, fighter.move)
	var box: Array = data.box
	if box.is_empty() or not _is_active(fighter, data):
		return []
	var a := fighter.x + fighter.facing * int(box[0])
	var b := fighter.x + fighter.facing * int(box[1])
	return [mini(a, b), maxi(a, b), fighter.y + int(box[2]), fighter.y + int(box[3])]


func _is_active(fighter: PureFighter, data: Dictionary) -> bool:
	var frame := fighter.move_tick + 1
	var first := int(data.startup)
	return frame >= first and frame < first + int(data.active)


static func _in_frames(frames: Array, frame: int) -> bool:
	return not frames.is_empty() and frame >= int(frames[0]) and frame <= int(frames[1])


# --- input ------------------------------------------------------------------------------

func _read_input(fighter: PureFighter, input: FighterInput) -> void:
	var sx := 0
	if input.move.x > 0.4:
		sx = 1
	elif input.move.x < -0.4:
		sx = -1
	var sy := 0
	if input.move.y > 0.4 or input.vertical > 0:
		sy = 1
	elif input.move.y < -0.4 or input.vertical < 0:
		sy = -1
	var dir := 5 + sx * fighter.facing + 3 * sy
	fighter.push_dir(dir)
	fighter.last_dir = dir
	fighter.held_buttons = 0
	for b in _BUTTON_ACTIONS.size():
		var action := _BUTTON_ACTIONS[b]
		if input.held_actions & action:
			fighter.held_buttons |= 1 << b
		if input.pressed_actions & action:
			fighter.press_ages[b] = 0
		elif fighter.hitstop == 0:
			fighter.press_ages[b] = mini(fighter.press_ages[b] + 1, 99)


func _pressed(fighter: PureFighter, button: int) -> bool:
	return fighter.press_ages[button] < BUFFER


func _consume(fighter: PureFighter, button: int) -> void:
	fighter.press_ages[button] = 99


## Strongest attack button in the buffer (H, M, L), or -1.
func _attack_button(fighter: PureFighter) -> int:
	for button in [_B.H, _B.M, _B.L]:
		if _pressed(fighter, button):
			return button
	return -1


static func _button_name(button: int) -> StringName:
	return [&"L", &"M", &"H"][button]


func _holding_back(fighter: PureFighter) -> bool:
	return fighter.last_dir in [1, 4, 7] or (fighter.held_buttons & (1 << _B.BLOCK)) != 0


func _holding_down(fighter: PureFighter) -> bool:
	return fighter.last_dir in [1, 2, 3]


# --- stepping ---------------------------------------------------------------------------

func _set_state(fighter: PureFighter, state: PureFighter.State) -> void:
	fighter.state = state
	fighter.state_tick = 0
	if state != _S.ATTACK and state != _S.THROWING:
		fighter.move = &""
		fighter.move_tick = 0
	if state in [_S.IDLE, _S.WALK, _S.CROUCH, _S.LANDING, _S.INTRO, _S.VICTORY, _S.DEFEAT]:
		fighter.crouching = state == _S.CROUCH


func _step(index: int) -> void:
	var fighter := pf[index]
	_track_guard(fighter)
	if fighter.hitstop > 0:
		fighter.hitstop -= 1
		return
	fighter.state_tick += 1
	fighter.throw_protect = maxi(fighter.throw_protect - 1, 0)
	var vel_set := false
	match fighter.state:
		_S.IDLE, _S.CROUCH, _S.WALK:
			vel_set = _neutral(index)
		_S.PREJUMP:
			fighter.vx = 0
			if fighter.state_tick >= PREJUMP_TICKS:
				_leave_ground(fighter)
				vel_set = true
		_S.AIR:
			vel_set = _air_actions(index)
		_S.LANDING:
			fighter.vx = 0
			if fighter.state_tick >= fighter.landing_ticks:
				vel_set = _neutral(index)
		_S.DASH, _S.BACKDASH:
			vel_set = _move_dash(fighter)
		_S.ATTACK:
			vel_set = _advance_move(index)
		_S.BLOCKSTUN, _S.HITSTUN:
			fighter.stun_left -= 1
			if fighter.y == 0:
				fighter.vx = 0
			if fighter.stun_left <= 0:
				fighter.throw_protect = POST_STUN_THROW_PROTECT
				if fighter.state == _S.HITSTUN:
					_reset_combo(fighter)
				vel_set = _neutral(index)
		_S.JUGGLE:
			pass
		_S.KNOCKDOWN:
			fighter.vx = 0
			if fighter.state_tick >= KNOCKDOWN_TICKS and fighter.health > 0:
				_reset_combo(fighter)
				var fwd := _dir_forward(fighter.last_dir)
				if fwd != 0:
					_set_state(fighter, _S.ROLL)
					fighter.roll_dir = fwd * fighter.facing
				else:
					_set_state(fighter, _S.WAKEUP)
		_S.WAKEUP:
			if fighter.state_tick >= WAKEUP_TICKS:
				fighter.throw_protect = WAKE_THROW_PROTECT
				_face_opponent(index)
				vel_set = _neutral(index)
		_S.ROLL:
			fighter.vx = fighter.roll_dir * ROLL_SPEED
			vel_set = true
			if fighter.state_tick >= ROLL_TICKS:
				fighter.vx = 0
				fighter.throw_protect = WAKE_THROW_PROTECT
				_face_opponent(index)
				_set_state(fighter, _S.IDLE)
		_S.THROWING:
			_advance_throw(index)
		_S.THROWN:
			_advance_thrown(index)
		_S.TECH:
			fighter.vx = 0
			if fighter.state_tick >= PureMoves.TECH_TICKS:
				_face_opponent(index)
				_set_state(fighter, _S.IDLE)
		_S.HELD, _S.INTRO, _S.VICTORY, _S.DEFEAT:
			fighter.vx = 0
	_apply_push(index)
	_physics(index, vel_set)


func _dir_forward(dir: int) -> int:
	return ((dir - 1) % 3) - 1


func _face_opponent(index: int) -> void:
	var fighter := pf[index]
	var dx := opponent(index).x - fighter.x
	if dx != 0:
		fighter.facing = 1 if dx > 0 else -1


func _track_guard(fighter: PureFighter) -> void:
	var guarding := _holding_back(fighter) and fighter.state in _BLOCK_STATES
	if guarding and not fighter.guarding:
		fighter.guard_since = current_tick
	fighter.guarding = guarding


## Neutral: start whatever the input asks for. Returns true when it set the velocity.
func _neutral(index: int) -> bool:
	var fighter := pf[index]
	_face_opponent(index)
	if _try_finisher(index) or _try_technique(index, false) or _try_throw(index) \
			or _try_normal(index):
		return true
	var dir := fighter.last_dir
	var stats := PureMoves.stats(fighter.legend)
	if dir in [7, 8, 9]:
		fighter.jump_dir = _dir_forward(dir)
		_set_state(fighter, _S.PREJUMP)
		fighter.vx = 0
		return true
	var dash_pressed := _pressed(fighter, _B.DASH)
	if MotionInput.matches(fighter, &"66") or (dash_pressed and _dir_forward(dir) >= 0 and dir > 3):
		_consume(fighter, _B.DASH)
		_set_state(fighter, _S.DASH)
		_emit(Ev.DASH, index, -1)
		return _move_dash(fighter)
	if MotionInput.matches(fighter, &"44") or (dash_pressed and dir == 4):
		_consume(fighter, _B.DASH)
		_set_state(fighter, _S.BACKDASH)
		_emit(Ev.DASH, index, -1)
		return _move_dash(fighter)
	if dir in [1, 2, 3]:
		if fighter.state != _S.CROUCH:
			_set_state(fighter, _S.CROUCH)
		fighter.vx = 0
		return true
	if dir == 6 or dir == 4:
		if fighter.state != _S.WALK:
			_set_state(fighter, _S.WALK)
		fighter.vx = fighter.facing * (int(stats.walk_f) if dir == 6 else -int(stats.walk_b))
		return true
	if fighter.state != _S.IDLE:
		_set_state(fighter, _S.IDLE)
	fighter.vx = 0
	return true


func _try_finisher(index: int) -> bool:
	var fighter := pf[index]
	if fighter.meter < PureMoves.METER_MAX:
		return false
	var wants := _pressed(fighter, _B.FINISHER) or (_attack_button(fighter) >= 0
		and MotionInput.matches(fighter, &"236236"))
	if not wants:
		return false
	for id in PureMoves.ids(fighter.legend):
		if PureMoves.get_move(fighter.legend, id).kind == &"finisher":
			_consume(fighter, _B.FINISHER)
			_consume_attacks(fighter)
			fighter.meter = 0
			_start_move(index, id)
			_emit(Ev.FINISHER, index, 1 - index, id, 3)
			return true
	return false


## A technique from a motion + attack, or the technique button + a direction.
func _try_technique(index: int, air: bool) -> bool:
	var fighter := pf[index]
	var button := _attack_button(fighter)
	var motion := &""
	if button >= 0:
		for candidate in [&"623", &"214", &"236"]:
			if MotionInput.matches(fighter, candidate):
				motion = candidate
				break
	if motion == &"" and _pressed(fighter, _B.TECH):
		var dir := fighter.last_dir
		if dir in [1, 2, 3]:
			motion = &"623"
		elif dir in [4, 7]:
			motion = &"214"
		else:
			motion = &"236"
		if air:
			motion = &""
	if motion == &"":
		return false
	for id in PureMoves.ids(fighter.legend):
		var data := PureMoves.get_move(fighter.legend, id)
		if data.kind == &"technique" and data.motion == motion and (data.stance == &"air") == air:
			_consume(fighter, _B.TECH)
			_consume_attacks(fighter)
			_start_move(index, id)
			return true
	return false


func _consume_attacks(fighter: PureFighter) -> void:
	for button in [_B.L, _B.M, _B.H]:
		_consume(fighter, button)


func _try_throw(index: int) -> bool:
	var fighter := pf[index]
	if not _pressed(fighter, _B.GRAB):
		return false
	_consume(fighter, _B.GRAB)
	_start_move(index, &"throw")
	return true


func _try_normal(index: int) -> bool:
	var fighter := pf[index]
	var button := _attack_button(fighter)
	if button < 0:
		return false
	var name := _button_name(button)
	var dir := fighter.last_dir
	var table := PureMoves.table(fighter.legend)
	var id := StringName("5" + name)
	if dir in [1, 2, 3]:
		id = StringName("2" + name)
		if dir == 3 and table.has(StringName("3" + name)):
			id = StringName("3" + name)
	elif table.has(StringName(str(dir) + name)) and dir != 5:
		id = StringName(str(dir) + name)
	_consume_attacks(fighter)
	_start_move(index, id)
	return true


func _air_actions(index: int) -> bool:
	var fighter := pf[index]
	if fighter.air_attack_used:
		return false
	var button := _attack_button(fighter)
	if button < 0:
		return false
	var table := PureMoves.table(fighter.legend)
	var id := StringName("j." + _button_name(button))
	if fighter.last_dir in [1, 2, 3]:
		for candidate in table:
			var data: Dictionary = table[candidate]
			if data.kind == &"technique" and data.stance == &"air" and data.button == _button_name(button):
				id = candidate
	_consume_attacks(fighter)
	fighter.air_attack_used = true
	_start_move(index, id)
	return false


func _start_move(index: int, id: StringName) -> void:
	var fighter := pf[index]
	var data := PureMoves.get_move(fighter.legend, id)
	assert(not data.is_empty(), "unknown move %s for %s" % [id, fighter.legend])
	if data.stance != &"air":
		_face_opponent(index)
	_set_state(fighter, _S.ATTACK)
	fighter.move = id
	fighter.move_tick = 0
	fighter.move_hits = 0
	fighter.move_rehit_wait = 0
	fighter.move_contact = false
	fighter.move_contact_hit = false
	fighter.armor_left = 1 if not (data.armor as Array).is_empty() else 0
	fighter.crouching = data.stance == &"crouch"
	if data.stance != &"air" and fighter.y == 0:
		fighter.vx = 0
	_emit(Ev.MOVE, index, 1 - index, id, int(data.strength))


## Moves the current move on a frame: cancels, its velocity, its end.
func _advance_move(index: int) -> bool:
	var fighter := pf[index]
	fighter.move_tick += 1
	var data := PureMoves.get_move(fighter.legend, fighter.move)
	if fighter.move_rehit_wait > 0:
		fighter.move_rehit_wait -= 1
	var frame := fighter.move_tick + 1
	if fighter.move_contact and frame < int(data.startup) + int(data.active) + CANCEL_WINDOW:
		if _try_cancel(index, data):
			return true
	if frame > PureMoves.total(data):
		if fighter.y > 0:
			_set_state(fighter, _S.AIR)
			fighter.air_attack_used = true
			return false
		return _neutral(index)
	return false


func _try_cancel(index: int, data: Dictionary) -> bool:
	var fighter := pf[index]
	if data.super_cancel and fighter.move_contact_hit and _try_finisher(index):
		return true
	if int(data.cancel) >= 2:
		var button := _attack_button(fighter)
		if button >= 0:
			for id in PureMoves.ids(fighter.legend):
				var chain := PureMoves.get_move(fighter.legend, id)
				if chain.chain_from == fighter.move and chain.button == _button_name(button):
					_consume_attacks(fighter)
					_start_move(index, id)
					return true
	if int(data.cancel) >= 1:
		return _try_technique(index, false) or _try_finisher(index)
	return false


func _leave_ground(fighter: PureFighter) -> void:
	var stats := PureMoves.stats(fighter.legend)
	_set_state(fighter, _S.AIR)
	fighter.vy = int(stats.jump_vy)
	fighter.vx = fighter.jump_dir * fighter.facing * int(stats.jump_vx)
	fighter.y = 1
	fighter.air_attack_used = false
	_emit(Ev.JUMP, fighter.slot, -1)


func _move_dash(fighter: PureFighter) -> bool:
	var stats := PureMoves.stats(fighter.legend)
	var forward := fighter.state == _S.DASH
	var ticks := int(stats.dash_ticks) if forward else int(stats.back_ticks)
	var speed := int(stats.dash_speed) if forward else int(stats.back_speed)
	if fighter.state_tick > ticks - 5:
		speed = speed * (ticks - fighter.state_tick) / 5
	fighter.vx = fighter.facing * (speed if forward else -speed)
	if fighter.state_tick >= ticks:
		fighter.vx = 0
		_set_state(fighter, _S.IDLE)
	return true


func _apply_push(index: int) -> void:
	var fighter := pf[index]
	if fighter.push_left == 0:
		return
	var step := maxi(absi(fighter.push_left) / 4, 12)
	step = mini(step, absi(fighter.push_left)) * signi(fighter.push_left)
	fighter.push_left -= step
	var before := fighter.x
	fighter.x = clampi(fighter.x + step, -WALL, WALL)
	var blocked := step - (fighter.x - before)
	# Against the wall the attacker takes the rest of the pushback.
	if blocked != 0:
		var other := opponent(index)
		if other.y == 0 and other.state in [_S.ATTACK, _S.IDLE, _S.WALK, _S.CROUCH]:
			other.x = clampi(other.x - blocked, -WALL, WALL)


## Velocity from the move's frames, gravity in the air, landing.
func _physics(index: int, vel_set: bool) -> void:
	var fighter := pf[index]
	var stats := PureMoves.stats(fighter.legend)
	var gravity := int(stats.gravity)
	var driven := false
	if fighter.state == _S.ATTACK:
		var data := PureMoves.get_move(fighter.legend, fighter.move)
		var frame := fighter.move_tick + 1
		for entry in data.vel:
			if frame >= int(entry[0]) and frame <= int(entry[1]):
				fighter.vx = int(entry[2]) * fighter.facing
				if int(entry[3]) != 0:
					fighter.vy = int(entry[3])
					if fighter.y == 0 and fighter.vy > 0:
						fighter.y = 1
				driven = true
		if not driven and fighter.y == 0 and data.stance != &"air":
			fighter.vx = 0
	elif fighter.state == _S.JUGGLE:
		gravity = 8 + fighter.juggle_points
	elif fighter.y == 0 and not vel_set and fighter.state not in [_S.DASH, _S.BACKDASH, _S.ROLL]:
		fighter.vx = 0
	var airborne := fighter.y > 0 or fighter.vy > 0
	if not airborne:
		fighter.vy = 0
		fighter.x = clampi(fighter.x + fighter.vx, -WALL, WALL)
		return
	if not driven:
		fighter.vy -= gravity
	fighter.x += fighter.vx
	fighter.y += fighter.vy
	if absi(fighter.x) > WALL:
		fighter.x = clampi(fighter.x, -WALL, WALL)
		if fighter.state == _S.JUGGLE and fighter.wall_bounce_pending:
			fighter.wall_bounce_pending = false
			fighter.wall_bounce_used = true
			fighter.vx = -fighter.vx * 6 / 10
			fighter.vy = 95
			_emit(Ev.WALL_BOUNCE, 1 - index, index)
		else:
			fighter.vx = 0
	if fighter.y <= 0:
		fighter.y = 0
		_land(index)


func _land(index: int) -> void:
	var fighter := pf[index]
	var falling_vy := fighter.vy
	fighter.vy = 0
	match fighter.state:
		_S.AIR:
			fighter.vx = 0
			fighter.landing_ticks = LANDING_TICKS
			_set_state(fighter, _S.LANDING)
			_emit(Ev.LAND, index, -1)
		_S.ATTACK:
			var data := PureMoves.get_move(fighter.legend, fighter.move)
			if data.stance == &"air":
				fighter.vx = 0
				fighter.landing_ticks = int(data.landing)
				_set_state(fighter, _S.LANDING)
				_emit(Ev.LAND, index, -1)
		_S.JUGGLE:
			if fighter.ground_bounce_pending:
				fighter.ground_bounce_pending = false
				fighter.ground_bounce_used = true
				fighter.vy = 105
				fighter.vx = fighter.vx / 2
				fighter.y = 1
				_emit(Ev.GROUND_BOUNCE, 1 - index, index)
			elif fighter.juggle_reset and fighter.health > 0:
				fighter.vx = 0
				fighter.landing_ticks = 6
				_reset_combo(fighter)
				_set_state(fighter, _S.LANDING)
			else:
				fighter.vx = 0
				_set_state(fighter, _S.KNOCKDOWN)
				_emit(Ev.KNOCKDOWN, 1 - index, index, &"", 2 if falling_vy < -100 else 1)
		_S.BLOCKSTUN, _S.HITSTUN:
			fighter.vx = 0
		_:
			fighter.vx = 0


# --- throws -----------------------------------------------------------------------------

func _advance_throw(index: int) -> void:
	var fighter := pf[index]
	var target := opponent(index)
	var data := PureMoves.get_move(fighter.legend, fighter.move)
	var length := int(data.cinematic) if int(data.cinematic) > 0 else PureMoves.THROW_TICKS
	fighter.vx = 0
	if target.state in [_S.THROWN, _S.HELD]:
		target.x = clampi(fighter.x + fighter.facing * 650, -WALL, WALL)
		target.facing = -fighter.facing
	if fighter.state_tick == length - 14 and target.state in [_S.THROWN, _S.HELD]:
		var back := fighter.jump_dir < 0
		target.x = clampi(fighter.x + fighter.facing * (-900 if back else 900), -WALL, WALL)
		var damage := target.throw_damage
		if data.kind == &"finisher":
			damage = damage * maxi(_scale(target.combo_hits + 1), 50) / 100
		_hurt(target, fighter, damage)
		var away := signi(target.x - fighter.x)
		_launch(target, away if away != 0 else fighter.facing, 45, 70, false)
		target.hitstop = PureMoves.HITSTOP[3]
		fighter.hitstop = PureMoves.HITSTOP[3]
		_emit(Ev.HIT, index, 1 - index,
			fighter.move, 3)
		if target.health == 0:
			_ko(1 - index, index)
	if fighter.state_tick >= length:
		finisher_owner = -1 if finisher_owner == index else finisher_owner
		_face_opponent(index)
		_set_state(fighter, _S.IDLE)


func _advance_thrown(index: int) -> void:
	var fighter := pf[index]
	fighter.vx = 0
	if fighter.tech_window > 0:
		fighter.tech_window -= 1
		if _pressed(fighter, _B.GRAB):
			_consume(fighter, _B.GRAB)
			_tech(1 - index, index)


func _tech(thrower_index: int, target_index: int) -> void:
	var thrower := pf[thrower_index]
	var target := pf[target_index]
	for fighter in [thrower, target]:
		_set_state(fighter, _S.TECH)
		fighter.tech_window = 0
	var side := signi(target.x - thrower.x)
	if side == 0:
		side = thrower.facing
	target.push_left = side * 500
	thrower.push_left = -side * 500
	_emit(Ev.THROW_TECH, thrower_index, target_index)


func _can_be_thrown(target: PureFighter) -> bool:
	if target.y > 0 or target.state in _NO_THROW_STATES or target.throw_protect > 0:
		return false
	if target.state == _S.ATTACK:
		var data := PureMoves.get_move(target.legend, target.move)
		if _in_frames(data.throw_invuln, target.move_tick + 1) or data.stance == &"air":
			return false
	if target.state == _S.BACKDASH and target.state_tick <= BACKDASH_INVULN:
		return false
	return true


func _start_throw(index: int, data: Dictionary) -> void:
	var fighter := pf[index]
	var target := opponent(index)
	fighter.jump_dir = -1 if fighter.last_dir in [1, 4, 7] and data.kind == &"throw" else 0
	var move := fighter.move
	_set_state(fighter, _S.THROWING)
	fighter.move = move
	fighter.move_tick = 0
	var cinematic := int(data.cinematic) > 0
	_set_state(target, _S.HELD if cinematic else _S.THROWN)
	target.tech_window = 0 if data.get("unbreakable", false) or cinematic else PureMoves.THROW_TECH_WINDOW
	target.throw_damage = int(data.damage)
	target.crouching = false
	target.push_left = 0
	fighter.push_left = 0
	_reset_combo(target)
	if cinematic:
		finisher_owner = index
	fighter.meter = mini(fighter.meter + PureMoves.METER_GAIN[2], PureMoves.METER_MAX)
	_emit(Ev.THROW, index, 1 - index, move, 3 if cinematic else 2)


# --- hits -------------------------------------------------------------------------------

func _resolve_strikes() -> void:
	var contacts: Array = []
	for i in 2:
		var attacker := pf[i]
		var target := opponent(i)
		if attacker.state != _S.ATTACK:
			continue
		var data := PureMoves.get_move(attacker.legend, attacker.move)
		if not _is_active(attacker, data):
			continue
		if data.grab:
			if attacker.move_hits == 0 and _can_be_thrown(target) \
					and absi(target.x - attacker.x) <= int(data.range):
				contacts.append([i, &"grab"])
			continue
		if attacker.move_hits >= int(data.hits) or attacker.move_rehit_wait > 0:
			continue
		if target.state in _INVULN_STATES or _strike_invulnerable(target):
			continue
		if _overlap(hitbox(attacker), hurtbox(target)):
			contacts.append([i, &"strike", attacker.move])
	# Both throwing on the same tick: a throw tech.
	if contacts.size() == 2 and contacts[0][1] == &"grab" and contacts[1][1] == &"grab":
		_tech(0, 1)
		return
	var grabbed := false
	for contact in contacts:
		if contact[1] == &"grab" and not grabbed:
			var i: int = contact[0]
			_start_throw(i, PureMoves.get_move(pf[i].legend, pf[i].move))
			grabbed = true
	if grabbed:
		return
	for contact in contacts:
		_strike(contact[0], contact[2])


func _strike_invulnerable(target: PureFighter) -> bool:
	if target.state == _S.JUGGLE and target.juggle_points >= JUGGLE_LIMIT:
		return true
	if target.state == _S.BACKDASH and target.state_tick <= BACKDASH_INVULN:
		return true
	if target.state == _S.ATTACK:
		var data := PureMoves.get_move(target.legend, target.move)
		return _in_frames(data.invuln, target.move_tick + 1)
	return false


static func _overlap(a: Array[int], b: Array[int]) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return a[0] <= b[1] and b[0] <= a[1] and a[2] <= b[3] and b[2] <= a[3]


func _strike(index: int, move_id: StringName) -> void:
	var attacker := pf[index]
	var target := opponent(index)
	var data := PureMoves.get_move(attacker.legend, move_id)
	attacker.move_hits += 1
	attacker.move_rehit_wait = int(data.rehit)
	attacker.move_contact = true
	var strength := int(data.strength)
	if target.state == _S.ATTACK:
		var target_move := PureMoves.get_move(target.legend, target.move)
		var frame := target.move_tick + 1
		if _in_frames(target_move.counter, frame):
			_counter_stance(1 - index, index)
			return
		if _in_frames(target_move.armor, frame) and target.armor_left > 0:
			target.armor_left -= 1
			_hurt(target, attacker, int(data.damage) / 2)
			attacker.hitstop = PureMoves.HITSTOP[strength]
			target.hitstop = PureMoves.HITSTOP[strength]
			_emit(Ev.ARMOR, index, 1 - index, move_id, strength)
			if target.health == 0:
				_ko(1 - index, index)
			return
	if _guards(target, attacker, data):
		_block(index, data, move_id)
		return
	if data.kind == &"finisher" and int(data.cinematic) > 0 and attacker.state == _S.ATTACK:
		_start_throw(index, data)
		target.throw_damage = int(data.damage)
		_emit(Ev.FINISHER_HIT, index, 1 - index, move_id, 3)
		return
	_hit(index, data, move_id)


func _guards(target: PureFighter, attacker: PureFighter, data: Dictionary) -> bool:
	if not target.state in _BLOCK_STATES:
		return false
	if target.state == _S.AIR and target.air_attack_used:
		return false
	var away := -signi(attacker.x - target.x)
	if away == 0:
		away = attacker.facing
	var fwd := _dir_forward(target.last_dir)
	var holding_away := fwd * target.facing == away and fwd != 0
	var block_key := (target.held_buttons & (1 << _B.BLOCK)) != 0 and target.facing != away
	if not (holding_away or block_key):
		return false
	var airborne := target.y > 0
	var crouching := _holding_down(target) and not airborne
	match data.guard:
		&"low":
			return crouching
		&"overhead", &"high":
			return not crouching
		&"mid":
			return true
	return false


func _block(index: int, data: Dictionary, move_id: StringName) -> void:
	var attacker := pf[index]
	var target := opponent(index)
	var just := current_tick - target.guard_since <= JUST_DEFEND_WINDOW
	var crouching := _holding_down(target) and target.y == 0
	_set_state(target, _S.BLOCKSTUN)
	target.crouching = crouching
	target.stun_left = maxi(int(data.blockstun) - (4 if just else 0), 1)
	target.push_left = attacker.facing * int(data.push) * 8 / 10
	var strength := int(data.strength)
	attacker.hitstop = PureMoves.BLOCKSTOP[strength]
	target.hitstop = PureMoves.BLOCKSTOP[strength]
	attacker.meter = mini(attacker.meter + PureMoves.METER_GAIN[strength] / 2, PureMoves.METER_MAX)
	target.meter = mini(target.meter + (60 if just else 20), PureMoves.METER_MAX)
	_emit(Ev.JUST_DEFEND if just else Ev.BLOCK, index, 1 - index, move_id, strength)


## Damage scaling per combo hit (percent): 100, 100, then -15 a hit, at least 30.
static func _scale(combo_hit: int) -> int:
	return maxi(100 - 15 * maxi(combo_hit - 2, 0), 30)


func _hit(index: int, data: Dictionary, move_id: StringName) -> void:
	var attacker := pf[index]
	var target := opponent(index)
	var continuing := target.state in [_S.HITSTUN, _S.JUGGLE]
	if not continuing:
		_reset_combo(target)
	var counter := not continuing and target.in_attack_startup()
	var punish := not continuing and not counter and (target.in_attack_recovery()
		or (target.state == _S.LANDING and target.landing_ticks > LANDING_TICKS))
	target.combo_hits += 1
	var damage := int(data.damage) * _scale(target.combo_hits) / 100
	if counter:
		damage = damage * 12 / 10
	elif punish:
		damage = damage * 11 / 10
	_hurt(target, attacker, damage)
	attacker.move_contact_hit = true
	var strength := int(data.strength)
	attacker.meter = mini(attacker.meter + PureMoves.METER_GAIN[strength], PureMoves.METER_MAX)
	attacker.hitstop = PureMoves.HITSTOP[strength] + (4 if counter else 0)
	target.hitstop = attacker.hitstop
	var launch: Array = data.launch
	var airborne := target.y > 0 or target.state == _S.JUGGLE
	var dir := attacker.facing
	var box: Array = data.box
	target.reaction = 1 if int(box[2]) + int(box[3]) < 1100 else 0
	if not launch.is_empty():
		_launch(target, dir, int(launch[0]), int(launch[1]), false)
		target.juggle_points += int(data.juggle)
	elif airborne:
		var reset := target.state != _S.JUGGLE
		_launch(target, dir, 35, 70 if not reset else 55, reset)
		target.juggle_points += int(data.juggle)
	elif data.knockdown:
		_launch(target, dir, 30, 45, false)
	elif data.wall_bounce and not target.wall_bounce_used:
		_launch(target, dir, 115, 55, false)
		target.wall_bounce_pending = true
	elif data.ground_bounce and not target.ground_bounce_used:
		_launch(target, dir, 20, 30, false)
	else:
		var crouching := _holding_down(target) and target.state != _S.ATTACK
		_set_state(target, _S.HITSTUN)
		target.crouching = crouching or target.crouching
		target.stun_left = maxi(int(data.hitstun) - mini(target.combo_hits - 1, 6), 8) \
			+ (4 if counter else 0)
		target.push_left = dir * int(data.push)
	if data.ground_bounce and not target.ground_bounce_used:
		target.ground_bounce_pending = true
	var type := Ev.COUNTER if counter else (Ev.PUNISH if punish else Ev.HIT)
	_emit(type, index, 1 - index, move_id, strength)
	if target.health == 0:
		_ko(1 - index, index)


func _counter_stance(lyra_index: int, attacker_index: int) -> void:
	var lyra := pf[lyra_index]
	var attacker := pf[attacker_index]
	var data := PureMoves.get_move(lyra.legend, lyra.move)
	_reset_combo(attacker)
	attacker.combo_hits = 1
	_hurt(attacker, lyra, int(data.damage))
	lyra.move_contact = true
	lyra.move_contact_hit = true
	lyra.hitstop = PureMoves.HITSTOP[3]
	attacker.hitstop = PureMoves.HITSTOP[3]
	_launch(attacker, lyra.facing, 50, 80, false)
	# The counter kick plays out as the rest of the stance.
	lyra.move_tick = int((data.counter as Array)[1])
	lyra.meter = mini(lyra.meter + PureMoves.METER_GAIN[3], PureMoves.METER_MAX)
	_emit(Ev.COUNTER_STANCE, lyra_index, attacker_index, lyra.move, 3)
	if attacker.health == 0:
		_ko(attacker_index, lyra_index)


func _hurt(target: PureFighter, attacker: PureFighter, damage: int) -> void:
	target.health = maxi(target.health - damage, 0)
	target.combo_damage += damage
	target.meter = mini(target.meter + 15, PureMoves.METER_MAX)
	if attacker != null:
		attacker.meter = mini(attacker.meter, PureMoves.METER_MAX)


func _launch(target: PureFighter, dir: int, vx: int, vy: int, reset: bool) -> void:
	_set_state(target, _S.JUGGLE)
	target.vx = dir * vx
	target.vy = vy
	target.y = maxi(target.y, 1)
	target.juggle_reset = reset
	target.stun_left = 0
	target.push_left = 0
	target.crouching = false


func _reset_combo(fighter: PureFighter) -> void:
	fighter.combo_hits = 0
	fighter.combo_damage = 0
	fighter.juggle_points = 0
	fighter.wall_bounce_used = false
	fighter.ground_bounce_used = false
	fighter.wall_bounce_pending = false
	fighter.ground_bounce_pending = false
	fighter.juggle_reset = false


# --- bodies, rounds ---------------------------------------------------------------------

func _solid(fighter: PureFighter) -> bool:
	if fighter.state in [_S.ROLL, _S.HELD, _S.THROWN]:
		return false
	if fighter.state == _S.ATTACK:
		var data := PureMoves.get_move(fighter.legend, fighter.move)
		return not _in_frames(data.pass_through, fighter.move_tick + 1)
	return true


func _resolve_bodies() -> void:
	var a := pf[0]
	var b := pf[1]
	if _solid(a) and _solid(b):
		var a_top := a.y + (CROUCH_HEIGHT if a.crouching else STAND_HEIGHT)
		var b_top := b.y + (CROUCH_HEIGHT if b.crouching else STAND_HEIGHT)
		var vertical := mini(a_top, b_top) - maxi(a.y, b.y)
		var dx := b.x - a.x
		var gap := body_gap()
		if vertical > 300 and absi(dx) < gap:
			var side := signi(dx)
			if side == 0:
				side = a.facing
			var overlap := gap - absi(dx)
			var a_move := overlap / 2
			var b_move := overlap - a_move
			a.x -= side * a_move
			b.x += side * b_move
			# At a wall the other fighter takes the whole push.
			if absi(a.x) > WALL:
				var over := absi(a.x) - WALL
				a.x = clampi(a.x, -WALL, WALL)
				b.x += side * over
			if absi(b.x) > WALL:
				var over := absi(b.x) - WALL
				b.x = clampi(b.x, -WALL, WALL)
				a.x -= side * over
	var apart := b.x - a.x
	if absi(apart) > MAX_SEPARATION:
		var excess := absi(apart) - MAX_SEPARATION
		var side := signi(apart)
		a.x += side * (excess / 2)
		b.x -= side * (excess - excess / 2)


## Closest the two bodies' centres can get (their pushbox half widths added).
func body_gap() -> int:
	return int(PureMoves.stats(pf[0].legend).body) + int(PureMoves.stats(pf[1].legend).body)


func _check_round_end() -> void:
	if round_over:
		return
	var a := pf[0]
	var b := pf[1]
	if a.health == 0 or b.health == 0:
		return
	if timer_ticks == 0:
		var a_share := a.health * 1000 / a.max_health
		var b_share := b.health * 1000 / b.max_health
		var winner := -1
		if a_share != b_share:
			winner = 0 if a_share > b_share else 1
		_end_round(winner)
		_emit(Ev.TIME_UP, winner, 1 - winner if winner >= 0 else -1)


func _ko(loser: int, winner: int) -> void:
	if round_over:
		return
	var fighter := pf[loser]
	if fighter.state != _S.JUGGLE:
		_launch(fighter, -fighter.facing, 50, 90, false)
	fighter.juggle_reset = false
	fighter.ground_bounce_pending = false
	_emit(Ev.KO, winner, loser)
	_end_round(winner)


func _end_round(winner: int) -> void:
	round_over = true
	round_winner = winner
	phase = Phase.ROUND_END
	phase_tick = 0
	finisher_owner = -1
	if winner >= 0:
		pf[winner].round_wins += 1
		_emit(Ev.ROUND_WIN, winner, 1 - winner)


func _step_phase() -> void:
	if phase != Phase.ROUND_END and phase != Phase.MATCH_OVER:
		return
	if phase_tick == VICTORY_AT:
		for i in 2:
			var fighter := pf[i]
			fighter.hitstop = 0
			fighter.y = 0
			fighter.vy = 0
			fighter.vx = 0
			fighter.push_left = 0
			_face_opponent(i)
			_set_state(fighter, _S.VICTORY if i == round_winner else _S.DEFEAT)
	if phase == Phase.ROUND_END and phase_tick >= ROUND_END_TICKS:
		var champion := -1
		for i in 2:
			if pf[i].round_wins >= ROUNDS_TO_WIN:
				champion = i
		if champion >= 0 or round_number >= MAX_ROUNDS:
			if champion < 0:
				champion = 0 if pf[0].round_wins > pf[1].round_wins else \
					(1 if pf[1].round_wins > pf[0].round_wins else -1)
			match_winner = champion
			phase = Phase.MATCH_OVER
			phase_tick = 0
			_emit(Ev.MATCH_WIN, champion, 1 - champion if champion >= 0 else -1)
		else:
			round_number += 1
			start_round()


func is_match_over() -> bool:
	return phase == Phase.MATCH_OVER


func _emit(type: Ev, attacker: int, target: int, move: StringName = &"", strength := 0) -> void:
	var at := pf[target] if target >= 0 else (pf[attacker] if attacker >= 0 else null)
	events.append({"type": type, "a": attacker, "t": target, "move": move, "strength": strength,
		"x": at.x if at else 0, "y": (at.y + 1100) if at else 0})
