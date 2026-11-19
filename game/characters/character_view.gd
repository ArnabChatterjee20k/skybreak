class_name CharacterView
extends Node3D
## Animates one fighter's model from sim state. A pure animation node: it sits
## under FighterView's body node, never moves or turns itself and uses no root
## motion. Origin at the capsule centre (1 m above the feet), facing -Z.
## One generic script; each character is a scene that sets clips and the model.

## Hover clip below this speed (m/s), fast-flight clip above it.
const FLY_FAST_SPEED := 14.0
## Run speed (m/s) at which the run clip plays at normal speed.
const RUN_CLIP_SPEED := 9.0
const RUN_SPEED_SCALE_MIN := 0.6
const RUN_SPEED_SCALE_MAX := 1.6
const TICK_SECONDS := 1.0 / 60.0
const ENERGY_COLOR_PARAM := &"rim_energy_color"
const ENERGY_MIX_PARAM := &"rim_energy_mix"
const LIBRARY_NAME := &"humanoid"

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


func _ready() -> void:
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(_player)
	_player.root_node = _player.get_path_to(model)
	_player.add_animation_library(LIBRARY_NAME, clips.library)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	_play(clips.clip_for_state(&"IDLE"), 0.0)


## Call every rendered frame. Picks the clip for the fighter's state and
## advances it; attack clips are timed by the move's ticks.
func apply_state(fighter: FighterState, delta: float) -> void:
	var state_name := StringName(FighterState.State.find_key(fighter.state))
	var restarted := fighter.state != _state or fighter.state_ticks < _state_ticks
	_state = fighter.state
	_state_ticks = fighter.state_ticks
	if fighter.state == FighterState.State.ATTACKING and fighter.move != null:
		_apply_attack(fighter, delta)
		return
	_move_id = &""
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


## Clip playing now, for tests and the preview.
func current_clip() -> StringName:
	return _clip


## Position in the current clip, seconds.
func current_clip_time() -> float:
	return _player.current_animation_position if _player.has_animation(_qualified(_clip)) else 0.0


func _clip_for(fighter: FighterState, state_name: StringName) -> StringName:
	if fighter.blocking and fighter.state in [FighterState.State.IDLE,
			FighterState.State.MOVING, FighterState.State.FLYING]:
		return clips.block_clip
	if fighter.state == FighterState.State.FLYING and fighter.velocity.length() > FLY_FAST_SPEED:
		return clips.fly_fast_clip
	return clips.clip_for_state(state_name)


func _speed_scale(fighter: FighterState, clip: StringName) -> float:
	if fighter.state == FighterState.State.MOVING and clip == clips.clip_for_state(&"MOVING"):
		var ground_speed := Vector2(fighter.velocity.x, fighter.velocity.z).length()
		return clampf(ground_speed / RUN_CLIP_SPEED, RUN_SPEED_SCALE_MIN, RUN_SPEED_SCALE_MAX)
	return 1.0


func _apply_attack(fighter: FighterState, delta: float) -> void:
	if fighter.attack_phase() == FighterState.AttackPhase.HOLD:
		if _clip != clips.charge_hold_clip:
			_play(clips.charge_hold_clip, clips.blend_time)
		_player.speed_scale = 1.0
		_player.advance(delta)
		return
	var clip := clips.clip_for_move(fighter.move_id())
	if fighter.move_id() != _move_id or fighter.move_tick < _move_tick:
		_move_id = fighter.move_id()
		_play(clip, 0.0)
	if fighter.move_tick != _move_tick:
		_move_tick = fighter.move_tick
		_tick_seconds = 0.0
	else:
		_tick_seconds += delta
	# Smooth between sim ticks, never running ahead of the next one.
	var tick := fighter.move_tick + minf(_tick_seconds / TICK_SECONDS, 1.0)
	_player.speed_scale = 1.0
	_player.seek(clips.attack_clip_time(clip, fighter.move, tick), true)


func _play(clip: StringName, blend: float) -> void:
	_clip = clip
	_move_tick = -1
	_player.play(_qualified(clip), blend)
	if blend <= 0.0:
		_player.seek(0.0, true)


func _loops(clip: StringName) -> bool:
	return clips.library.get_animation(clip).loop_mode != Animation.LOOP_NONE


func _qualified(clip: StringName) -> StringName:
	return StringName("%s/%s" % [LIBRARY_NAME, clip])
