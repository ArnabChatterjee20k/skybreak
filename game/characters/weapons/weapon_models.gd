class_name WeaponModels
extends RefCounted
## Chunky, readable weapon models built in code from primitive meshes, with
## the toon shader and an outline (the same look as the chunky characters).
## Every model has its grip at the origin and its long axis along +Y, so a
## hand attachment only needs one rotation. Items use the gold colour family.

const TOON := preload("res://game/view/shaders/toon.gdshader")
const OUTLINE := preload("res://game/view/shaders/outline.gdshader")

const GOLD := Color(0.95, 0.68, 0.16)
const DARK_GOLD := Color(0.62, 0.4, 0.1)
const STEEL := Color(0.78, 0.84, 0.92)
const LEATHER := Color(0.32, 0.18, 0.1)
const CHARCOAL := Color(0.16, 0.15, 0.2)
const KI_CYAN := Color(0.35, 0.95, 1.0)
const STONE := Color(0.48, 0.47, 0.52)
const EMBER := Color(1.0, 0.36, 0.1)
const WOOD := Color(0.55, 0.33, 0.15)
const TEAL := Color(0.1, 0.62, 0.6)
const PINK := Color(1.0, 0.45, 0.68)
const ROSE := Color(0.86, 0.16, 0.4)

static var _materials: Dictionary = {}
static var _outline: ShaderMaterial


## A new model of kind. Gauntlets build one fist; the view puts one in each hand.
static func build(kind: Weapon.Kind) -> Node3D:
	var root := Node3D.new()
	root.name = String(Weapon.weapon_name(kind)).capitalize().replace(" ", "")
	match kind:
		Weapon.Kind.KI_GAUNTLETS:
			_gauntlet(root)
		Weapon.Kind.STORM_BLADE:
			_blade(root)
		Weapon.Kind.SKY_LANCE:
			_lance(root)
		Weapon.Kind.TITAN_HAMMER:
			_hammer(root)
		Weapon.Kind.ORBIT_CHAKRAM:
			_chakram(root)
		Weapon.Kind.EMBER_SCYTHE:
			_scythe(root)
		Weapon.Kind.KI_BOW:
			_bow(root, WOOD, GOLD, KI_CYAN, false)
		Weapon.Kind.ARC_REVOLVER:
			_revolver(root)
		Weapon.Kind.STORM_REPEATER:
			_repeater(root)
		Weapon.Kind.SCATTER_CANNON:
			_scatter(root)
		Weapon.Kind.HEARTSTRING_BOW:
			_bow(root, PINK, GOLD, Color(1.0, 0.85, 0.95), true)
	if Weapon.is_ranged(kind) and kind != Weapon.Kind.KI_BOW and kind != Weapon.Kind.HEARTSTRING_BOW:
		root.scale = Vector3.ONE * 1.3
	return root


## Centre of the model's meshes, for framing and pickups.
static func centre_of(model: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var local := part.transform * part.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return model.transform.basis * box.get_center()


## Length of the model along +Y, metres, for framing and pickup glow.
static func length_of(kind: Weapon.Kind) -> float:
	match kind:
		Weapon.Kind.SKY_LANCE:
			return 2.6
		Weapon.Kind.EMBER_SCYTHE:
			return 1.9
		Weapon.Kind.TITAN_HAMMER, Weapon.Kind.STORM_BLADE:
			return 1.5
		Weapon.Kind.KI_BOW, Weapon.Kind.HEARTSTRING_BOW:
			return 1.4
	return 0.8


## Toon material of a colour, with the outline pass; shared per colour.
static func material(color: Color, glow := false) -> ShaderMaterial:
	var key := [color, glow]
	if _materials.has(key):
		return _materials[key]
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE
		_outline.set_shader_parameter("outline_width", 2.4)
	var made := ShaderMaterial.new()
	made.shader = TOON
	made.set_shader_parameter("albedo_color", color)
	made.set_shader_parameter("specular_enabled", true)
	if glow:
		made.set_shader_parameter("shadow_tint", Color(1, 1, 1))
		made.set_shader_parameter("rim_strength", 1.5)
		made.set_shader_parameter("rim_color", color.lightened(0.5))
	made.next_pass = _outline
	_materials[key] = made
	return made


static func _part(root: Node3D, mesh: Mesh, color: Color, at: Vector3, rotation_deg := Vector3.ZERO,
		glow := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material(color, glow)
	part.position = at
	part.rotation_degrees = rotation_deg
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(part)
	return part


static func _box(root: Node3D, size: Vector3, color: Color, at: Vector3, rotation_deg := Vector3.ZERO,
		glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(root, mesh, color, at, rotation_deg, glow)


static func _cylinder(root: Node3D, radius: float, height: float, color: Color, at: Vector3,
		rotation_deg := Vector3.ZERO, top_radius := -1.0, glow := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return _part(root, mesh, color, at, rotation_deg, glow)


static func _sphere(root: Node3D, radius: float, color: Color, at: Vector3, glow := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _part(root, mesh, color, at, Vector3.ZERO, glow)


static func _torus(root: Node3D, inner: float, outer: float, color: Color, at: Vector3,
		rotation_deg := Vector3.ZERO, glow := false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 20
	mesh.ring_segments = 8
	return _part(root, mesh, color, at, rotation_deg, glow)


static func _prism(root: Node3D, size: Vector3, color: Color, at: Vector3, rotation_deg := Vector3.ZERO,
		glow := false) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _part(root, mesh, color, at, rotation_deg, glow)


## A chunky heart in the XY plane: two lobes and a point.
static func _heart(root: Node3D, size: float, color: Color, at: Vector3, glow := true) -> void:
	_sphere(root, size * 0.32, color, at + Vector3(-size * 0.22, size * 0.12, 0), glow)
	_sphere(root, size * 0.32, color, at + Vector3(size * 0.22, size * 0.12, 0), glow)
	_prism(root, Vector3(size * 0.95, size * 0.62, size * 0.4), color, at + Vector3(0, -size * 0.2, 0),
		Vector3(0, 0, 180), glow)


static func _gauntlet(root: Node3D) -> void:
	_cylinder(root, 0.16, 0.24, DARK_GOLD, Vector3(0, -0.12, 0), Vector3.ZERO, 0.19)
	_box(root, Vector3(0.34, 0.24, 0.3), GOLD, Vector3(0, 0.1, 0))
	for i in 4:
		_box(root, Vector3(0.075, 0.12, 0.16), GOLD.lightened(0.15), Vector3(-0.12 + i * 0.08, 0.26, -0.04))
		_sphere(root, 0.04, KI_CYAN, Vector3(-0.12 + i * 0.08, 0.27, -0.13), true)
	_box(root, Vector3(0.36, 0.05, 0.05), KI_CYAN, Vector3(0, -0.02, -0.16), Vector3.ZERO, true)
	_box(root, Vector3(0.1, 0.16, 0.1), GOLD, Vector3(0.2, 0.08, -0.04), Vector3(0, 0, -25))


static func _blade(root: Node3D) -> void:
	_cylinder(root, 0.05, 0.32, LEATHER, Vector3(0, 0.0, 0))
	_sphere(root, 0.08, GOLD, Vector3(0, -0.2, 0))
	_box(root, Vector3(0.46, 0.09, 0.12), GOLD, Vector3(0, 0.2, 0))
	_sphere(root, 0.06, KI_CYAN, Vector3(0, 0.2, -0.05), true)
	_box(root, Vector3(0.17, 1.0, 0.05), STEEL, Vector3(0, 0.75, 0))
	_box(root, Vector3(0.05, 0.9, 0.06), KI_CYAN, Vector3(0, 0.72, 0), Vector3.ZERO, true)
	_prism(root, Vector3(0.17, 0.24, 0.05), STEEL, Vector3(0, 1.37, 0))


static func _lance(root: Node3D) -> void:
	_cylinder(root, 0.045, 2.2, WOOD, Vector3(0, 0.3, 0))
	_cylinder(root, 0.07, 0.18, GOLD, Vector3(0, 0.0, 0))
	_cylinder(root, 0.08, 0.12, GOLD, Vector3(0, 1.35, 0))
	_cylinder(root, 0.13, 0.55, STEEL, Vector3(0, 1.68, 0), Vector3.ZERO, 0.0)
	_box(root, Vector3(0.04, 0.3, 0.32), TEAL, Vector3(0, 1.18, 0.18))
	_sphere(root, 0.07, GOLD, Vector3(0, -0.82, 0))


static func _hammer(root: Node3D) -> void:
	_cylinder(root, 0.055, 1.1, LEATHER, Vector3(0, 0.3, 0))
	_sphere(root, 0.08, GOLD, Vector3(0, -0.27, 0))
	_box(root, Vector3(0.42, 0.4, 0.72), STONE, Vector3(0, 1.0, 0))
	_box(root, Vector3(0.46, 0.44, 0.1), GOLD, Vector3(0, 1.0, 0.24))
	_box(root, Vector3(0.46, 0.44, 0.1), GOLD, Vector3(0, 1.0, -0.24))
	_box(root, Vector3(0.3, 0.3, 0.06), EMBER, Vector3(0, 1.0, -0.37), Vector3.ZERO, true)


static func _chakram(root: Node3D) -> void:
	_box(root, Vector3(0.06, 0.26, 0.06), LEATHER, Vector3(0, 0.0, 0))
	_torus(root, 0.3, 0.42, GOLD, Vector3(0, 0.36, 0), Vector3(90, 0, 0))
	_torus(root, 0.24, 0.29, KI_CYAN, Vector3(0, 0.36, 0), Vector3(90, 0, 0), true)
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		var out := Vector3(sin(angle), cos(angle), 0)
		_prism(root, Vector3(0.12, 0.18, 0.05), STEEL, Vector3(0, 0.36, 0) + out * 0.48,
			Vector3(0, 0, -rad_to_deg(angle)))


static func _scythe(root: Node3D) -> void:
	_cylinder(root, 0.05, 1.8, CHARCOAL, Vector3(0, 0.5, 0))
	_cylinder(root, 0.08, 0.16, GOLD, Vector3(0, 1.4, 0))
	_cylinder(root, 0.07, 0.12, GOLD, Vector3(0, 0.0, 0))
	# The blade sweeps forward and down from the top in a crescent of plates.
	var pieces := 9
	var previous := Vector3(0, 1.42, 0)
	for i in pieces:
		var t := float(i + 1) / pieces
		var angle := lerpf(0.15, 2.2, t)
		var point := Vector3(0, 1.42 + sin(angle) * 0.32, -(1.0 - cos(angle)) * 0.55 - t * 0.35)
		var middle := (previous + point) * 0.5
		var along := point - previous
		var tilt := rad_to_deg(atan2(along.y, -along.z))
		_box(root, Vector3(0.05, lerpf(0.26, 0.06, t), along.length() + 0.03), STEEL, middle,
			Vector3(tilt, 0, 0))
		_box(root, Vector3(0.06, lerpf(0.08, 0.02, t), along.length() + 0.03), EMBER,
			middle + Vector3(0, -lerpf(0.13, 0.03, t), 0), Vector3(tilt, 0, 0), true)
		previous = point
	_sphere(root, 0.08, EMBER, Vector3(0, -0.42, 0), true)


static func _bow(root: Node3D, limb: Color, trim: Color, string_color: Color, hearts: bool) -> void:
	_box(root, Vector3(0.09, 0.26, 0.1), LEATHER if not hearts else ROSE, Vector3.ZERO)
	var segments := 5
	for side: float in [-1.0, 1.0]:
		for i in segments:
			var t := float(i + 0.5) / segments
			var y := side * (0.12 + t * 0.56)
			var z := 0.24 * t * t
			_box(root, Vector3(0.08, 0.14, 0.07), limb, Vector3(0, y, z), Vector3(-side * t * 40.0, 0, 0))
		_sphere(root, 0.055, trim, Vector3(0, side * 0.7, 0.25))
	var string := _cylinder(root, 0.012, 1.38, string_color, Vector3(0, 0, 0.26), Vector3.ZERO, -1.0, true)
	string.name = "String"
	if hearts:
		_heart(root, 0.26, GOLD, Vector3(0.06, 0, -0.04))
		_heart(root, 0.26, GOLD, Vector3(-0.06, 0, -0.04))
		_heart(root, 0.16, ROSE, Vector3(0.05, 0.62, 0.22))
		_heart(root, 0.16, ROSE, Vector3(0.05, -0.62, 0.22))
		var sparkles := CPUParticles3D.new()
		sparkles.name = "Sparkles"
		sparkles.amount = 24
		sparkles.lifetime = 0.8
		sparkles.local_coords = false
		sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sparkles.emission_box_extents = Vector3(0.05, 0.6, 0.15)
		sparkles.gravity = Vector3(0, 0.6, 0)
		sparkles.initial_velocity_min = 0.1
		sparkles.initial_velocity_max = 0.4
		sparkles.scale_amount_min = 0.5
		sparkles.scale_amount_max = 1.0
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		var sparkle_material := StandardMaterial3D.new()
		sparkle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sparkle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sparkle_material.albedo_color = Color(1.0, 0.85, 0.5)
		sparkle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad.material = sparkle_material
		sparkles.mesh = quad
		root.add_child(sparkles)


static func _revolver(root: Node3D) -> void:
	_box(root, Vector3(0.09, 0.22, 0.12), LEATHER, Vector3(0, 0, 0.02), Vector3(-15, 0, 0))
	_box(root, Vector3(0.11, 0.13, 0.26), CHARCOAL, Vector3(0, 0.15, -0.06))
	_cylinder(root, 0.075, 0.13, GOLD, Vector3(0, 0.16, -0.06), Vector3(90, 0, 0))
	_cylinder(root, 0.035, 0.34, CHARCOAL, Vector3(0, 0.19, -0.34), Vector3(90, 0, 0))
	_cylinder(root, 0.045, 0.05, GOLD, Vector3(0, 0.19, -0.5), Vector3(90, 0, 0))
	_box(root, Vector3(0.03, 0.03, 0.2), KI_CYAN, Vector3(0.06, 0.15, -0.06), Vector3.ZERO, true)


static func _repeater(root: Node3D) -> void:
	_box(root, Vector3(0.09, 0.2, 0.12), LEATHER, Vector3(0, 0, 0.02), Vector3(-12, 0, 0))
	_box(root, Vector3(0.16, 0.18, 0.5), CHARCOAL, Vector3(0, 0.16, -0.12))
	_box(root, Vector3(0.1, 0.12, 0.3), WOOD, Vector3(0, 0.1, 0.3))
	_cylinder(root, 0.12, 0.12, GOLD, Vector3(0, 0.03, -0.12), Vector3(0, 0, 90))
	for i in 3:
		var angle := TAU * i / 3.0
		_cylinder(root, 0.028, 0.46, STEEL, Vector3(cos(angle) * 0.045, 0.2 + sin(angle) * 0.045, -0.56),
			Vector3(90, 0, 0))
	_cylinder(root, 0.08, 0.06, GOLD, Vector3(0, 0.2, -0.78), Vector3(90, 0, 0))
	_box(root, Vector3(0.04, 0.04, 0.4), KI_CYAN, Vector3(0.085, 0.18, -0.12), Vector3.ZERO, true)


static func _scatter(root: Node3D) -> void:
	_box(root, Vector3(0.1, 0.22, 0.13), LEATHER, Vector3(0, 0, 0.04), Vector3(-15, 0, 0))
	_box(root, Vector3(0.2, 0.22, 0.36), DARK_GOLD, Vector3(0, 0.17, -0.06))
	# An iron barrel with a short flared muzzle and bands: a cannon, not a solid gold cone (#98).
	_cylinder(root, 0.1, 0.44, CHARCOAL, Vector3(0, 0.2, -0.42), Vector3(-90, 0, 0), 0.12)
	_cylinder(root, 0.12, 0.1, CHARCOAL, Vector3(0, 0.2, -0.67), Vector3(-90, 0, 0), 0.17)
	_torus(root, 0.13, 0.19, GOLD, Vector3(0, 0.2, -0.72), Vector3(90, 0, 0))
	_torus(root, 0.1, 0.15, GOLD, Vector3(0, 0.2, -0.32), Vector3(90, 0, 0))
	_box(root, Vector3(0.05, 0.03, 0.3), EMBER, Vector3(0, 0.33, -0.45), Vector3.ZERO, true)
	_sphere(root, 0.07, EMBER, Vector3(0, 0.32, -0.02), true)
