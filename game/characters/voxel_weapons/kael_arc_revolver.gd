extends VoxelWeaponDesign
## Kael's Arc Revolver (docs/lookdev/weapons.md): a heavy sky-knight sidearm.
## Big: a raked grip, a gunmetal frame, a fat brass cylinder, an octagonal
## barrel. Medium: three brass arc coils on the barrel, a trigger guard, the
## hammer spur, a teal enamel side plate. Tiny: cylinder flutes and glowing
## chamber mouths, grip rivets and lattice, a winged-sky medallion (fine cell)
## on each grip side, a front sight, a lanyard ring.

const GRIP_TILT := deg_to_rad(15.0)
const BARREL_Y := 0.19
const CYL_Y := 0.16
const CYL_Z := -0.06


func kind() -> Weapon.Kind:
	return Weapon.Kind.ARC_REVOLVER


func palette() -> Dictionary:
	return {
		Mat.BODY: Color(0.24, 0.25, 0.29), Mat.BODY_DARK: Color(0.14, 0.15, 0.18),
		Mat.EDGE: Color(0.50, 0.52, 0.57),
		Mat.TRIM: Color(0.72, 0.56, 0.31), Mat.TRIM_DARK: Color(0.45, 0.31, 0.13),
		Mat.RIVET: Color(0.90, 0.78, 0.52), Mat.ENGRAVE: Color(0.30, 0.22, 0.12),
		Mat.EMBLEM: Color(0.84, 0.68, 0.38),
		Mat.GRIP: Color(0.52, 0.30, 0.16), Mat.GRIP_DARK: Color(0.27, 0.17, 0.10),
		Mat.ACCENT: Color(0.11, 0.36, 0.39),
		Mat.GLOW: Color(1.0, 0.70, 0.36), Mat.GLOW_CORE: Color(1.0, 0.95, 0.86),
	}


func build_grids() -> Array[VoxelGrid]:
	return [_gun(), _medallion(1.0), _medallion(-1.0)]


## Point p in the raked grip's own frame (grip centre at the origin, +Y up the grip).
static func grip_local(p: Vector3) -> Vector3:
	return Basis(Vector3.RIGHT, GRIP_TILT) * (p - Vector3(0, 0, 0.02))


func _gun() -> VoxelGrid:
	var g := grid(AABB(Vector3(-0.09, -0.16, -0.56), Vector3(0.18, 0.43, 0.68)))
	var c := g.cell
	var all := AABB(Vector3(-0.09, -0.16, -0.56), Vector3(0.18, 0.43, 0.68))
	# Grip: leather panels in a lattice over a gunmetal core, a brass butt cap.
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		return VoxelSdf.box(q, Vector3(0, -0.005, 0), Vector3(0.036, 0.105, 0.055), 0.012), Mat.BODY_DARK)
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		if q.y < -0.085 or q.y > 0.08 or absf(q.z) > 0.042:
			return 1.0
		return absf(q.x) - 0.046, Mat.GRIP_DARK, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		# Slanted wrap bands, two cells each, a cell of shadow between.
		var band := fposmod((q.y + q.z * 0.45) / 0.03, 1.0)
		return -1.0 if absf(q.x) > 0.04 and band < 0.62 else 1.0, Mat.GRIP, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		return VoxelSdf.box(q, Vector3(0, -0.115, 0.002), Vector3(0.042, 0.016, 0.062), 0.008), Mat.TRIM)
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		return VoxelSdf.torus(q, Vector3(0, -0.145, 0.03), Vector3(1, 0, 0), 0.016, 0.0065), Mat.TRIM_DARK, -1, ADD)
	for s: float in [-1.0, 1.0]:
		for y: float in [-0.065, 0.06]:
			var at := Basis(Vector3.RIGHT, -GRIP_TILT) * Vector3(0.047 * s, y, 0.0) + Vector3(0, 0, 0.02)
			rivet(g, at, Vector3(s, 0, 0), c * 0.9)
	# Frame: a gunmetal block with a top strap, chamfered, and a brass trim line.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.15, -0.06), Vector3(0.05, 0.062, 0.13), 0.01), Mat.BODY)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if absf(p.y - 0.098) < c * 0.6 and p.z > -0.19 and p.z < 0.07 else 1.0, Mat.TRIM, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if p.y > 0.2 else 1.0, Mat.BODY_DARK, -1, PAINT)
	# Teal enamel side plates with a glowing arc conduit along them.
	for s: float in [-1.0, 1.0]:
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.05 * s, 0.135, 0.03), Vector3(c * 0.6, 0.03, 0.035), 0.0), Mat.ACCENT, -1, PAINT)
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.053 * s, 0.175, -0.07), Vector3(c * 0.8, c * 0.6, 0.11), 0.0), Mat.GLOW, -1, ADD)
		for z: float in [0.0, 0.06]:
			rivet(g, Vector3(0.052 * s, 0.11, z), Vector3(s, 0, 0), c * 0.8)
	# Hammer: a spur at the back of the top strap.
	g.paint(all, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.215, 0.075)
		return maxf(VoxelSdf.box(q, Vector3(0, 0, 0), Vector3(0.016, 0.028, 0.022), 0.006), q.y - 0.02 - q.z * 0.6), Mat.BODY_DARK, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.245, 0.095), Vector3(0.022, 0.008, 0.014), 0.004), Mat.EDGE, -1, ADD)
	# Trigger guard (a brass loop) and the trigger.
	g.paint(all, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.075, -0.06)
		var ring := Vector2(Vector2(q.z / 1.25, q.y).length() - 0.04, q.x).length() - 0.01
		return ring if q.y < 0.005 else 1.0, Mat.TRIM, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.capsule(p, Vector3(0, 0.085, -0.055), Vector3(0, 0.05, -0.045), 0.009, 0.007), Mat.BODY_DARK, -1, ADD)
	_cylinder(g)
	_barrel(g)
	return g


## The brass cylinder: six flutes, six glowing chamber mouths at the front, a centre pin.
func _cylinder(g: VoxelGrid) -> void:
	var c := g.cell
	var a := Vector3(0, CYL_Y, CYL_Z + 0.068)
	var b := Vector3(0, CYL_Y, CYL_Z - 0.068)
	var box := _segment_box(a, b, 0.1)
	g.paint(box, func(p: Vector3) -> float: return VoxelSdf.cylinder(p, a, b, 0.078, 0.078), Mat.TRIM)
	g.paint(box, func(p: Vector3) -> float:
		var d := Vector2(p.x, p.y - CYL_Y)
		var ang := fposmod(atan2(d.y, d.x) / TAU * 6.0 + 0.5, 1.0)
		var on := absf(ang - 0.5) < 0.07 and d.length() > 0.068 and absf(p.z - CYL_Z) < 0.048
		return -1.0 if on else 1.0, Mat.EMPTY, -1, CARVE)
	g.paint(box, func(p: Vector3) -> float:
		var d := Vector2(p.x, p.y - CYL_Y)
		return -1.0 if d.length() > 0.07 and absf(absf(p.z - CYL_Z) - 0.062) < c * 0.6 else 1.0, Mat.TRIM_DARK, -1, PAINT)
	for k in 6:
		var ang := TAU * k / 6.0
		var at := Vector3(cos(ang) * 0.046, CYL_Y + sin(ang) * 0.046, CYL_Z - 0.068)
		g.paint(box, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, at + Vector3(0, 0, 0.03), at - Vector3(0, 0, 0.004), 0.014, 0.014), Mat.GLOW)
	g.paint(box, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, CYL_Y, CYL_Z), Vector3(0, CYL_Y, CYL_Z - 0.078), 0.012, 0.012), Mat.EDGE)


## The octagonal barrel with three brass arc coils (energy between the turns), a sight, the muzzle.
func _barrel(g: VoxelGrid) -> void:
	var c := g.cell
	var box := AABB(Vector3(-0.07, BARREL_Y - 0.07, -0.56), Vector3(0.14, 0.14, 0.44))
	var oct := func(p: Vector3, r: float) -> float:
		var x := absf(p.x)
		var y := absf(p.y - BARREL_Y)
		return maxf(maxf(x, y), (x + y) * 0.74) - r
	g.paint(box, func(p: Vector3) -> float:
		return maxf(oct.call(p, 0.034), maxf(-0.505 - p.z, p.z + 0.13)), Mat.BODY)
	# Top rib, a shade lighter, and the front sight blade.
	g.paint(box, func(p: Vector3) -> float:
		return maxf(VoxelSdf.box(p, Vector3(0, BARREL_Y + 0.038, -0.33), Vector3(0.012, 0.007, 0.17)), 0.0), Mat.EDGE, -1, ADD)
	g.paint(box, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, BARREL_Y + 0.052, -0.485), Vector3(0.005, 0.012, 0.012)), Mat.TRIM, -1, ADD)
	for k in 3:
		var z0 := -0.22 - k * 0.075
		g.paint(box, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.y - BARREL_Y).length()
			return maxf(absf(r - 0.044) - 0.008, absf(p.z - z0) - 0.017), Mat.TRIM, -1, ADD)
		g.paint(box, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.y - BARREL_Y).length()
			return -1.0 if absf(p.z - z0) < c * 0.6 and r > 0.044 else 1.0, Mat.GLOW, -1, PAINT)
	# The muzzle: a brass crown ring around a glowing bore.
	g.paint(box, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, BARREL_Y, -0.49), Vector3(0, BARREL_Y, -0.53), 0.046, 0.05), Mat.TRIM)
	g.paint(box, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, BARREL_Y, -0.5), Vector3(0, BARREL_Y, -0.54), 0.02, 0.02), Mat.EMPTY, -1, CARVE)
	g.paint(box, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, BARREL_Y, -0.49), Vector3(0, BARREL_Y, -0.52), 0.022, 0.022), Mat.GLOW, -1, PAINT)


## A brass medallion with the winged-sky sigil, proud of the grip side (half cell).
func _medallion(s: float) -> VoxelGrid:
	var centre := Basis(Vector3.RIGHT, -GRIP_TILT) * Vector3(0.05 * s, 0.0, 0.0) + Vector3(0, 0, 0.02)
	var g := grid(AABB(centre - Vector3(0.02, 0.04, 0.04), Vector3(0.04, 0.08, 0.08)), 2.0)
	var c := g.cell
	var n := Vector3(s, 0, 0)
	g.paint(AABB(centre - Vector3.ONE * 0.04, Vector3.ONE * 0.08), func(p: Vector3) -> float:
		var d := p - centre
		var outward := d.dot(n)
		if outward < c * 0.5 or outward > c * 3.5:
			return 1.0
		return Vector2(d.y, d.z).length() - (0.03 - maxf(outward - c * 2.5, 0.0)), Mat.TRIM)
	var v := Basis(Vector3.RIGHT, -GRIP_TILT) * Vector3.UP
	mark(g, centre + n * c * 3.0, Vector3(0, 0, -s), v, 0.026, winged_sky, Mat.ENGRAVE, true)
	return g
