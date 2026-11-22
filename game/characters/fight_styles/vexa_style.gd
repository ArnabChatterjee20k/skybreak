class_name VexaStyle
extends FightStyle
## Vexa: acrobatic capoeira and taekwondo. A bouncing ginga (feet trading back steps, the
## same-side arm sweeping across the face), spinning and flipping kicks, a handstand
## upkick, cartwheel evades and a tumbling dive kick.


func _init() -> void:
	legend = &"vexa"
	hip_drop = 0.16
	lead_foot = Vector3(0.24, ANKLE, 0.10)
	rear_foot = Vector3(-0.24, ANKLE, -0.08)
	stance_yaw = -15.0
	chest_yaw = 0.0
	lean = 14.0
	lead_guard = Vector3(0.18, 1.20, 0.30)
	rear_guard = Vector3(-0.30, 1.0, -0.10)
	sway = 0.03
	sway_hz = 0.7
	walk_cycle = 0.42
	types = {&"5L": &"backfist", &"5M": &"side", &"5H": &"spin", &"2L": &"sweep", &"2M": &"front",
		&"2H": &"up", &"3H": &"sweep", &"6M": &"axe", &"6H": &"round", &"j.L": &"front",
		&"j.M": &"round", &"j.H": &"spin", &"5L>M": &"round", &"2M>H": &"sweep",
		&"crescent_wheel": &"spin", &"hurricane_ginga": &"spin"}
	keys = {
		&"2H": [
			[3, {"hip": Vector3(0, -0.45, 0.1), "sp": Vector3(60, 0, 0), "lh": Vector3(0.2, 0.08, 0.35),
				"rh": Vector3(-0.2, 0.08, 0.35), "le": Vector3(1, 0, 0), "re": Vector3(-1, 0, 0)}],
			["s", {"hip": Vector3(0, -0.30, 0.15), "hipr": Vector3(150, -15, 0), "lh": Vector3(0.2, 0.08, 0.30),
				"rh": Vector3(-0.2, 0.08, 0.30), "rf": Vector3(-0.05, 1.95, 0.45), "lf": Vector3(0.15, 1.5, -0.2),
				"rk": Vector3(0, 0, 1), "lk": Vector3(0, 0, -1), "rt": Vector3(0, 1, 0.3), "lt": Vector3(0, 1, 0)}],
			["e", {"hip": Vector3(0, -0.28, 0.15), "hipr": Vector3(160, -15, 0), "lh": Vector3(0.2, 0.08, 0.30),
				"rh": Vector3(-0.2, 0.08, 0.30), "rf": Vector3(-0.05, 2.0, 0.40), "lf": Vector3(0.15, 1.45, -0.25),
				"rt": Vector3(0, 1, 0.3), "lt": Vector3(0, 1, 0)}],
			["r-6", {"hip": Vector3(0, -0.4, 0.0), "sp": Vector3(40, 0, 0)}],
		],
		&"flip_kick": [
			[2, {"hip": Vector3(0, -0.35, 0), "sp": Vector3(25, 0, 0)}],
			["s", {"hipr": Vector3(-120, -15, 0), "rf": Vector3(0.0, 1.9, 0.55), "rk": Vector3(0, 0, 1),
				"rt": Vector3(0, 1, 0.5), "lf": Vector3(0.1, 1.0, -0.1), "lh": Vector3(0.4, 0.9, -0.3),
				"rh": Vector3(-0.4, 0.9, -0.3), "sp": Vector3(-25, 0, 0)}],
			["e+6", {"hipr": Vector3(-300, -15, 0), "rf": Vector3(-0.05, 0.6, 0.2), "lf": Vector3(0.1, 0.5, 0.0),
				"lh": Vector3(0.4, 1.4, 0.0), "rh": Vector3(-0.4, 1.4, 0.0)}],
			["r-10", {"hipr": Vector3(-360, -15, 0), "hip": Vector3(0, -0.3, 0)}],
		],
		&"cartwheel": [
			[3, {"hip": Vector3(0, -0.2, 0.1), "hipr": Vector3(0, -90, -60), "lh": Vector3(0.6, 0.3, 0.2),
				"rh": Vector3(-0.1, 1.6, 0.0)}],
			[9, {"hip": Vector3(0, 0.05, 0.1), "hipr": Vector3(0, -90, -180), "lh": Vector3(0.25, 0.1, 0.2),
				"rh": Vector3(-0.25, 0.1, 0.2), "lf": Vector3(0.6, 1.7, 0.0), "rf": Vector3(-0.6, 1.7, 0.0),
				"lt": Vector3(0, 1, 0), "rt": Vector3(0, 1, 0)}],
			[16, {"hip": Vector3(0, -0.1, 0.1), "hipr": Vector3(0, -90, -290), "rh": Vector3(-0.6, 0.3, 0.2),
				"lh": Vector3(0.1, 1.6, 0.0), "lf": Vector3(0.5, 0.9, 0.0)}],
			[22, {"hipr": Vector3(0, -30, -360), "hip": Vector3(0, -0.2, 0)}],
		],
		&"dive_kick": [
			[3, {"hipr": Vector3(30, -40, 0), "rf": Vector3(-0.05, 0.5, 0.2), "lf": Vector3(0.1, 0.6, -0.1),
				"lh": Vector3(0.3, 1.5, -0.1), "rh": Vector3(-0.3, 1.4, -0.1)}],
			["s", {"hipr": Vector3(40, -60, 0), "rf": Vector3(0.0, -0.05, 0.65), "rk": Vector3(0, 1, 0.3),
				"rt": Vector3(0, -0.6, 1), "lf": Vector3(0.12, 0.65, -0.15), "lh": Vector3(0.35, 1.5, -0.2),
				"rh": Vector3(-0.35, 1.45, -0.25), "sp": Vector3(10, 0, 0)}],
			["e", {"hipr": Vector3(40, -60, 0), "rf": Vector3(0.0, -0.05, 0.65), "rt": Vector3(0, -0.6, 1),
				"lf": Vector3(0.12, 0.65, -0.15), "lh": Vector3(0.35, 1.5, -0.2), "rh": Vector3(-0.35, 1.45, -0.25)}],
		],
		&"throw": [],
	}


## Ginga: feet trade a back step every half cycle, the same-side arm sweeps over the face.
func stance(t: float) -> Dictionary:
	var pose := super(t)
	var cycle := 1.5
	var phase := fposmod(t / cycle, 1.0)
	var swing := sin(phase * TAU)
	var left_back := maxf(swing, 0.0)
	var right_back := maxf(-swing, 0.0)
	# A foot only moves while it is off the floor: the lift is up whenever it travels.
	var lift_l := 0.08 * sqrt(absf(sin(phase * TAU * 2.0))) if phase < 0.5 else 0.0
	var lift_r := 0.08 * sqrt(absf(sin(phase * TAU * 2.0))) if phase >= 0.5 else 0.0
	pose.lf = lead_foot + Vector3(0.0, lift_l, -0.42 * left_back * left_back)
	pose.rf = rear_foot + Vector3(0.0, lift_r, -0.42 * right_back * right_back)
	pose.hip = Vector3(0.02 * swing, -hip_drop - 0.04 * absf(swing), -0.10 * absf(swing))
	pose.hipr = Vector3(0, stance_yaw + 18.0 * swing, 0)
	pose.lh = Vector3(0.10 + 0.08 * left_back, 1.05 + 0.30 * left_back, 0.30)
	pose.rh = Vector3(-0.10 - 0.08 * right_back, 1.05 + 0.30 * right_back, 0.30)
	pose.hd = Vector3(-lean * 1.2, -(stance_yaw + 18.0 * swing), 0)
	return pose


func walk(t: float, forward: bool, speed: float) -> Dictionary:
	var pose := super(t, forward, speed)
	var spine: Vector3 = pose.sp
	pose.sp = spine + Vector3(4.0, 0, 6.0 * sin(t * 6.0))
	return pose


func intro(t: float) -> Dictionary:
	# A one-handed cartwheel into the ginga.
	var f := clampf(t / 1.2, 0.0, 1.0)
	var base := stance(t)
	if f >= 1.0:
		return base
	var flip := base.duplicate()
	flip.hipr = Vector3(0, -90, -360.0 * _ease(f))
	flip.hip = Vector3(0, 0.05 * sin(f * PI), 0)
	flip.lh = Vector3(0.6, 0.3 + 0.8 * (1.0 - absf(sin(f * PI))), 0.1)
	flip.lf = Vector3(0.6, 0.13 + 1.4 * sin(f * PI), 0)
	flip.rf = Vector3(-0.6, 0.13 + 1.4 * sin(f * PI), 0)
	return blend(flip, base, _ease((f - 0.85) / 0.15))


func victory(n: int, t: float) -> Dictionary:
	var pose := stance(t)
	if n % 2 == 0:
		pose.hip = Vector3(0, -0.1, 0)
		pose.hipr = Vector3(0, 20, 0)
		pose.lh = Vector3(0.35, 1.9, 0.1)
		pose.rh = Vector3(-0.15, 1.05, 0.1)
		pose.lf = Vector3(0.15, ANKLE, 0.1)
		pose.rf = Vector3(-0.05, 0.5, 0.15)
		pose.rk = Vector3(0, 0.5, 1)
		pose.hd = Vector3(-15, -20, 10)
	else:
		pose.hip = Vector3(0, -0.4, 0)
		pose.hipr = Vector3(0, -40, 0)
		pose.sp = Vector3(30, 0, 0)
		pose.lh = Vector3(0.25, 0.1, 0.3)
		pose.rh = Vector3(-0.3, 1.5, -0.2)
		pose.lf = Vector3(0.3, ANKLE, 0.3)
		pose.rf = Vector3(-0.3, ANKLE, -0.3)
		pose.hd = Vector3(-30, 40, 0)
	return blend(stance(t), pose, _ease(clampf(t / 0.35, 0.0, 1.0)))
