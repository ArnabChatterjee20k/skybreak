class_name BodySeparation
extends RefCounted
## Keeps drawn bodies out of each other (#73). The sim pushboxes keep the fighters' roots
## apart, but attack clips lunge the drawn chest and head past them, into the victim. Each
## frame this measures the core capsules as last drawn (BodyCapsules) and eases the overlapping
## fighters' views apart, the striker more. View only: the sim never sees it.

## Core body parts that never meet another fighter's core (as VisualQa checks them).
const CORE: Array[StringName] = [&"pelvis", &"chest", &"head", &"thigh_l", &"thigh_r"]
## Pairs further apart than this (m) are not measured.
const NEAR := 3.0
## Kept between cores (m), so a pose change within a frame doesn't touch.
const MARGIN := 0.06
## Pushes lead the measured overlap by this factor: the poses are a frame old and lunges keep coming.
const LEAD := 1.4
## Largest offset (m) a view takes.
const MAX_OFFSET := 1.2
## Offsets ease back to the sim position at this rate (1/s) once nothing overlaps.
const RETURN_RATE := 4.0
## Share of a push the striker takes when only one of the pair is attacking.
const STRIKER_SHARE := 0.75

var views: Array[FighterView] = []
var offsets: Array[Vector3] = []
var _bodies: Array = []
var _poses: Array = []
var _skeletons: Array[Skeleton3D] = []


func setup(fighter_views: Array[FighterView]) -> void:
	views = fighter_views
	offsets.resize(views.size())
	offsets.fill(Vector3.ZERO)
	_bodies.resize(views.size())
	_poses.resize(views.size())
	_skeletons.resize(views.size())
	for i in views.size():
		var character := views[i].find_children("*", "CharacterView", true, false)
		var body: BodyCapsules = null
		if not character.is_empty():
			body = (character[0] as CharacterView).body
		_bodies[i] = body
		var poses: Array[Transform3D] = []
		_poses[i] = poses
		var skeleton := _skeleton_of(views[i])
		_skeletons[i] = skeleton
		if skeleton != null and body != null:
			skeleton.skeleton_updated.connect(_snapshot.bind(skeleton, poses))


## Updates every view's offset from the poses drawn last frame; call before the views present.
func update(sim: CombatSim, delta: float) -> void:
	var cores := _cores()
	var pushes: Array[Vector3] = []
	pushes.resize(views.size())
	pushes.fill(Vector3.ZERO)
	var pushed: Array[bool] = []
	pushed.resize(views.size())
	pushed.fill(false)
	for i in views.size():
		for j in range(i + 1, views.size()):
			if (cores[i] as Dictionary).is_empty() or (cores[j] as Dictionary).is_empty():
				continue
			var one := sim.fighters[i]
			var two := sim.fighters[j]
			if pair_exempt(one, two, i, j) or one.position.distance_to(two.position) > NEAR:
				continue
			var depth := _deepest(cores[i], cores[j]) + MARGIN
			if depth <= 0.0:
				continue
			var away := views[i].position - views[j].position
			away.y = 0.0
			if away.length_squared() < 1.0e-6:
				away = DetMath.forward(two.facing_yaw)
			away = away.normalized()
			var share := 0.5
			if striking(one) and not striking(two):
				share = STRIKER_SHARE
			elif striking(two) and not striking(one):
				share = 1.0 - STRIKER_SHARE
			pushes[i] += away * depth * share
			pushes[j] -= away * depth * (1.0 - share)
			pushed[i] = true
			pushed[j] = true
	for i in views.size():
		if pushed[i]:
			offsets[i] = (offsets[i] + pushes[i] * LEAD).limit_length(MAX_OFFSET)
		else:
			offsets[i] = offsets[i].move_toward(Vector3.ZERO, offsets[i].length() * minf(RETURN_RATE * delta, 1.0))
		if not sim.fighters[i].is_ko_state() and views[i].visible:
			views[i].body_offset = offsets[i]
		else:
			offsets[i] = Vector3.ZERO
			views[i].body_offset = Vector3.ZERO


## Whether a pair is never pushed: vanishing, or a grab pair mid-throw.
static func pair_exempt(one: FighterState, two: FighterState, i: int, j: int) -> bool:
	if one.state == FighterState.State.VANISHING or two.state == FighterState.State.VANISHING:
		return true
	var grabbing := [FighterState.State.GRABBED, FighterState.State.THROWING]
	return (one.state in grabbing and one.grab_partner == j) or (two.state in grabbing and two.grab_partner == i)


## Whether a fighter is mid-attack (startup, active or recovery).
static func striking(fighter: FighterState) -> bool:
	return fighter.state == FighterState.State.ATTACKING and fighter.attack_phase() in [
		FighterState.AttackPhase.STARTUP, FighterState.AttackPhase.ACTIVE, FighterState.AttackPhase.RECOVERY]


func _cores() -> Array:
	var out := []
	for i in views.size():
		var body: BodyCapsules = _bodies[i]
		var drawn: Array[Transform3D] = _poses[i]
		var skeleton := _skeletons[i]
		if body == null or drawn.is_empty() or skeleton == null or not views[i].visible:
			out.append({})
			continue
		out.append(body.capsules(func(bone: int) -> Transform3D: return drawn[bone], skeleton.global_transform, CORE))
	return out


## Deepest overlap (m) between two sets of capsules; negative when apart.
static func _deepest(first: Dictionary, second: Dictionary) -> float:
	var deepest := -INF
	for a: StringName in first:
		for b: StringName in second:
			deepest = maxf(deepest, BodyCapsules.capsule_depth(first[a], second[b]))
	return deepest


func _snapshot(skeleton: Skeleton3D, poses: Array[Transform3D]) -> void:
	poses.resize(skeleton.get_bone_count())
	for bone in poses.size():
		poses[bone] = skeleton.get_bone_global_pose(bone)


static func _skeleton_of(view: Node) -> Skeleton3D:
	var found := view.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
