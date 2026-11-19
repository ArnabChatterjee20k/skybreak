extends GutTest
## T-D22e: grounded soles meet the ground under them (QA-12a floating stance and landings, QA-12b
## steep runs) without pops.

const MODEL_PATH := "res://game/characters/kael_chunky/kael_chunky.glb"
const KAEL_PATH := "res://game/characters/kael_chunky/kael_chunky.tscn"
const DT := 1.0 / 60.0
const TOLERANCE := 0.01

var _layers: MotionLayers
var _rest: Array[Quaternion] = []
var _hips := Vector3.ZERO
var _feet: Array[int] = []
var _rest_ankle := 0.0


func before_each() -> void:
	var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	var rests: Array[Transform3D] = []
	_rest.clear()
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
		parents.append(skeleton.get_bone_parent(i))
		rests.append(skeleton.get_bone_rest(i))
		_rest.append(skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
	_hips = skeleton.get_bone_rest(skeleton.find_bone(&"Hips")).origin
	_feet = [skeleton.find_bone(&"LeftFoot"), skeleton.find_bone(&"RightFoot")]
	_rest_ankle = skeleton.get_bone_global_rest(_feet[0]).origin.y
	model.free()
	_layers = MotionLayers.new()
	_layers.setup_bones(names, parents, rests)


func after_each() -> void:
	_layers.free()


## Each sole's height over the ground (ground(x) gives the floor height at skeleton-space x).
func _gaps(pose: Array[Quaternion], hips: Vector3, ground: Callable) -> Array[float]:
	var world: Array = _layers._world(pose, hips)
	var out: Array[float] = []
	for foot in _feet:
		var ankle := (world[foot] as Transform3D).origin
		out.append(ankle.y - _rest_ankle - float(ground.call(ankle)))
	return out


func _flat(_at: Vector3) -> float:
	return 0.0


## A 35 degree slope rising toward +X.
func _slope(at: Vector3) -> float:
	return at.x * tan(deg_to_rad(35.0))


func _ground_at(world: Vector3, ground: Callable) -> float:
	return ground.call(world)


func test_a_standing_pose_floating_above_the_floor_is_put_back_on_it() -> void:
	_layers.stance = true
	_layers.foot_lock = true
	var floating := _hips + Vector3(0, 0.12, 0)
	var pose: Array[Quaternion] = []
	var hips := Vector3.ZERO
	for tick in 10:
		pose = _rest.duplicate()
		hips = _layers.process_pose(pose, floating, DT)
	var gaps := _gaps(pose, hips, _flat)
	assert_almost_eq(minf(gaps[0], gaps[1]), 0.0, TOLERANCE, "the lowest sole is on the floor")


func test_a_standing_pose_below_the_floor_is_lifted_onto_it() -> void:
	_layers.stance = true
	var sunk := _hips - Vector3(0, 0.08, 0)
	var pose: Array[Quaternion] = []
	var hips := Vector3.ZERO
	for tick in 10:
		pose = _rest.duplicate()
		hips = _layers.process_pose(pose, sunk, DT)
	var gaps := _gaps(pose, hips, _flat)
	assert_almost_eq(minf(gaps[0], gaps[1]), 0.0, TOLERANCE, "the lowest sole is on the floor, not in it")


func test_feet_never_sink_into_a_steep_slope_while_running() -> void:
	_layers.ground_at = _ground_at.bind(_slope)
	var worst := INF
	var straight := true
	for tick in 120:
		# A stride: the legs swing through the floor, which rises toward one foot.
		var pose := _rest.duplicate()
		var swing := sin(tick * 0.4) * 0.6
		for side in 2:
			var up := _layers._index[MotionLayers.LEGS[side][0]] as int
			pose[up] = Quaternion(Vector3.RIGHT, swing * (1.0 if side == 0 else -1.0)) * pose[up]
		var hips := _layers.process_pose(pose, _hips - Vector3(0, 0.05, 0), DT)
		var gaps := _gaps(pose, hips, _slope)
		worst = minf(worst, minf(gaps[0], gaps[1]))
	assert_gt(worst, -TOLERANCE, "no sole below the slope (worst %.3f m)" % worst)


func test_a_planted_foot_tilts_to_the_slope_but_no_further_than_the_limit() -> void:
	_layers.stance = true
	_layers.foot_lock = true
	_layers.ground_at = _ground_at.bind(_slope)
	var pose: Array[Quaternion] = []
	var hips := Vector3.ZERO
	for tick in 10:
		pose = _rest.duplicate()
		hips = _layers.process_pose(pose, _hips, DT)
	var rest_world: Array = _layers._world(_rest.duplicate(), _hips)
	var world: Array = _layers._world(pose, hips)
	var tilts: Array[float] = []
	for foot in _feet:
		var before := (rest_world[foot] as Transform3D).basis.get_rotation_quaternion()
		var after := (world[foot] as Transform3D).basis.get_rotation_quaternion()
		tilts.append(before.angle_to(after))
	var most := maxf(tilts[0], tilts[1])
	assert_gt(most, deg_to_rad(10.0), "a planted foot follows the slope")
	assert_lt(most, MotionLayers.MAX_FOOT_TILT + deg_to_rad(12.0), "within the tilt limit (plus the leg solve)")


func test_the_knee_ik_never_straightens_past_its_reach() -> void:
	_layers.stance = true
	_layers.ground_at = func(_at: Vector3) -> float: return -2.0
	var pose: Array[Quaternion] = []
	var hips := Vector3.ZERO
	for tick in 10:
		pose = _rest.duplicate()
		hips = _layers.process_pose(pose, _hips, DT)
	var world: Array = _layers._world(pose, hips)
	for side in 2:
		var up: int = _layers._index[MotionLayers.LEGS[side][0]]
		var lo: int = _layers._index[MotionLayers.LEGS[side][1]]
		var foot: int = _layers._index[MotionLayers.LEGS[side][2]]
		var l1 := (world[up] as Transform3D).origin.distance_to((world[lo] as Transform3D).origin)
		var l2 := (world[lo] as Transform3D).origin.distance_to((world[foot] as Transform3D).origin)
		var reach := (world[up] as Transform3D).origin.distance_to((world[foot] as Transform3D).origin)
		assert_lt(reach, (l1 + l2) * MotionLayers.KNEE_REACH + 0.002, "leg %d not hyperextended" % side)


func test_grounding_turns_no_bone_past_the_pop_limit_when_a_landing_settles() -> void:
	_layers.flying = true
	_layers.velocity = Vector3(0, -20, 10)
	var pose: Array[Quaternion] = []
	for tick in 60:
		pose = _rest.duplicate()
		_layers.process_pose(pose, _hips, DT)
	_layers.brace = true
	_layers.flying = false
	for tick in 12:
		pose = _rest.duplicate()
		_layers.process_pose(pose, _hips, DT)
	_layers.brace = false
	_layers.stance = true
	_layers.foot_lock = true
	_layers.velocity = Vector3.ZERO
	_layers.land(2.0)
	var last := pose
	var worst := 0.0
	for tick in 60:
		pose = _rest.duplicate()
		_layers.process_pose(pose, _hips, DT)
		for i in pose.size():
			worst = maxf(worst, _layers._world_rotation(pose, i).angle_to(_layers._world_rotation(last, i)))
		last = pose
	assert_lt(worst, QaViewChecks.POP_ANGLE, "no pop as the landing settles")


func test_a_fighter_coming_down_braces_with_the_landing_clip_before_touchdown() -> void:
	var view := (load(KAEL_PATH) as PackedScene).instantiate() as CharacterView
	add_child_autofree(view)
	var fighter := FighterState.new()
	fighter.state = FighterState.State.FALLING
	fighter.stand_height = 1.0
	fighter.position = Vector3(0, 6.0, 0)
	fighter.velocity = Vector3(0, -8.0, 0)
	view.apply_state(fighter, DT)
	assert_ne(view.current_clip(), &"land", "high up it still falls")
	fighter.position = Vector3(0, 1.0 + 8.0 * CharacterView.LANDING_LEAD_SECONDS * 0.5, 0)
	view.apply_state(fighter, DT)
	assert_eq(view.current_clip(), &"land", "just above the floor it braces for the landing")
	assert_true(view.layers.brace, "and the flight lean eases out fast")
