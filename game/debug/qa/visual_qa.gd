class_name VisualQa
extends Node
## Geometric visual QA (T-D30): runs a seeded bot match in a zone match with all four
## legends and weapons forced on, and measures every frame: feet on the drawn ground,
## held weapons out of their holder's body, bodies out of each other, bow strings beside
## the face. Add it to the tree, then await run().

## Tolerances (m).
const GROUND_TOLERANCE := 0.05
const OVERLAP_TOLERANCE := 0.02
## Ticks a forced weapon stays in hand before the next one.
const WEAPON_EVERY := 150
const CHECKS: Array[StringName] = [&"ground_contact", &"weapon_vs_holder", &"fighter_vs_fighter", &"bow_vs_head"]
## Fighter-vs-fighter is pending until pushboxes (T-D29) are on main.
const PENDING: Array[StringName] = [&"fighter_vs_fighter"]
const GROUNDED_STATES: Array[int] = [FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.BLOCKING]
const EXEMPT_STATES: Array[int] = [FighterState.State.VANISHING, FighterState.State.GRABBED,
	FighterState.State.THROWING]

var zone := &"heartbloom_gardens"
var ticks := 3600
var seed_value := 1
## Legend order; rotated by the seed so every legend meets every slot across runs.
var legends: Array[StringName] = [&"kael", &"vexa", &"lyra", &"brann"]

## Check -> violations; check -> worst value (m); worst frames [{check, tick, value, fighter}].
var violations := {}
var worst := {}
## Check -> frames measured.
var samples := {}
var worst_frames: Array = []
var frames := 0
var match_node: ZoneMatch
var ground: RenderedGround
var _bodies: Array[BodyCapsules] = []
## Per fighter: bone global poses as drawn, snapshotted when the skeleton finishes its modifiers.
var _poses: Array = []


func run() -> void:
	for check in CHECKS:
		violations[check] = 0
		worst[check] = -INF
		samples[check] = 0
	match_node = load("res://game/levels/zone_match.tscn").instantiate()
	var fighters := []
	for i in legends.size():
		var legend := legends[(i + seed_value) % legends.size()]
		fighters.append({"character": legend, "team": i, "is_ai": true, "ai_level": 3})
	match_node.configure({"zone": zone, "fighters": fighters, "rounds": 99})
	add_child(match_node)
	match_node.set_process(false)
	match_node.set_physics_process(false)
	match_node.sim.rng.seed = seed_value
	ground = RenderedGround.of(match_node.world)
	for view in match_node.fighter_views:
		var character := view.find_children("*", "CharacterView", true, false)
		var body: BodyCapsules = null
		if not character.is_empty():
			var view_node := character[0] as CharacterView
			body = view_node.get("body") if view_node.get("body") != null else BodyCapsules.measure(
				view_node.model.get_node("%GeneralSkeleton"), view_node.find_children("*", "MeshInstance3D", true, false))
		_bodies.append(body)
		var poses: Array[Transform3D] = []
		_poses.append(poses)
		var skeleton := _skeleton_of(view)
		if skeleton != null:
			skeleton.skeleton_updated.connect(_snapshot.bind(skeleton, poses))
	await get_tree().process_frame
	for tick in ticks:
		_force_weapons(tick)
		match_node.step_tick()
		match_node.present_frame(1.0, 1.0 / 60.0)
		# Skeleton modifiers run at the end of the frame; measure the finished pose.
		await get_tree().process_frame
		_measure(tick)
	match_node.queue_free()


## Failing violation count (pending checks excluded).
func failures() -> int:
	var total := 0
	for check in CHECKS:
		if not PENDING.has(check):
			total += int(violations[check])
	return total


func summary() -> String:
	var lines := PackedStringArray()
	for check in CHECKS:
		lines.append("%s %s: %d violations in %d samples, worst %.3f m%s" % [zone, check, violations[check],
			samples[check], worst[check],
			" (pending T-D29)" if PENDING.has(check) else ""])
	return "\n".join(lines)


func _force_weapons(tick: int) -> void:
	var kinds: Array = Weapon.Kind.values().slice(1)
	for i in match_node.sim.fighters.size():
		var fighter := match_node.sim.fighters[i]
		var kind: Weapon.Kind = kinds[(tick / WEAPON_EVERY + i * 3) % kinds.size()]
		if fighter.held_weapon() != kind and fighter.state != FighterState.State.ATTACKING:
			fighter.weapons[0] = kind
			fighter.ammo[0] = Weapon.full_ammo(kind)
			fighter.active_slot = 0


func _measure(tick: int) -> void:
	frames += 1
	var sim := match_node.sim
	var capsules: Array = []
	for i in sim.fighters.size():
		var view := match_node.fighter_views[i]
		var skeleton := _skeleton_of(view)
		var body := _bodies[i]
		if skeleton == null or body == null or not view.visible:
			capsules.append({})
			continue
		# Bone poses after the modifiers (IK), as skinned and drawn; the skeleton restores the clip pose after.
		var drawn: Array[Transform3D] = _poses[i]
		if drawn.is_empty():
			capsules.append({})
			continue
		var pose := func(bone: int) -> Transform3D: return drawn[bone]
		var space := skeleton.global_transform
		var all := body.capsules(pose, space)
		capsules.append(all)
		var fighter := sim.fighters[i]
		# Ground contact.
		if fighter.state in GROUNDED_STATES and fighter.position.y <= fighter.stand_height + 0.01:
			var sole := body.lowest_sole(pose, space)
			var gap := sole.y - ground.height_at(sole.x, sole.z, sole.y)
			_record(&"ground_contact", absf(gap) > GROUND_TOLERANCE, gap, tick, i, {
				"state": FighterState.State.find_key(fighter.state), "state_ticks": fighter.state_ticks,
				"sole": sole, "sim_floor": fighter.stand_height - sim.tuning.ground_height,
				"drawn_centre": ground.height_at(fighter.position.x, fighter.position.z, sole.y)})
		# Weapon vs holder.
		var models: Array[Node3D] = _held_models(i)
		var kind := fighter.held_weapon()
		if not models.is_empty() and WeaponGrip.hands_of(kind).size() == 1:
			var boxes: Array[Transform3D] = []
			for model in models:
				for box in WeaponGrip.part_boxes(model):
					boxes.append(model.global_transform * box)
			var names: Array = MotionLayers.CLEAR_OF[WeaponGrip.hands_of(kind)[0]]
			if WeaponGrip.off_hand_of(kind) != Vector3.INF:
				names = names.filter(func(n: StringName) -> bool: return not n.begins_with("lower_arm"))
			var subset := {}
			for name in names:
				if all.has(name):
					subset[name] = all[name]
			var hit := BodyCapsules.deepest_box(subset, boxes)
			_record(&"weapon_vs_holder", float(hit[0]) > OVERLAP_TOLERANCE, float(hit[0]), tick, i, {
				"kind": Weapon.Kind.find_key(kind), "state": FighterState.State.find_key(fighter.state),
				"move": fighter.move_id(), "capsule": hit[2]})
		# Bow string and arrow vs the head.
		var string: BowString = match_node.weapon_layer.call("bow_string_of", i) if match_node.weapon_layer.has_method("bow_string_of") else null
		if string != null and all.has(&"head") and string.drawn:
			var head: Array = all[&"head"]
			var depth := maxf(BodyCapsules.segment_depth(string.tip_top, string.nock, head),
				maxf(BodyCapsules.segment_depth(string.nock, string.tip_bottom, head),
				BodyCapsules.segment_depth(string.nock, string.arrow_tip, head)))
			_record(&"bow_vs_head", depth > 0.0, depth, tick, i, {"kind": Weapon.Kind.find_key(kind),
				"move": fighter.move_id(), "move_tick": fighter.move_tick, "phase": fighter.attack_phase(),
				"parts": [BodyCapsules.segment_depth(string.tip_top, string.nock, head),
					BodyCapsules.segment_depth(string.nock, string.tip_bottom, head),
					BodyCapsules.segment_depth(string.nock, string.arrow_tip, head)]})
	# Fighter vs fighter.
	for i in capsules.size():
		for j in range(i + 1, capsules.size()):
			if (capsules[i] as Dictionary).is_empty() or (capsules[j] as Dictionary).is_empty():
				continue
			if sim.fighters[i].state in EXEMPT_STATES or sim.fighters[j].state in EXEMPT_STATES:
				continue
			if sim.fighters[i].position.distance_to(sim.fighters[j].position) > 4.0:
				continue
			var deepest := -INF
			for a: Array in (capsules[i] as Dictionary).values():
				for b: Array in (capsules[j] as Dictionary).values():
					deepest = maxf(deepest, BodyCapsules.capsule_depth(a, b))
			_record(&"fighter_vs_fighter", deepest > OVERLAP_TOLERANCE, deepest, tick, i)


func _snapshot(skeleton: Skeleton3D, poses: Array[Transform3D]) -> void:
	poses.resize(skeleton.get_bone_count())
	for bone in poses.size():
		poses[bone] = skeleton.get_bone_global_pose(bone)


func _record(check: StringName, violated: bool, value: float, tick: int, fighter: int, info := {}) -> void:
	samples[check] = int(samples[check]) + 1
	# Ground gaps count both ways; overlaps only inward.
	var size := absf(value) if check == &"ground_contact" else value
	if size > float(worst[check]):
		worst[check] = size
	if not violated:
		return
	violations[check] = int(violations[check]) + 1
	var frame := {"check": check, "tick": tick, "value": value, "fighter": fighter,
		"legend": _legend(fighter)}
	frame.merge(info)
	worst_frames.append(frame)


func _legend(fighter: int) -> StringName:
	return legends[(fighter + seed_value) % legends.size()]


## Held weapon models of fighter i: the first child of each hand attachment.
func _held_models(i: int) -> Array[Node3D]:
	var models: Array[Node3D] = []
	for node: Node in match_node.weapon_layer._held[i].nodes:
		if is_instance_valid(node) and node.get_child_count() > 0:
			models.append(node.get_child(0) as Node3D)
	return models


static func _skeleton_of(view: Node) -> Skeleton3D:
	var found := view.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
