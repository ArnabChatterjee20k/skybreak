class_name LyraStyle
extends FightStyle
## Lyra: savate and taekwondo kicker. Tall, narrow and up on the balls of her feet with a
## light bounce, hands loose and low; long precise kicks from a high chamber, a hopping axe,
## a vaulting axe kick and a counter stance that answers with a spinning back kick.


func _init() -> void:
	legend = &"lyra"
	hip_drop = 0.05
	lead_foot = Vector3(0.07, ANKLE + 0.02, 0.30)
	rear_foot = Vector3(-0.10, ANKLE + 0.03, -0.30)
	stance_yaw = -28.0
	chest_yaw = -4.0
	lean = 2.0
	head_pitch = 4.0
	lead_guard = Vector3(0.12, 1.12, 0.32)
	rear_guard = Vector3(-0.02, 1.22, 0.12)
	sway = 0.006
	bounce = 0.025
	bounce_hz = 2.2
	walk_stride = 0.30
	types = {&"5L": &"jab", &"5M": &"round", &"5H": &"side", &"2L": &"front", &"2M": &"round",
		&"2H": &"up", &"3H": &"sweep", &"6M": &"axe", &"4H": &"spin", &"j.L": &"front",
		&"j.M": &"round", &"j.H": &"side", &"5M>M": &"round", &"5L>H": &"side",
		&"constellation": &"round"}
	keys = {
		&"vaulting_axe": [
			[3, {"hip": Vector3(0, -0.28, 0), "sp": Vector3(20, 0, 0), "lh": Vector3(0.2, 0.9, 0.1),
				"rh": Vector3(-0.2, 0.9, 0.0)}],
			[12, {"hip": Vector3(0, 0.0, 0.0), "rf": Vector3(-0.05, 2.05, 0.45), "rk": Vector3(0, 1, 0),
				"lf": Vector3(0.1, 0.55, -0.1), "sp": Vector3(-22, 0, 0), "lh": Vector3(0.4, 1.6, -0.1),
				"rh": Vector3(-0.4, 1.6, -0.1)}],
			["s", {"rf": Vector3(0.0, 1.05, 0.9), "rt": Vector3(0, -0.3, 1), "sp": Vector3(18, 0, 0),
				"lf": Vector3(0.1, 0.35, -0.1), "lh": Vector3(0.3, 1.1, 0.1), "rh": Vector3(-0.3, 1.0, -0.2)}],
			["e+5", {"hip": Vector3(0, -0.2, 0.05), "rf": Vector3(-0.1, ANKLE, 0.5), "sp": Vector3(12, 0, 0)}],
		],
		&"rising_crescent": [
			[2, {"hip": Vector3(0, -0.3, 0), "sp": Vector3(15, 0, 0)}],
			["s", {"hipr": Vector3(-20, -90, 0), "rf": Vector3(0.1, 1.85, 0.55), "rk": Vector3(0, 0, 1),
				"rt": Vector3(0, 0.6, 1), "lf": Vector3(0.1, 0.35, -0.1), "sp": Vector3(-20, 0, 0),
				"lh": Vector3(0.4, 1.3, -0.1), "rh": Vector3(-0.4, 1.2, -0.1)}],
			["e+2", {"hipr": Vector3(-25, -170, 0), "rf": Vector3(-0.3, 1.5, 0.1), "lf": Vector3(0.1, 0.5, 0.0)}],
			["r-8", {"hipr": Vector3(0, -360 + stance_yaw, 0), "hip": Vector3(0, -0.1, 0)}],
		],
		&"starguard": [
			[3, {"hip": Vector3(0, -0.14, -0.08), "lh": Vector3(0.20, 1.40, 0.35), "rh": Vector3(-0.05, 1.10, 0.30),
				"le": Vector3(1, -0.3, 0.4), "fist": 0.0, "sp": Vector3(-5, 0, 0)}],
			[22, {"hip": Vector3(0, -0.15, -0.10), "lh": Vector3(0.22, 1.42, 0.36), "rh": Vector3(-0.05, 1.12, 0.32),
				"le": Vector3(1, -0.3, 0.4), "fist": 0.0, "sp": Vector3(-6, 0, 0)}],
			[24, {"hipr": Vector3(0, 150, 0), "rf": Vector3(0.0, 0.7, 0.3), "hd": Vector3(0, -150, 0)}],
			[27, {"hipr": Vector3(0, 250, -20), "rf": Vector3(0.0, 1.15, 1.05), "rk": Vector3(0, 1, 0),
				"rt": Vector3(0, -0.2, 1), "lh": Vector3(0.3, 1.2, -0.1), "rh": Vector3(-0.3, 1.0, -0.2)}],
			[36, {"hipr": Vector3(0, 330, 0), "rf": Vector3(-0.1, 0.4, -0.1)}],
		],
		&"throw": [],
	}


func intro(t: float) -> Dictionary:
	# Salutes with a slow high kick held at head height, then drops into guard.
	var held := stance(t)
	held.rf = Vector3(0.0, 1.75, 0.80)
	held.rk = Vector3(0, 1, 0.2)
	held.rt = Vector3(0, 0.3, 1)
	held.lf = Vector3(0.06, ANKLE + 0.04, -0.05)
	held.sp = Vector3(-14, 0, 0)
	held.lh = Vector3(0.3, 1.2, 0.0)
	held.rh = Vector3(-0.35, 1.0, -0.15)
	if t < 0.4:
		return blend(stance(t), held, _ease(t / 0.4))
	if t < 1.3:
		return held
	return blend(held, stance(t), _ease((t - 1.3) / 0.4))


func victory(n: int, t: float) -> Dictionary:
	var pose := stance(t)
	if n % 2 == 0:
		pose.hip = Vector3(0, 0.0, 0)
		pose.hipr = Vector3(0, 0, 0)
		pose.lf = Vector3(0.05, ANKLE, 0.05)
		pose.rf = Vector3(-0.02, 0.55, 0.05)
		pose.rk = Vector3(-0.6, 0, 0.8)
		pose.rt = Vector3(0, -0.5, 1)
		pose.lh = Vector3(0.20, 1.95, 0.0)
		pose.rh = Vector3(-0.20, 1.95, 0.0)
		pose.hd = Vector3(-10, 0, 0)
	else:
		pose.hipr = Vector3(0, -30, 0)
		pose.lh = Vector3(0.08, 1.6, 0.3)
		pose.rh = Vector3(-0.25, 1.0, -0.05)
		pose.lw = Vector3(0, 0, 90)
		pose.hd = Vector3(5, 30, -8)
	return blend(stance(t), pose, _ease(clampf(t / 0.4, 0.0, 1.0)))


func _hikite(other: String, _kind: StringName) -> Vector3:
	return lead_guard if other == "l" else rear_guard
