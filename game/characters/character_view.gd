class_name CharacterView
extends Node3D
## Animates one fighter's model from sim state. A pure animation node: it sits
## under FighterView's body node, never moves or turns itself and uses no root
## motion. Origin at the capsule centre (1 m above the feet), facing -Z.
## One generic script; each character is a scene that sets clips and the model.
## With clips.motion set it plays mocap (MotionSlots picks the clip, ClipSet clips are the
## fallback per slot), switches clips by inertialization and runs MotionLayers live on top.
## Everything here reads the sim; nothing is written back.

## Hover clip below this speed (m/s), fast-flight clip above it.
const FLY_FAST_SPEED := 14.0
## Run speed (m/s) at which the run clip plays at normal speed.
const RUN_CLIP_SPEED := 9.0
const RUN_SPEED_SCALE_MIN := 0.6
const RUN_SPEED_SCALE_MAX := 1.6
## Stun clips are sped up or slowed to fill the stun, within these limits.
const STUN_SPEED_SCALE_MIN := 0.5
const STUN_SPEED_SCALE_MAX := 2.5
const TICK_SECONDS := 1.0 / 60.0
const ENERGY_COLOR_PARAM := &"rim_energy_color"
const ENERGY_MIX_PARAM := &"rim_energy_mix"
const LIBRARY_NAME := &"humanoid"
const MOTION_LIBRARY_NAME := &"motion"
## Ground clips play this much faster than their stun fill rate allows, within these limits.
const LOCOMOTION_SCALE_MIN := 0.6
const LOCOMOTION_SCALE_MAX := 2.2
## Share of the knockdown spent falling to the lying pose; the rest gets up.
const KO_FALL_SHARE := 0.4
## Share of the get-up time by which the body stands in its stance (the rest settles).
const GET_UP_DONE := 0.9
## Fraction of ko_fall at which the body lies flat (it holds from there).
const KO_LIE_FRACTION := 0.8
## Idle turns wider than this (radians) step the feet round with turn_step.
const TURN_STEP_ANGLE := deg_to_rad(45.0)
const TURN_STEP_SPEED := 1.6
## Flinch strength per hit kind.
const FLINCH_BLOCK := 0.5
const FLINCH_HIT := 1.0
const FLINCH_KNOCKBACK := 1.8
const FLINCH_KO := 2.4
## Height (capsule centre) above which a fighter counts as airborne; the sim
## stands fighters at MovementTuning.ground_height.
const AIRBORNE_MARGIN := 0.05
static var _ground_height := MovementTuning.new().ground_height
## How much of a one-hand attack follows the swing arc rather than the clip.
const SWING_WEIGHT := 0.85
## How much of the hold a weapon keeps during hit reactions.
const REACTION_HOLD_WEIGHT := 0.6
## Knocked-out states: they play the knockdown fall unless the clip set maps them.
const KO_STATES: Array[int] = [FighterState.State.KO_FALL, FighterState.State.KO_DOWN]

@export var clips: ClipSet
## The model's root (holds the retargeted %GeneralSkeleton).
@export var model: Node3D

var _player: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _clip := &""
var _state := -1
var _state_ticks := 0
var _move_id := &""
var _move_tick := -1
var _tick_seconds := 0.0
## Live realism layer (null without clips.motion).
var layers: MotionLayers
## This legend's body capsules (T-D30), measured from its rest mesh.
var body: BodyCapsules
var _weapon_kind := Weapon.Kind.NONE
var _motion: MotionLibrary
var _motion_windows: Dictionary[StringName, Vector2] = {}
var _motion_speeds := {}
var _playing_motion := false
var _airborne := false
var _fall_speed := 0.0
var _landing := &""
var _look_world := Vector3.ZERO
var _look_weight := 0.0
## The zone's floor, Callable(x, z, from_y) -> world height; found on the match's sim when unset.
var ground_height: Callable
var _ground_searched := false
## Motion personality (clips.motion_profile, or the defaults).
var profile: MotionProfile
## Move id -> fitted motion clip, merged over clips.motion_moves.
var _move_overrides: Dictionary = {}
var _turn_yaw := 0.0
var _turning := false
var _impact_move := &""


func _ready() -> void:
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(_player)
	_player.root_node = _player.get_path_to(model)
	_player.add_animation_library(LIBRARY_NAME, clips.library)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	if clips.motion != null:
		_setup_motion()
	else:
		_setup_layers(false)
	_play(clips.clip_for_state(&"IDLE"), 0.0)


func _setup_motion() -> void:
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	_motion = MotionClips.for_skeleton(MotionClips.build(clips.motion, skeleton), skeleton)
	_motion_windows = MotionClips.impact_windows(_motion)
	_move_overrides = clips.motion_moves.duplicate()
	var specs := _fit_specs()
	_motion = MotionClips.fitted(_motion, skeleton, specs, "%s|%s" % [scene_file_path, clips.resource_path])
	for id: StringName in specs:
		var move: MoveData = specs[id].move
		_move_overrides[id] = StringName("fit_%s" % id)
		_motion_windows[_move_overrides[id]] = Vector2(move.startup_ticks, move.recovery_start_tick()) * TICK_SECONDS
	_player.add_animation_library(MOTION_LIBRARY_NAME, _motion)
	_setup_layers(true)


## The live layers; without mocap only the weapon-arm and foot IK stages run.
func _setup_layers(body_layers: bool) -> void:
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	profile = clips.motion_profile if clips.motion_profile != null else MotionProfile.new()
	layers = MotionLayers.new()
	layers.name = "MotionLayers"
	layers.apply_profile(profile)
	layers.body_layers = body_layers
	skeleton.add_child(layers)
	# First modifier, so the scarf and other secondary chains follow the layered body.
	skeleton.move_child(layers, 0)
	body = BodyCapsules.measure(skeleton, _meshes)
	layers.body = body


## Moves whose strike is fitted onto a mocap take (MotionClips.fit_specs); characters with their
## own move set override this.
func _fit_specs() -> Dictionary:
	return {}


## Call every rendered frame. Picks the clip for the fighter's state and
## advances it; attack clips are timed by the move's ticks. Hitstop freezes it.
func apply_state(fighter: FighterState, delta: float) -> void:
	if fighter.hitstop_ticks > 0:
		delta = 0.0
	var state_name := StringName(FighterState.State.find_key(fighter.state))
	var restarted := fighter.state != _state or fighter.state_ticks < _state_ticks
	# KO_FALL into KO_DOWN carries on with the same fall clip, which ends lying down.
	if fighter.is_ko_state() and _state in KO_STATES and fighter.state != _state:
		restarted = false
	_state = fighter.state
	_state_ticks = fighter.state_ticks
	if layers != null:
		_update_layers(fighter, delta)
	if fighter.state == FighterState.State.ATTACKING and fighter.move != null:
		_apply_attack(fighter, delta)
		return
	_move_id = &""
	if _motion != null and _apply_motion_state(fighter, delta, restarted):
		return
	var clip := _clip_for(fighter, state_name)
	_player.speed_scale = _speed_scale(fighter, clip)
	if clip != _clip or (restarted and not _loops(clip)):
		_play(clip, clips.blend_time)
	_player.advance(delta)


## Tints the toon rim toward the fighter's energy colour; alpha is the blend.
func set_energy_color(color: Color) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(ENERGY_COLOR_PARAM, Color(color, 1.0))
		mesh.set_instance_shader_parameter(ENERGY_MIX_PARAM, color.a)


func set_vanished(vanished: bool) -> void:
	model.visible = not vanished


## Clip playing now, for tests and the preview (a motion clip when is_playing_motion()).
func current_clip() -> StringName:
	return _clip


## True if clip is in the character's clips or its motion library.
func has_clip(clip: StringName) -> bool:
	return clips.library.has_animation(clip) or (_motion != null and _motion.has_animation(clip))


func is_playing_motion() -> bool:
	return _playing_motion


## Where the head and chest turn to (world space), e.g. the lock-on target; weight 0 stops.
func set_look_target(world_point: Vector3, weight := 1.0) -> void:
	_look_world = world_point
	_look_weight = weight


## Reacts to one CombatSim event aimed at this fighter (event.target is its index): a hit
## or block flinches the upper body away from the contact point.
func react_to_event(event: Dictionary, fighter: FighterState) -> void:
	if layers == null:
		return
	var strength := 0.0
	match event.get("type", -1):
		CombatSim.EventType.HIT, CombatSim.EventType.COUNTER, CombatSim.EventType.THROW:
			strength = FLINCH_KNOCKBACK if event.get("knockback_type", 0) != MoveData.KnockbackType.NONE else FLINCH_HIT
		CombatSim.EventType.BLOCK, CombatSim.EventType.PERFECT_BLOCK, CombatSim.EventType.ARMOR:
			strength = FLINCH_BLOCK
		CombatSim.EventType.GUARD_BREAK:
			strength = FLINCH_KNOCKBACK
		CombatSim.EventType.KO:
			strength = FLINCH_KO
	if strength <= 0.0:
		return
	var away: Vector3 = fighter.position - (event.get("position", fighter.position) as Vector3)
	away.y = 0.0
	if away.length() < 0.01:
		away = Basis(Vector3.UP, fighter.facing_yaw) * Vector3.BACK
	layers.flinch(to_model(away.normalized(), fighter.facing_yaw), strength)


## A view's procedural layer (VexaView and the others) without the lean and hover bob when
## MotionLayers runs: the layers are the single source of both (see motion/README.md).
func defer_to_layers(layer: Dictionary, fighter: FighterState) -> Dictionary:
	if layers == null:
		return layer
	if layer.has(&"Spine"):
		layer[&"Spine"].rotation = Quaternion.IDENTITY
	if layer.has(&"Hips") and fighter.state == FighterState.State.FLYING:
		layer[&"Hips"].offset.y = 0.0
	return layer


## A world-space direction in the model's (skeleton's) space: facing +Z, +X to its left.
static func to_model(world: Vector3, facing_yaw: float) -> Vector3:
	var local := Basis(Vector3.UP, -facing_yaw) * world
	return Vector3(-local.x, local.y, -local.z)


## Position in the current clip, seconds.
func current_clip_time() -> float:
	var qualified := StringName("%s/%s" % [MOTION_LIBRARY_NAME, _clip]) if _playing_motion else _qualified(_clip)
	return _player.current_animation_position if _player.has_animation(qualified) else 0.0


func _clip_for(fighter: FighterState, state_name: StringName) -> StringName:
	if fighter.blocking and fighter.state in [FighterState.State.IDLE,
			FighterState.State.MOVING, FighterState.State.FLYING]:
		return clips.block_clip
	if fighter.state == FighterState.State.FLYING and fighter.velocity.length() > FLY_FAST_SPEED:
		return clips.fly_fast_clip
	if fighter.state == FighterState.State.KNOCKDOWN and fighter.state_ticks >= _knockdown_split(fighter):
		return clips.get_up_clip
	if fighter.is_ko_state() and not clips.state_clips.has(state_name):
		return clips.clip_for_state(&"KNOCKDOWN")
	var clip := clips.clip_for_state(state_name, is_airborne(fighter))
	var intro: StringName = clips.intro_clips.get(clip, &"")
	if intro != &"" and fighter.state_ticks * TICK_SECONDS < clips.library.get_animation(intro).length:
		return intro
	return clip


## Off the floor: flying, falling or dashing in the air.
static func is_airborne(fighter: FighterState) -> bool:
	# Against the fighter's own floor (zone terrain, islands), not the flat arena's.
	return fighter.position.y > fighter.stand_height + AIRBORNE_MARGIN


func _speed_scale(fighter: FighterState, clip: StringName) -> float:
	if fighter.state == FighterState.State.MOVING and clip == clips.clip_for_state(&"MOVING"):
		var ground_speed := Vector2(fighter.velocity.x, fighter.velocity.z).length()
		return clampf(ground_speed / RUN_CLIP_SPEED, RUN_SPEED_SCALE_MIN, RUN_SPEED_SCALE_MAX)
	var stun_ticks := _stun_ticks_for(fighter, clip)
	if stun_ticks > 0:
		var seconds := stun_ticks * TICK_SECONDS
		var length := clips.library.get_animation(clip).length
		return clampf(length / seconds, STUN_SPEED_SCALE_MIN, STUN_SPEED_SCALE_MAX)
	return 1.0


## Ticks a stun clip has to play in, 0 for clips that are not stun clips.
## Knockdown spends its first half falling and the rest getting up.
func _stun_ticks_for(fighter: FighterState, clip: StringName) -> int:
	if fighter.stun_ticks <= 0:
		return 0
	match fighter.state:
		FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN:
			return fighter.stun_ticks
		FighterState.State.KNOCKDOWN:
			var split := _knockdown_split(fighter)
			return fighter.stun_ticks - split if clip == clips.get_up_clip else split
	return 0


func _knockdown_split(fighter: FighterState) -> int:
	return maxi(fighter.stun_ticks / 2, 1)


func _apply_attack(fighter: FighterState, delta: float) -> void:
	if fighter.attack_phase() == FighterState.AttackPhase.HOLD:
		if _clip != clips.charge_hold_clip:
			_play(clips.charge_hold_clip, 0.0 if layers else clips.blend_time)
		_player.speed_scale = 1.0
		_player.advance(delta)
		return
	var motion_clip := _motion_move_clip(fighter.move_id())
	var clip := motion_clip if motion_clip != &"" else clips.clip_for_move(fighter.move_id())
	if fighter.move_id() != _move_id or fighter.move_tick < _move_tick:
		_move_id = fighter.move_id()
		if motion_clip != &"":
			_play_motion(clip)
		else:
			_play(clip, 0.0)
	if fighter.move_tick != _move_tick:
		_move_tick = fighter.move_tick
		_tick_seconds = 0.0
	else:
		_tick_seconds += delta
	if layers != null and profile.impact_weight > 0.0 and fighter.move_tick >= fighter.move.startup_ticks \
			and _impact_move != fighter.move_id():
		# The strike lands: the hips and knees take the weight.
		_impact_move = fighter.move_id()
		layers.land(profile.impact_weight * clampf(fighter.move.damage / 10.0, 0.5, 1.5))
	elif fighter.move_tick < fighter.move.startup_ticks:
		_impact_move = &""
	# Smooth between sim ticks, never running ahead of the next one.
	var tick := fighter.move_tick + minf(_tick_seconds / TICK_SECONDS, 1.0)
	_player.speed_scale = 1.0
	if _playing_motion:
		var length := _motion.get_animation(clip).length
		var window: Vector2 = _motion_windows.get(clip, Vector2(length * 0.4, length * 0.5))
		_player.seek(ClipSet.phase_clip_time(length, window, fighter.move, tick), true)
	else:
		_player.seek(clips.attack_clip_time(clip, fighter.move, tick), true)


func _play(clip: StringName, blend: float) -> void:
	if layers != null:
		# Inertialization replaces the crossfade.
		layers.inertialize()
		blend = 0.0
	_clip = clip
	_playing_motion = false
	_move_tick = -1
	_player.play(_qualified(clip), blend)
	if blend <= 0.0:
		_player.seek(0.0, true)


func _play_motion(clip: StringName, from := 0.0) -> void:
	layers.inertialize()
	_clip = clip
	_playing_motion = true
	_move_tick = -1
	_player.play(StringName("%s/%s" % [MOTION_LIBRARY_NAME, clip]), 0.0)
	_player.seek(from, true)


func _motion_move_clip(move_id: StringName) -> StringName:
	if _motion == null:
		return &""
	var clip := MotionSlots.move_clip(move_id, _move_overrides)
	return clip if clip != &"" and _motion.has_animation(clip) else &""


## Plays the motion clip for a non-attacking state. False when the slot has no mocap.
func _apply_motion_state(fighter: FighterState, delta: float, restarted: bool) -> bool:
	if fighter.state == FighterState.State.CHARGING:
		return false
	var local := to_model(fighter.velocity, fighter.facing_yaw)
	var clip := MotionSlots.state_clip(fighter, local, _airborne, _clip if _playing_motion else &"", _landing)
	if clip == &"" or not _motion.has_animation(clip):
		return false
	clip = _turn_clip(fighter, clip)
	if clip == &"ko_fall" and _getting_up(fighter):
		# Keep the get-up clip; replaying the fall every frame would re-inertialize and freeze it.
		return _knockdown_pose(fighter, delta)
	var animation := _motion.get_animation(clip)
	var one_shot := animation.loop_mode == Animation.LOOP_NONE
	if not _playing_motion or clip != _clip or (restarted and one_shot and clip != _landing):
		_play_motion(clip)
	var speed := profile.timing_scale
	if clip in MotionSlots.LOCOMOTION:
		speed = clampf(Vector2(local.x, local.z).length() / (_clip_speed(clip) * profile.stride_scale),
			LOCOMOTION_SCALE_MIN, LOCOMOTION_SCALE_MAX)
	elif clip == &"turn_step":
		speed = TURN_STEP_SPEED * profile.timing_scale
	elif clip == &"ko_fall":
		speed = _ko_speed(fighter, animation.length)
	elif fighter.stun_ticks > 0 and fighter.state in [FighterState.State.HITSTUN,
			FighterState.State.BLOCKSTUN, FighterState.State.GUARD_BROKEN]:
		speed = clampf(animation.length / (fighter.stun_ticks * TICK_SECONDS), STUN_SPEED_SCALE_MIN, STUN_SPEED_SCALE_MAX)
	elif clip == &"jump":
		speed = 1.3
	_player.speed_scale = speed
	if fighter.state == FighterState.State.KNOCKDOWN and not (fighter.stats != null and fighter.is_knocked_out()):
		return _knockdown_pose(fighter, delta)
	_player.advance(delta)
	if clip == &"ko_fall":
		_player.seek(minf(_player.current_animation_position, animation.length * KO_LIE_FRACTION), true)
	if clip == _landing and _player.current_animation_position >= animation.length - 0.001:
		_landing = &""
	if clip == &"turn_step" and _player.current_animation_position >= animation.length - 0.001:
		_turning = false
	return true


## Idle: a turn wider than TURN_STEP_ANGLE since the last settled facing steps the feet round.
func _turn_clip(fighter: FighterState, clip: StringName) -> StringName:
	if clip != &"fight_idle" or not _motion.has_animation(&"turn_step"):
		_turning = false
		_turn_yaw = fighter.facing_yaw
		return clip
	if not _turning and absf(angle_difference(_turn_yaw, fighter.facing_yaw)) > TURN_STEP_ANGLE:
		_turning = true
		_turn_yaw = fighter.facing_yaw
		_play_motion(&"turn_step")
	if _turning:
		_turn_yaw = fighter.facing_yaw
		return &"turn_step"
	return clip


func _getting_up(fighter: FighterState) -> bool:
	if fighter.state != FighterState.State.KNOCKDOWN or (fighter.stats != null and fighter.is_knocked_out()):
		return false
	return fighter.state_ticks >= maxi(int((fighter.state_ticks + fighter.stun_ticks) * KO_FALL_SHARE), 1)


## Knockdown: fall to the lying pose, lie, then get up, all timed to the stun.
func _knockdown_pose(fighter: FighterState, delta: float) -> bool:
	var total := maxi(fighter.state_ticks + fighter.stun_ticks, 1)
	var fall_ticks := maxi(int(total * KO_FALL_SHARE), 1)
	if fighter.state_ticks < fall_ticks:
		_player.advance(delta)
		_player.seek(minf(_player.current_animation_position, _motion.get_animation(&"ko_fall").length * KO_LIE_FRACTION), true)
		return true
	var get_up := &"get_up_full" if _motion.has_animation(&"get_up_full") else &"tech"
	if _clip != get_up:
		_play_motion(get_up)
	var length := _motion.get_animation(get_up).length
	var t := float(fighter.state_ticks - fall_ticks) / float(maxi(total - fall_ticks, 1))
	# Standing in the stance by GET_UP_DONE of the window, then holding it.
	_player.seek(clampf(t / GET_UP_DONE, 0.0, 1.0) * length, true)
	return true


func _ko_speed(fighter: FighterState, length: float) -> float:
	if fighter.state != FighterState.State.KNOCKDOWN or (fighter.stats != null and fighter.is_knocked_out()):
		return 1.0
	var fall_ticks := maxi(int((fighter.state_ticks + fighter.stun_ticks) * KO_FALL_SHARE), 1)
	return clampf(length * KO_LIE_FRACTION / (fall_ticks * TICK_SECONDS), 0.8, 3.0)


## A locomotion clip's own ground speed (m/s), from its root motion.
func _clip_speed(clip: StringName) -> float:
	if not _motion_speeds.has(clip):
		var curve: PackedVector3Array = _motion.root_motion.get(clip, PackedVector3Array())
		var speed := RUN_CLIP_SPEED
		if curve.size() > 1:
			var travel := Vector2(curve[-1].x - curve[0].x, curve[-1].y - curve[0].y).length()
			speed = maxf(travel / _motion.get_animation(clip).length, 0.5)
		_motion_speeds[clip] = speed
	return _motion_speeds[clip]


## Feeds the live layers from the sim: velocity, flight, ground, landings, look target, weapon arms.
func _update_layers(fighter: FighterState, delta: float) -> void:
	var airborne := is_airborne(fighter)
	var local := to_model(fighter.velocity, fighter.facing_yaw)
	if _airborne and not airborne:
		var strength := clampf(_fall_speed / 10.0, 0.3, 2.0)
		layers.land(strength)
		if fighter.state == FighterState.State.IDLE:
			_landing = &"heavy_land" if _fall_speed > MotionSlots.HEAVY_LANDING_SPEED else &"land"
	if airborne:
		_fall_speed = maxf(-fighter.velocity.y, 0.0)
	if fighter.state != FighterState.State.IDLE:
		_landing = &""
	if fighter.state == FighterState.State.DASHING and fighter.state_ticks <= 1 and airborne:
		layers.burst(1.0)
	_airborne = airborne
	layers.velocity = local
	layers.crouch = 0.0 if airborne or fighter.state == FighterState.State.KNOCKDOWN else profile.crouch
	layers.flying = airborne and fighter.state in [FighterState.State.FLYING, FighterState.State.DASHING,
		FighterState.State.VANISHING]
	layers.foot_ik = not airborne and fighter.state != FighterState.State.KNOCKDOWN
	layers.ground = Vector2.ZERO
	layers.ground_probe = _probe_ground if _zone_ground().is_valid() else Callable()
	var to_target := to_model(_look_world - fighter.position, fighter.facing_yaw)
	layers.look_target = to_target + Vector3(0, 1.0, 0)
	layers.look_weight = _look_weight if fighter.state in [FighterState.State.IDLE, FighterState.State.MOVING,
		FighterState.State.FLYING, FighterState.State.BLOCKING, FighterState.State.ATTACKING] else 0.0
	_update_arms(fighter)


## The zone's floor sampler: set, or the CombatSim's ground_height of the match above this view.
func _zone_ground() -> Callable:
	if not ground_height.is_valid() and not _ground_searched:
		_ground_searched = true
		var node := get_parent()
		while node != null:
			var sim: Variant = node.get("sim")
			if sim is CombatSim:
				ground_height = (sim as CombatSim).ground_height
				break
			node = node.get_parent()
	return ground_height


## Foot IK probe: the floor under a skeleton-space point, as [height, normal] in skeleton space.
func _probe_ground(point: Vector3) -> Array:
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	var space := skeleton.global_transform
	var at := space * point
	var h: float = ground_height.call(at.x, at.z, at.y)
	var e := 0.25
	var normal := Vector3(
		float(ground_height.call(at.x - e, at.z, at.y)) - float(ground_height.call(at.x + e, at.z, at.y)), 2.0 * e,
		float(ground_height.call(at.x, at.z - e, at.y)) - float(ground_height.call(at.x, at.z + e, at.y))).normalized()
	var local := space.affine_inverse() * Vector3(at.x, h, at.z)
	return [local.y, (space.basis.inverse() * normal).normalized()]


## Per-weapon-class hold (T-D30): one-hand guard, two-hand heavies across the body, pistol aim,
## braced guns at the hip, bow draw while shooting; the clearance solver runs whenever armed.
func _update_arms(fighter: FighterState) -> void:
	var kind := fighter.held_weapon()
	var attacking := fighter.state == FighterState.State.ATTACKING
	var reacting := fighter.state in [FighterState.State.HITSTUN, FighterState.State.KNOCKDOWN,
		FighterState.State.GRABBED, FighterState.State.GUARD_BROKEN, FighterState.State.KO_FALL,
		FighterState.State.KO_DOWN]
	_hold_weapon(kind)
	layers.arm_pose = MotionLayers.ArmPose.NONE
	layers.arm_weight = 0.0
	if kind == Weapon.Kind.NONE:
		return
	if reacting:
		# Hit reactions keep part of the class's hold, so a flinch never folds the weapon into the body.
		match WeaponGrip.hold_of(kind):
			WeaponGrip.Hold.ONE_HAND:
				layers.arm_pose = MotionLayers.ArmPose.GUARD
			WeaponGrip.Hold.HEAVY:
				layers.arm_pose = MotionLayers.ArmPose.TWO_HANDED
			WeaponGrip.Hold.BRACED:
				layers.arm_pose = MotionLayers.ArmPose.BRACED
		layers.arm_weight = REACTION_HOLD_WEIGHT if layers.arm_pose != MotionLayers.ArmPose.NONE else 0.0
		return
	match WeaponGrip.hold_of(kind):
		WeaponGrip.Hold.ONE_HAND:
			if attacking:
				# The swing arc: held out in front of the shoulder, sweeping as the attack runs.
				layers.arm_pose = MotionLayers.ArmPose.SWING
				layers.arm_weight = SWING_WEIGHT
				layers.arm_phase = float(fighter.move_tick) / float(maxi(fighter.move_total_ticks(), 1)) \
					if fighter.move != null else 0.0
			else:
				layers.arm_pose = MotionLayers.ArmPose.GUARD
				layers.arm_weight = 0.8
		WeaponGrip.Hold.HEAVY:
			layers.arm_pose = MotionLayers.ArmPose.TWO_HANDED
			layers.arm_weight = 0.5 if attacking else 0.9
		WeaponGrip.Hold.PISTOL:
			layers.arm_pose = MotionLayers.ArmPose.PISTOL_AIM
			layers.arm_weight = 1.0 if attacking else 0.0
		WeaponGrip.Hold.BRACED:
			layers.arm_pose = MotionLayers.ArmPose.BRACED
			layers.arm_weight = 1.0
		WeaponGrip.Hold.BOW:
			if attacking:
				layers.arm_pose = MotionLayers.ArmPose.BOW_DRAW
				layers.arm_weight = 1.0


## Tells the layers which weapon is in hand: its grip, part boxes and off-hand point.
func _hold_weapon(kind: Weapon.Kind) -> void:
	if kind == _weapon_kind:
		return
	_weapon_kind = kind
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	var hands := WeaponGrip.hands_of(kind)
	layers.weapon_hand = hands[0] if hands.size() == 1 else &""
	layers.weapon_boxes = WeaponGrip.model_boxes(kind) if hands.size() == 1 else ([] as Array[Transform3D])
	layers.weapon_off_hand = WeaponGrip.off_hand_of(kind)
	if hands.size() == 1:
		layers.weapon_grip = WeaponGrip.grip_transform(skeleton, kind, hands[0])
		var off := WeaponGrip.LEFT_HAND if hands[0] == WeaponGrip.RIGHT_HAND else WeaponGrip.RIGHT_HAND
		layers.off_hand_socket = WeaponGrip.hand_socket(skeleton, off)


func _loops(clip: StringName) -> bool:
	return clips.library.get_animation(clip).loop_mode != Animation.LOOP_NONE


func _qualified(clip: StringName) -> StringName:
	return StringName("%s/%s" % [LIBRARY_NAME, clip])
