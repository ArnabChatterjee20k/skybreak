class_name VoxelDesign
extends RefCounted
## Base class for a code-built voxel character (see README.md in this folder).
## A design paints parts into VoxelGrids in the skeleton's rest pose, tags each
## cell with a rig tag, and says how a material is coloured, which surface
## (shader material) it uses and how a tag is skinned. VoxelBody builds the
## mesh from it and swaps it onto the character's skeleton.
##
## Override: build_grids, color, surface_of, weights; optionally soft_materials,
## blur_cells, surface_params. Skeleton space: +Y up, +Z the character's front,
## +X its left; the rest pose is the rig's T-pose.

## The shader surfaces every design can use (VoxelBody makes one material each).
enum Surf { CLOTH, METAL, GLASS, SKIN, GLOW, HAIR }

const FILL := VoxelGrid.Mode.FILL
const ADD := VoxelGrid.Mode.ADD
const CARVE := VoxelGrid.Mode.CARVE
const PAINT := VoxelGrid.Mode.PAINT

var skeleton: Skeleton3D
var bones := {}  # bone name -> index
var rest := {}  # bone name -> rest position (skeleton space)


func _init(skel: Skeleton3D) -> void:
	skeleton = skel
	for i in skel.get_bone_count():
		var bone_name := StringName(skel.get_bone_name(i))
		bones[bone_name] = i
		rest[bone_name] = skel.get_bone_global_rest(i).origin


# ---------------------------------------------------------------- to override

## Every grid of the character (body at the body cell, head/hands at finer cells).
func build_grids() -> Array[VoxelGrid]:
	push_error("VoxelDesign.build_grids not overridden")
	return []


## Final vertex colour (sRGB) of a voxel face corner: mat's base colour, its
## per-voxel variation, darkened by occlusion (0..1, cavity) and lifted by
## exposure (0..1, convex edge). See default_color for the house recipe.
func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	return default_color(Color.MAGENTA, mat, c, occlusion, exposure, false, false)


## Which Surf a material renders with.
func surface_of(_mat: int) -> int:
	return Surf.CLOTH


## Skin weights for a cell with rig tag `tag` at rest position p: add bone
## weights to a dictionary with _add / _piecewise / _chain_w, then return _pack(w).
func weights(_tag: int, _p: Vector3) -> Array:
	var w := {}
	_add(w, &"Hips", 1.0)
	return _pack(w)


## Materials whose single-voxel noise VoxelGrid.smooth cleans up (soft cloth,
## skin, hair); hard plates keep their crisp corners.
func soft_materials() -> Array:
	return []


## Cavity-AO blur radius in cells for a grid (wider on fine grids).
func blur_cells(grid: VoxelGrid) -> int:
	return 2 if grid.cell > 0.015 else 3


## Shader parameters per Surf; override to retune a character's materials.
func surface_params() -> Array:
	return [
		{"roughness_value": 0.86, "specular_value": 0.3, "bevel_tilt": 0.35, "edge_lift": 0.05},  # CLOTH
		{"roughness_value": 0.44, "metallic_value": 0.75, "specular_value": 0.6, "edge_lift": 0.25},  # METAL
		{"roughness_value": 0.08, "metallic_value": 0.1, "specular_value": 0.9, "emission_value": 0.25},  # GLASS
		{"roughness_value": 0.62, "specular_value": 0.35, "edge_lift": 0.06},  # SKIN
		{"roughness_value": 0.5, "emission_value": 0.35, "edge_lift": 0.0},  # GLOW
		{"roughness_value": 0.7, "specular_value": 0.45, "edge_lift": 0.18},  # HAIR
	]


# ---------------------------------------------------------------- shared recipes

## The house colour recipe: +-2% value noise on quiet (big cloth) panels, +-3.5%
## elsewhere with a little hue/saturation drift; cavity darkening, cool-tinted
## on hair; lighter worn edges on `wears` materials.
static func default_color(base: Color, mat: int, c: Vector3i, occlusion: float, exposure: float,
		quiet: bool, wears: bool, cool_cavity := false) -> Color:
	var noise := VoxelSdf.hash3(c, mat) * 2.0 - 1.0
	var drift := VoxelSdf.hash3(c, mat + 31) * 2.0 - 1.0
	var col := base * (1.0 + noise * (0.02 if quiet else 0.035))
	col = Color.from_hsv(fposmod(col.h + drift * (0.005 if quiet else 0.012), 1.0),
		clampf(col.s * (1.0 + drift * (0.02 if quiet else 0.05)), 0.0, 1.0), col.v)
	col = shade(col, occlusion, cool_cavity)
	if wears:
		col = col.lerp(col.lightened(0.35), exposure * 0.7)
	col.a = 1.0
	return col


## Cavity darkening: up to 60% darker and slightly tinted in occluded spots.
static func shade(col: Color, occlusion: float, cool := false) -> Color:
	var tint := Color(0.62, 0.68, 0.86) if cool else Color(0.86, 0.82, 0.9)
	var k := 1.0 - occlusion * 0.6
	return Color(col.r * lerpf(1.0, tint.r, occlusion), col.g * lerpf(1.0, tint.g, occlusion),
		col.b * lerpf(1.0, tint.b, occlusion)) * k


# ---------------------------------------------------------------- weight helpers

## Blends between keyed bones along x (keys ascending: [x, bone name]).
static func _piecewise(x: float, keys: Array, w: Dictionary, smooth: bool) -> void:
	var add := func(bone: String, amount: float) -> void:
		var b := StringName(bone)
		w[b] = w.get(b, 0.0) + amount
	if x <= keys[0][0]:
		add.call(keys[0][1], 1.0)
		return
	for i in keys.size() - 1:
		if x <= keys[i + 1][0]:
			var t: float = (x - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
			if smooth:
				t = smoothstep(0.0, 1.0, t)
			add.call(keys[i][1], 1.0 - t)
			add.call(keys[i + 1][1], t)
			return
	add.call(keys[-1][1], 1.0)


## Points p0..pn with bone i owning segment i; blends half-way at each joint.
static func _chain_w(p: Vector3, w: Dictionary, pts: PackedVector3Array, names: Array) -> void:
	var best := 0
	var best_f := 0.0
	var best_d := INF
	for i in pts.size() - 1:
		var ab := pts[i + 1] - pts[i]
		var f := clampf((p - pts[i]).dot(ab) / ab.dot(ab), 0.0, 1.0)
		var d := p.distance_squared_to(pts[i] + ab * f)
		if d < best_d:
			best_d = d
			best = i
			best_f = f
	best = mini(best, names.size() - 1)
	var next := 0.0
	var prev := 0.0
	if best_f > 0.7 and best + 1 < names.size():
		next = 0.5 * (best_f - 0.7) / 0.3
		w[names[best + 1]] = w.get(names[best + 1], 0.0) + next
	if best_f < 0.3 and best > 0:
		prev = 0.5 * (0.3 - best_f) / 0.3
		w[names[best - 1]] = w.get(names[best - 1], 0.0) + prev
	w[names[best]] = w.get(names[best], 0.0) + 1.0 - next - prev


static func _add(w: Dictionary, bone: StringName, amount: float) -> void:
	if amount > 0.0001:
		w[bone] = w.get(bone, 0.0) + amount


## Top 4 weights, normalised, as [bone indices, weights] for the mesher.
func _pack(w: Dictionary) -> Array:
	var pairs := []
	for b: StringName in w:
		assert(bones.has(b), "unknown bone %s" % b)
		pairs.append([w[b], bones[b]])
	pairs.sort_custom(func(a, b): return a[0] > b[0])
	var ids := PackedInt32Array([0, 0, 0, 0])
	var ws := PackedFloat32Array([0, 0, 0, 0])
	var total := 0.0
	for i in mini(4, pairs.size()):
		total += pairs[i][0]
	for i in mini(4, pairs.size()):
		ids[i] = pairs[i][1]
		ws[i] = pairs[i][0] / total
	return [ids, ws]
