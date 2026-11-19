"""Design parameters for the procedural Kael. Edit these and re-run build_kael.py.

Units are metres. Blender axes: +Z up, the character faces -Y, his left is +X.
Feet rest on z = 0; the skull top sits near BODY_HEIGHT and the hair goes above it.
"""

# Overall size: about 7 heads tall without the hair, about 2 m with it.
BODY_HEIGHT = 1.88
HEAD_UNITS = 7.0
HEAD = BODY_HEIGHT / HEAD_UNITS  # One head height, about 0.27 m.

# Joint heights (z) and offsets (x), derived from the head unit so proportions scale together.
JOINTS = {
	"hips": 0.97,
	"spine": 1.07,
	"chest": 1.20,
	"upper_chest": 1.33,
	"neck": 1.51,
	"head": 1.61,
	"head_top": BODY_HEIGHT,
	"shoulder_x": 0.035,
	"upper_arm_x": 0.215,
	"arm_z": 1.475,
	"upper_arm_len": 0.285,
	"lower_arm_len": 0.255,
	"hand_len": 0.105,
	"leg_x": 0.098,
	"knee_z": 0.52,
	"ankle_z": 0.085,
	"toe_y": -0.12,
	"toe_tip_y": -0.215,
}

# Radii of the body volumes: (side-to-side, front-to-back).
RADII = {
	"neck": (0.06, 0.06),
	"upper_arm_top": (0.058, 0.06),
	"bicep": (0.056, 0.058),
	"elbow": (0.042, 0.045),
	"forearm": (0.05, 0.047),
	"wrist": (0.033, 0.03),
	"waist": (0.125, 0.095),
	"chest": (0.165, 0.11),
	"upper_chest": (0.175, 0.105),
	"shoulder": (0.07, 0.07),
}

# Toon colours per material slot (linear-ish sRGB values, set again in Godot materials).
COLORS = {
	"skin": (0.95, 0.73, 0.59),
	"gi_orange": (0.96, 0.45, 0.10),
	"gi_trim": (0.97, 0.96, 0.92),
	"navy": (0.09, 0.12, 0.27),
	"pants_orange": (0.93, 0.42, 0.09),
	"boots": (0.94, 0.93, 0.90),
	"hair": (0.08, 0.10, 0.23),
	"face": (0.95, 0.73, 0.59),
}

# Slots that get the toon specular band (the rest stay matte).
SPECULAR_SLOTS = ("boots",)

# Hair: list of spikes as (azimuth deg, elevation deg, length, base radius, sweep up, sweep back, curl).
# Azimuth 0 = front, 90 = his left, 180 = back. Elevation 90 = straight up from the crown.
HAIR_SPIKES = [
	# Crown: big swept-back flames, the silhouette's signature.
	(180, 60, 0.32, 0.064, 0.45, 0.95, 0.28),
	(150, 64, 0.30, 0.060, 0.55, 0.85, 0.25),
	(210, 64, 0.30, 0.060, 0.55, 0.85, 0.25),
	(170, 80, 0.30, 0.064, 0.85, 0.65, 0.28),
	(195, 82, 0.28, 0.060, 0.85, 0.6, 0.28),
	(120, 55, 0.27, 0.056, 0.5, 0.8, 0.22),
	(240, 55, 0.27, 0.056, 0.5, 0.8, 0.22),
	(180, 38, 0.25, 0.060, 0.1, 1.0, 0.15),
	(140, 36, 0.23, 0.054, 0.05, 0.95, 0.12),
	(220, 36, 0.23, 0.054, 0.05, 0.95, 0.12),
	(180, 15, 0.19, 0.054, -0.35, 0.95, 0.08),
	(155, 10, 0.16, 0.046, -0.45, 0.85, 0.08),
	(205, 10, 0.16, 0.046, -0.45, 0.85, 0.08),
	# Top front: two rising locks, asymmetric so the face reads from the front.
	(15, 72, 0.27, 0.06, 1.0, 0.45, 0.35),
	(-30, 70, 0.24, 0.058, 0.95, 0.5, 0.3),
	(55, 66, 0.26, 0.058, 0.8, 0.6, 0.28),
	(-62, 66, 0.25, 0.058, 0.8, 0.6, 0.28),
	# Upper sides: wide wings that give the head its width.
	(90, 52, 0.27, 0.056, 0.45, 0.7, 0.22),
	(-90, 52, 0.27, 0.056, 0.45, 0.7, 0.22),
	(75, 38, 0.21, 0.05, 0.25, 0.6, 0.18),
	(-75, 38, 0.21, 0.05, 0.25, 0.6, 0.18),
	# Sides: sweep back over the ears.
	(105, 24, 0.19, 0.046, 0.0, 0.85, 0.1),
	(-105, 24, 0.19, 0.046, 0.0, 0.85, 0.1),
	(130, 14, 0.16, 0.044, -0.2, 0.8, 0.1),
	(-130, 14, 0.16, 0.044, -0.2, 0.8, 0.1),
	# Sideburns in front of the ears.
	(78, 2, 0.11, 0.032, -1.2, 0.15, 0.0),
	(-78, 2, 0.11, 0.032, -1.2, 0.15, 0.0),
]

# Spikes rising steeper than HAIR_TALL_ELEVATION are shortened by HAIR_TALL_SCALE to keep him about 2 m tall.
HAIR_TALL_ELEVATION = 50
HAIR_TALL_SCALE = 0.84

# Bangs: (x offset, length, base radius, droop, side swing). They hang over the forehead.
HAIR_BANGS = [
	(0.03, 0.17, 0.034, 0.8, 0.35),
	(-0.035, 0.12, 0.030, 0.75, -0.25),
	(0.08, 0.11, 0.028, 0.8, 0.5),
	(-0.082, 0.13, 0.03, 0.85, -0.45),
	(-0.005, 0.08, 0.026, 0.6, 0.0),
]

# Random seed for small variations (cloth folds, hair jitter).
SEED = 7
