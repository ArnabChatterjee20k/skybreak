class_name FightStyle
extends RefCounted
## A legend's Pure Fight martial-arts style (GAME_DESIGN §16.3): stance, idle, walk, guard,
## reactions, intro and win/lose poses, and every move as keyframed poses for FightRig.
## Poses are Dictionaries (see FightRig.apply). Strikes are built from the move's hitbox so
## the striking fist or foot reaches the hitbox on the first active frame; each legend
## colours them with its own body mechanics and overrides its signature moves with keys.

const ANKLE := 0.13
const TICK := 1.0 / 60.0

## Style knobs, set by each legend.
var hip_drop := 0.12
var lead_foot := Vector3(0.10, ANKLE, 0.32)
var rear_foot := Vector3(-0.15, ANKLE, -0.32)
var stance_yaw := -30.0
var chest_yaw := -8.0
var lean := 8.0
var head_pitch := 0.0
var lead_guard := Vector3(0.08, 1.25, 0.32)
var rear_guard := Vector3(-0.06, 1.22, 0.15)
var sway := 0.01
var sway_hz := 0.5
var bounce := 0.0
var bounce_hz := 2.0
var walk_stride := 0.34
## Strike type per move id (see _strike_keys); missing ids pick a type from the limb.
var types: Dictionary = {}
## Explicit keys per move id: Array of [frame spec, pose overrides]; beat the generator.
var keys: Dictionary = {}
var legend: StringName = &"kael"
## The finisher's cinematic: strike kinds and limbs thrown in turn, the last one the launcher.
var finisher_strikes: Array = [[&"jab", "l"], [&"straight", "r"], [&"front", "r"], [&"hook", "l"],
	[&"straight", "r"], [&"round", "l"], [&"uppercut", "r"]]


# --- base poses ---------------------------------------------------------------------------

func stance(t: float) -> Dictionary:
	var breath := sin(t * TAU * sway_hz)
	var hop := absf(sin(t * TAU * bounce_hz * 0.5)) * bounce
	var drop := hip_drop - hop
	var pose := {
		"hip": Vector3(0.0, -drop + breath * sway, 0.0),
		"hipr": Vector3(0.0, stance_yaw, breath * 1.5),
		"sp": Vector3(lean, 0.0, 0.0),
		"ch": Vector3(lean * 0.5 + breath * 1.5, chest_yaw, 0.0),
		"hd": Vector3(head_pitch - lean * 1.2, -(stance_yaw + chest_yaw), 0.0),
		"lh": lead_guard + Vector3(0, breath * 0.012, 0), "rh": rear_guard + Vector3(0, breath * 0.01, 0),
		"le": Vector3(0.6, -1.0, -0.2), "re": Vector3(-0.6, -1.0, -0.4),
		"lf": lead_foot + Vector3(0, hop * 0.6, 0), "rf": rear_foot + Vector3(0, hop * 0.6, 0),
		"lk": Vector3(0.3, 0.0, 1.0), "rk": Vector3(-0.2, 0.0, 1.0),
		"lt": Vector3(0.25, 0.0, 1.0), "rt": Vector3(-0.6, 0.0, 0.8),
	}
	return pose


func crouch(t: float) -> Dictionary:
	var pose := stance(t)
	pose.hip = Vector3(0.0, -0.36 - hip_drop * 0.3, -0.04)
	pose.sp = Vector3(lean + 14.0, 0.0, 0.0)
	pose.hd = Vector3(head_pitch - lean - 18.0, -(stance_yaw + chest_yaw), 0.0)
	pose.lh = lead_guard + Vector3(0.0, -0.38, 0.06)
	pose.rh = rear_guard + Vector3(0.0, -0.36, 0.04)
	pose.lk = Vector3(0.6, 0.2, 1.0)
	pose.rk = Vector3(-0.6, 0.2, 1.0)
	return pose


func block(t: float, low: bool, amount: float) -> Dictionary:
	var pose := crouch(t) if low else stance(t)
	var hips: Vector3 = pose.hip
	pose.hip = hips + Vector3(0.0, -0.02, -0.06 * amount)
	pose.lh = Vector3(0.10, (0.95 if low else 1.42), 0.26)
	pose.rh = Vector3(-0.04, (0.90 if low else 1.36), 0.20)
	pose.le = Vector3(0.5, -0.6, 0.6)
	pose.re = Vector3(-0.5, -0.6, 0.6)
	var chest: Vector3 = pose.ch
	pose.ch = chest + Vector3(6.0 * amount, 10.0, 0.0)
	return pose


## Hit reaction: high snaps the head and chest back, low folds over the gut.
func hit(t: float, low: bool, amount: float) -> Dictionary:
	var pose := stance(t)
	var hips: Vector3 = pose.hip
	if low:
		pose.hip = hips + Vector3(0.0, -0.10 * amount, -0.08 * amount)
		pose.sp = Vector3(lean + 28.0 * amount, 0.0, 0.0)
		pose.ch = Vector3(18.0 * amount, chest_yaw, 0.0)
		pose.hd = Vector3(-20.0 * amount, 0.0, 0.0)
		pose.lh = Vector3(0.10, 1.00, 0.22)
		pose.rh = Vector3(-0.08, 0.98, 0.18)
	else:
		pose.hip = hips + Vector3(0.0, -0.03 * amount, -0.12 * amount)
		pose.sp = Vector3(lean - 16.0 * amount, 0.0, 6.0 * amount)
		pose.ch = Vector3(-14.0 * amount, chest_yaw + 12.0 * amount, 0.0)
		pose.hd = Vector3(-28.0 * amount, 0.0, 8.0 * amount)
		pose.lh = Vector3(0.30, 1.28, 0.05)
		pose.rh = Vector3(-0.30, 1.20, -0.02)
		pose.le = Vector3(1.0, -0.3, -0.5)
		pose.re = Vector3(-1.0, -0.3, -0.5)
	return pose


## Airborne hit: arched back, limbs trailing; spin turns the body with the fall.
func juggle(t: float, rising: float) -> Dictionary:
	var pose := stance(t)
	pose.hip = Vector3(0.0, 0.05, 0.0)
	pose.hipr = Vector3(-35.0 + rising * 20.0, stance_yaw * 0.3, 0.0)
	pose.sp = Vector3(-18.0, 0.0, 0.0)
	pose.ch = Vector3(-10.0, 0.0, 0.0)
	pose.hd = Vector3(-20.0, 0.0, 0.0)
	pose.lh = Vector3(0.45, 1.25, -0.25)
	pose.rh = Vector3(-0.45, 1.3, -0.20)
	pose.le = Vector3(1, 0, -1)
	pose.re = Vector3(-1, 0, -1)
	pose.lf = Vector3(0.15, 0.45, 0.45)
	pose.rf = Vector3(-0.15, 0.25, 0.30)
	pose.lt = Vector3(0, -0.4, 1)
	pose.rt = Vector3(0, -0.4, 1)
	return pose


## Lying on the back (knockdown), ground level.
func lying(_t: float) -> Dictionary:
	return {
		"hip": Vector3(0.0, -0.66, -0.2), "hipr": Vector3(-88.0, 0.0, 0.0), "sp": Vector3(0, 0, 0),
		"ch": Vector3(4, 0, 0), "hd": Vector3(25, 0, 0),
		"lh": Vector3(0.42, 0.08, -0.55), "rh": Vector3(-0.42, 0.08, -0.6),
		"le": Vector3(1, 0, 0), "re": Vector3(-1, 0, 0),
		"lf": Vector3(0.22, 0.10, 0.62), "rf": Vector3(-0.18, 0.22, 0.48),
		"lk": Vector3(0.2, 1, 0), "rk": Vector3(-0.2, 1, 0),
		"lt": Vector3(0.2, 1.0, 0.1), "rt": Vector3(-0.2, 1.0, 0.2),
	}


func knockdown(ticks: int) -> Dictionary:
	var settle := clampf(ticks / 10.0, 0.0, 1.0)
	var pose := lying(0.0)
	var hips: Vector3 = pose.hip
	pose.hip = hips + Vector3(0.0, 0.10 * (1.0 - settle) * absf(sin(settle * PI * 2.0)), 0.0)
	return pose


func wakeup(f: float) -> Dictionary:
	if f < 0.45:
		return blend(lying(0.0), kneel(), _ease(f / 0.45))
	return blend(kneel(), stance(0.0), _ease((f - 0.45) / 0.55))


func kneel() -> Dictionary:
	var pose := crouch(0.0)
	pose.hip = Vector3(0.0, -0.50, -0.05)
	pose.lf = Vector3(0.14, ANKLE, 0.38)
	pose.rf = Vector3(-0.14, 0.10, -0.34)
	pose.rt = Vector3(0, -0.8, 0.6)
	pose.lh = Vector3(0.25, 0.65, 0.30)
	pose.rh = Vector3(-0.25, 0.60, 0.1)
	return pose


## Rolling on the floor: tucked ball turning one full turn.
func roll(f: float, backwards: bool) -> Dictionary:
	var pose := crouch(0.0)
	var turn := 360.0 * _ease(f) * (-1.0 if backwards else 1.0)
	pose.hip = Vector3(0.0, -0.45 + 0.08 * sin(f * PI), 0.0)
	pose.hipr = Vector3(turn, stance_yaw * 0.5, 0.0)
	pose.sp = Vector3(40, 0, 0)
	pose.ch = Vector3(20, 0, 0)
	pose.lh = Vector3(0.18, 0.75, 0.35)
	pose.rh = Vector3(-0.18, 0.75, 0.32)
	pose.lf = Vector3(0.12, 0.45, 0.25)
	pose.rf = Vector3(-0.12, 0.45, 0.20)
	return pose


func walk(t: float, forward: bool, speed: float) -> Dictionary:
	var pose := stance(t)
	# One step per foot each cycle; the planted foot slides back at exactly walk speed.
	var cycle := maxf(walk_stride * 2.0 / maxf(speed, 0.1), 0.4)
	var phase := fposmod(t / cycle, 1.0)
	var sign := 1.0 if forward else -1.0
	var lead: Vector3 = pose.lf
	var rear: Vector3 = pose.rf
	pose.lf = lead + _step_offset(phase, sign)
	pose.rf = rear + _step_offset(fposmod(phase + 0.5, 1.0), sign)
	var hips: Vector3 = pose.hip
	pose.hip = hips + Vector3(0.0, -0.015 * absf(cos(phase * TAU)), 0.02 * sign)
	var spine: Vector3 = pose.sp
	pose.sp = spine + Vector3(3.0 * sign, 0.0, 0.0)
	return pose


## Foot offset over a step cycle: first half planted (moving back at walk speed), second half
## swinging forward with a lift.
func _step_offset(phase: float, sign: float) -> Vector3:
	var half := walk_stride * 0.5
	if phase < 0.5:
		return Vector3(0.0, 0.0, sign * lerpf(half, -half, phase / 0.5))
	var swing := (phase - 0.5) / 0.5
	return Vector3(0.0, sin(swing * PI) * 0.09, sign * lerpf(-half, half, _ease(swing)))


func dash(f: float, forward: bool) -> Dictionary:
	var pose := stance(0.0)
	var sign := 1.0 if forward else -1.0
	var hips: Vector3 = pose.hip
	pose.hip = hips + Vector3(0.0, -0.06 + 0.05 * sin(f * PI), 0.06 * sign)
	pose.sp = Vector3(lean + 16.0 * sign, 0.0, 0.0)
	var skim := sin(f * PI)
	pose.lf = lead_foot + Vector3(0.0, 0.12 * skim, 0.10 * sign)
	pose.rf = rear_foot + Vector3(0.0, 0.18 * skim, -0.18 * sign)
	pose.lt = Vector3(0.2, -0.3, 1)
	pose.rt = Vector3(-0.5, -0.3, 0.8)
	return pose


func prejump(f: float) -> Dictionary:
	var pose := crouch(0.0)
	return blend(stance(0.0), pose, 0.6 * _ease(f))


## Jump: tucked at the apex, legs reaching down on the way to the floor.
func jump(vy: float, _forward: int) -> Dictionary:
	var pose := stance(0.0)
	var tuck := clampf(1.0 - absf(vy) / 150.0, 0.0, 1.0)
	pose.hip = Vector3(0.0, 0.0, 0.0)
	pose.lf = Vector3(0.12, 0.10 + 0.45 * tuck, 0.22)
	pose.rf = Vector3(-0.12, 0.18 + 0.30 * tuck, -0.10)
	pose.lt = Vector3(0.1, -0.5, 1)
	pose.rt = Vector3(-0.1, -0.5, 1)
	pose.lk = Vector3(0.2, 0.3, 1)
	pose.rk = Vector3(-0.2, 0.3, 1)
	pose.sp = Vector3(lean + 10.0 * tuck, 0.0, 0.0)
	return pose


func landing(f: float) -> Dictionary:
	return blend(crouch(0.0), stance(0.0), _ease(f))


func intro(t: float) -> Dictionary:
	return stance(t)


func victory(_n: int, t: float) -> Dictionary:
	return stance(t)


func defeat(_t: float) -> Dictionary:
	return kneel()


## Holding the opponent (throw or cinematic grab): the thrower's frames.
func throwing(id: StringName, tick: int, length: int) -> Dictionary:
	var f := clampf(float(tick) / maxf(length, 1), 0.0, 1.0)
	if PureMoves.get_move(legend, id).get("kind", &"") == &"finisher":
		return _rush(tick, length)
	var grab := stance(0.0)
	grab.lh = Vector3(0.12, 1.25, 0.55)
	grab.rh = Vector3(-0.12, 1.20, 0.55)
	grab.le = Vector3(1, -0.5, 0)
	grab.re = Vector3(-1, -0.5, 0)
	var heave := grab.duplicate()
	heave.hipr = Vector3(-10, stance_yaw - 60.0, 0)
	heave.sp = Vector3(-12, 0, 0)
	heave.lh = Vector3(0.25, 1.65, 0.25)
	heave.rh = Vector3(0.0, 1.60, 0.35)
	var toss := heave.duplicate()
	toss.hipr = Vector3(18, stance_yaw + 50.0, 0)
	toss.sp = Vector3(24, 0, 0)
	toss.lh = Vector3(0.20, 1.0, 0.75)
	toss.rh = Vector3(-0.10, 1.05, 0.70)
	if f < 0.25:
		return blend(stance(0.0), grab, _ease(f / 0.25))
	if f < 0.62:
		return blend(grab, heave, _ease((f - 0.25) / 0.37))
	if f < 0.8:
		return blend(heave, toss, _ease((f - 0.62) / 0.18))
	return blend(toss, stance(0.0), _ease((f - 0.8) / 0.2))


## Finisher cinematic: a strike every few frames, the last one held as the launcher lands.
func _rush(tick: int, length: int) -> Dictionary:
	var count := finisher_strikes.size()
	var finale := length - 14
	var each := maxf(float(finale - 6) / count, 4.0)
	var index := clampi(int((tick - 2) / each), 0, count - 1)
	var w := clampf(fposmod(tick - 2, each) / each, 0.0, 1.0)
	if tick >= finale:
		index = count - 1
		w = 1.0
	var entry: Array = finisher_strikes[index]
	var kind: StringName = entry[0]
	var side: String = entry[1]
	var last := index == count - 1
	var height := 1.85 if last else 1.15
	var strike_pair: Array
	if kind in [&"front", &"round", &"side", &"spin", &"axe", &"up", &"sweep"]:
		strike_pair = _kick(side, kind, 0.72, height * 0.75, false, false)
	else:
		strike_pair = _punch(side, kind, 0.66, height)
	var base := stance(0.0)
	var windup := base.duplicate()
	windup.merge(strike_pair[0], true)
	var strike := base.duplicate()
	strike.merge(strike_pair[1], true)
	if tick > length - 8:
		return blend(strike, base, _ease(float(tick - (length - 8)) / 8.0))
	if w < 0.35:
		return blend(windup, strike, _ease(w / 0.35))
	return blend(strike, windup, _ease((w - 0.35) / 0.65) * (0.0 if last else 0.6))


## Being held for a throw or cinematic: lifted, limbs flailing.
func thrown(t: float) -> Dictionary:
	var pose := hit(t, false, 0.8)
	var wobble := sin(t * 18.0)
	pose.lf = Vector3(0.12, 0.25 + 0.08 * wobble, 0.15)
	pose.rf = Vector3(-0.12, 0.20 - 0.08 * wobble, -0.05)
	return pose


func tech(f: float) -> Dictionary:
	var pose := block(0.0, false, 1.0 - f)
	var hips: Vector3 = pose.hip
	pose.hip = hips + Vector3(0, 0, -0.1 * sin(f * PI))
	return pose


# --- moves ----------------------------------------------------------------------------------

## Pose of move id on frame (1-based, fractional) with its frame data.
func move_pose(id: StringName, frame: float, data: Dictionary, base: Dictionary) -> Dictionary:
	var move_keys: Array = keys[id] if keys.has(id) else _strike_keys(id, data)
	var total := float(PureMoves.total(data))
	var times: Array[float] = [0.0]
	var poses: Array[Dictionary] = [base]
	for key in move_keys:
		times.append(_frame_of(key[0], data))
		var pose := base.duplicate()
		pose.merge(key[1] as Dictionary, true)
		poses.append(pose)
	times.append(maxf(total, times[times.size() - 1] + 1.0))
	poses.append(base)
	for i in range(1, times.size()):
		if frame <= times[i]:
			var span := maxf(times[i] - times[i - 1], 0.001)
			var w := clampf((frame - times[i - 1]) / span, 0.0, 1.0)
			return blend(poses[i - 1], poses[i], _ease(w))
	return base


## "s" first active frame, "e" last active, "r" total; "+n"/"-n" offsets; ints as is.
func _frame_of(spec: Variant, data: Dictionary) -> float:
	if spec is int or spec is float:
		return float(spec)
	var text := String(spec)
	var anchor := text.substr(0, 1)
	var offset := float(text.substr(1)) if text.length() > 1 else 0.0
	var startup := float(data.startup)
	match anchor:
		"s":
			return startup + offset
		"e":
			return startup + maxf(float(data.active) - 1.0, 0.0) + offset
		"r":
			return float(PureMoves.total(data)) + offset
	return float(text)


## Keys from the hitbox: anticipation, the limb on the hitbox through the active frames,
## follow-through, back to base.
func _strike_keys(id: StringName, data: Dictionary) -> Array:
	var box: Array = data.box
	if box.is_empty():
		return []
	var limb: StringName = data.limb
	var kind: StringName = types.get(id, &"")
	var reach := float(box[1]) / 1000.0 - 0.07
	var height := (float(box[2]) + float(box[3])) / 2000.0
	var air: bool = data.stance == &"air"
	if air:
		height = clampf(height, 0.1, 1.2)
	var strike := {}
	var windup := {}
	var side := "l" if String(limb).begins_with("l") else "r"
	var mirror := 1.0 if side == "l" else -1.0
	var other := "r" if side == "l" else "l"
	if String(limb).ends_with("hand"):
		if kind == &"":
			kind = &"straight"
		var punch := _punch(side, kind, reach, height)
		windup = punch[0]
		strike = punch[1]
		strike[other + "h"] = _hikite(other, kind)
	elif String(limb).ends_with("foot") or limb == &"lknee":
		if kind == &"":
			kind = &"front"
		var kick := _kick(side, kind, reach, height, air, data.stance == &"crouch")
		windup = kick[0]
		strike = kick[1]
	else:
		windup = {"hip": Vector3(0, -hip_drop - 0.05, -0.1), "sp": Vector3(lean + 15, 0, 0)}
		strike = {"hip": Vector3(0, -hip_drop - 0.08, 0.22), "hipr": Vector3(0, stance_yaw + 60, 0),
			"sp": Vector3(lean + 25, 0, 0), "rh": Vector3(-0.05, 1.25, 0.35),
			"lh": Vector3(0.15, 1.3, 0.25)}
	var follow := strike.duplicate()
	var target_key := side + ("h" if String(limb).ends_with("hand") else "f")
	if follow.has(target_key):
		follow[target_key] = (follow[target_key] as Vector3).lerp(windup.get(target_key, follow[target_key]), 0.35)
	var spec_w := "s-%d" % maxi(int(data.startup) / 2, 1)
	if air:
		return [[spec_w, windup], ["s", strike], ["e", strike], ["e+6", follow]]
	return [[spec_w, windup], ["s", strike], ["e", strike], ["e+%d" % maxi(int(data.recovery) / 3, 2), follow]]


## [windup, strike] of a punch toward (reach forward, height).
func _punch(side: String, kind: StringName, reach: float, height: float) -> Array:
	var mirror := 1.0 if side == "l" else -1.0
	var yaw_out := stance_yaw + (-22.0 if side == "l" else 78.0)
	var windup := {side + "h": Vector3(0.10 * mirror, height + 0.05, 0.10),
		"hipr": Vector3(0, stance_yaw + (-12.0 if side == "r" else 10.0), 0)}
	var strike := {side + "h": Vector3(0.03 * mirror, height, reach), side + "e": Vector3(0.6 * mirror, -1, 0),
		"hipr": Vector3(0, yaw_out, 0), "ch": Vector3(lean * 0.5, (12.0 if side == "l" else -18.0), 0),
		"hip": Vector3(0, -hip_drop - 0.02, 0.06)}
	match kind:
		&"jab":
			strike["hip"] = Vector3(0, -hip_drop, 0.04)
		&"hook":
			windup[side + "h"] = Vector3(0.35 * mirror, height + 0.05, 0.05)
			strike[side + "h"] = Vector3(0.0, height, reach)
			strike[side + "e"] = Vector3(1.0 * mirror, 0.3, -0.2)
			strike["hipr"] = Vector3(0, yaw_out - 20.0 * mirror, 0)
		&"uppercut":
			windup[side + "h"] = Vector3(0.05 * mirror, 0.85, 0.15)
			windup["hip"] = Vector3(0, -hip_drop - 0.18, 0)
			strike[side + "h"] = Vector3(0.02 * mirror, minf(height + 0.25, 1.9), reach * 0.8)
			strike[side + "e"] = Vector3(0.3 * mirror, -1, 0.3)
			strike["hip"] = Vector3(0, -hip_drop + 0.05, 0.05)
			strike["sp"] = Vector3(lean - 12.0, 0, 0)
		&"hammer":
			windup[side + "h"] = Vector3(0.05 * mirror, 1.85, -0.05)
			windup["sp"] = Vector3(lean - 15.0, 0, 0)
			strike[side + "h"] = Vector3(0.02 * mirror, height - 0.15, reach)
			strike[side + "e"] = Vector3(0.4 * mirror, 1.0, -0.5)
			strike["sp"] = Vector3(lean + 22.0, 0, 0)
		&"elbow":
			strike[side + "h"] = Vector3(0.08 * mirror, height + 0.05, reach * 0.55)
			strike[side + "e"] = Vector3(0.2 * mirror, 0, 1)
			strike["hip"] = Vector3(0, -hip_drop - 0.04, 0.16)
		&"backfist":
			windup[side + "h"] = Vector3(-0.15 * mirror, height, 0.12)
			strike[side + "e"] = Vector3(0.5 * mirror, 0.8, 0)
		&"chop":
			windup[side + "h"] = Vector3(0.30 * mirror, height + 0.35, 0.0)
			strike[side + "e"] = Vector3(0.8 * mirror, 0.5, -0.2)
	return [windup, strike]


## The off hand during a punch (karate legends pull it to the hip).
func _hikite(other: String, _kind: StringName) -> Vector3:
	var mirror := 1.0 if other == "l" else -1.0
	return Vector3(0.12 * mirror, 1.15, 0.12)


## [windup, strike] of a kick toward (reach, height).
func _kick(side: String, kind: StringName, reach: float, height: float, air: bool,
		crouching: bool) -> Array:
	var mirror := 1.0 if side == "l" else -1.0
	var support := "r" if side == "l" else "l"
	var kick_height := maxf(height, ANKLE)
	var windup := {side + "f": Vector3(0.08 * mirror, 0.55 + kick_height * 0.25, 0.22),
		side + "k": Vector3(0.2 * mirror, 0.6, 1.0), side + "t": Vector3(0, -0.6, 1),
		"hip": Vector3(0, -hip_drop + 0.02, -0.02)}
	var strike := {side + "f": Vector3(0.0, kick_height, reach), side + "k": Vector3(0.2 * mirror, 1.0, 0.3),
		side + "t": Vector3(0, -0.2, 1),
		"hip": Vector3(0, -hip_drop + 0.04, -0.06),
		"sp": Vector3(lean - 10.0 - kick_height * 6.0, 0, 0),
		"lh": lead_guard + Vector3(0.05, -0.05, -0.08), "rh": Vector3(-0.28, 1.0, -0.15)}
	match kind:
		&"round":
			strike["hipr"] = Vector3(0, stance_yaw - 70.0 * mirror, -20.0 * mirror)
			strike[side + "k"] = Vector3(0.9 * mirror, 0.4, 0.3)
			strike[side + "t"] = Vector3(-0.8 * mirror, 0, 0.5)
			windup[side + "k"] = Vector3(0.9 * mirror, 0.4, 0.5)
		&"side":
			strike["hipr"] = Vector3(0, stance_yaw - 80.0 * mirror, 25.0 * mirror)
			strike[side + "k"] = Vector3(0.0, 1.0, 0.0)
			strike[side + "t"] = Vector3(0.8 * mirror, 0, 0.3)
			strike["sp"] = Vector3(lean - 5.0, 0, 18.0 * mirror)
			windup[side + "f"] = Vector3(0.1 * mirror, 0.75, 0.05)
		&"spin":
			windup["hipr"] = Vector3(0, stance_yaw + 160.0, 0)
			windup["hd"] = Vector3(0, -150.0, 0)
			strike["hipr"] = Vector3(0, stance_yaw + 330.0, -15.0 * mirror)
			strike[side + "k"] = Vector3(0.9 * mirror, 0.5, 0.0)
		&"axe":
			windup[side + "f"] = Vector3(0.05 * mirror, minf(kick_height + 0.9, 2.1), reach * 0.7)
			windup[side + "k"] = Vector3(0, 1, 0)
			windup["sp"] = Vector3(lean - 25.0, 0, 0)
			strike[side + "f"] = Vector3(0.0, maxf(kick_height - 0.35, 0.5), reach)
			strike["sp"] = Vector3(lean + 15.0, 0, 0)
		&"up":
			windup[side + "f"] = Vector3(0.05 * mirror, 0.35, 0.25)
			strike[side + "f"] = Vector3(0.0, minf(kick_height + 0.4, 2.0), reach * 0.6)
			strike["sp"] = Vector3(lean - 30.0, 0, 0)
		&"sweep":
			windup[side + "f"] = Vector3(0.15 * mirror, 0.20, 0.2)
			strike[side + "f"] = Vector3(0.05 * mirror, ANKLE + 0.02, reach)
			strike[side + "k"] = Vector3(0.6 * mirror, 1.0, 0.2)
			strike[side + "t"] = Vector3(-0.7 * mirror, 0.0, 0.7)
			strike["hipr"] = Vector3(0, stance_yaw - 60.0 * mirror, 0)
	if crouching:
		var low := crouch(0.0)
		for key in [support + "f", "lh", "rh"]:
			strike[key] = low[key]
			windup[key] = low[key]
		strike["hip"] = Vector3(0, -0.40, -0.05)
		windup["hip"] = Vector3(0, -0.40, -0.02)
		strike["sp"] = Vector3(lean + 10.0, 0, 0)
		strike[support + "k"] = Vector3(0.6 * -mirror, 0.3, 1)
	if air:
		windup.erase(support + "f")
		strike[support + "f"] = Vector3(-0.1 * mirror, 0.45, -0.05)
		windup[support + "f"] = Vector3(-0.1 * mirror, 0.50, 0.05)
	return [windup, strike]


# --- helpers --------------------------------------------------------------------------------

static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	var out := a.duplicate()
	for key in b:
		var to: Variant = b[key]
		if out.has(key) and to is Vector3:
			out[key] = (out[key] as Vector3).lerp(to, w)
		elif out.has(key) and to is float:
			out[key] = lerpf(float(out[key]), to, w)
		else:
			out[key] = to
	return out


static func _ease(w: float) -> float:
	w = clampf(w, 0.0, 1.0)
	return w * w * (3.0 - 2.0 * w)


## The style for a legend.
static func for_legend(id: StringName) -> FightStyle:
	match id:
		&"vexa":
			return VexaStyle.new()
		&"lyra":
			return LyraStyle.new()
		&"brann":
			return BrannStyle.new()
	return KaelStyle.new()
