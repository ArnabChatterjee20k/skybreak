class_name KaelStyle
extends FightStyle
## Kael: karate shoto. Low, wide front stance, lead hand forward, rear fist chambered;
## sharp linear punches with the off hand snapped back to the hip (hikite), snap front kicks,
## a kiai freeze on every strike, and a rising uppercut.


func _init() -> void:
	legend = &"kael"
	hip_drop = 0.17
	lead_foot = Vector3(0.10, ANKLE, 0.42)
	rear_foot = Vector3(-0.18, ANKLE, -0.38)
	stance_yaw = -38.0
	chest_yaw = -6.0
	lean = 6.0
	lead_guard = Vector3(0.04, 1.22, 0.48)
	rear_guard = Vector3(-0.10, 1.08, 0.12)
	sway = 0.008
	sway_hz = 0.45
	walk_cycle = 0.45
	types = {&"5L": &"jab", &"5M": &"straight", &"5H": &"front", &"2L": &"front", &"2M": &"straight",
		&"2H": &"uppercut", &"3H": &"sweep", &"6M": &"hammer", &"6H": &"side", &"j.L": &"front",
		&"j.M": &"chop", &"j.H": &"side", &"5L>M": &"elbow", &"5M>H": &"front", &"iron_lunge": &"elbow"}
	keys = {
		&"skyward_fist": [
			[2, {"hip": Vector3(0, -0.42, 0.05), "sp": Vector3(25, 0, 0), "rh": Vector3(-0.05, 0.75, 0.25),
				"lh": Vector3(0.1, 1.0, 0.3), "hipr": Vector3(0, -10, 0)}],
			["s", {"hip": Vector3(0, -0.05, 0.08), "rh": Vector3(-0.02, 1.95, 0.32), "re": Vector3(-0.3, -1, 0.4),
				"hipr": Vector3(0, 35, 0), "sp": Vector3(-10, 0, 0), "lh": Vector3(0.15, 1.1, 0.0),
				"lf": Vector3(0.10, 0.55, 0.25), "lk": Vector3(0.2, 1, 1), "rf": Vector3(-0.1, ANKLE, -0.1)}],
			["e", {"hip": Vector3(0, 0.05, 0.0), "rh": Vector3(-0.0, 2.05, 0.15), "re": Vector3(-0.3, -1, 0.4),
				"hipr": Vector3(0, 60, 0), "sp": Vector3(-14, 0, 0), "lh": Vector3(0.18, 1.15, -0.05),
				"lf": Vector3(0.10, 0.50, 0.20), "rf": Vector3(-0.10, 0.25, -0.05)}],
			["r-8", {"hip": Vector3(0, -0.05, 0), "rh": Vector3(-0.1, 1.5, 0.2), "lf": Vector3(0.12, 0.35, 0.25),
				"rf": Vector3(-0.12, 0.3, -0.1), "sp": Vector3(5, 0, 0)}],
		],
		&"ridgeback_kick": [
			[5, {"hip": Vector3(0, -0.30, 0), "sp": Vector3(18, 0, 0)}],
			[12, {"rf": Vector3(-0.05, 1.75, 0.55), "rk": Vector3(0, 1, 0), "sp": Vector3(-20, 0, 0),
				"lf": Vector3(0.12, 0.35, 0.0), "lh": Vector3(0.3, 1.4, 0.2), "rh": Vector3(-0.3, 1.3, -0.1)}],
			["s", {"rf": Vector3(0.0, 0.85, 0.85), "rt": Vector3(0, -0.3, 1), "sp": Vector3(20, 0, 0),
				"lf": Vector3(0.12, 0.30, -0.05), "lh": Vector3(0.2, 1.0, 0.3), "rh": Vector3(-0.25, 1.0, -0.1)}],
			["e+4", {"hip": Vector3(0, -0.25, 0.1), "rf": Vector3(-0.1, ANKLE, 0.55), "sp": Vector3(15, 0, 0)}],
		],
		&"iron_lunge": [
			[3, {"hip": Vector3(0, -0.2, -0.12), "rh": Vector3(-0.15, 1.15, -0.1), "hipr": Vector3(0, -50, 0),
				"sp": Vector3(10, 0, 0)}],
			["s", {"hip": Vector3(0, -0.24, 0.30), "rh": Vector3(-0.05, 1.28, 0.45), "re": Vector3(-0.2, 0, 1),
				"lh": Vector3(0.12, 1.12, 0.10), "hipr": Vector3(0, 40, 0), "sp": Vector3(18, 0, 0),
				"lf": Vector3(0.12, ANKLE, 0.75), "rf": Vector3(-0.15, ANKLE, -0.45), "rt": Vector3(-0.8, 0, 0.5)}],
			["e", {"hip": Vector3(0, -0.24, 0.32), "rh": Vector3(-0.05, 1.28, 0.47), "re": Vector3(-0.2, 0, 1),
				"lh": Vector3(0.12, 1.12, 0.10), "hipr": Vector3(0, 42, 0), "sp": Vector3(18, 0, 0),
				"lf": Vector3(0.12, ANKLE, 0.75), "rf": Vector3(-0.15, ANKLE, -0.45)}],
		],
		&"thousand_petal": [
			[3, {"hip": Vector3(0, -0.25, -0.1), "rh": Vector3(-0.1, 1.05, 0.0), "lh": Vector3(0.1, 1.3, 0.4)}],
			["s", {"hip": Vector3(0, -0.22, 0.25), "rh": Vector3(-0.02, 1.3, 0.85), "hipr": Vector3(0, 40, 0),
				"lf": Vector3(0.12, ANKLE, 0.7), "rf": Vector3(-0.15, ANKLE, -0.5)}],
		],
		&"throw": [],
	}


func _hikite(other: String, _kind: StringName) -> Vector3:
	var mirror := 1.0 if other == "l" else -1.0
	return Vector3(0.16 * mirror, 1.0, -0.05)


func intro(t: float) -> Dictionary:
	var upright := stance(t)
	upright.hip = Vector3(0, -0.01, 0)
	upright.hipr = Vector3.ZERO
	upright.sp = Vector3.ZERO
	upright.ch = Vector3.ZERO
	upright.hd = Vector3.ZERO
	upright.lf = Vector3(0.10, ANKLE, 0.02)
	upright.rf = Vector3(-0.10, ANKLE, -0.02)
	upright.lt = Vector3(0, 0, 1)
	upright.rt = Vector3(0, 0, 1)
	upright.lh = Vector3(0.22, 0.85, 0.02)
	upright.rh = Vector3(-0.22, 0.85, 0.02)
	var bow := upright.duplicate()
	bow.sp = Vector3(22, 0, 0)
	bow.ch = Vector3(12, 0, 0)
	bow.hd = Vector3(10, 0, 0)
	bow.hip = Vector3(0, -0.02, -0.06)
	bow.lh = Vector3(0.20, 0.80, 0.12)
	bow.rh = Vector3(-0.20, 0.80, 0.12)
	var kiai := stance(t)
	kiai.rh = Vector3(-0.03, 1.3, 0.75)
	kiai.lh = _hikite("l", &"")
	kiai.hipr = Vector3(0, 40, 0)
	if t < 0.5:
		return upright
	if t < 1.0:
		return blend(upright, bow, _ease((t - 0.5) / 0.4))
	if t < 1.4:
		return blend(bow, kiai, _ease((t - 1.0) / 0.3))
	return blend(kiai, stance(t), _ease((t - 1.4) / 0.4))


func victory(n: int, t: float) -> Dictionary:
	var pose := stance(t)
	if n % 2 == 0:
		pose.hip = Vector3(0, -0.02, 0)
		pose.hipr = Vector3(0, -15, 0)
		pose.lf = Vector3(0.12, ANKLE, 0.15)
		pose.rf = Vector3(-0.12, ANKLE, -0.15)
		pose.rh = Vector3(-0.15, 2.05, 0.10)
		pose.re = Vector3(-1, 0, 0)
		pose.lh = _hikite("l", &"")
		pose.hd = Vector3(-12, 10, 0)
	else:
		pose.hip = Vector3(0, -0.28, 0)
		pose.hipr = Vector3(0, -90, 0)
		pose.lf = Vector3(0.38, ANKLE, 0.0)
		pose.rf = Vector3(-0.38, ANKLE, 0.0)
		pose.lt = Vector3(0, 0, 1)
		pose.rt = Vector3(0, 0, 1)
		pose.lk = Vector3(1, 0, 0.5)
		pose.rk = Vector3(-1, 0, 0.5)
		pose.lh = Vector3(0.45, 1.32, 0.42)
		pose.rh = _hikite("r", &"")
		pose.hd = Vector3(0, 90, 0)
	var settle := clampf(t / 0.4, 0.0, 1.0)
	return blend(stance(t), pose, _ease(settle))


func defeat(t: float) -> Dictionary:
	# Down on one knee, a fist on the floor, head bowed.
	var pose := kneel()
	pose.rh = Vector3(-0.18, 0.12, 0.30)
	pose.lh = Vector3(0.20, 0.75, 0.25)
	pose.hd = Vector3(30, 0, 0)
	pose.sp = Vector3(28, 0, 0)
	return blend(stance(t), pose, _ease(clampf(t / 0.6, 0.0, 1.0)))
