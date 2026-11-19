class_name MotionClips
extends RefCounted
## Runtime additions to the MotionLibrary for the takes mocap lacks, plus strike impact windows.
## Each derived clip is a base take with authored overlays layered on top (model-frame rotations,
## hips offsets), then two-bone IK keeps the planted feet where the base take had them and moves
## the striking limb to its new target:
## - launcher_up: the hooking straight turned into a crouch-and-rise uppercut.
## - sweep_low: the mirrored roundhouse dropped into a deep crouch with the foot along the floor.
## - hit_stagger: the light flinch, stretched, with the torso snapping back and the head whipping.
## - light_1..3: the mocap jabs with a 2-3 tick shoulder load inside startup (anticipation).
## - get_up_full: the get-up take, then a rise all the way to the fighting stance.
## - turn_step: turn_in_place with its body yaw taken out, so only the stepping feet show.
## fit_strike() retimes (and mirrors, for the other hand) a take onto another character's move, so
## the strike lands on that move's hitbox mid-active (Vexa, Lyra, Brann).
## All rigs share the profile's rest rotations, so clips built on one skeleton drive both.

const FPS := 60.0
const SKELETON := "%GeneralSkeleton"
const KAEL_MOVES := "res://game/combat/moves/kael/kael_move_set.tres"
## Derived clip -> [base clip, strike move id or "" for a reaction].
const DERIVED := {
	&"launcher_up": [&"launcher", &"launcher"],
	&"sweep_low": [&"sweep", &"sweep"],
	&"hit_stagger": [&"hit_light", &""],
}
## Jab -> chest yaw (degrees) of its shoulder load: the punching shoulder pulls back first.
const JABS := {&"light_1": 14.0, &"light_2": -22.0, &"light_3": 12.0}
## Get-up: share of the tech take used (from where the body starts to rise), and the seconds of the
## final rise from the take's crouch to the stance.
const RISE_FROM := 0.4
const RISE_SECONDS := 0.4
## Fitted strikes: the reach correction never moves the strike path further than this (m).
const MAX_FIT_SHIFT := 0.7
## Fitted strikes: how far the limb draws back in startup and drives through the target (m).
const FIT_WINDUP := 0.16
const FIT_APPROACH := 0.07
const FIT_FOLLOW := 0.17
## Sweep: extra turn (degrees) of the kicking foot's arc after the hit, by phase.
const SWEEP_FOLLOW := [[0.0, 0.0], [2.0, 0.0], [2.45, -40.0], [3.0, 0.0]]
## Hips height keys are stored divided by the rig's motion scale (Kael's).
const MOTION_SCALE := 0.8
## Gap between the two hands of a both-hands strike (m).
const HAND_GAP := 0.13

static var _cache := {}


## The library plus the derived clips, built once per library.
static func build(source: MotionLibrary, skeleton: Skeleton3D) -> MotionLibrary:
	if _cache.has(source):
		return _cache[source]
	var library := MotionLibrary.new()
	for clip in source.get_animation_list():
		library.add_animation(clip, source.get_animation(clip))
	library.root_motion = source.root_motion.duplicate()
	library.foot_contacts = source.foot_contacts.duplicate()
	library.strike_bones = source.strike_bones.duplicate()
	library.clip_sources = source.clip_sources.duplicate()
	var rig := Rig.new(skeleton)
	var windows := impact_windows(source)
	library.add_animation(&"launcher_up", _launcher(source.get_animation(&"launcher"), rig, windows[&"launcher"]))
	library.add_animation(&"sweep_low", _sweep(source.get_animation(&"sweep"), rig, windows[&"sweep"]))
	library.add_animation(&"hit_stagger", _stagger(source.get_animation(&"hit_light"), rig))
	for jab: StringName in JABS:
		library.remove_animation(jab)
		library.add_animation(jab, _jab(source.get_animation(jab), rig, windows[jab], JABS[jab]))
	library.add_animation(&"get_up_full", _rise(source.get_animation(&"tech"), source.get_animation(&"fight_idle"), rig))
	library.add_animation(&"turn_step", _turn_step(source.get_animation(&"turn_in_place"), rig))
	library.foot_contacts[&"get_up_full"] = source.foot_contacts.get(&"tech", PackedByteArray())
	library.root_motion[&"get_up_full"] = PackedVector3Array()
	library.root_motion[&"turn_step"] = PackedVector3Array()
	library.clip_sources[&"get_up_full"] = "derived from tech + fight_idle"
	library.clip_sources[&"turn_step"] = "derived from turn_in_place"
	for clip: StringName in DERIVED:
		var base: StringName = DERIVED[clip][0]
		library.foot_contacts[clip] = source.foot_contacts.get(base, PackedByteArray())
		library.root_motion[clip] = PackedVector3Array()
		if source.strike_bones.has(base):
			library.strike_bones[clip] = source.strike_bones[base]
		library.clip_sources[clip] = "derived from %s (%s)" % [base, source.clip_sources.get(base, "")]
	rig.free_layers()
	_cache[source] = library
	return library


## The library with its hips heights rescaled for a rig whose legs differ from Kael's, so the
## feet stay on the floor (the stored heights are Kael's, divided by his motion scale).
static func for_skeleton(library: MotionLibrary, skeleton: Skeleton3D) -> MotionLibrary:
	var factor := snappedf(stance_hips_factor(library, skeleton), 0.01)
	if absf(factor - 1.0) < 0.005:
		return library
	var key := [library, snappedf(factor, 0.01)]
	if _cache.has(key):
		return _cache[key]
	var scaled := library.duplicate() as MotionLibrary
	for clip in library.get_animation_list():
		var animation := library.get_animation(clip).duplicate(true) as Animation
		var track := animation.find_track(NodePath("%s:Hips" % SKELETON), Animation.TYPE_POSITION_3D)
		if track >= 0:
			for k in animation.track_get_key_count(track):
				var value: Vector3 = animation.track_get_key_value(track, k)
				animation.track_set_key_value(track, k, Vector3(value.x * factor, value.y * factor, value.z * factor))
		scaled.remove_animation(clip)
		scaled.add_animation(clip, animation)
	_cache[key] = scaled
	return scaled


## Fit specs for a character's posed moves: move id -> {base, move, limbs, target}, for every move
## whose motion_moves entry is "fit" (the slot's own take) or "fit:<take>".
static func fit_specs(moves: Array[MoveData], styles: Dictionary, strike_point: Callable,
		overrides: Dictionary) -> Dictionary:
	var specs := {}
	for move in moves:
		var wanted := String(overrides.get(move.id, &""))
		if not wanted.begins_with("fit"):
			continue
		var limb: StringName = (styles.get(move.id, {}) as Dictionary).get("limb", &"RightHand")
		var limbs: Array = [&"RightHand", &"LeftHand"] if limb == &"BothHands" else [limb]
		var base: StringName = StringName(wanted.get_slice(":", 1)) if wanted.contains(":") \
			else MotionSlots.MOVES.get(move.id, &"light_2")
		specs[move.id] = {"base": base, "move": move, "limbs": limbs, "target": strike_point.call(move)}
	return specs


## The library plus one fitted clip per spec ("fit_<move id>"), built once per character.
## The take is mirrored when it strikes with the other side, and swapped for a punch or a kick
## when it strikes with the other kind of limb.
static func fitted(library: MotionLibrary, skeleton: Skeleton3D, specs: Dictionary, key: String) -> MotionLibrary:
	if specs.is_empty():
		return library
	var cache_key := [library, key]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var out := library.duplicate() as MotionLibrary
	out.clip_sources = library.clip_sources.duplicate()
	out.root_motion = library.root_motion.duplicate()
	var rig := Rig.new(skeleton)
	var mirrors := {}
	for id: StringName in specs:
		var spec: Dictionary = specs[id]
		var limb: StringName = spec.limbs[0]
		var base: StringName = spec.base
		var strike := String(library.strike_bones.get(base, ""))
		var foot := String(limb).ends_with("Foot")
		if strike != "" and strike.ends_with("Toes") != foot:
			base = &"light_4" if foot else &"light_2"
			strike = String(library.strike_bones.get(base, ""))
		var animation := library.get_animation(base)
		if strike != "" and strike.begins_with("Left") != String(limb).begins_with("Left"):
			if not mirrors.has(base):
				mirrors[base] = mirror(animation, rig)
			animation = mirrors[base]
		var clip := StringName("fit_%s" % id)
		out.add_animation(clip, fit_strike(animation, rig, spec.move, spec.limbs, spec.target))
		out.clip_sources[clip] = "fitted from %s%s" % [base, " (mirrored)" if mirrors.has(base) and animation == mirrors[base] else ""]
		out.root_motion[clip] = PackedVector3Array()
	rig.free_layers()
	_cache[cache_key] = out
	return out


## Hips scale that puts the fighting stance's lower ankle at its rest height on this rig.
static func stance_hips_factor(library: MotionLibrary, skeleton: Skeleton3D) -> float:
	var animation := library.get_animation(&"fight_idle")
	var rig := Rig.new(skeleton)
	var rotations := rig.rest_rotations()
	for track in animation.get_track_count():
		var bone := StringName(String(animation.track_get_path(track)).get_slice(":", 1))
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D and rig.index.has(bone):
			rotations[rig.index[bone]] = animation.rotation_track_interpolate(track, 0.0)
	var hips_track := animation.find_track(NodePath("%s:Hips" % SKELETON), Animation.TYPE_POSITION_3D)
	var hips: Vector3 = animation.position_track_interpolate(hips_track, 0.0) * skeleton.motion_scale
	var world := rig.world(rotations, hips)
	var rest_world := rig.world(rig.rest_rotations(), skeleton.get_bone_rest(rig.index[&"Hips"]).origin)
	var foot: int = rig.index[&"LeftFoot"]
	var ankle := minf((world[foot] as Transform3D).origin.y, (world[rig.index[&"RightFoot"]] as Transform3D).origin.y)
	var rest_ankle := (rest_world[foot] as Transform3D).origin.y
	rig.free_layers()
	return (hips.y - (ankle - rest_ankle)) / hips.y


## Strike clip -> Vector2(active start, active end) in seconds. The mocap strikes are timed tick
## for tick to Kael's moves, so the windows are those moves' active ticks.
static func impact_windows(library: AnimationLibrary) -> Dictionary[StringName, Vector2]:
	var windows: Dictionary[StringName, Vector2] = {}
	var moves := load(KAEL_MOVES) as MoveSet
	var all: Array[MoveData] = []
	all.append_array(moves.light_string)
	all.append_array(moves.charged_smash)
	for move: MoveData in [moves.smash, moves.breaker, moves.launcher, moves.rising, moves.spike,
			moves.sweep, moves.push_block]:
		all.append(move)
	for move in all:
		windows[move.id] = Vector2(move.startup_ticks / FPS, move.recovery_start_tick() / FPS)
	windows[&"launcher_up"] = windows[&"launcher"]
	windows[&"sweep_low"] = windows[&"sweep"]
	return windows


# --- Derived clips -------------------------------------------------------------------------------

## Phase time: 0..1 startup, 1..2 active, 2..3 recovery.
static func _phase(t: float, window: Vector2, length: float) -> float:
	if t < window.x:
		return t / window.x
	if t < window.y:
		return 1.0 + (t - window.x) / (window.y - window.x)
	return 2.0 + (t - window.y) / maxf(length - window.y, 0.001)


static func _launcher(base: Animation, rig: Rig, window: Vector2) -> Animation:
	var overlay := {
		# Load low and twist the right side back, then drive up through the legs and arch back.
		&"Hips": [[0.0, Vector3.ZERO], [0.75, Vector3(12, -14, 0)], [1.3, Vector3(-6, 18, 0)],
			[2.3, Vector3(-12, 10, 0)], [3.0, Vector3.ZERO]],
		&"Chest": [[0.0, Vector3.ZERO], [0.75, Vector3(10, -12, 0)], [1.4, Vector3(-10, 14, 0)],
			[2.4, Vector3(-14, 6, 0)], [3.0, Vector3.ZERO]],
		&"Head": [[0.0, Vector3.ZERO], [1.3, Vector3(-10, 0, 0)], [3.0, Vector3.ZERO]],
		&"LeftUpperArm": [[0.0, Vector3.ZERO], [1.2, Vector3(20, 0, -10)], [3.0, Vector3.ZERO]],
	}
	var hips := [[0.0, 0.0], [0.8, -0.13], [1.25, 0.03], [2.2, 0.05], [3.0, 0.0]]
	# Right fist: drops to the hip in the wind-up, rips up the centre line through the active ticks.
	var hand := [[0.0, Vector3.ZERO], [0.8, Vector3(0.05, -0.32, -0.05)], [1.0, Vector3(0.03, -0.05, 0.05)],
		[1.5, Vector3(0.02, 0.22, 0.02)], [2.3, Vector3(0.0, 0.3, -0.05)], [3.0, Vector3.ZERO]]
	var out := _derive(base, rig, func(t: float) -> float: return _phase(t, window, base.length),
		overlay, hips, {&"RightHand": hand}, [])
	# Soften the IK corners outside the strike itself (less jerk, same arc).
	return smooth(out, 2, window)


static func _sweep(base: Animation, rig: Rig, window: Vector2) -> Animation:
	var overlay := {
		&"Hips": [[0.0, Vector3.ZERO], [0.8, Vector3(18, 0, 0)], [2.2, Vector3(22, 0, 0)], [3.0, Vector3.ZERO]],
		&"Chest": [[0.0, Vector3.ZERO], [0.8, Vector3(10, 0, 0)], [2.2, Vector3(12, 0, 0)], [3.0, Vector3.ZERO]],
		&"Head": [[0.0, Vector3.ZERO], [1.0, Vector3(-18, 0, 0)], [2.2, Vector3(-20, 0, 0)], [3.0, Vector3.ZERO]],
		# Follow-through: the hips and chest keep turning with the kick, then unwind.
		&"Spine": [[0.0, Vector3.ZERO], [2.0, Vector3.ZERO], [2.45, Vector3(0, -24, 0)], [3.0, Vector3.ZERO]],
		&"UpperChest": [[0.0, Vector3.ZERO], [2.0, Vector3.ZERO], [2.5, Vector3(0, -18, 0)], [3.0, Vector3.ZERO]],
	}
	var hips := [[0.0, 0.0], [0.8, -0.26], [2.3, -0.28], [3.0, 0.0]]
	# The kicking foot's arc is flattened onto the floor (sweep_floor), the support foot stays planted.
	return _derive(base, rig, func(t: float) -> float: return _phase(t, window, base.length),
		overlay, hips, {}, [&"RightFoot"])


static func _stagger(base: Animation, rig: Rig) -> Animation:
	# Stretched a little so the snap-back reads; time in seconds of the stretched clip.
	var stretch := 1.25
	var overlay := {
		&"Hips": [[0.0, Vector3.ZERO], [0.07, Vector3(-10, 0, 0)], [0.3, Vector3(-4, 0, 0)], [1.0, Vector3.ZERO]],
		&"Spine": [[0.0, Vector3.ZERO], [0.06, Vector3(-16, 0, 0)], [0.25, Vector3(-9, 0, 0)],
			[0.6, Vector3(-3, 0, 0)], [1.0, Vector3.ZERO]],
		&"Chest": [[0.0, Vector3.ZERO], [0.06, Vector3(-18, 0, 4)], [0.28, Vector3(-8, 0, 2)],
			[0.7, Vector3(-2, 0, 0)], [1.0, Vector3.ZERO]],
		&"UpperChest": [[0.0, Vector3.ZERO], [0.07, Vector3(-12, 0, 0)], [0.3, Vector3(-5, 0, 0)], [1.0, Vector3.ZERO]],
		&"Neck": [[0.0, Vector3.ZERO], [0.08, Vector3(-14, 0, 0)], [0.2, Vector3(6, 0, 0)], [0.45, Vector3.ZERO]],
		&"Head": [[0.0, Vector3.ZERO], [0.09, Vector3(-22, 0, 0)], [0.22, Vector3(10, 0, 0)],
			[0.5, Vector3(-3, 0, 0)], [0.8, Vector3.ZERO]],
		&"LeftUpperArm": [[0.0, Vector3.ZERO], [0.08, Vector3(25, 0, 30)], [0.4, Vector3(10, 0, 10)], [1.0, Vector3.ZERO]],
		&"RightUpperArm": [[0.0, Vector3.ZERO], [0.08, Vector3(25, 0, -30)], [0.4, Vector3(10, 0, -10)], [1.0, Vector3.ZERO]],
		&"LeftLowerArm": [[0.0, Vector3.ZERO], [0.1, Vector3(-20, 0, 0)], [0.5, Vector3.ZERO]],
		&"RightLowerArm": [[0.0, Vector3.ZERO], [0.1, Vector3(-20, 0, 0)], [0.5, Vector3.ZERO]],
	}
	var hips := [[0.0, 0.0], [0.12, -0.07], [0.35, -0.04], [1.0, 0.0]]
	var length := base.length * stretch
	return _derive(base, rig, func(t: float) -> float: return t / length, overlay, hips, {}, [], stretch)


## A mocap jab with a shoulder load: the chest and punching shoulder twist back over the first
## 2-3 startup ticks, then snap through into the punch (a touch of overshoot) and settle.
static func _jab(base: Animation, rig: Rig, window: Vector2, yaw: float) -> Animation:
	var side := 1.0 if yaw > 0.0 else -1.0
	var overlay := {
		&"Chest": [[0.0, Vector3.ZERO], [0.6, Vector3(-3, yaw, 0)], [1.0, Vector3(0, -yaw * 0.25, 0)],
			[1.8, Vector3.ZERO], [3.0, Vector3.ZERO]],
		&"Hips": [[0.0, Vector3.ZERO], [0.6, Vector3(0, yaw * 0.35, 0)], [1.0, Vector3.ZERO], [3.0, Vector3.ZERO]],
	}
	overlay[&"LeftShoulder" if side > 0.0 else &"RightShoulder"] = [[0.0, Vector3.ZERO],
		[0.6, Vector3(0, yaw * 0.6, 0)], [1.0, Vector3.ZERO], [3.0, Vector3.ZERO]]
	return _derive(base, rig, func(t: float) -> float: return _phase(t, window, base.length), overlay, [], {}, [])


## The get-up take from where the body starts to rise, then a rise to the stance's first frame.
static func _rise(take: Animation, stance: Animation, rig: Rig) -> Animation:
	var start := take.length * RISE_FROM
	var rise_frames := roundi(RISE_SECONDS * FPS)
	var take_frames := roundi((take.length - start) * FPS)
	var frames := take_frames + rise_frames + 1
	var last := _sample(take, rig, take.length)
	var end := _sample(stance, rig, 0.0)
	var poses: Array = []
	for f in frames:
		if f <= take_frames:
			poses.append(_sample(take, rig, start + f / FPS))
		else:
			var w := smoothstep(0.0, 1.0, float(f - take_frames) / rise_frames)
			var rotations: Array[Quaternion] = []
			for i in (last[0] as Array).size():
				rotations.append((last[0][i] as Quaternion).slerp(end[0][i], w))
			poses.append([rotations, (last[1] as Vector3).lerp(end[1], w)])
	return _from_poses(poses, take, rig)


## turn_in_place with the hips' yaw progress removed: the feet step, the body keeps facing ahead
## (the view turns the fighter).
static func _turn_step(take: Animation, rig: Rig) -> Animation:
	var frames := roundi(take.length * FPS) + 1
	var hips_id: int = rig.index[&"Hips"]
	var first := _sample(take, rig, 0.0)
	var yaw0 := _yaw((first[0] as Array)[hips_id])
	var poses: Array = []
	for f in frames:
		var pose := _sample(take, rig, f / FPS)
		var undo := Quaternion(Vector3.UP, yaw0 - _yaw(pose[0][hips_id]))
		pose[0][hips_id] = undo * (pose[0][hips_id] as Quaternion)
		pose[1] = undo * (pose[1] as Vector3)
		poses.append(pose)
	return _from_poses(poses, take, rig)


static func _yaw(q: Quaternion) -> float:
	var forward := q * Vector3.BACK
	return atan2(forward.x, forward.z)


## [rotations, hips (metres)] of a clip at a time, on the rig's rest for untracked bones.
static func _sample(animation: Animation, rig: Rig, time: float) -> Array:
	var rotations := rig.rest_rotations()
	var hips := Vector3.ZERO
	for track in animation.get_track_count():
		var bone := StringName(String(animation.track_get_path(track)).get_slice(":", 1))
		if not rig.index.has(bone):
			continue
		match animation.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				rotations[rig.index[bone]] = animation.rotation_track_interpolate(track, time)
			Animation.TYPE_POSITION_3D:
				hips = animation.position_track_interpolate(track, time) * MOTION_SCALE
	return [rotations, hips]


## A clip from per-frame [rotations, hips] poses, with the tracks of template.
static func _from_poses(poses: Array, template: Animation, rig: Rig) -> Animation:
	var out := Animation.new()
	out.length = (poses.size() - 1) / FPS
	out.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for track in template.get_track_count():
		if template.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var bone := StringName(String(template.track_get_path(track)).get_slice(":", 1))
			if rig.index.has(bone):
				var t := out.add_track(Animation.TYPE_ROTATION_3D)
				out.track_set_path(t, NodePath("%s:%s" % [SKELETON, bone]))
				tracks[bone] = t
	var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_track, NodePath("%s:Hips" % SKELETON))
	for f in poses.size():
		var pose: Array = poses[f]
		for bone: StringName in tracks:
			var i: int = rig.index[bone]
			var q: Quaternion = (pose[0][i] as Quaternion).normalized()
			out.rotation_track_insert_key(tracks[bone], f / FPS, q)
		out.position_track_insert_key(hips_track, f / FPS, (pose[1] as Vector3) / MOTION_SCALE)
	return out


## Light temporal smoothing of every rotation and the hips ([1, 2, 1] passes), keeping the active
## window (seconds) as it is so the strike still lands sharp.
static func smooth(animation: Animation, passes: int, keep := Vector2(-1, -1)) -> Animation:
	var out := animation.duplicate(true) as Animation
	for track in out.get_track_count():
		var count := out.track_get_key_count(track)
		for _pass in passes:
			var values := []
			for k in count:
				values.append(out.track_get_key_value(track, k))
			for k in range(1, count - 1):
				var time := out.track_get_key_time(track, k)
				if time >= keep.x and time <= keep.y:
					continue
				var a: Variant = values[k - 1]
				var b: Variant = values[k]
				var c: Variant = values[k + 1]
				if b is Quaternion:
					var mid := (a as Quaternion).slerp(c, 0.5)
					out.track_set_key_value(track, k, (b as Quaternion).slerp(mid, 0.5).normalized())
				else:
					out.track_set_key_value(track, k, (b as Vector3).lerp(((a as Vector3) + (c as Vector3)) * 0.5, 0.5))
	return out


## Mirrors a clip left to right (model x -> -x): each bone takes its twin's rotation away from rest,
## reflected, so the other hand or foot does the move.
static func mirror(base: Animation, rig: Rig) -> Animation:
	var frames := roundi(base.length * FPS) + 1
	var poses: Array = []
	for f in frames:
		var pose := _sample(base, rig, minf(f / FPS, base.length))
		poses.append(rig.mirrored(pose[0], pose[1]))
	var out := _from_poses(poses, base, rig)
	out.loop_mode = base.loop_mode
	return out


## A take retimed onto a move: the frame where the strike limb comes closest to target (model
## space) lands mid-active, the take before it fills startup and the rest fills recovery, then the
## limb's path is shifted (two-bone IK, ramped in over the last startup ticks) so the peak reaches
## target. The clip lasts exactly move.total_ticks() / 60. limbs: hands or feet; with two, the
## second strikes beside the first.
static func fit_strike(base: Animation, rig: Rig, move: MoveData, limbs: Array, target: Vector3) -> Animation:
	var source_frames := roundi(base.length * FPS) + 1
	var lead: StringName = limbs[0]
	var lead_id: int = rig.index[lead]
	# The peak is the take's fullest extension toward the target (after it the limb comes back).
	var peak := 0
	var best := -INF
	var paths: Array = []
	for f in source_frames:
		var pose := _sample(base, rig, minf(f / FPS, base.length))
		var world := rig.world(pose[0], pose[1])
		paths.append(world)
		if f < source_frames * 0.15 or f > source_frames * 0.85:
			continue
		var hips: Vector3 = pose[1]
		var toward := (target - hips).normalized()
		var reach := ((world[lead_id] as Transform3D).origin - hips).dot(toward)
		if reach > best:
			best = reach
			peak = f
	var startup := float(move.startup_ticks)
	var active_end := float(move.recovery_start_tick())
	var total := float(move.total_ticks())
	var half := minf(1.5, float(peak) * 0.3)
	var shifts := {}
	for k in limbs.size():
		var limb: StringName = limbs[k]
		var side := Vector3(HAND_GAP * (0.5 if limb.begins_with("Left") else -0.5), 0, 0) if limbs.size() > 1 else Vector3.ZERO
		var at_peak: Vector3 = (paths[peak][rig.index[limb]] as Transform3D).origin
		shifts[limb] = (target + side - at_peak).limit_length(MAX_FIT_SHIFT)
	var poses: Array = []
	for tick in int(total) + 1:
		var source: float
		if tick <= startup:
			source = lerpf(0.0, peak - half, tick / startup)
		elif tick <= active_end:
			source = lerpf(peak - half, peak + half, (tick - startup) / maxf(active_end - startup, 1.0))
		else:
			source = lerpf(peak + half, source_frames - 1.0, (tick - active_end) / maxf(total - active_end, 1.0))
		var pose := _sample(base, rig, minf(source / FPS, base.length))
		var weight := smoothstep(startup - 5.0, startup, tick) * (1.0 - smoothstep(active_end - 1.0, active_end + 4.0, tick))
		# Anticipation: draw back away from the target through the first half of startup.
		var windup := FIT_WINDUP * sin(PI * clampf(tick / maxf(startup - 2.0, 1.0), 0.0, 1.0)) * (1.0 - weight)
		# The limb arrives from short of the target (still accelerating at the hit), then the
		# follow-through carries it on across the body and down after the active ticks.
		var approach := -FIT_APPROACH * (1.0 - smoothstep(startup - 2.0, startup, tick)) * smoothstep(startup - 5.0, startup - 2.0, tick)
		var follow := FIT_FOLLOW * smoothstep(active_end - 1.0, active_end + 5.0, tick) * (1.0 - smoothstep(active_end + 6.0, active_end + 16.0, tick))
		if weight > 0.0 or windup > 0.0 or follow > 0.0:
			var world := rig.world(pose[0], pose[1])
			var hips: Vector3 = pose[1]
			var direction := Vector3(target.x - hips.x, 0.0, target.z - hips.z).normalized()
			var across := Vector3.UP.cross(direction)
			for limb: StringName in limbs:
				var chain := rig.chain_of(limb)
				var at: Vector3 = (world[rig.index[limb]] as Transform3D).origin
				var side := -1.0 if String(limb).begins_with("Left") else 1.0
				var sweep := (across * side * 0.8 + Vector3.DOWN * 0.6) * follow
				rig.solve(pose[0], pose[1], chain, at + (shifts[limb] as Vector3) * weight + direction * (approach - windup) + sweep)
				world = rig.world(pose[0], pose[1])
		poses.append(pose)
	return _from_poses(poses, base, rig)


## Samples base at 60 fps, applies the overlays at each frame's key time, re-plants the feet and
## moves IK hands, and returns a new clip. hand_offsets: hand -> keys of model-space offsets.
## floor_feet: feet whose height is pressed toward the floor (a sweep) instead of kept.
static func _derive(base: Animation, rig: Rig, key_time: Callable, overlay: Dictionary, hips_keys: Array,
		hand_offsets: Dictionary, floor_feet: Array, stretch := 1.0) -> Animation:
	var length := base.length * stretch
	var frames := roundi(length * FPS) + 1
	var tracks := {}
	for track in base.get_track_count():
		if base.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			tracks[StringName(String(base.track_get_path(track)).get_slice(":", 1))] = track
	var hips_track := base.find_track(NodePath("%s:Hips" % SKELETON), Animation.TYPE_POSITION_3D)
	var out := Animation.new()
	out.length = (frames - 1) / FPS
	out.loop_mode = Animation.LOOP_NONE
	var out_tracks := {}
	for bone: StringName in tracks:
		var t := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(t, NodePath("%s:%s" % [SKELETON, bone]))
		out_tracks[bone] = t
	var out_hips := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(out_hips, NodePath("%s:Hips" % SKELETON))
	for f in frames:
		var time := f / FPS
		var source_time := minf(time / stretch, base.length)
		var u: float = key_time.call(time)
		var rotations := rig.rest_rotations()
		for bone: StringName in tracks:
			rotations[rig.index[bone]] = base.rotation_track_interpolate(tracks[bone], source_time)
		var hips: Vector3 = base.position_track_interpolate(hips_track, source_time) * MOTION_SCALE
		var base_world := rig.world(rotations, hips)
		for bone: StringName in overlay:
			var euler := _sample_vec(overlay[bone], u) * (PI / 180.0)
			var i: int = rig.index[bone]
			rotations[i] = rig.rest_frame(i, euler) * rotations[i]
		hips.y += _sample_float(hips_keys, u)
		# Feet back where the base take had them (planted), or pressed to the floor (sweep).
		for leg: Array in MotionLayers.LEGS:
			var foot: int = rig.index[leg[2]]
			var target: Vector3 = (base_world[foot] as Transform3D).origin
			if floor_feet.has(leg[2]):
				target = _floor_sweep(base_world, rig, leg, target)
				# Follow-through: the foot's arc carries on round after the hit, then comes back.
				var hip: Vector3 = (base_world[rig.index[leg[0]]] as Transform3D).origin
				var yaw := deg_to_rad(_sample_float(SWEEP_FOLLOW, u))
				target = hip + Basis(Vector3.UP, yaw) * (target - hip)
			rig.solve(rotations, hips, leg, target)
		for hand: StringName in hand_offsets:
			var chain: Array = MotionLayers.ARMS[0] if hand == &"LeftHand" else MotionLayers.ARMS[1]
			var start: Vector3 = (base_world[rig.index[hand]] as Transform3D).origin
			rig.solve(rotations, hips, chain, start + _sample_vec(hand_offsets[hand], u))
		for bone: StringName in out_tracks:
			out.rotation_track_insert_key(out_tracks[bone], time, rotations[rig.index[bone]].normalized())
		out.position_track_insert_key(out_hips, time, hips / MOTION_SCALE)
	return out


## The kicking foot's target for a floor sweep: same direction from the hip, but low.
static func _floor_sweep(world: Array, rig: Rig, leg: Array, foot: Vector3) -> Vector3:
	var hip: Vector3 = (world[rig.index[leg[0]]] as Transform3D).origin
	var flat := Vector3(foot.x - hip.x, 0.0, foot.z - hip.z)
	var reach := rig.leg_length(leg) * 0.97
	var height := clampf(foot.y, 0.12, 0.2)
	var out := flat.normalized() * maxf(flat.length(), reach * 0.75)
	return Vector3(hip.x + out.x, height, hip.z + out.z)


static func _sample_vec(keys: Array, u: float) -> Vector3:
	if u <= keys[0][0]:
		return keys[0][1]
	for k in range(1, keys.size()):
		if u <= keys[k][0]:
			var a: float = keys[k - 1][0]
			var w := smoothstep(0.0, 1.0, (u - a) / (keys[k][0] - a))
			return (keys[k - 1][1] as Vector3).lerp(keys[k][1], w)
	return keys[-1][1]


static func _sample_float(keys: Array, u: float) -> float:
	if keys.is_empty():
		return 0.0
	if u <= keys[0][0]:
		return keys[0][1]
	for k in range(1, keys.size()):
		if u <= keys[k][0]:
			var a: float = keys[k - 1][0]
			return lerpf(keys[k - 1][1], keys[k][1], smoothstep(0.0, 1.0, (u - a) / (keys[k][0] - a)))
	return keys[-1][1]


## The skeleton's layout, for FK and two-bone IK on plain arrays.
class Rig:
	var index := {}
	var parents := PackedInt32Array()
	var origins: Array[Vector3] = []
	var rests: Array[Quaternion] = []
	var rest_parent: Array[Quaternion] = []
	var _layers := MotionLayers.new()
	var _twins := {}

	func _init(skeleton: Skeleton3D) -> void:
		var names := PackedStringArray()
		var rest_transforms: Array[Transform3D] = []
		var globals: Array[Transform3D] = []
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
			index[StringName(skeleton.get_bone_name(i))] = i
			parents.append(skeleton.get_bone_parent(i))
			var rest := skeleton.get_bone_rest(i)
			rest_transforms.append(rest)
			origins.append(rest.origin)
			rests.append(rest.basis.get_rotation_quaternion())
			globals.append(rest if parents[i] < 0 else globals[parents[i]] * rest)
			rest_parent.append(Quaternion.IDENTITY if parents[i] < 0 else globals[parents[i]].basis.get_rotation_quaternion())
		_layers.setup_bones(names, parents, rest_transforms)

	func rest_rotations() -> Array[Quaternion]:
		return rests.duplicate()

	func rest_frame(i: int, euler: Vector3) -> Quaternion:
		return rest_parent[i].inverse() * Quaternion.from_euler(euler) * rest_parent[i]

	func world(rotations: Array[Quaternion], hips: Vector3) -> Array:
		return _layers._world(rotations, hips)

	func leg_length(leg: Array) -> float:
		return origins[index[leg[1]]].length() + origins[index[leg[2]]].length()

	## Two-bone IK of chain [upper, lower, end] so end reaches target (model space).
	func solve(rotations: Array[Quaternion], hips: Vector3, chain: Array, target: Vector3) -> void:
		var w := world(rotations, hips)
		_layers._two_bone(rotations, w, index[chain[0]], index[chain[1]], index[chain[2]], target)

	## The [upper, lower, end] chain of a hand or foot.
	func chain_of(limb: StringName) -> Array:
		for chain: Array in MotionLayers.ARMS + MotionLayers.LEGS:
			if chain[2] == limb:
				return chain
		return []

	## A pose mirrored left to right: rotations away from rest reflected and swapped between twins.
	func mirrored(rotations: Array[Quaternion], hips: Vector3) -> Array:
		var count := rotations.size()
		var world: Array[Quaternion] = []
		for i in count:
			world.append(rotations[i] if parents[i] < 0 else world[parents[i]] * rotations[i])
		var out_world: Array[Quaternion] = []
		out_world.resize(count)
		for i in count:
			var twin := twin_of(i)
			var delta := world[twin] * (rest_parent[twin] * rests[twin]).inverse()
			out_world[i] = Quaternion(delta.x, -delta.y, -delta.z, delta.w) * rest_parent[i] * rests[i]
		var out: Array[Quaternion] = []
		for i in count:
			out.append((out_world[i] if parents[i] < 0 else out_world[parents[i]].inverse() * out_world[i]).normalized())
		return [out, Vector3(-hips.x, hips.y, hips.z)]

	func twin_of(i: int) -> int:
		if _twins.is_empty():
			for bone: StringName in index:
				var name := String(bone)
				var other := name.replace("Left", "Right") if name.begins_with("Left") else name.replace("Right", "Left")
				_twins[index[bone]] = index.get(StringName(other), index[bone])
		return _twins.get(i, i)

	func free_layers() -> void:
		_layers.free()
