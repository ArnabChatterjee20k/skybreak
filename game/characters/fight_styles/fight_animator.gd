class_name FightAnimator
extends RefCounted
## Picks a fighter's pose from Pure Fight sim state (FightStyle) and smooths state changes.
## Reads the sim only. Strikes are shortened at the opponent's body so limbs never pass
## through it.

const S := PureFighter.State
## Frames a state change blends over; hits snap faster.
const BLEND_FRAMES := 4.0
const HIT_BLEND_FRAMES := 1.5
## Opponent body half-depth along the line (m): a limb stops at this distance from its centre.
const BODY_HALF := 0.20
const BODY_TOP := 1.85

var style: FightStyle
var _from: Dictionary = {}
var _last: Dictionary = {}
var _key := ""
var _since := 99.0
var _blend_frames := BLEND_FRAMES
## Strike limb pose key ("rh", "lf", ...) while a move is active, else "".
var active_limb := ""


func _init(fight_style: FightStyle) -> void:
	style = fight_style


## Pose for fighter this frame; blend is the share of a tick since the last sim tick.
func pose(sim: PureFightSim, index: int, blend: float, time: float, delta: float) -> Dictionary:
	var fighter := sim.pf[index]
	var key := "%d:%s" % [fighter.state, fighter.move]
	if key != _key:
		_from = _last
		_since = 0.0
		_blend_frames = HIT_BLEND_FRAMES if fighter.state in [S.HITSTUN, S.JUGGLE, S.BLOCKSTUN] \
			else BLEND_FRAMES
		if fighter.state == S.ATTACK:
			_blend_frames = 2.0
		_key = key
	var frozen := fighter.hitstop > 0
	var sub := 0.0 if frozen else blend
	var target := _raw(sim, fighter, sub, time)
	_clamp_to_opponent(sim, index, target)
	if not frozen:
		_since += delta * 60.0
	var out := target
	if not _from.is_empty() and _since < _blend_frames:
		out = FightStyle.blend(_from, target, FightStyle._ease(_since / _blend_frames))
	_last = out
	return out


func _raw(sim: PureFightSim, fighter: PureFighter, sub: float, time: float) -> Dictionary:
	var ticks := fighter.state_tick + sub
	var seconds := ticks / 60.0
	active_limb = ""
	match fighter.state:
		S.INTRO:
			return style.intro(float(sim.phase_tick) / 60.0)
		S.IDLE:
			return style.stance(time)
		S.CROUCH:
			return style.crouch(time)
		S.WALK:
			return style.walk(seconds, fighter.vx * fighter.facing > 0, absf(fighter.vx) * 0.06)
		S.PREJUMP:
			return style.prejump(ticks / PureFightSim.PREJUMP_TICKS)
		S.AIR:
			return style.jump(float(fighter.vy), fighter.jump_dir)
		S.LANDING:
			return style.landing(ticks / maxf(fighter.landing_ticks, 1))
		S.DASH, S.BACKDASH:
			var stats := PureMoves.stats(fighter.legend)
			var length := float(stats.dash_ticks if fighter.state == S.DASH else stats.back_ticks)
			return style.dash(ticks / length, fighter.state == S.DASH)
		S.ATTACK:
			var data := PureMoves.get_move(fighter.legend, fighter.move)
			var base := style.stance(time)
			if data.stance == &"crouch":
				base = style.crouch(time)
			elif data.stance == &"air" or (fighter.y > 0 and data.vel.is_empty()):
				base = style.jump(float(fighter.vy), fighter.jump_dir)
			var frame := fighter.move_tick + 1 + sub
			if sim._is_active(fighter, data) and not (data.box as Array).is_empty():
				var limb := String(data.limb)
				active_limb = limb.substr(0, 1) + ("h" if limb.ends_with("hand") else "f")
			return style.move_pose(fighter.move, frame, data, base)
		S.BLOCKSTUN:
			return style.block(time, fighter.crouching, minf(fighter.stun_left / 8.0, 1.0))
		S.HITSTUN:
			var amount := minf(fighter.stun_left / 10.0, 1.0) * (1.0 if fighter.state_tick > 0 else 0.6)
			return style.hit(time, fighter.reaction == 1 or fighter.crouching, maxf(amount, 0.25))
		S.JUGGLE:
			return style.juggle(time, clampf(fighter.vy / 120.0, -1.0, 1.0))
		S.KNOCKDOWN:
			return style.knockdown(fighter.state_tick)
		S.WAKEUP:
			return style.wakeup(ticks / PureFightSim.WAKEUP_TICKS)
		S.ROLL:
			return style.roll(ticks / PureFightSim.ROLL_TICKS, fighter.roll_dir != fighter.facing)
		S.THROWING:
			var data := PureMoves.get_move(fighter.legend, fighter.move)
			var length := int(data.cinematic) if int(data.cinematic) > 0 else PureMoves.THROW_TICKS
			return style.throwing(fighter.move, fighter.state_tick, length)
		S.THROWN, S.HELD:
			return style.thrown(time)
		S.TECH:
			return style.tech(ticks / PureMoves.TECH_TICKS)
		S.VICTORY:
			return style.victory(sim.round_number + fighter.slot, seconds)
		S.DEFEAT:
			return style.defeat(seconds)
	return style.stance(time)


## Shortens hand and foot targets that would reach inside the opponent's body.
func _clamp_to_opponent(sim: PureFightSim, index: int, pose: Dictionary) -> void:
	var me := sim.pf[index]
	var op := sim.opponent(index)
	var forward := float((op.x - me.x) * me.facing) / 1000.0
	if forward <= 0.0:
		return
	var lift := float(op.y - me.y) / 1000.0
	var top := BODY_TOP if op.state not in [S.KNOCKDOWN, S.WAKEUP] else 0.45
	var stop := forward - BODY_HALF
	for key in ["lh", "rh", "lf", "rf"]:
		if not pose.has(key):
			continue
		var at: Vector3 = pose[key]
		var height := at.y - lift
		if height > -0.05 and height < top and at.z > stop and absf(at.x) < 0.45:
			pose[key] = Vector3(at.x, at.y, stop)
