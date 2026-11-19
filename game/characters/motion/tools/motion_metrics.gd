extends SceneTree
## Objective realism metrics, OLD clips vs NEW mocap clips as CharacterView plays them (T-D22b:
## the integrated library with the derived launcher_up, sweep_low and hit_stagger), at 60 fps.
## Prints a Markdown table for chunky Kael (default) or Vexa (her posed move clips are the old ones).
##   godot --headless --path . -s res://game/characters/motion/tools/motion_metrics.gd -- [kael|vexa]

const MODEL := "res://game/characters/kael_chunky/kael_chunky.glb"
const OLD_CLIPS := "res://game/characters/kael_chunky/kael_chunky_clip_set.tres"
const NEW_CLIPS := "res://game/characters/motion/motion_library.res"
const MOVE_DIR := "res://game/combat/moves/kael/"
const DT := 1.0 / 60.0
## A frame-to-frame change in angular velocity above this (rad/s per frame) is a pop.
const POP_THRESHOLD := 6.0
const CONTACT_HEIGHT := 0.05
const CONTACT_SPEED := 1.0
## [label, old clip, new clip, locomotion]
const PAIRS := [
	["idle", "idle", "fight_idle", false], ["run", "run", "run", true],
	["light_1", "light_1", "light_1", false], ["light_2", "light_2", "light_2", false],
	["light_3", "light_3", "light_3", false], ["light_4", "light_4", "light_4", false],
	["smash", "smash", "smash", false], ["launcher", "launcher", "launcher", false],
	["spike", "spike", "spike", false], ["sweep", "sweep", "sweep", false],
	["block hit", "block_hit", "block_hit", false], ["heavy hit", "hit", "hit_heavy", false],
	["launcher (T-D22b)", "launcher", "launcher_up", false], ["sweep (T-D22b)", "sweep", "sweep_low", false],
	["heavy hit (T-D22b)", "hit", "hit_stagger", false],
	["KO fall", "knockdown", "ko_fall", false], ["get up", "get_up", "get_up", false],
]
const BODY := [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head", &"LeftUpperArm", &"LeftLowerArm",
	&"RightUpperArm", &"RightLowerArm", &"LeftUpperLeg", &"LeftLowerLeg", &"RightUpperLeg", &"RightLowerLeg"]
## Rough mass fractions for the centre of mass.
const MASS := {&"Hips": 0.25, &"Chest": 0.2, &"Head": 0.08, &"LeftUpperArm": 0.03, &"RightUpperArm": 0.03,
	&"LeftLowerArm": 0.02, &"RightLowerArm": 0.02, &"LeftUpperLeg": 0.1, &"RightUpperLeg": 0.1,
	&"LeftLowerLeg": 0.06, &"RightLowerLeg": 0.06, &"LeftFoot": 0.025, &"RightFoot": 0.025}
const STRIKE_BONES := {
	"light_1": &"LeftMiddleProximal", "light_2": &"RightMiddleProximal", "light_3": &"LeftMiddleProximal",
	"light_4": &"RightToes", "smash": &"RightMiddleProximal", "launcher": &"RightMiddleProximal",
	"spike": &"RightToes", "sweep": &"RightToes", "launcher (T-D22b)": &"RightMiddleProximal",
	"sweep (T-D22b)": &"RightToes",
}
const SCENES := {"kael": "res://game/characters/kael_chunky/kael_chunky.tscn", "vexa": "res://game/characters/vexa/vexa.tscn"}
## Moves whose old clip is the character's move clip (Vexa's are generated as vexa_<id>).
const MOVE_LABELS := {"light_1": &"light_1", "light_2": &"light_2", "light_3": &"light_3", "light_4": &"light_4",
	"smash": &"smash", "launcher": &"launcher", "spike": &"spike", "sweep": &"sweep",
	"launcher (T-D22b)": &"launcher", "sweep (T-D22b)": &"sweep"}

var _who := "kael"
var _view: CharacterView
var _done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_who = args[0] if args.size() > 0 else "kael"
	_view = (load(SCENES[_who]) as PackedScene).instantiate() as CharacterView
	root.add_child(_view)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var skeleton := _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	var old_library := _view.clips.library
	var new_library := MotionClips.for_skeleton(MotionClips.build(_view.clips.motion, skeleton), skeleton)
	var old := {"player": null, "skeleton": skeleton, "library": old_library}
	var new := {"player": null, "skeleton": skeleton, "library": new_library}
	_view.set_process(false)
	if _view.layers:
		_view.layers.active = false
	print("## %s" % _who)
	var lines := ["| clip | foot slide cm/contact (old → new) | pops (old → new) | mean ang. jerk rad/s² (old → new) | CoM shift over support cm (old → new) | pelvis bob cm (old → new) | anticipation / follow-through ticks (old → new) |",
		"|---|---|---|---|---|---|---|"]
	for pair: Array in PAIRS:
		if MOVE_LABELS.has(pair[0]):
			pair = pair.duplicate()
			pair[1] = String(_view.clips.clip_for_move(MOVE_LABELS[pair[0]]))
		var a := _measure(old, pair[1], pair[3], false, pair[0])
		var b := _measure(new, pair[2], pair[3], true, pair[0])
		var phases := "–"
		if STRIKE_BONES.has(pair[0]):
			phases = "%d / %d → %d / %d" % [a["anticipation"], a["follow"], b["anticipation"], b["follow"]]
		lines.append("| %s | %.1f → %.1f | %d → %d | %.0f → %.0f | %.1f → %.1f | %.1f → %.1f | %s |" % [pair[0],
			a["slide"], b["slide"], a["pops"], b["pops"], a["jerk"], b["jerk"], a["com"], b["com"],
			a["bob"], b["bob"], phases])
	print("\n".join(lines))
	quit(0)
	return true


func _character(library: AnimationLibrary) -> Dictionary:
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var player := AnimationPlayer.new()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"lib", library)
	return {"player": player, "skeleton": model.get_node("%GeneralSkeleton"), "library": library}


func _measure(character: Dictionary, clip: String, locomotion: bool, is_new: bool, label: String) -> Dictionary:
	var library: AnimationLibrary = character["library"]
	var skeleton: Skeleton3D = character["skeleton"]
	var animation := library.get_animation(clip)
	var frames := int(round(animation.length / DT)) + 1
	var globals: Array[Dictionary] = []
	var rotations: Array[Dictionary] = []
	for f in frames:
		apply_clip(skeleton, animation, minf(f * DT, animation.length))
		var g := {}
		var r := {}
		for bone: StringName in MASS.keys() + BODY + [&"LeftFoot", &"RightFoot"] + STRIKE_BONES.values():
			var id := skeleton.find_bone(bone)
			var pose := _global_pose(skeleton, id)
			g[bone] = pose.origin
			r[bone] = pose.basis.get_rotation_quaternion()
		globals.append(g)
		rotations.append(r)
	# Root travel per frame (new clips store it; old clips are in place).
	var travel: Array[Vector3] = []
	for f in frames:
		var v := Vector3.ZERO
		if is_new and library is MotionLibrary:
			var root_now := (library as MotionLibrary).root_at(clip, f * DT)
			v = Vector3(root_now.x, 0, root_now.y)
		travel.append(v)
	var out := {"slide": _foot_slide(skeleton, globals, travel, locomotion), "bob": 0.0, "com": 0.0}
	var pops := 0
	var jerk := 0.0
	var count := 0
	for bone: StringName in BODY:
		var last_w := Vector3.INF
		for f in range(1, frames):
			var q: Quaternion = rotations[f][bone] * (rotations[f - 1][bone] as Quaternion).inverse()
			var w := MotionLayers.rotvec(q) / DT
			if last_w != Vector3.INF:
				var dw := (w - last_w).length()
				if dw > POP_THRESHOLD:
					pops += 1
				jerk += dw / DT
				count += 1
			last_w = w
	out["pops"] = pops
	out["jerk"] = jerk / maxf(count, 1)
	var low := INF
	var high := -INF
	var com_low := INF
	var com_high := -INF
	for f in frames:
		var hips_y: float = (globals[f][&"Hips"] as Vector3).y
		low = minf(low, hips_y)
		high = maxf(high, hips_y)
		var com := Vector3.ZERO
		var total := 0.0
		for bone: StringName in MASS:
			com += (globals[f][bone] as Vector3) * MASS[bone]
			total += MASS[bone]
		com /= total
		var base: Vector3 = ((globals[f][&"LeftFoot"] as Vector3) + (globals[f][&"RightFoot"] as Vector3)) * 0.5
		var feet: Vector3 = (globals[f][&"LeftFoot"] as Vector3) - (globals[f][&"RightFoot"] as Vector3)
		feet.y = 0
		# Signed offset of the CoM from the support centre along the stance line.
		var along := (com - base).dot(feet.normalized()) if feet.length() > 0.01 else 0.0
		com_low = minf(com_low, along)
		com_high = maxf(com_high, along)
	out["bob"] = (high - low) * 100.0
	out["com"] = (com_high - com_low) * 100.0
	if STRIKE_BONES.has(label):
		var phases := _phases(globals, STRIKE_BONES[label], label)
		out["anticipation"] = phases.x
		out["follow"] = phases.y
	return out


static func _global_pose(skeleton: Skeleton3D, id: int) -> Transform3D:
	var pose := skeleton.get_bone_pose(id)
	var parent := skeleton.get_bone_parent(id)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return pose


## Poses the skeleton straight from the clip's tracks (no AnimationPlayer needed).
static func apply_clip(skeleton: Skeleton3D, animation: Animation, time: float) -> void:
	skeleton.reset_bone_poses()
	for track in animation.get_track_count():
		var bone := skeleton.find_bone(String(animation.track_get_path(track)).get_slice(":", 1))
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track, time))
			Animation.TYPE_POSITION_3D:
				# The mixer scales position tracks by the motion scale at runtime; so does this.
				skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track, time) * skeleton.motion_scale)
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, animation.scale_track_interpolate(track, time))
	skeleton.force_update_all_bone_transforms()


func _foot_slide(skeleton: Skeleton3D, globals: Array[Dictionary], travel: Array[Vector3], locomotion: bool) -> float:
	var total := 0.0
	var contacts := 0
	for foot: StringName in [&"LeftFoot", &"RightFoot"]:
		var rest_y := skeleton.get_bone_global_rest(skeleton.find_bone(foot)).origin.y
		# Old in-place loops have no root curve: credit them the best constant speed.
		var reference := Vector3.ZERO
		if locomotion and travel[-1] == Vector3.ZERO:
			var speeds: Array[float] = []
			for f in range(1, globals.size()):
				if (globals[f][foot] as Vector3).y < rest_y + CONTACT_HEIGHT:
					speeds.append(((globals[f][foot] as Vector3) - (globals[f - 1][foot] as Vector3)).z)
			speeds.sort()
			if not speeds.is_empty():
				reference = Vector3(0, 0, speeds[speeds.size() / 2])
		var in_contact := false
		for f in range(1, globals.size()):
			var moved: Vector3 = (globals[f][foot] as Vector3) + travel[f] - (globals[f - 1][foot] as Vector3) - travel[f - 1] - reference
			moved.y = 0
			# Planted: near the floor and not swinging (a swing moves faster than CONTACT_SPEED).
			var planted := (globals[f][foot] as Vector3).y < rest_y + CONTACT_HEIGHT and moved.length() / DT < CONTACT_SPEED
			if planted:
				if not in_contact:
					contacts += 1
				var step: Vector3 = (globals[f][foot] as Vector3) + travel[f] - (globals[f - 1][foot] as Vector3) - travel[f - 1] - reference
				step.y = 0
				total += step.length()
			in_contact = planted
	return total * 100.0 / maxf(contacts, 1)


## Anticipation: ticks in startup where the strike point moves away from the target (wind-up).
## Follow-through: ticks after the peak until the strike point slows below 15% of its top speed.
func _phases(globals: Array[Dictionary], bone: StringName, move_id: String) -> Vector2i:
	var move := load(MOVE_DIR + move_id.get_slice(" ", 0) + ".tres") as MoveData
	var target := Vector3.ZERO
	for offset in move.hitbox_offsets:
		target += offset
	target /= move.hitbox_offsets.size()
	# Hitboxes are in view space: the model is turned 180 degrees and lowered 1 m.
	target = Vector3(-target.x, target.y + 1.0, -target.z)
	var anticipation := 0
	var top := 0.0
	var peak := 0
	var best := INF
	for f in globals.size():
		var d := (globals[f][bone] as Vector3).distance_to(target)
		if d < best:
			best = d
			peak = f
		if f > 0:
			top = maxf(top, ((globals[f][bone] as Vector3) - (globals[f - 1][bone] as Vector3)).length())
			if f <= move.startup_ticks and d > (globals[f - 1][bone] as Vector3).distance_to(target) + 0.002:
				anticipation += 1
	var follow := 0
	for f in range(peak + 1, globals.size()):
		var speed := ((globals[f][bone] as Vector3) - (globals[f - 1][bone] as Vector3)).length()
		if speed < top * 0.15:
			break
		follow += 1
	return Vector2i(anticipation, follow)
