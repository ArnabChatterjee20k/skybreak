extends GutTest
## QA-21: voxel Lyra's cape chain (ScarfLag + LyraCapeClearance) never pops: no bone turns more
## than QaViewChecks.POP_ANGLE in one rendered frame through runs, turnarounds, yaw wraps,
## flight, dashes, attacks and hit reacts.

const VOXEL_PATH := "res://game/characters/lyra_voxel/lyra_voxel.tscn"
const CLASSIC_PATH := "res://game/characters/lyra/lyra.tscn"
const LYRA_MOVES := "res://game/combat/moves/lyra/lyra_move_set.tres"
const FRAME := 1.0 / 60.0
const CAPE_BONES: Array[StringName] = [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]

var _body: Node3D
var _view: CharacterView
var _fighter: FighterState
var _skeleton: Skeleton3D
var _poses: Array[Transform3D] = []
var _rotations: Array[Quaternion] = []
## Pops counted as QaViewChecks does (non-finger bones, settled states), and the worst turns.
var _pops := 0
var _cape_pops := 0
var _worst := 0.0
var _worst_detail := ""


func _load(path: String) -> void:
	_body = Node3D.new()
	add_child_autofree(_body)
	_view = (load(path) as PackedScene).instantiate() as CharacterView
	_body.add_child(_view)
	_fighter = FighterState.new()
	_skeleton = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_skeleton.skeleton_updated.connect(func() -> void: QaViewChecks._remember_pose(_skeleton, _poses))
	_poses.clear()
	_rotations.clear()
	_pops = 0
	_cape_pops = 0
	_worst = 0.0


## One rendered frame: the sim state moves on a tick, the body follows it, the view poses.
func _frame(state: FighterState.State, yaw: float, velocity: Vector3, height := 1.0) -> void:
	if _fighter.state != state:
		_fighter.state = state
		_fighter.state_ticks = 0
	else:
		_fighter.state_ticks += 1
	_fighter.facing_yaw = wrapf(yaw, -PI, PI)
	_fighter.velocity = velocity
	_fighter.position += velocity * FRAME
	_fighter.position.y = height
	if state == FighterState.State.DASHING:
		_fighter.dash_direction = velocity.normalized()
	_body.position = _fighter.position
	_body.basis = Basis(Vector3.UP, _fighter.facing_yaw)
	_view.apply_state(_fighter, FRAME)
	await get_tree().process_frame
	_measure()


## Same measure as QaViewChecks._check_rig on the pose the skeleton last rendered.
func _measure() -> void:
	if _poses.size() != _skeleton.get_bone_count():
		return
	var fresh := _rotations.is_empty()
	var worst := 0.0
	var worst_bone := -1
	for bone in _poses.size():
		var rotation := _poses[bone].basis.get_rotation_quaternion()
		if fresh:
			_rotations.append(rotation)
			continue
		var angle := _rotations[bone].angle_to(rotation)
		_rotations[bone] = rotation
		if not QaViewChecks._is_finger(_skeleton.get_bone_name(bone)) and angle > worst:
			worst = angle
			worst_bone = bone
	var settled := _fighter.state != FighterState.State.VANISHING and _fighter.state_ticks > 1
	if worst > QaViewChecks.POP_ANGLE and settled:
		_pops += 1
		if _skeleton.get_bone_name(worst_bone) in CAPE_BONES:
			_cape_pops += 1
	if worst > _worst:
		_worst = worst
		_worst_detail = "%s %.2f rad in %s" % [_skeleton.get_bone_name(worst_bone), worst,
			FighterState.State.find_key(_fighter.state)]


func _forward(yaw: float, speed: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3.BACK * speed


## Runs, whips round, wraps the yaw past +-PI, flies, dashes, attacks and takes hits.
func _drive() -> void:
	var s := FighterState.State
	for i in 30:
		await _frame(s.IDLE, 0.0, Vector3.ZERO)
	for i in 40:
		await _frame(s.MOVING, 0.0, _forward(0.0, 8.0))
	# Rapid turnarounds on the ground.
	var yaw := 0.0
	for i in 72:
		if i % 6 == 0:
			yaw += PI
		await _frame(s.MOVING, yaw, _forward(yaw, 8.0))
	# Spinning steadily through +-PI, then back the other way.
	yaw = 2.6
	for i in 90:
		yaw += 0.12
		await _frame(s.MOVING, yaw, _forward(yaw, 8.0))
	for i in 90:
		yaw -= 0.12
		await _frame(s.MOVING, yaw, _forward(yaw, 8.0))
	# Flight: cruise, climb and dive, and turnarounds in the air.
	for i in 60:
		await _frame(s.FLYING, yaw, _forward(yaw, 14.0) + Vector3.UP * 4.0, 2.0 + i * 0.05)
	for i in 72:
		if i % 8 == 0:
			yaw += PI
		await _frame(s.FLYING, yaw, _forward(yaw, 14.0) + Vector3.DOWN * 3.0, 5.0)
	# Dashes in alternating directions, air and ground.
	for d in 8:
		var dir := yaw + PI * 0.5 * d
		for i in 14:
			await _frame(s.DASHING, yaw, _forward(dir, 30.0), 5.0 if d % 2 == 0 else 1.0)
		for i in 6:
			await _frame(s.FLYING if d % 2 == 0 else s.IDLE, yaw, Vector3.ZERO, 5.0 if d % 2 == 0 else 1.0)
	# Attacks and hit reacts.
	var moves := LyraMoveClips.moves_of(load(LYRA_MOVES) as MoveSet)
	for move: MoveData in moves.slice(0, 6):
		_fighter.move = move
		for i in move.total_ticks():
			_fighter.move_tick = i
			await _frame(s.ATTACKING, yaw, Vector3.ZERO)
		_fighter.move = null
		for i in 20:
			await _frame(s.HITSTUN, yaw + PI, _forward(yaw, -6.0))


func test_voxel_lyras_cape_never_pops() -> void:
	_load(VOXEL_PATH)
	await _drive()
	gut.p("voxel Lyra: %d pops (%d on the cape), worst %s" % [_pops, _cape_pops, _worst_detail])
	assert_eq(_cape_pops, 0, "no cape bone turns more than %.1f rad in a frame (%s)" % [QaViewChecks.POP_ANGLE, _worst_detail])
	assert_eq(_pops, 0, "no bone pops (%s)" % _worst_detail)


func test_classic_lyra_does_not_pop_either() -> void:
	_load(CLASSIC_PATH)
	await _drive()
	gut.p("classic Lyra: %d pops, worst %s" % [_pops, _worst_detail])
	assert_eq(_pops, 0, "no bone pops (%s)" % _worst_detail)
