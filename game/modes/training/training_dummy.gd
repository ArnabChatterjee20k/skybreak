class_name TrainingDummy
extends RefCounted
## The training dummy's brain: one FighterInput per tick for a chosen
## behaviour, read from sim state only. Its own seeded rng (not the sim's)
## drives random block, so the sim stays untouched by training choices.

enum Mode {
	STAND, ## Does nothing; knocked into the air, it settles back on the floor.
	CROUCH, ## Holds descend: hugs the floor.
	JUMP, ## Hops up into the air and drops back down, over and over.
	FLY, ## Hovers a few metres up.
	BLOCK_ALL, ## Holds block all the time.
	BLOCK_AFTER_FIRST_HIT, ## Takes the first hit, then blocks until the pressure stops.
	RANDOM_BLOCK, ## Rolls between the attacker's strings whether to guard the next one.
	PERFECT_BLOCK, ## Taps block just before every strike lands.
	TECH, ## Breaks every grab.
	PLAYBACK, ## Plays the recorded input loop.
}

const MODE_NAMES := {
	Mode.STAND: "Stand",
	Mode.CROUCH: "Crouch",
	Mode.JUMP: "Jump",
	Mode.FLY: "Fly",
	Mode.BLOCK_ALL: "Block all",
	Mode.BLOCK_AFTER_FIRST_HIT: "Block after first hit",
	Mode.RANDOM_BLOCK: "Random block",
	Mode.PERFECT_BLOCK: "Perfect block",
	Mode.TECH: "Tech grabs",
	Mode.PLAYBACK: "Playback recording",
}

## Ticks a jump climbs before dropping back down.
const JUMP_CLIMB_TICKS := 14
## Ticks a jump waits on the floor before the next one.
const JUMP_REST_TICKS := 30
## Height above the floor the flying dummy hovers at, metres.
const FLY_HEIGHT := 4.0
## After its last hit or block, the dummy keeps its guard up this long.
const GUARD_HOLD_TICKS := 40
## Ticks before a strike's first active tick that the perfect-block tap comes.
const PERFECT_BLOCK_LEAD := 3

var mode: Mode = Mode.STAND
## Loop played in PLAYBACK.
var input_loop: InputLoop
## Chance (0..1) random block guards a move.
var block_chance := 0.5

var _rng := RandomNumberGenerator.new()
var _previous := FighterInput.new()
var _jump_ticks := 0
var _guard_hold := 0
var _seen_move: MoveData
var _seen_move_tick := -1
var _block_this_move := false
var _attacker_was_attacking := false
var _tapped_this_move := false


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


## Forgets everything it was tracking (after a mode change or a reset).
func reset() -> void:
	_previous = FighterInput.new()
	_jump_ticks = 0
	_guard_hold = 0
	_seen_move = null
	_seen_move_tick = -1
	_block_this_move = _rng.randf() < block_chance
	_attacker_was_attacking = false
	_tapped_this_move = false
	if input_loop:
		input_loop.rewind()


## The dummy's input for the coming tick; attacker is the fighter it plays against.
func input_for(sim: CombatSim, dummy_index: int, attacker_index: int) -> FighterInput:
	var dummy := sim.fighters[dummy_index]
	var attacker := sim.fighters[attacker_index]
	_track_attacker(attacker)
	var held := 0
	var vertical := 0
	match mode:
		Mode.STAND:
			# Knocked into the air, it floats back down to the floor.
			if dummy.position.y > sim.tuning.ground_height + 0.01:
				vertical = -1
		Mode.CROUCH:
			vertical = -1
		Mode.JUMP:
			vertical = _jump(sim, dummy)
		Mode.FLY:
			var height := dummy.position.y - sim.tuning.ground_height
			vertical = 1 if height < FLY_HEIGHT else 0
		Mode.BLOCK_ALL:
			held |= FighterInput.Action.BLOCK
		Mode.BLOCK_AFTER_FIRST_HIT:
			if dummy.state in [FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN]:
				_guard_hold = GUARD_HOLD_TICKS
			elif attacker.state == FighterState.State.ATTACKING and _guard_hold > 0:
				_guard_hold = GUARD_HOLD_TICKS
			else:
				_guard_hold = maxi(_guard_hold - 1, 0)
			if _guard_hold > 0:
				held |= FighterInput.Action.BLOCK
		Mode.RANDOM_BLOCK:
			# The guard goes up (or not) between strings, never as a perfect-block tap.
			if attacker.state != FighterState.State.ATTACKING and _attacker_was_attacking:
				_block_this_move = _rng.randf() < block_chance
			if _block_this_move:
				held |= FighterInput.Action.BLOCK
		Mode.PERFECT_BLOCK:
			if _should_tap_perfect_block(attacker):
				_tapped_this_move = true
				held |= FighterInput.Action.BLOCK
		Mode.TECH:
			if dummy.state == FighterState.State.GRABBED and not _previous.is_held(FighterInput.Action.GRAB):
				held |= FighterInput.Action.GRAB
		Mode.PLAYBACK:
			if input_loop and input_loop.has_recording():
				var played := input_loop.play_next(_previous)
				_previous = played
				return played
	var input := FighterInput.from_held(held, _previous)
	input.vertical = vertical
	_previous = input
	return input


## Notices a new attacker move (a fresh move, or the same one restarted) and the end of its attacks.
func _track_attacker(attacker: FighterState) -> void:
	_attacker_was_attacking = _seen_move != null
	if attacker.state != FighterState.State.ATTACKING or attacker.move == null:
		_seen_move = null
		_seen_move_tick = -1
		return
	if attacker.move != _seen_move or attacker.move_tick < _seen_move_tick:
		_tapped_this_move = false
	_seen_move = attacker.move
	_seen_move_tick = attacker.move_tick


func _should_tap_perfect_block(attacker: FighterState) -> bool:
	if _tapped_this_move or attacker.state != FighterState.State.ATTACKING or attacker.holding_charge:
		return false
	var move := attacker.move
	if move.kind != MoveData.Kind.STRIKE:
		return false
	# The attacker's move_tick goes up by one before hits resolve this tick.
	return move.startup_ticks - attacker.move_tick == PERFECT_BLOCK_LEAD


## Climb for JUMP_CLIMB_TICKS, fall back to the floor, rest JUMP_REST_TICKS, repeat.
func _jump(sim: CombatSim, dummy: FighterState) -> int:
	var on_floor := dummy.position.y <= sim.tuning.ground_height + 0.01
	_jump_ticks += 1
	if _jump_ticks <= JUMP_CLIMB_TICKS:
		return 1
	if _jump_ticks == JUMP_CLIMB_TICKS + 1 and not on_floor:
		# Falling: hold the count here until the floor.
		_jump_ticks = JUMP_CLIMB_TICKS
		return -1
	if _jump_ticks >= JUMP_CLIMB_TICKS + JUMP_REST_TICKS:
		_jump_ticks = 0
	return 0
