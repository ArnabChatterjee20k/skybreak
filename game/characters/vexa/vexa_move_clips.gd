class_name VexaMoveClips
extends RefCounted
## Vexa's attack clips, posed in code with FigurePoser from her move set: each
## move winds up, strikes its hitbox through the ACTIVE ticks and recovers to
## guard, and lasts exactly the move's total ticks.

const CLIP_PREFIX := "vexa_"
const TICK := 1.0 / 60.0
## Hitbox in the view (facing -Z, origin 1 m up) to the model (facing +Z, feet at 0).
const VIEW_TO_MODEL := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1, 0))

## How each move looks. limb: the striking hand or foot (BothHands strikes with
## both, RightHand leads). windup: where it pulls back to. follow: where it
## travels after the hit, relative to the hitbox. twist/lean in degrees.
const STYLES := {
	&"light_1": {"limb": &"LeftHand", "windup": Vector3(0.2, 1.3, 0.05), "twist": [10, -20], "lean": 6},
	&"light_2": {"limb": &"RightHand", "windup": Vector3(-0.22, 1.28, -0.02), "twist": [-25, 30], "lean": 8},
	&"light_3": {"limb": &"LeftHand", "windup": Vector3(-0.15, 1.35, 0.15), "twist": [45, -40], "lean": 4},
	&"light_4": {"limb": &"RightFoot", "windup": Vector3(-0.15, 0.45, 0.25), "twist": [-10, 15], "lean": -12},
	&"light_5": {"limb": &"BothHands", "windup": Vector3(0.0, 1.2, -0.05), "twist": [0, 0], "lean": 16, "crouch": 0.1},
	&"smash": {"limb": &"RightHand", "windup": Vector3(-0.3, 1.25, -0.2), "twist": [-40, 35], "lean": 15, "crouch": 0.1},
	&"charged_smash_1": {"limb": &"RightHand", "windup": Vector3(0.3, 1.45, -0.15), "twist": [-50, 40], "lean": 12},
	&"charged_smash_2": {"limb": &"RightHand", "windup": Vector3(0.3, 1.5, -0.2), "twist": [-55, 45], "lean": 14},
	&"charged_smash_3": {"limb": &"RightHand", "windup": Vector3(0.35, 1.55, -0.25), "twist": [-60, 50], "lean": 16, "crouch": 0.08},
	&"breaker": {"limb": &"LeftHand", "windup": Vector3(0.25, 1.2, -0.15), "twist": [25, -30], "lean": 22, "crouch": 0.12},
	&"launcher": {"limb": &"LeftHand", "windup": Vector3(0.15, 0.75, 0.3), "follow": Vector3(0, 0.6, -0.2), "twist": [20, -25], "lean": -8, "crouch": 0.18, "strike_crouch": 0.0},
	&"rising": {"limb": &"RightHand", "windup": Vector3(-0.15, 0.8, 0.3), "follow": Vector3(0, 0.5, -0.1), "twist": [-15, 20], "lean": -14, "crouch": 0.2, "strike_crouch": 0.0},
	&"spike": {"limb": &"BothHands", "windup": Vector3(0.0, 2.0, 0.05), "follow": Vector3(0, -0.5, -0.4), "twist": [0, 0], "lean": 20},
	&"sweep": {"limb": &"RightFoot", "windup": Vector3(-0.4, 0.15, -0.3), "follow": Vector3(0.6, 0, -0.5), "twist": [-30, 40], "lean": 10, "crouch": 0.3},
	&"push_block": {"limb": &"BothHands", "windup": Vector3(0.0, 1.25, 0.15), "twist": [0, 0], "lean": 6},
	&"grab": {"limb": &"BothHands", "windup": Vector3(0.0, 1.2, 0.1), "twist": [0, 0], "lean": 12, "crouch": 0.05},
}
## Guard: fists up in front of the chest, feet staggered, a slight crouch.
const GUARD_CROUCH := 0.05
const GUARD_TARGETS := {
	&"LeftHand": Vector3(0.16, 1.3, 0.26),
	&"RightHand": Vector3(-0.14, 1.24, 0.16),
	&"LeftFoot": Vector3(0.15, 0.1, 0.14),
	&"RightFoot": Vector3(-0.15, 0.1, -0.14),
}
## Gap between the two hands of a both-hands strike.
const HAND_GAP := 0.13

static var _cache := {}


## A copy of base whose library also holds Vexa's clip for every move of
## move_set, mapped by move id and timed tick for tick. Built once per pair.
static func clip_set(base: ClipSet, move_set: MoveSet, skeleton: Skeleton3D) -> ClipSet:
	var key := "%s|%s" % [base.resource_path, move_set.resource_path]
	if _cache.has(key) and not base.resource_path.is_empty():
		return _cache[key]
	var clips := base.duplicate() as ClipSet
	clips.library = AnimationLibrary.new()
	for name in base.library.get_animation_list():
		clips.library.add_animation(name, base.library.get_animation(name))
	clips.move_clips = base.move_clips.duplicate()
	clips.impact_windows = base.impact_windows.duplicate()
	var poser := FigurePoser.new(skeleton)
	for move in moves_of(move_set):
		var clip := StringName(CLIP_PREFIX + move.id)
		clips.library.add_animation(clip, bake(poser, move))
		clips.move_clips[move.id] = clip
		clips.impact_windows[clip] = Vector2(move.startup_ticks, move.recovery_start_tick()) * TICK
	_cache[key] = clips
	return clips


## Every move of a set, light string first.
static func moves_of(move_set: MoveSet) -> Array[MoveData]:
	var moves: Array[MoveData] = []
	moves.append_array(move_set.light_string)
	moves.append_array(move_set.charged_smash)
	for move: MoveData in [move_set.smash, move_set.breaker, move_set.launcher, move_set.rising,
			move_set.spike, move_set.sweep, move_set.push_block, move_set.grab]:
		if move:
			moves.append(move)
	return moves


## The bone whose head lands the hit of a move.
static func strike_bone(move_id: StringName) -> StringName:
	var limb: StringName = STYLES.get(move_id, STYLES[&"light_2"]).limb
	return &"RightHand" if limb == &"BothHands" else limb


## Mean of a move's active hitbox centres, in model space.
static func strike_point(move: MoveData) -> Vector3:
	var sum := Vector3.ZERO
	for tick in move.active_ticks:
		sum += move.hitbox_offsets[mini(tick, move.hitbox_offsets.size() - 1)]
	return VIEW_TO_MODEL * (sum / move.active_ticks)


## The keyed clip of one move: guard, wind-up, strike, peak, follow-through, guard.
static func bake(poser: FigurePoser, move: MoveData) -> Animation:
	var style: Dictionary = STYLES.get(move.id, STYLES[&"light_2"])
	var windup: Vector3 = style.windup
	var twist: Array = style.twist
	var turn := deg_to_rad(twist[1])
	var lean := deg_to_rad(style.lean)
	var crouch: float = style.get("crouch", 0.0)
	var strike_crouch: float = style.get("strike_crouch", crouch)
	# Aim at the hitbox, then strike where the limb actually gets to.
	var point := reached_point(poser, style, strike_point(move), turn, lean, strike_crouch)
	var follow: Vector3 = point + Basis(Vector3.UP, PI) * style.get("follow", Vector3(0, -0.2, 0))
	var start := move.startup_ticks
	var active_end := move.recovery_start_tick()
	var wind_tick := maxf(start * 0.55, 1.0)
	var keys := [
		[0.0, _pose(style, Vector3.ZERO, 0.0, 0.0, 0.0)],
		[wind_tick * TICK, _pose(style, windup, deg_to_rad(twist[0]), -lean * 0.3, crouch)],
		[start * TICK, _pose(style, windup.lerp(point, 0.8), turn * 0.8, lean * 0.8, strike_crouch)],
		[(start + move.active_ticks * 0.5) * TICK, _pose(style, point, turn, lean, strike_crouch)],
		[active_end * TICK, _pose(style, point.lerp(follow, 0.5), turn, lean, strike_crouch)],
		[(active_end + move.recovery_ticks * 0.45) * TICK, _pose(style, follow, turn * 0.6, lean * 0.5, strike_crouch * 0.6)],
		[move.total_ticks() * TICK, _pose(style, Vector3.ZERO, 0.0, 0.0, 0.0)],
	]
	return poser.bake(move.total_ticks() * TICK, keys)


## Where the striking limb ends up when it reaches for goal in the strike pose.
static func reached_point(poser: FigurePoser, style: Dictionary, goal: Vector3, twist: float, lean: float,
		crouch: float) -> Vector3:
	var at := poser.positions(_pose(style, goal, twist, lean, crouch))
	if style.limb == &"BothHands":
		return at[&"RightHand"] + Vector3(HAND_GAP, 0, 0)
	return at[style.limb]


## A pose with the striking limb at goal (Vector3.ZERO keeps it at guard).
static func _pose(style: Dictionary, goal: Vector3, twist: float, lean: float, crouch: float) -> Dictionary:
	var targets := GUARD_TARGETS.duplicate()
	var limb: StringName = style.limb
	if goal != Vector3.ZERO:
		if limb == &"BothHands":
			targets[&"LeftHand"] = goal + Vector3(HAND_GAP, 0, 0)
			targets[&"RightHand"] = goal - Vector3(HAND_GAP, 0, 0)
		else:
			targets[limb] = goal
	return {"crouch": GUARD_CROUCH + crouch, "twist": twist, "lean": lean, "targets": targets}
