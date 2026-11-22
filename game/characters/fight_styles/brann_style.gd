class_name BrannStyle
extends FightStyle
## Brann: wrestler-boxer heavyweight. Hunched behind the gauntlets, a slow heavy weight
## shift; wide looping hooks with the whole body, an armoured shoulder advance, suplexes
## and slams.


func _init() -> void:
	legend = &"brann"
	hip_drop = 0.13
	lead_foot = Vector3(0.18, ANKLE, 0.30)
	rear_foot = Vector3(-0.22, ANKLE, -0.30)
	stance_yaw = -22.0
	chest_yaw = -6.0
	lean = 20.0
	head_pitch = -4.0
	lead_guard = Vector3(0.10, 1.38, 0.30)
	rear_guard = Vector3(-0.10, 1.34, 0.24)
	sway = 0.012
	sway_hz = 0.35
	walk_cycle = 0.6
	types = {&"5L": &"jab", &"5M": &"hook", &"5H": &"hook", &"2L": &"axe", &"2M": &"uppercut",
		&"2H": &"uppercut", &"3H": &"sweep", &"6M": &"hammer", &"j.L": &"elbow", &"j.M": &"hammer",
		&"5L>M": &"hook", &"5M>H": &"hook", &"gauntlet_uppercut": &"uppercut"}
	keys = {
		&"5H": [
			[4, {"hipr": Vector3(0, -55, 0), "rh": Vector3(-0.45, 1.45, -0.25), "sp": Vector3(10, 0, -6),
				"hip": Vector3(0, -0.16, -0.08)}],
			["s", {"hipr": Vector3(0, 50, 0), "rh": Vector3(0.0, 1.38, 1.0), "re": Vector3(-1, 0.4, -0.1),
				"sp": Vector3(28, 0, 6), "hip": Vector3(0, -0.18, 0.12), "lh": Vector3(0.15, 1.3, 0.1),
				"rf": Vector3(-0.22, ANKLE, -0.25), "rt": Vector3(-0.9, 0, 0.4)}],
			["e+4", {"hipr": Vector3(0, 70, 0), "rh": Vector3(0.25, 1.1, 0.6), "sp": Vector3(32, 0, 8)}],
		],
		&"6M": [
			[6, {"lh": Vector3(0.03, 1.95, 0.0), "rh": Vector3(-0.03, 1.95, 0.0), "sp": Vector3(-12, 0, 0),
				"hip": Vector3(0, -0.05, -0.05)}],
			["s", {"lh": Vector3(0.03, 1.15, 0.80), "rh": Vector3(-0.03, 1.15, 0.80), "sp": Vector3(38, 0, 0),
				"le": Vector3(1, 0.5, 0), "re": Vector3(-1, 0.5, 0), "hip": Vector3(0, -0.22, 0.1)}],
			["e+5", {"lh": Vector3(0.05, 1.0, 0.6), "rh": Vector3(-0.05, 1.0, 0.6), "sp": Vector3(35, 0, 0)}],
		],
		&"iron_suplex": [
			[3, {"lh": Vector3(0.25, 1.2, 0.7), "rh": Vector3(-0.25, 1.15, 0.7), "sp": Vector3(30, 0, 0),
				"hip": Vector3(0, -0.2, 0.15), "fist": 0.0}],
			["e", {"lh": Vector3(0.20, 1.2, 0.75), "rh": Vector3(-0.20, 1.15, 0.75), "sp": Vector3(30, 0, 0),
				"hip": Vector3(0, -0.2, 0.18), "fist": 0.0}],
		],
		&"mountain_drop": [
			[2, {"lh": Vector3(0.25, 1.2, 0.8), "rh": Vector3(-0.25, 1.15, 0.8), "sp": Vector3(30, 0, 0),
				"hip": Vector3(0, -0.2, 0.2), "fist": 0.0}],
			["e", {"lh": Vector3(0.20, 1.2, 0.85), "rh": Vector3(-0.20, 1.15, 0.85), "sp": Vector3(30, 0, 0),
				"hip": Vector3(0, -0.2, 0.22), "fist": 0.0}],
		],
		&"throw": [],
	}


func stance(t: float) -> Dictionary:
	var pose := super(t)
	var shift := sin(t * TAU * sway_hz)
	var hips: Vector3 = pose.hip
	pose.hip = hips + Vector3(0.05 * shift, 0, 0)
	pose.hipr = Vector3(0, stance_yaw, -3.0 * shift)
	pose.ch = Vector3(lean * 0.5, chest_yaw, 3.0 * shift)
	return pose


func _hikite(other: String, _kind: StringName) -> Vector3:
	return lead_guard if other == "l" else rear_guard


## Suplex and Mountain Drop: lift over the head, arch back, slam.
func throwing(id: StringName, tick: int, length: int) -> Dictionary:
	if id != &"iron_suplex" and id != &"mountain_drop":
		return super(id, tick, length)
	var f := clampf(float(tick) / maxf(length, 1), 0.0, 1.0)
	var hold := stance(0.0)
	hold.lh = Vector3(0.22, 1.25, 0.45)
	hold.rh = Vector3(-0.22, 1.2, 0.45)
	hold.fist = 0.0
	var lift := hold.duplicate()
	lift.lh = Vector3(0.22, 2.05, 0.15)
	lift.rh = Vector3(-0.22, 2.05, 0.15)
	lift.sp = Vector3(-20, 0, 0)
	lift.hip = Vector3(0, -0.05, -0.05)
	var slam := hold.duplicate()
	slam.lh = Vector3(0.22, 0.55, 0.85)
	slam.rh = Vector3(-0.22, 0.55, 0.85)
	slam.sp = Vector3(55, 0, 0)
	slam.hip = Vector3(0, -0.38, 0.15)
	if f < 0.2:
		return blend(stance(0.0), hold, _ease(f / 0.2))
	if f < 0.6:
		return blend(hold, lift, _ease((f - 0.2) / 0.4))
	if f < 0.75:
		return blend(lift, slam, _ease((f - 0.6) / 0.15))
	return blend(slam, stance(0.0), _ease((f - 0.75) / 0.25))


func intro(t: float) -> Dictionary:
	# Smashes the gauntlets together twice, then hunches into guard.
	var open := stance(t)
	open.lh = Vector3(0.45, 1.35, 0.3)
	open.rh = Vector3(-0.45, 1.35, 0.3)
	open.sp = Vector3(5, 0, 0)
	var smash := stance(t)
	smash.lh = Vector3(0.05, 1.35, 0.45)
	smash.rh = Vector3(-0.05, 1.35, 0.45)
	smash.sp = Vector3(25, 0, 0)
	var beat := fposmod(t, 0.6) / 0.6
	if t < 1.2:
		return blend(open, smash, _ease(1.0 - absf(beat * 2.0 - 1.0)))
	return blend(smash, stance(t), _ease((t - 1.2) / 0.4))


func victory(n: int, t: float) -> Dictionary:
	var pose := stance(t)
	if n % 2 == 0:
		pose.sp = Vector3(-8, 0, 0)
		pose.hipr = Vector3(0, 0, 0)
		pose.lh = Vector3(0.45, 1.75, 0.2)
		pose.rh = Vector3(-0.45, 1.75, 0.2)
		pose.le = Vector3(1, -1, 0)
		pose.re = Vector3(-1, -1, 0)
		pose.hd = Vector3(-20, 0, 0)
	else:
		pose.sp = Vector3(35, 0, 0)
		pose.hip = Vector3(0, -0.3, 0)
		pose.rh = Vector3(-0.05, 0.3, 0.6)
		pose.lh = Vector3(0.3, 1.2, 0.1)
		pose.hd = Vector3(-25, 0, 0)
	return blend(stance(t), pose, _ease(clampf(t / 0.4, 0.0, 1.0)))
