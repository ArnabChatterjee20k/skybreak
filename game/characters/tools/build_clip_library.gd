extends SceneTree
## Builds the shared humanoid AnimationLibrary from the retargeted Quaternius
## Universal Animation Library imports and measures each strike's impact window
## into the given ClipSets. Run after `--import`:
## godot --headless --path . -s res://game/characters/tools/build_clip_library.gd

const SOURCES := [
	"res://game/characters/animations/ual/ual1_standard.glb",
	"res://game/characters/animations/ual/ual2_standard.glb",
]
const OUTPUT := "res://game/characters/animations/humanoid_clips.res"
const CLIP_SETS := ["res://game/characters/kael/kael_clip_set.tres"]

## Our clip name -> [source clip, loops].
const CLIPS := {
	&"idle": ["Idle", true],
	&"run": ["Sprint", true],
	&"hover": ["Swim_Idle", true],
	&"fly": ["NinjaJump_Idle", true],
	&"fall": ["Jump", true],
	&"dash": ["Shield_Dash", false],
	&"charge": ["Spell_Simple_Idle", true],
	&"block": ["Idle_Shield", true],
	&"guard_broken": ["Idle_Shield_Break", false],
	&"hit": ["Hit_Chest", false],
	&"hit_head": ["Hit_Head", false],
	&"block_hit": ["Shield_OneShot", false],
	&"knockdown": ["Hit_Knockback", false],
	&"get_up": ["LayToIdle", false],
	&"victory": ["Idle_FoldArms", true],
	&"jab": ["Punch_Jab", false],
	&"cross": ["Punch_Cross", false],
	&"hook": ["Melee_Hook", false],
	&"palm_strike": ["Spell_Simple_Shoot", false],
	&"swing_low": ["Sword_Regular_A", false],
	&"swing_back": ["Sword_Regular_B", false],
	&"swing_rising": ["Sword_Regular_C", false],
	&"overhead": ["OverhandThrow", false],
	&"shove": ["Push", false],
}
## Clips whose impact window is measured (the rest have none).
const STRIKES: Array[StringName] = [&"jab", &"cross", &"hook", &"palm_strike", &"swing_low",
	&"swing_back", &"swing_rising", &"overhead", &"shove"]
const EFFECTORS := ["LeftHand", "RightHand", "LeftFoot", "RightFoot"]
const SAMPLE_STEP := 1.0 / 60.0
## Impact window around the peak reach: the strike arriving, then a beat held.
const WINDOW_BEFORE := 0.05
const WINDOW_AFTER := 0.03
const HIPS_TRACK := NodePath("%GeneralSkeleton:Hips")


func _init() -> void:
	var library := AnimationLibrary.new()
	var players := {}
	for path: String in SOURCES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		get_root().add_child(scene)
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		players[player] = scene
	var windows: Dictionary[StringName, Vector2] = {}
	for clip: StringName in CLIPS:
		var source: String = CLIPS[clip][0]
		var player := _player_with(players, source)
		if player == null:
			push_error("missing source clip " + source)
			quit(1)
			return
		var animation := player.get_animation(source).duplicate(true) as Animation
		animation.resource_name = clip
		animation.loop_mode = Animation.LOOP_LINEAR if CLIPS[clip][1] else Animation.LOOP_NONE
		_pin_hips_horizontally(animation)
		library.add_animation(clip, animation)
		if clip in STRIKES:
			windows[clip] = _impact_window(player, source)
			print("%s (%s): %.2fs, impact %.3f-%.3f" % [clip, source, animation.length, windows[clip].x, windows[clip].y])
	var error := ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	print("saved %s: %d clips (%s)" % [OUTPUT, library.get_animation_list().size(), error_string(error)])
	library = load(OUTPUT)
	for set_path: String in CLIP_SETS:
		var clip_set: ClipSet = load(set_path)
		clip_set.library = library
		clip_set.impact_windows = windows
		print("updated %s (%s)" % [set_path, error_string(ResourceSaver.save(clip_set, set_path))])
	for scene: Node in players.values():
		scene.free()
	quit()


func _player_with(players: Dictionary, source: String) -> AnimationPlayer:
	for player: AnimationPlayer in players:
		if player.has_animation(source):
			return player
	return null


## No root motion: the hips keep their first-frame X/Z so the body stays on the
## fighter's capsule (the sim moves the fighter); height and rotation stay.
func _pin_hips_horizontally(animation: Animation) -> void:
	var track := animation.find_track(HIPS_TRACK, Animation.TYPE_POSITION_3D)
	if track < 0 or animation.track_get_key_count(track) == 0:
		return
	var first: Vector3 = animation.track_get_key_value(track, 0)
	for key in animation.track_get_key_count(track):
		var value: Vector3 = animation.track_get_key_value(track, key)
		animation.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))


## Time of the furthest forward reach of any hand or foot, from the source rig.
func _impact_window(player: AnimationPlayer, source: String) -> Vector2:
	var skeleton: Skeleton3D = player.get_node(player.root_node).get_node("%GeneralSkeleton")
	var length := player.get_animation(source).length
	player.play(source)
	var start_reach := {}
	var best_time := 0.0
	var best_gain := -INF
	var t := 0.0
	while t <= length:
		player.seek(t, true)
		var hips := _global_origin(skeleton, "Hips")
		for effector: String in EFFECTORS:
			var at := _global_origin(skeleton, effector)
			# Source rigs face +Z: reach is how far ahead of the hips the limb is.
			var reach := at.z - hips.z
			if not start_reach.has(effector):
				start_reach[effector] = reach
			if reach - start_reach[effector] > best_gain:
				best_gain = reach - start_reach[effector]
				best_time = t
		t += SAMPLE_STEP
	player.stop()
	return Vector2(maxf(best_time - WINDOW_BEFORE, SAMPLE_STEP), minf(best_time + WINDOW_AFTER, length))


## Bone origin in skeleton space from the local poses (the cached global poses
## only refresh on the next frame).
func _global_origin(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	var bone := skeleton.find_bone(bone_name)
	var pose := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return pose.origin
