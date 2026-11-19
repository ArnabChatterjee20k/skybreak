class_name ProceduralKaelView
extends Node3D
## Kael built in code (see source/): plays his clips from sim state. A pure animation node for
## FighterView's body: it never moves or turns itself and has no root motion. Origin at the capsule
## centre (1 m above the feet), facing -Z, about 2 m tall. Attack clips are seeked by move_tick,
## so the pose always matches the sim's frame data.

const TICKS_PER_SECOND := 60.0
## Above this speed (m/s) flying uses the forward-flight lean instead of the hover.
const FLY_FORWARD_SPEED := 6.0
## Ground speed (m/s) at which the run clip plays at its authored rate.
const RUN_SPEED := 9.0
## Crossfade between looping clips, in seconds. Attacks and stun clips cut in exactly.
const LOOP_BLEND := 0.12
const HOLD_CLIP := &"charged_smash_hold"

## Clip per FighterState.State name. Names not in FighterState yet are matched once they exist;
## unknown states fall back to idle.
const STATE_CLIPS := {
	"IDLE": &"idle",
	"MOVING": &"run",
	"FALLING": &"fall",
	"FLYING": &"fly_hover",
	"DASHING": &"dash",
	"VANISHING": &"dash",
	"CHARGING": &"charge_ki",
	"GUARD_BROKEN": &"guard_broken",
	"BLOCKING": &"block",
	"BLOCKSTUN": &"blockstun",
	"HITSTUN": &"hitstun_light",
	"HITSTUN_LIGHT": &"hitstun_light",
	"HITSTUN_HEAVY": &"hitstun_heavy",
	"LAUNCHED": &"hitstun_heavy",
	"KNOCKDOWN": &"knockdown",
	"GETTING_UP": &"get_up",
	"GET_UP": &"get_up",
	"VICTORY": &"victory",
	"DEFEAT": &"defeat",
	"KNOCKED_OUT": &"defeat",
}

## Clips that repeat.
const LOOP_CLIPS: Array[StringName] = [&"idle", &"run", &"fly_hover", &"fly_forward", &"dash",
	&"charge_ki", &"fall", &"block", &"guard_broken", &"charged_smash_hold"]

## Clips that follow the sim's state_ticks instead of free-running time.
const TICKED_CLIPS: Array[StringName] = [&"guard_broken", &"victory", &"defeat"]
## Stun clips stretch over the state's stun_ticks, so the recovery pose lands as the stun ends.
const STUN_CLIPS: Array[StringName] = [&"blockstun", &"hitstun_light", &"hitstun_heavy"]
## Knockdown clip tick where he is already on the floor (KNOCKDOWN starts after the bounce).
const KNOCKDOWN_FLOOR_TICK := 14

## Every clip the model ships with.
const CLIPS: Array[StringName] = [&"idle", &"run", &"fly_hover", &"fly_forward", &"dash", &"charge_ki",
	&"fall", &"light_1", &"light_2", &"light_3", &"light_4", &"smash", &"breaker", &"launcher", &"rising",
	&"spike", &"sweep", &"charged_smash_1", &"charged_smash_2", &"charged_smash_3", &"charged_smash_hold",
	&"push_block", &"hitstun_light", &"hitstun_heavy", &"blockstun", &"block", &"guard_broken",
	&"knockdown", &"get_up", &"victory", &"defeat"]

## Striking bone per attack clip: its peak reach falls inside the move's active ticks.
const STRIKE_BONES := {
	&"light_1": &"LeftMiddleProximal",
	&"light_2": &"RightMiddleProximal",
	&"light_3": &"LeftMiddleProximal",
	&"light_4": &"RightToes",
	&"smash": &"RightMiddleProximal",
	&"breaker": &"LeftMiddleProximal",
	&"launcher": &"RightMiddleProximal",
	&"rising": &"RightToes",
	&"spike": &"RightToes",
	&"sweep": &"RightToes",
	&"charged_smash_1": &"RightMiddleProximal",
	&"charged_smash_2": &"RightMiddleProximal",
	&"charged_smash_3": &"RightMiddleProximal",
	&"push_block": &"LeftMiddleProximal",
}

## Where the latest tick sits between the last two ticks (1 = exactly the latest tick). FighterView
## may set it to its interpolation blend so attack poses glide between ticks like the position does.
var tick_blend := 1.0

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _meshes: Array[GeometryInstance3D] = []
var _clip := &""


func _ready() -> void:
	_player = find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_skeleton = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in LOOP_CLIPS:
		_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for node in find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(node as GeometryInstance3D)
	_play(&"idle", 0.0)


## Maps the fighter's sim state to a clip and pose. Call every rendered frame.
func apply_state(fighter: FighterState, delta: float) -> void:
	var key: Variant = FighterState.State.find_key(fighter.state)
	var state_name := String(key) if key != null else ""
	if fighter.state == FighterState.State.ATTACKING and fighter.move != null:
		_apply_attack(fighter, delta)
		return
	var clip: StringName = STATE_CLIPS.get(state_name, &"idle")
	if fighter.is_knocked_out():
		clip = &"defeat"
	elif clip == &"idle" and fighter.blocking:
		clip = &"block"
	elif clip == &"fly_hover" and fighter.velocity.length() > FLY_FORWARD_SPEED:
		clip = &"fly_forward"
	if clip == &"hitstun_light" and fighter.knockback_type != MoveData.KnockbackType.NONE:
		clip = &"hitstun_heavy"
	if not _player.has_animation(clip):
		clip = &"idle"
	var tick := maxi(fighter.state_ticks - 1, 0)
	if clip == &"knockdown":
		_apply_knockdown(fighter, tick)
		return
	if clip in STUN_CLIPS and fighter.stun_ticks > 0:
		var progress := clampf(float(tick) / fighter.stun_ticks, 0.0, 1.0)
		_seek_ticks(clip, progress * clip_ticks(clip))
		return
	if clip in TICKED_CLIPS or clip in STUN_CLIPS:
		_seek_ticks(clip, tick)
		return
	var speed := 1.0
	if clip == &"run":
		var ground := Vector2(fighter.velocity.x, fighter.velocity.z).length()
		speed = clampf(ground / RUN_SPEED, 0.6, 1.6)
	if _clip != clip:
		_play(clip, LOOP_BLEND)
	_player.advance(delta * speed)


## Tints the toon rim toward the fighter's energy colour; alpha is the strength (0 = off).
func set_energy_color(color: Color) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"rim_energy_color", Color(color, 1.0))
		mesh.set_instance_shader_parameter(&"rim_energy_mix", color.a)


func set_vanished(vanished: bool) -> void:
	visible = not vanished


func current_clip() -> StringName:
	return _clip


func clip_position() -> float:
	return _player.current_animation_position


func skeleton() -> Skeleton3D:
	return _skeleton


## Length of a clip in sim ticks (its last frame index).
func clip_ticks(clip: StringName) -> int:
	return roundi(_player.get_animation(clip).length * TICKS_PER_SECOND)


## Shows a clip at a sim tick (frame), for previews and tests.
func pose_at(clip: StringName, tick: float) -> void:
	_seek_ticks(clip, tick)


func _apply_attack(fighter: FighterState, delta: float) -> void:
	if fighter.attack_phase() == FighterState.AttackPhase.HOLD:
		_seek_ticks(HOLD_CLIP, float(fighter.phase_tick()))
		return
	var clip := fighter.move_id()
	if not _player.has_animation(clip):
		if _clip != &"idle":
			_play(&"idle", LOOP_BLEND)
		_player.advance(delta)
		return
	_seek_ticks(clip, fighter.move_tick - 1.0 + tick_blend)


## On the floor, then the get-up clip over the knockdown's last ticks.
func _apply_knockdown(fighter: FighterState, tick: int) -> void:
	var get_up := clip_ticks(&"get_up")
	var left := fighter.stun_ticks - tick
	if fighter.stun_ticks > 0 and left <= get_up:
		_seek_ticks(&"get_up", get_up - left)
	else:
		_seek_ticks(&"knockdown", KNOCKDOWN_FLOOR_TICK + tick)


func _seek_ticks(clip: StringName, tick: float) -> void:
	var animation := _player.get_animation(clip)
	var time := maxf(tick / TICKS_PER_SECOND, 0.0)
	if animation.loop_mode != Animation.LOOP_NONE and animation.length > 0.0:
		time = fmod(time, animation.length)
	else:
		time = minf(time, animation.length)
	if _clip != clip:
		_play(clip, 0.0)
	_player.seek(time, true)


func _play(clip: StringName, blend: float) -> void:
	_clip = clip
	_player.play(clip, blend)
