extends SceneTree
## Builds chunky Kael's AnimationLibrary: the shared humanoid clips that work on his proportions
## (with per-character pose offsets) plus his own clips from kael_chunky_moves.glb, and writes
## the ClipSet's library and impact windows. Run after `--import`:
## godot --headless --path . -s res://game/characters/kael_chunky/tools/build_kael_chunky_clips.gd

const SHARED := "res://game/characters/animations/humanoid_clips.res"
const MOVES_GLB := "res://game/characters/kael_chunky/animations/kael_chunky_moves.glb"
const OUTPUT := "res://game/characters/kael_chunky/animations/kael_chunky_clips.res"
const CLIP_SET := "res://game/characters/kael_chunky/kael_chunky_clip_set.tres"
const MOVE_DIR := "res://game/combat/moves/kael/"
## Shared clips he uses as they are (plus the offsets below).
const SHARED_CLIPS: Array[StringName] = [&"run", &"fall", &"dash", &"block", &"block_hit", &"hit", &"hit_head",
	&"knockdown", &"get_up", &"guard_broken", &"victory"]
## His own looping clips; every other own clip plays once.
const LOOPING: Array[StringName] = [&"idle", &"power_up", &"hover", &"fly", &"smash_hold"]
## Per-character pose offsets for shared clips: clip (or &"*" for the rest) -> {bone: [axis,
## degrees]}, the axis in skeleton space. Applied in the parent's frame before the clip's own
## rotation, so an upper-arm offset swings the whole arm.
const OFFSETS := {}


func _init() -> void:
	var shared: AnimationLibrary = load(SHARED)
	var library := AnimationLibrary.new()
	var model: Node = (load("res://game/characters/kael_chunky/kael_chunky.glb") as PackedScene).instantiate()
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	for clip in SHARED_CLIPS:
		var animation := shared.get_animation(clip).duplicate(true) as Animation
		_apply_offsets(animation, clip, skeleton)
		library.add_animation(clip, animation)
	var scene: Node = (load(MOVES_GLB) as PackedScene).instantiate()
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var windows: Dictionary[StringName, Vector2] = {}
	for clip in player.get_animation_list():
		var animation := player.get_animation(clip).duplicate(true) as Animation
		_prune(animation)
		animation.loop_mode = Animation.LOOP_LINEAR if StringName(clip) in LOOPING else Animation.LOOP_NONE
		library.add_animation(clip, animation)
		var move_path := MOVE_DIR + clip + ".tres"
		if ResourceLoader.exists(move_path):
			# Authored on the move's ticks: clip time = move_tick / 60 in every phase.
			var move: MoveData = load(move_path)
			windows[clip] = Vector2(move.startup_ticks, move.recovery_start_tick()) / 60.0
	scene.free()
	model.free()
	var error := ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	print("saved %s: %d clips (%s)" % [OUTPUT, library.get_animation_list().size(), error_string(error)])
	var clip_set: ClipSet = load(CLIP_SET)
	clip_set.library = load(OUTPUT)
	clip_set.impact_windows = windows
	print("updated %s (%s)" % [CLIP_SET, error_string(ResourceSaver.save(clip_set, CLIP_SET))])
	quit()


## Drops the Root tracks and scale tracks that stay at 1: only what moves is kept.
func _prune(animation: Animation) -> void:
	for track in range(animation.get_track_count() - 1, -1, -1):
		var path := String(animation.track_get_path(track))
		var root := path.ends_with(":Root")
		var unit_scale := animation.track_get_type(track) == Animation.TYPE_SCALE_3D
		if unit_scale:
			for key in animation.track_get_key_count(track):
				if not (animation.track_get_key_value(track, key) as Vector3).is_equal_approx(Vector3.ONE):
					unit_scale = false
					break
		if root or unit_scale:
			animation.remove_track(track)


func _apply_offsets(animation: Animation, clip: StringName, skeleton: Skeleton3D) -> void:
	var offsets: Dictionary = OFFSETS.get(clip, OFFSETS.get(&"*", {}))
	for bone: StringName in offsets:
		var track := animation.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_ROTATION_3D)
		if track < 0:
			continue
		# Skeleton-space axis (+X his left, +Y up, +Z front) moved into the parent's rest frame.
		var offset := Quaternion(offsets[bone][0], deg_to_rad(offsets[bone][1]))
		var parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(skeleton.find_bone(bone)))
		var to_parent := parent.basis.get_rotation_quaternion()
		var local_offset := to_parent.inverse() * offset * to_parent
		for key in animation.track_get_key_count(track):
			var value: Quaternion = animation.track_get_key_value(track, key)
			animation.track_set_key_value(track, key, (local_offset * value).normalized())
