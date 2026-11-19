class_name VexaView
extends CharacterView
## Vexa's CharacterView: the shared clips plus a procedural layer on top
## ("animation as math"): breathing and idle bob, squash and stretch when hit,
## a speed lean, snapped dash poses for afterimages and spring-lagged hood
## points and sash tails. Everything is a function of FighterState and time.

const SPRING_STEP := 1.0 / 60.0
## Hit squash: ticks it lasts and how far it squashes (fraction of height).
const SQUASH_TICKS := 9
const SQUASH_AMOUNT := 0.22
const BLOCK_SQUASH_AMOUNT := 0.07
const BREATH_PERIOD := 2.6
const BREATH_AMOUNT := 0.018
const IDLE_BOB := 0.012
const IDLE_BOB_PERIOD := 1.3
const HOVER_BOB := 0.035
const HOVER_BOB_PERIOD := 1.8
## Spine lean per m/s of forward and sideways speed, and its limits (radians).
const LEAN_PER_SPEED := 0.03
const LEAN_MAX := 0.42
const ROLL_PER_SPEED := 0.02
const ROLL_MAX := 0.25
## Air drag on the cloth: acceleration per m/s of the fighter's own speed.
const CLOTH_DRAG := 6.0
const LAYER_BONES: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest"]
const SNAP_STATES: Array[FighterState.State] = [FighterState.State.DASHING, FighterState.State.VANISHING]

## Pose (seconds into the dash clip) that dashes and vanishes snap to and hold,
## so an afterimage copy of it reads crisply.
@export var dash_snap_time := 0.3

var _skeleton: Skeleton3D
var _springs: Array[FigureSpring] = []
var _bones: Array[int] = []
var _base: Array[Transform3D] = []
var _time := 0.0
var _spring_time := 0.0


func _ready() -> void:
	super._ready()
	_skeleton = model.get_node("%GeneralSkeleton") as Skeleton3D
	for bone in LAYER_BONES:
		_bones.append(_skeleton.find_bone(bone))
	_base = _poses()
	var figure := model as VexaFigure
	var design := figure.design if figure and figure.design else VexaDesign.new()
	var tips := VexaFigure.spring_tips(design)
	for bone: StringName in VexaFigure.HOOD_POINTS:
		_springs.append(FigureSpring.new(_skeleton, bone, tips[bone], 260.0, 15.0))
	for bone: StringName in VexaFigure.SASH_BONES:
		_springs.append(FigureSpring.new(_skeleton, bone, tips[bone], 90.0, 8.0))


func apply_state(fighter: FighterState, delta: float) -> void:
	_set_poses(_base)
	var frozen := fighter.hitstop_ticks > 0
	if fighter.state in SNAP_STATES:
		_snap(fighter)
	else:
		super.apply_state(fighter, delta)
	if not frozen:
		_time += delta
	_base = _poses()
	_apply_layer(procedural_layer(fighter, _time))
	_step_springs(fighter, 0.0 if frozen else delta)


## The procedural offsets for a state at a time, by bone:
## {bone: {"offset": Vector3, "rotation": Quaternion, "scale": Vector3}}.
## Pure: the same fighter state and time always give the same layer.
static func procedural_layer(fighter: FighterState, time: float) -> Dictionary:
	var layer := {}
	for bone in LAYER_BONES:
		layer[bone] = {"offset": Vector3.ZERO, "rotation": Quaternion.IDENTITY, "scale": Vector3.ONE}
	var breath := sin(TAU * time / BREATH_PERIOD) * BREATH_AMOUNT
	layer[&"UpperChest"].scale = Vector3(1.0 + breath, 1.0 + breath * 0.5, 1.0 + breath)
	match fighter.state:
		FighterState.State.IDLE, FighterState.State.CHARGING:
			layer[&"Hips"].offset.y = sin(TAU * time / IDLE_BOB_PERIOD) * IDLE_BOB
		FighterState.State.FLYING:
			layer[&"Hips"].offset.y = sin(TAU * time / HOVER_BOB_PERIOD) * HOVER_BOB
	var squash := _squash(fighter)
	if squash != 0.0:
		var height := 1.0 - squash
		var width := 1.0 / sqrt(maxf(height, 0.1))
		layer[&"Hips"].scale = Vector3(width, height, width)
		layer[&"Chest"].scale = Vector3(1.0 + squash * 0.4, 1.0 - squash * 0.4, 1.0 + squash * 0.4)
	layer[&"Spine"].rotation = _lean(fighter)
	return layer


## Global bone poses right now, for an afterimage to copy.
func afterimage_pose() -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone in _skeleton.get_bone_count():
		poses.append(_skeleton.get_bone_global_pose(bone))
	return poses


func skeleton() -> Skeleton3D:
	return _skeleton


## Squash (positive) then stretch (negative) over the first ticks of a hit.
static func _squash(fighter: FighterState) -> float:
	var amount := 0.0
	match fighter.state:
		FighterState.State.HITSTUN:
			amount = SQUASH_AMOUNT
		FighterState.State.BLOCKSTUN:
			amount = BLOCK_SQUASH_AMOUNT
		_:
			return 0.0
	var t := float(fighter.state_ticks) / SQUASH_TICKS
	if t <= 0.0 or t >= 1.0:
		return 0.0
	return amount * sin(TAU * t) * (1.0 - t)


## Leans into the fighter's own speed: forward pitch and a bank into sideways motion.
static func _lean(fighter: FighterState) -> Quaternion:
	var factor := 0.0
	match fighter.state:
		FighterState.State.MOVING:
			factor = 1.0
		FighterState.State.DASHING, FighterState.State.VANISHING:
			factor = 1.3
		FighterState.State.FLYING, FighterState.State.FALLING:
			factor = 0.5
		_:
			return Quaternion.IDENTITY
	var local := _model_velocity(fighter)
	var pitch := clampf(local.z * LEAN_PER_SPEED * factor, -LEAN_MAX, LEAN_MAX)
	var roll := clampf(-local.x * ROLL_PER_SPEED * factor, -ROLL_MAX, ROLL_MAX)
	return Quaternion(Vector3.BACK, roll) * Quaternion(Vector3.RIGHT, pitch)


## Velocity in the model's space (the model faces +Z inside the view).
static func _model_velocity(fighter: FighterState) -> Vector3:
	var local := Basis(Vector3.UP, -fighter.facing_yaw) * fighter.velocity
	return Vector3(-local.x, local.y, -local.z)


## Dashes and vanishes jump straight to one held pose of the dash clip.
func _snap(fighter: FighterState) -> void:
	_state = fighter.state
	_state_ticks = fighter.state_ticks
	_move_id = &""
	var clip := clips.clip_for_state(StringName(FighterState.State.find_key(fighter.state)))
	if clip != _clip:
		_play(clip, 0.0)
	_player.speed_scale = 1.0
	_player.seek(minf(dash_snap_time, clips.library.get_animation(clip).length), true)


func _apply_layer(layer: Dictionary) -> void:
	for i in LAYER_BONES.size():
		var bone := _bones[i]
		var entry: Dictionary = layer[LAYER_BONES[i]]
		_skeleton.set_bone_pose_position(bone, _base[i].origin + entry.offset)
		_skeleton.set_bone_pose_rotation(bone, _base[i].basis.get_rotation_quaternion() * entry.rotation)
		_skeleton.set_bone_pose_scale(bone, _base[i].basis.get_scale() * entry.scale)


func _step_springs(fighter: FighterState, delta: float) -> void:
	var push := -_model_velocity(fighter) * CLOTH_DRAG
	_spring_time += delta
	var stepped := false
	while _spring_time >= SPRING_STEP:
		_spring_time -= SPRING_STEP
		stepped = true
		for spring in _springs:
			spring.step(_skeleton, SPRING_STEP, push)
	if not stepped:
		for spring in _springs:
			spring.pose(_skeleton)


func _poses() -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone in _bones:
		poses.append(Transform3D(Basis(_skeleton.get_bone_pose_rotation(bone)).scaled(
			_skeleton.get_bone_pose_scale(bone)), _skeleton.get_bone_pose_position(bone)))
	return poses


func _set_poses(poses: Array[Transform3D]) -> void:
	for i in _bones.size():
		_skeleton.set_bone_pose_position(_bones[i], poses[i].origin)
		_skeleton.set_bone_pose_rotation(_bones[i], poses[i].basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(_bones[i], poses[i].basis.get_scale())
