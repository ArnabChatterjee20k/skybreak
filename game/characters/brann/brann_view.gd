class_name BrannView
extends CharacterView
## Brann's CharacterView: the shared clips plus his posed move clips, with a
## heavy procedural layer on top: a slow deep breath, a low idle sway, a small
## stone squash when hit, a forward lean, forge cracks that flare while he
## charges or is armoured, and a spring-swung beard braid and apron. His Titan
## Hammer rides on his back and the Scatter Cannon on his hip until he picks up
## a weapon. Everything is a function of FighterState and time.

const SPRING_STEP := 1.0 / 60.0
## Hit squash: stone barely gives.
const SQUASH_TICKS := 10
const SQUASH_AMOUNT := 0.12
const BLOCK_SQUASH_AMOUNT := 0.04
const BREATH_PERIOD := 3.4
const BREATH_AMOUNT := 0.025
const IDLE_SWAY := 0.035
const IDLE_SWAY_PERIOD := 2.2
const HOVER_BOB := 0.03
const HOVER_BOB_PERIOD := 2.4
const LEAN_PER_SPEED := 0.025
const LEAN_MAX := 0.32
const ROLL_PER_SPEED := 0.015
const ROLL_MAX := 0.18
const CLOTH_DRAG := 5.0
## Crack glow: resting energy, its slow pulse and the flare at full charge or armour.
const EMBER_ENERGY := 2.0
const EMBER_PULSE := 0.35
const EMBER_FLARE := 3.0
const EMBER_CHARGE_TICKS := 70
const LAYER_BONES: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest"]
## Stowed signature weapons: bone, grip position in the model's rest space,
## then tilt (about Z), pitch (about X) and spin (about the weapon's long axis), degrees,
## and an optional scale.
const STOWED := {
	Weapon.Kind.TITAN_HAMMER: [&"UpperChest", Vector3(0.36, 0.62, -0.42), 42.0, 0.0, 90.0],
	# Holstered flat on his right hip, muzzle back and a little down, well clear of the ground (#98).
	Weapon.Kind.SCATTER_CANNON: [&"Hips", Vector3(-0.5, 0.92, 0.06), 0.0, -15.0, 0.0, 0.8],
}
const STOWED_SCALE := 1.0

## His moves; each gets a posed clip timed to its ticks (BrannMoveClips).
@export var move_set: MoveSet

var _skeleton: Skeleton3D
var _springs: Array[FigureSpring] = []
var _bones: Array[int] = []
var _base: Array[Transform3D] = []
var _time := 0.0
var _spring_time := 0.0
var _ember: StandardMaterial3D
var _stowed: Array[Node3D] = []


func _ready() -> void:
	if move_set:
		clips = BrannMoveClips.clip_set(clips, move_set, model.get_node("%GeneralSkeleton") as Skeleton3D)
	super._ready()
	_skeleton = model.get_node("%GeneralSkeleton") as Skeleton3D
	for bone in LAYER_BONES:
		_bones.append(_skeleton.find_bone(bone))
	_base = _poses()
	var figure := model as BrannFigure
	var design := figure.design if figure and figure.design else BrannDesign.new()
	var tips := BrannFigure.spring_tips(design)
	_springs.append(FigureSpring.new(_skeleton, BrannFigure.BRAID_BONE, tips[BrannFigure.BRAID_BONE], 150.0, 10.0))
	_springs.append(FigureSpring.new(_skeleton, BrannFigure.APRON_BONE, tips[BrannFigure.APRON_BONE], 120.0, 11.0))
	_own_ember(figure)
	_stow_weapons()


func apply_state(fighter: FighterState, delta: float) -> void:
	_set_poses(_base)
	var frozen := fighter.hitstop_ticks > 0
	super.apply_state(fighter, delta)
	if not frozen:
		_time += delta
	_base = _poses()
	_apply_layer(defer_to_layers(procedural_layer(fighter, _time), fighter))
	_step_springs(fighter, 0.0 if frozen else delta)
	if _ember:
		_ember.emission_energy_multiplier = ember_energy(fighter, _time)
	var armed := fighter.held_weapon() != Weapon.Kind.NONE
	for node in _stowed:
		node.visible = not armed


## The procedural offsets for a state at a time, by bone:
## {bone: {"offset": Vector3, "rotation": Quaternion, "scale": Vector3}}.
## Pure: the same fighter state and time always give the same layer.
static func procedural_layer(fighter: FighterState, time: float) -> Dictionary:
	var layer := {}
	for bone in LAYER_BONES:
		layer[bone] = {"offset": Vector3.ZERO, "rotation": Quaternion.IDENTITY, "scale": Vector3.ONE}
	var breath := sin(TAU * time / BREATH_PERIOD) * BREATH_AMOUNT
	layer[&"UpperChest"].scale = Vector3(1.0 + breath, 1.0 + breath * 0.4, 1.0 + breath * 1.2)
	match fighter.state:
		FighterState.State.IDLE, FighterState.State.CHARGING:
			# A slow side-to-side weight shift, the hips dipping as they pass the middle.
			var sway := sin(TAU * time / IDLE_SWAY_PERIOD)
			layer[&"Hips"].offset = Vector3(sway * IDLE_SWAY, -absf(cos(TAU * time / IDLE_SWAY_PERIOD)) * 0.012, 0)
			layer[&"Chest"].rotation = Quaternion(Vector3.BACK, -sway * 0.03)
		FighterState.State.FLYING:
			layer[&"Hips"].offset.y = sin(TAU * time / HOVER_BOB_PERIOD) * HOVER_BOB
	var squash := _squash(fighter)
	if squash != 0.0:
		var height := 1.0 - squash
		var width := 1.0 / sqrt(maxf(height, 0.1))
		layer[&"Hips"].scale = Vector3(width, height, width)
		layer[&"Chest"].scale = Vector3(1.0 + squash * 0.3, 1.0 - squash * 0.3, 1.0 + squash * 0.3)
	layer[&"Spine"].rotation = _lean(fighter)
	return layer


## Emission of the forge cracks: a slow pulse that flares with charge and armour.
static func ember_energy(fighter: FighterState, time: float) -> float:
	var flare := 0.0
	if fighter.state == FighterState.State.CHARGING:
		flare = clampf(float(fighter.charge_ticks) / EMBER_CHARGE_TICKS, 0.0, 1.0)
	elif fighter.is_armored():
		flare = 1.0
	return EMBER_ENERGY + sin(TAU * time / BREATH_PERIOD) * EMBER_PULSE + flare * EMBER_FLARE


func _fit_specs() -> Dictionary:
	if move_set == null:
		return {}
	return MotionClips.fit_specs(BrannMoveClips.moves_of(move_set), BrannMoveClips.STYLES, BrannMoveClips.strike_point,
		clips.motion_moves)


func skeleton() -> Skeleton3D:
	return _skeleton


## The stowed signature weapons (hammer on the back, cannon on the hip).
func stowed_weapons() -> Array[Node3D]:
	return _stowed


## The view's own copy of the crack glow, so flares never touch other Branns.
func ember_material() -> StandardMaterial3D:
	return _ember


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


static func _lean(fighter: FighterState) -> Quaternion:
	var factor := 0.0
	match fighter.state:
		FighterState.State.MOVING:
			factor = 1.0
		FighterState.State.DASHING, FighterState.State.VANISHING:
			factor = 1.2
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


func _own_ember(figure: BrannFigure) -> void:
	if figure == null or figure.meshes.is_empty():
		return
	var instance := figure.meshes[0]
	for s in instance.mesh.get_surface_count():
		if instance.mesh.surface_get_name(s) == "ember":
			_ember = (instance.mesh.surface_get_material(s) as StandardMaterial3D).duplicate()
			instance.set_surface_override_material(s, _ember)


## Hangs the shared weapon models (the same ones the weapon layer draws in
## hand) on his back and hip.
func _stow_weapons() -> void:
	for kind: Weapon.Kind in STOWED:
		var entry: Array = STOWED[kind]
		var bone := _skeleton.find_bone(entry[0])
		var attachment := BoneAttachment3D.new()
		attachment.name = "Stowed%s" % String(Weapon.weapon_name(kind)).capitalize().replace(" ", "")
		attachment.bone_name = entry[0]
		_skeleton.add_child(attachment)
		var turn := Basis(Vector3.BACK, deg_to_rad(entry[2])) * Basis(Vector3.RIGHT, deg_to_rad(entry[3])) \
			* Basis(Vector3.UP, deg_to_rad(entry[4]))
		var size: float = entry[5] if entry.size() > 5 else 1.0
		var place := Transform3D(turn.scaled(Vector3.ONE * STOWED_SCALE * size), entry[1])
		var weapon := WeaponModels.build(kind)
		weapon.transform = _skeleton.get_bone_global_rest(bone).affine_inverse() * place * weapon.transform
		attachment.add_child(weapon)
		_stowed.append(attachment)


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
