class_name MotionClips
extends RefCounted
## Runtime additions to the MotionLibrary for the takes mocap lacks, plus strike impact windows.
## Each derived clip is a base take with authored overlays layered on top (model-frame rotations,
## hips offsets), then two-bone IK keeps the planted feet where the base take had them and moves
## the striking limb to its new target:
## - launcher_up: the hooking straight turned into a crouch-and-rise uppercut.
## - sweep_low: the mirrored roundhouse dropped into a deep crouch with the foot along the floor.
## - hit_stagger: the light flinch, stretched, with the torso snapping back and the head whipping.
## - push_block_both: push_block for two-handed shoves (Vexa's light_5).
## Both rigs share the profile's rest rotations, so clips built on one skeleton drive both.

const FPS := 60.0
const SKELETON := "%GeneralSkeleton"
const KAEL_MOVES := "res://game/combat/moves/kael/kael_move_set.tres"
## Derived clip -> [base clip, strike move id or "" for a reaction].
const DERIVED := {
	&"launcher_up": [&"launcher", &"launcher"],
	&"sweep_low": [&"sweep", &"sweep"],
	&"hit_stagger": [&"hit_light", &""],
}
## Hips height keys are stored divided by the rig's motion scale (Kael's).
const MOTION_SCALE := 0.8

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
	return _derive(base, rig, func(t: float) -> float: return _phase(t, window, base.length),
		overlay, hips, {&"RightHand": hand}, [])


static func _sweep(base: Animation, rig: Rig, window: Vector2) -> Animation:
	var overlay := {
		&"Hips": [[0.0, Vector3.ZERO], [0.8, Vector3(18, 0, 0)], [2.2, Vector3(22, 0, 0)], [3.0, Vector3.ZERO]],
		&"Chest": [[0.0, Vector3.ZERO], [0.8, Vector3(10, 0, 0)], [2.2, Vector3(12, 0, 0)], [3.0, Vector3.ZERO]],
		&"Head": [[0.0, Vector3.ZERO], [1.0, Vector3(-18, 0, 0)], [2.2, Vector3(-20, 0, 0)], [3.0, Vector3.ZERO]],
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

	func free_layers() -> void:
		_layers.free()
