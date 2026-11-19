extends SceneTree
## Bakes the keyframe poses in FightingClips into Animation clips (60 fps)
## and adds them to the shared humanoid clip library, so any character on the
## humanoid profile can play them. Writes each strike's impact window into
## the ClipSets. Run after `--import`:
## godot --headless --path . -s res://game/characters/tools/author_clips.gd

const LIBRARY_PATH := "res://game/characters/animations/humanoid_clips.res"
const CLIP_SETS := ["res://game/characters/kael/kael_clip_set.tres"]
## Gives bone lengths and soles for grounding; rotations use the profile rest.
const REFERENCE_PATH := "res://game/characters/kael/kael.tscn"
const FPS := 60.0
## Planted knees are solved within this many degrees of the authored bend.
const KNEE_SEARCH := 70.0
const KNEE_MAX := 155.0
## Grounding reports a planted foot further off the floor than this (metres).
const FLOAT_WARNING := 0.02
const PLANT_TOLERANCE := 0.002
const PLANT_ATTEMPTS := 6
const HIPS := &"Hips"
const SIDES := {"L": "Left", "R": "Right"}

var _skeleton: Skeleton3D
## Foot side -> sole points: [[bone, point in the bone's frame], ...].
var _soles := {}
var _hips_rest := Vector3.ZERO


func _init() -> void:
	var reference: CharacterView = (load(REFERENCE_PATH) as PackedScene).instantiate()
	get_root().add_child(reference)
	_skeleton = reference.model.get_node("%GeneralSkeleton")
	_read_rest()
	var library: AnimationLibrary = load(LIBRARY_PATH)
	var windows: Dictionary[StringName, Vector2] = {}
	var definitions := FightingClips.definitions()
	for clip: StringName in definitions:
		var definition: Dictionary = definitions[clip]
		var animation := _bake(clip, definition)
		if library.has_animation(clip):
			library.remove_animation(clip)
		library.add_animation(clip, animation)
		if definition.has("impact"):
			var impact: Vector2i = definition.impact
			windows[clip] = Vector2(impact.x / FPS, impact.y / FPS)
		print("%s: %d frames%s" % [clip, definition.frames,
			", impact %d-%d" % [definition.impact.x, definition.impact.y] if definition.has("impact") else ""])
	var error := ResourceSaver.save(library, LIBRARY_PATH, ResourceSaver.FLAG_COMPRESS)
	print("saved %s: %d clips (%s)" % [LIBRARY_PATH, library.get_animation_list().size(), error_string(error)])
	for set_path: String in CLIP_SETS:
		var clip_set: ClipSet = load(set_path)
		clip_set.library = library
		clip_set.impact_windows.merge(windows, true)
		print("updated %s (%s)" % [set_path, error_string(ResourceSaver.save(clip_set, set_path))])
	reference.free()
	quit()


func _read_rest() -> void:
	for bone in FightingClips.animated_bones():
		var rest := _skeleton.get_bone_rest(_skeleton.find_bone(bone)).basis
		if not rest.is_equal_approx(FightingClips.profile_rest(bone)[0]):
			push_warning("%s rest differs from the profile" % bone)
	_hips_rest = _skeleton.get_bone_rest(_skeleton.find_bone(HIPS)).origin
	for foot: String in SIDES:
		_soles[foot] = FightingClips.sole_points(_skeleton, SIDES[foot])


func _bake(clip: StringName, definition: Dictionary) -> Animation:
	var animation := Animation.new()
	animation.resource_name = clip
	var frames: int = definition.frames
	var loop: bool = definition.get("loop", false)
	animation.length = frames / FPS
	animation.step = 1.0 / FPS
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var bones := FightingClips.animated_bones()
	var tracks := {}
	for bone in bones:
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%GeneralSkeleton:" + bone))
		tracks[bone] = track
	var hips_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hips_track, NodePath("%GeneralSkeleton:Hips"))
	var worst_float := 0.0
	var worst_frame := 0
	for frame in (frames if loop else frames + 1):
		var sample := _sample(definition, frame)
		var body: Dictionary = sample.body
		var hips_y := _hips_rest.y - float(sample.drop)
		if definition.get("grounded", false):
			# A planted leg that cannot reach the floor lowers the hips.
			for attempt in PLANT_ATTEMPTS:
				var gap := 0.0
				for foot: String in sample.plant:
					gap = maxf(gap, _plant(body, foot, hips_y))
				if gap <= PLANT_TOLERANCE or attempt == PLANT_ATTEMPTS - 1:
					if gap > worst_float:
						worst_float = gap
						worst_frame = frame
					break
				hips_y -= gap
			hips_y += maxf(-_lowest_sole(body, hips_y), 0.0)
		var time := frame / FPS
		for bone in bones:
			animation.rotation_track_insert_key(tracks[bone], time, FightingClips.to_local(bone, body.get(bone, Basis())))
		var hips := Vector3(_hips_rest.x, hips_y, _hips_rest.z) / _skeleton.motion_scale
		animation.position_track_insert_key(hips_track, time, hips)
	if worst_float > FLOAT_WARNING:
		push_warning("%s: a planted foot floats %.3f m at frame %d" % [clip, worst_float, worst_frame])
	return animation


## Body-axes pose at a frame: {body: {bone: Basis}, drop, plant}.
func _sample(definition: Dictionary, frame: int) -> Dictionary:
	var keys: Array = definition.keys
	var next := 0
	while next < keys.size() - 1 and keys[next].f <= frame:
		next += 1
	var from: Dictionary = keys[maxi(next - 1, 0)]
	var to: Dictionary = keys[next]
	var span: float = maxf(to.f - from.f, 1)
	var weight := _ease(clampf((frame - from.f) / span, 0.0, 1.0), to.ease)
	var body := {}
	for bone in FightingClips.animated_bones():
		var a := _body_rotation(bone, from.pose.get(bone))
		var b := _body_rotation(bone, to.pose.get(bone))
		body[bone] = Basis(a.get_rotation_quaternion().slerp(b.get_rotation_quaternion(), weight))
	_add_shake(definition, frame, body)
	var plant: Array = (from if weight < 0.5 else to).pose.get("plant", ["L", "R"])
	return {
		"body": body,
		"drop": lerpf(from.pose.get("drop", 0.0), to.pose.get("drop", 0.0), weight),
		"plant": plant,
	}


func _ease(t: float, ease_name: String) -> float:
	match ease_name:
		"linear": return t
		"in": return t * t
		"out": return 1.0 - (1.0 - t) * (1.0 - t)
		"snap": return 1.0 - pow(1.0 - t, 4.0)
	return t * t * (3.0 - 2.0 * t)


## Euler degrees (Y * X * Z, plus an optional twist w about the bone's rest
## direction, applied first) to a rotation in body axes.
func _body_rotation(bone: StringName, value: Variant) -> Basis:
	if value == null:
		return Basis()
	var euler := Vector3(value.x, value.y, value.z)
	var rotation := Basis.from_euler(euler * PI / 180.0, EULER_ORDER_YXZ)
	if value is Vector4 and value.w != 0.0:
		var direction: Vector3 = FightingClips.profile_rest(bone)[1] * Vector3.UP
		rotation = rotation * Basis(direction.normalized(), deg_to_rad(value.w))
	return rotation


## A trembling loop: two sines per axis with whole cycles per loop.
func _add_shake(definition: Dictionary, frame: int, body: Dictionary) -> void:
	var shake: Dictionary = definition.get("shake", {})
	var rates: Array = definition.get("shake_hz", [11, 17])
	var t := frame / FPS
	var seed := 0
	for bone: String in shake:
		seed += 1
		var amount := deg_to_rad(shake[bone])
		var wobble := Vector3.ZERO
		for axis in 3:
			var phase := seed * 1.7 + axis * 2.3
			wobble[axis] = amount * (0.6 * sin(TAU * rates[0] * t + phase) + 0.4 * sin(TAU * rates[1] * t + phase * 1.3))
		body[bone] = Basis.from_euler(wobble) * body[bone]


## Bends a planted leg's knee (keeping the foot's angle) until its sole
## touches the floor. Returns how far it stays off the floor.
func _plant(body: Dictionary, foot: String, hips_y: float) -> float:
	var side: String = SIDES[foot]
	var knee_bone := StringName(side + "LowerLeg")
	var foot_bone := StringName(side + "Foot")
	var knee: Basis = body[knee_bone]
	var ankle: Basis = body[foot_bone]
	var bend := rad_to_deg(knee.get_euler(EULER_ORDER_YXZ).x)
	var best := 0.0
	var best_gap := INF
	var step := 1.0
	var low := maxf(-KNEE_SEARCH, -bend)
	var high := minf(KNEE_SEARCH, KNEE_MAX - bend)
	for pass_index in 2:
		var change := low
		while change <= high:
			body[knee_bone] = Basis(Vector3.RIGHT, deg_to_rad(change)) * knee
			body[foot_bone] = Basis(Vector3.RIGHT, deg_to_rad(-change)) * ankle
			var gap := absf(_sole_height(body, foot, hips_y))
			if gap < best_gap - 0.0005 or (absf(gap - best_gap) <= 0.0005 and absf(change) < absf(best)):
				best_gap = gap
				best = change
			change += step
		low = maxf(best - step, low)
		high = minf(best + step, high)
		step = 0.1
	body[knee_bone] = Basis(Vector3.RIGHT, deg_to_rad(best)) * knee
	body[foot_bone] = Basis(Vector3.RIGHT, deg_to_rad(-best)) * ankle
	return _sole_height(body, foot, hips_y)


func _lowest_sole(body: Dictionary, hips_y: float) -> float:
	return minf(_sole_height(body, "L", hips_y), _sole_height(body, "R", hips_y))


## Height of a foot's lowest sole point above the floor, in metres.
func _sole_height(body: Dictionary, foot: String, hips_y: float) -> float:
	var side: String = SIDES[foot]
	var hips := Transform3D(Basis(FightingClips.to_local(HIPS, body[HIPS])), Vector3(_hips_rest.x, hips_y, _hips_rest.z))
	var globals := {HIPS: hips}
	var chain: Array[StringName] = [StringName(side + "UpperLeg"), StringName(side + "LowerLeg"),
		StringName(side + "Foot"), StringName(side + "Toes")]
	var parent := hips
	for bone in chain:
		var rest_origin := _skeleton.get_bone_rest(_skeleton.find_bone(bone)).origin
		parent = parent * Transform3D(Basis(FightingClips.to_local(bone, body[bone])), rest_origin)
		globals[bone] = parent
	var lowest := INF
	for sole: Array in _soles[foot]:
		lowest = minf(lowest, ((globals[StringName(sole[0])] as Transform3D) * (sole[1] as Vector3)).y)
	return lowest
