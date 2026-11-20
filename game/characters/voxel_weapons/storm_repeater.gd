extends VoxelWeaponDesign
## The Storm Repeater (shared pickup, docs/lookdev/weapons.md), in the item
## gold family. Big: a long charcoal receiver, a wooden stock, three barrels.
## Medium: the gold drum magazine, a barrel clamp and muzzle ring, a
## foregrip, the raked grip. Tiny: drum flutes and rivets, the glowing gold
## charge rail, the item spark mark on the drum face (fine cell), a sight.

const GRIP_TILT := deg_to_rad(12.0)
const BARREL_Y := 0.2


func kind() -> Weapon.Kind:
	return Weapon.Kind.STORM_REPEATER


func palette() -> Dictionary:
	return {
		Mat.BODY: Color("#34333b"), Mat.BODY_DARK: Color("#222128"), Mat.EDGE: Color("#7a7c86"),
		Mat.TRIM: Color("#d9a441"), Mat.TRIM_DARK: Color("#8c6020"),
		Mat.RIVET: Color("#f0cd78"), Mat.ENGRAVE: Color("#5a3a12"), Mat.EMBLEM: Color("#fff0c8"),
		Mat.WOOD: Color("#8a5a30"), Mat.CLOTH_DARK: Color("#6a4424"), Mat.STITCH: Color("#5e3a1c"),
		Mat.GRIP: Color("#5a3420"), Mat.GRIP_DARK: Color("#2e1a10"),
		Mat.GLOW: Color("#ffc640"), Mat.GLOW_CORE: Color("#fff0c8"),
	}


func build_grids() -> Array[VoxelGrid]:
	return [_gun(), _drum_face(1.0), _drum_face(-1.0)]


static func grip_local(p: Vector3) -> Vector3:
	return Basis(Vector3.RIGHT, GRIP_TILT) * (p - Vector3(0, 0, 0.02))


func _gun() -> VoxelGrid:
	var all := AABB(Vector3(-0.14, -0.14, -0.84), Vector3(0.28, 0.44, 1.32))
	var g := grid(all)
	var c := g.cell
	# Grip, in slanted leather bands, and a gold cap.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(grip_local(p), Vector3.ZERO, Vector3(0.04, 0.1, 0.055), 0.012), Mat.GRIP_DARK)
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		if absf(q.y) > 0.08:
			return 1.0
		return VoxelSdf.box(q, Vector3.ZERO, Vector3(0.04 + c * 0.9, 0.1, 0.055 + c * 0.9), 0.012) \
			if fposmod((q.y + q.z * 0.5) / 0.03, 1.0) < 0.6 else 1.0, Mat.GRIP, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(grip_local(p), Vector3(0, -0.105, 0), Vector3(0.046, 0.014, 0.06), 0.006), Mat.TRIM)
	# Receiver: a long charcoal block with a darker top and a gold seam.
	g.paint(all, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.16, -0.12)
		var cham := (absf(q.x) + absf(q.y)) * 0.75 - 0.105
		return maxf(VoxelSdf.box(q, Vector3.ZERO, Vector3(0.08, 0.09, 0.25)), cham), Mat.BODY)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if p.y > 0.235 else 1.0, Mat.BODY_DARK, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if absf(p.y - 0.12) < c * 0.6 and holds(g, p, Mat.BODY) else 1.0, Mat.TRIM, -1, PAINT)
	# The glowing charge rail along both sides.
	for s: float in [-1.0, 1.0]:
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.085 * s, 0.18, -0.12), Vector3(c * 0.7, c * 0.8, 0.2)), Mat.GLOW, -1, ADD)
		for z: float in [-0.33, 0.09]:
			rivet(g, Vector3(0.082 * s, 0.18, z), Vector3(s, 0, 0), c)
	# Sight on top.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.27, -0.05), Vector3(0.018, 0.02, 0.04), c * 0.4), Mat.BODY_DARK, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.28, -0.05), Vector3(0.006, 0.012, 0.02)), Mat.EMPTY, -1, CARVE)
	# Stock: wood with a gold butt plate and a stitched leather cheek pad.
	g.paint(all, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.1, 0.3)
		var taper := q.y + (q.z + 0.15) * 0.25 - 0.06
		# Deeper at the butt than at the receiver.
		var drop := clampf((q.z + 0.15) / 0.3, 0.0, 1.0) * 0.035
		return maxf(VoxelSdf.box(q - Vector3(0, -drop * 0.5, 0), Vector3.ZERO, Vector3(0.05, 0.055 + drop * 0.5, 0.15), c),
			-taper - 0.13), Mat.WOOD)
	# Wood grain: darker streaks along the stock, a gold butt plate, two gold pins.
	g.paint(all, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		var streak := fposmod(p.y / (c * 3.0) + sin(p.z * 18.0) * 0.4, 1.0) < 0.3
		return -1.0 if streak and VoxelSdf.hash3(Vector3i(cc.x, cc.y, cc.z / 4), 29) < 0.8 and holds(g, p, Mat.WOOD) else 1.0,
		Mat.CLOTH_DARK, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if p.z > 0.41 and (holds(g, p, Mat.WOOD) or holds(g, p, Mat.CLOTH_DARK)) else 1.0, Mat.TRIM, -1, PAINT)
	for s: float in [-1.0, 1.0]:
		for z: float in [0.22, 0.36]:
			rivet(g, Vector3(0.05 * s, 0.09, z), Vector3(s, 0, 0), c, Mat.RIVET)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.155, 0.28), Vector3(0.054, 0.018, 0.08), c * 0.5), Mat.GRIP, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if holds(g, p, Mat.GRIP) and p.y > 0.14 and absf(absf(p.z - 0.28) - 0.07) < c * 0.6 else 1.0,
		Mat.STITCH, -1, PAINT)
	# The gold drum under the receiver: flutes and rivets.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(-0.06, 0.03, -0.12), Vector3(0.06, 0.03, -0.12), 0.12, 0.12), Mat.TRIM, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		var d := Vector2(p.y - 0.03, p.z + 0.12)
		var on := d.length() > 0.11 and fposmod(atan2(d.y, d.x) / TAU * 16.0, 1.0) < 0.3 and absf(p.x) < 0.045
		return -1.0 if on else 1.0, Mat.TRIM_DARK, -1, PAINT)
	# Three barrels in a gold clamp, a muzzle ring.
	for k in 3:
		var a := TAU * k / 3.0 + PI * 0.5
		var off := Vector3(cos(a) * 0.045, sin(a) * 0.045, 0)
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, BARREL_Y, -0.33) + off, Vector3(0, BARREL_Y, -0.8) + off, 0.028, 0.026), Mat.EDGE)
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, BARREL_Y, -0.76) + off, Vector3(0, BARREL_Y, -0.82) + off, 0.013, 0.013), Mat.EMPTY, -1, CARVE)
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, BARREL_Y, -0.75) + off, Vector3(0, BARREL_Y, -0.77) + off, 0.014, 0.014), Mat.GLOW, -1, PAINT)
	for z: float in [-0.5, -0.77]:
		g.paint(all, func(p: Vector3) -> float:
			return maxf(VoxelSdf.torus(p, Vector3(0, BARREL_Y, z), Vector3(0, 0, 1), 0.075, 0.016), 0.0), Mat.TRIM, -1, ADD)
	# Foregrip for the off hand (WeaponGrip.OFF_HAND).
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.12, -0.46), Vector3(0.03, 0.04, 0.05), c * 0.5), Mat.BODY, -1, ADD)
	grip_wrap(g, Vector3(0, 0.0, -0.46), Vector3(0, 0.1, -0.46), 0.028, 0.035)
	return g


## The item spark mark on each face of the drum (half cell).
func _drum_face(s: float) -> VoxelGrid:
	var face := snap(0.06) + cell()
	var centre := Vector3(face * s, 0.03, -0.12)
	var box := AABB(centre - Vector3(0.03, 0.09, 0.09), Vector3(0.06, 0.18, 0.18))
	var g := grid(box, 2.0)
	var c := g.cell
	g.paint(box, func(p: Vector3) -> float:
		var d := p - centre
		var out := d.x * s
		if out > c * 0.5 or out < -c * 2.5:
			return 1.0
		return Vector2(d.y, d.z).length() - 0.075, Mat.TRIM_DARK)
	mark(g, centre, Vector3(0, 0, -s), Vector3.UP, 0.07, item_spark, Mat.GLOW_CORE, false)
	return g
