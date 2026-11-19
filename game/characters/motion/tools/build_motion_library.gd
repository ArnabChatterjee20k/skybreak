extends SceneTree
## Turns build_motion.py's JSON into res://game/characters/motion/motion_library.res.
##   godot --headless --path . -s res://game/characters/motion/tools/build_motion_library.gd -- <motion_clips.json>

const OUT := "res://game/characters/motion/motion_library.res"
const SKELETON := "%GeneralSkeleton"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var library := MotionLibrary.new()
	var bones: Array = data["bones"]
	for clip_name: String in data["clips"]:
		var clip: Dictionary = data["clips"][clip_name]
		library.add_animation(StringName(clip_name), _animation(clip, bones))
		var root := PackedVector3Array()
		for value: Array in clip["root"]:
			root.append(Vector3(value[0], value[1], value[2]))
		library.root_motion[StringName(clip_name)] = root
		var contacts := PackedByteArray()
		var left: Array = clip["contacts"]["Left"]
		var right: Array = clip["contacts"]["Right"]
		for i in left.size():
			contacts.append(int(left[i]) | (int(right[i]) << 1))
		library.foot_contacts[StringName(clip_name)] = contacts
		if clip.has("strike_bone"):
			library.strike_bones[StringName(clip_name)] = StringName(clip["strike_bone"])
		library.clip_sources[StringName(clip_name)] = "%s %s" % [clip["source"], str(clip["source_window"])]
	var error := ResourceSaver.save(library, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved %d clips to %s (%s)" % [library.get_animation_list().size(), OUT, error_string(error)])
	quit(0 if error == OK else 1)


func _animation(clip: Dictionary, bones: Array) -> Animation:
	var animation := Animation.new()
	var frames: int = clip["frames"]
	animation.length = (frames - 1) / MotionLibrary.FPS
	animation.loop_mode = Animation.LOOP_LINEAR if clip["loop"] else Animation.LOOP_NONE
	var rotations: Array = clip["rotations"]
	for b in bones.size():
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [SKELETON, bones[b]]))
		for f in frames:
			var q: Array = rotations[f][b]
			animation.rotation_track_insert_key(track, f / MotionLibrary.FPS, Quaternion(q[0], q[1], q[2], q[3]).normalized())
	var hips := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hips, NodePath("%s:Hips" % SKELETON))
	var positions: Array = clip["hips"]
	for f in frames:
		var p: Array = positions[f]
		animation.position_track_insert_key(hips, f / MotionLibrary.FPS, Vector3(p[0], p[1], p[2]))
	return animation
