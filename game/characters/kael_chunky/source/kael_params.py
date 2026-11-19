"""Design parameters for chunky Kael (GAME_DESIGN.md section 6). Edit and re-run build_kael.py.

Units are metres. Blender axes: +Z up, he faces -Y, his left is +X. Feet on z = 0.
About 4.5 heads tall: a big head, broad shoulders, oversized hands and feet, short legs.
"""

# Joint heights (z) and side offsets (x).
J = {
	"ankle": 0.13,
	"knee": 0.43,
	"hips": 0.80,
	"spine": 0.90,
	"chest": 1.01,
	"upper_chest": 1.12,
	"neck": 1.30,
	"head": 1.38,
	"leg_x": 0.135,
	"shoulder_x": 0.05,
	"upper_arm_x": 0.30,
	"arm_z": 1.27,
	"upper_arm_len": 0.25,
	"lower_arm_len": 0.24,
	"hand_len": 0.12,
	"toe_y": -0.15,
	"toe_tip_y": -0.27,
}

# The head: one big rounded volume. About 0.45 m from chin to crown.
HEAD_CENTRE = (0.0, -0.01, 1.60)
HEAD_RADII = (0.205, 0.195, 0.225)

# Toon colours per material slot (sRGB). Two main colours (teal, orange) plus gold and charcoal.
# Kept a little dark: the toon shader's bands and rim brighten them on screen.
COLORS = {
	"skin": (0.96, 0.74, 0.6),
	"face": (0.96, 0.74, 0.6),
	"hair": (0.64, 0.68, 0.78),
	"coat": (0.03, 0.42, 0.44),
	"gold": (0.9, 0.6, 0.14),
	"tunic": (0.19, 0.19, 0.23),
	"pants": (0.3, 0.26, 0.26),
	"boots": (0.9, 0.4, 0.09),
	"scarf": (0.95, 0.36, 0.07),
	"leather": (0.33, 0.2, 0.13),
	"lens": (0.5, 0.85, 0.9),
}

# Slots that get the toon specular band (metal and glass); the rest stay matte.
SPECULAR_SLOTS = ("gold", "lens")
# Cooler shadow tint for the silver hair, so it does not go grey.
SHADOW_TINTS = {"hair": (0.5, 0.55, 0.82), "skin": (0.78, 0.5, 0.52), "face": (0.78, 0.5, 0.52)}

# Hair tufts: (azimuth deg, elevation deg, length, base radius, bend). Azimuth 0 = front, 90 = his
# left. Short, fat, windswept clumps above and behind the goggle strap; every tuft leans back.
HAIR_TUFTS = [
	# Crown: low, fat clumps swept back.
	(10, 66, 0.12, 0.09, 0.7),
	(-40, 60, 0.12, 0.085, 0.65),
	(50, 58, 0.12, 0.085, 0.65),
	(160, 70, 0.14, 0.09, 0.55),
	(115, 56, 0.15, 0.085, 0.5),
	(245, 56, 0.15, 0.085, 0.5),
	# Upper sides: they give the head its width from the front and back.
	(80, 36, 0.15, 0.08, 0.45),
	(-80, 36, 0.15, 0.08, 0.45),
	# Back: layered clumps fanning out down to the nape.
	(180, 40, 0.15, 0.09, 0.35),
	(140, 28, 0.17, 0.085, 0.3),
	(220, 28, 0.17, 0.085, 0.3),
	(180, 10, 0.14, 0.08, 0.15),
	(125, 4, 0.14, 0.072, 0.1),
	(235, 4, 0.14, 0.072, 0.1),
	# Over the ears.
	(100, 14, 0.11, 0.06, -0.3),
	(-100, 14, 0.11, 0.06, -0.3),
]

# Fringe over the forehead under the goggles: (x offset, length, base radius, side swing).
HAIR_FRINGE = [
	(-0.11, 0.11, 0.055, -0.45),
	(-0.04, 0.13, 0.06, -0.15),
	(0.035, 0.12, 0.06, 0.15),
	(0.105, 0.1, 0.055, 0.45),
]

# Scarf tail chain: number of bones and the tail length (m).
SCARF_BONES = 5
SCARF_LENGTH = 0.95

SEED = 11
