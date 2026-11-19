class_name WeaponLayer
extends Node3D
## Draws everything weapon-related from sim state: pickups (sky-drop pillar
## and streak, then bobbing and glowing on the ground), projectiles (arrows,
## bullets with tracers, pellets, spinning thrown weapons) and the weapon in
## each fighter's hand on its hand bone. Reads the sim only; interpolates
## between the last two ticks like FighterView.

## Hand bones of the humanoid profile.
const RIGHT_HAND := &"RightHand"
const LEFT_HAND := &"LeftHand"
## Item glow colour (GAME_DESIGN §5.11 gold family) and the Heartbloom pink.
const ITEM_GLOW := Color(1.0, 0.78, 0.25)
const HEART_GLOW := Color(1.0, 0.5, 0.75)
const BOB_HEIGHT := 0.18
const BOB_SPEED := 2.6
const SPIN_SPEED := 1.4
const TRACER_LENGTH := 2.2

var sim: CombatSim
var fighter_views: Array[FighterView] = []

var _pickup_nodes: Dictionary = {}
var _projectile_nodes: Dictionary = {}
var _previous: Dictionary = {}
var _held: Array[Dictionary] = []
var _time := 0.0


func setup(combat_sim: CombatSim, views: Array[FighterView]) -> void:
	sim = combat_sim
	fighter_views = views
	_held.clear()
	for _view in views:
		_held.append({"kind": -1, "nodes": []})


## Call once per sim tick, before the sim advances.
func remember_previous_tick() -> void:
	_previous.clear()
	for pickup in sim.pickups:
		_previous["p%d" % pickup.id] = pickup.position
	for projectile in sim.projectiles:
		_previous["s%d" % projectile.id] = projectile.position


## Call every rendered frame. blend: 0 = previous tick, 1 = latest tick.
func present(blend: float, delta: float) -> void:
	_time += delta
	_present_pickups(blend)
	_present_projectiles(blend)
	for i in fighter_views.size():
		_present_held(i)
		_draw_bow(i)


func _present_pickups(blend: float) -> void:
	var alive := {}
	for pickup in sim.pickups:
		alive[pickup.id] = true
		var node: Node3D = _pickup_nodes.get(pickup.id)
		if node == null:
			node = _make_pickup(pickup.kind)
			_pickup_nodes[pickup.id] = node
			add_child(node)
		var at: Vector3 = (_previous.get("p%d" % pickup.id, pickup.position) as Vector3).lerp(pickup.position, blend)
		node.position = at
		var model: Node3D = node.get_node("Model")
		var pillar: Node3D = node.get_node("Pillar")
		var streak: Node3D = node.get_node("Streak")
		var glow: Node3D = node.get_node("Glow")
		pillar.visible = pickup.phase == WeaponPickup.Phase.TELEGRAPH
		streak.visible = pickup.phase == WeaponPickup.Phase.FALLING
		glow.visible = pickup.phase == WeaponPickup.Phase.GROUNDED
		model.visible = pickup.phase != WeaponPickup.Phase.TELEGRAPH or int(_time * 8.0) % 2 == 0
		var bob := sin(_time * BOB_SPEED + pickup.id) * BOB_HEIGHT if glow.visible else 0.0
		model.position = Vector3(0, 0.25 + bob, 0)
		model.rotation = Vector3(0, _time * SPIN_SPEED + pickup.id, deg_to_rad(-60))
		if pillar.visible:
			# The pillar reaches from the drop point down to the floor.
			var height := at.y - sim.floor_height()
			pillar.scale = Vector3(1, height, 1)
			pillar.position = Vector3(0, -height * 0.5, 0)
		glow.scale = Vector3.ONE * (1.0 + 0.12 * sin(_time * 5.0))
	for id: int in _pickup_nodes.keys():
		if not alive.has(id):
			(_pickup_nodes[id] as Node3D).queue_free()
			_pickup_nodes.erase(id)


func _make_pickup(kind: Weapon.Kind) -> Node3D:
	var node := Node3D.new()
	var glow_color := HEART_GLOW if kind == Weapon.Kind.HEARTSTRING_BOW else ITEM_GLOW
	var model := Node3D.new()
	model.name = "Model"
	var weapon := WeaponModels.build(kind)
	weapon.position = -WeaponModels.centre_of(weapon)
	model.add_child(weapon)
	node.add_child(model)
	var pillar := MeshInstance3D.new()
	pillar.name = "Pillar"
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.6
	pillar_mesh.bottom_radius = 0.6
	pillar_mesh.height = 1.0
	pillar.mesh = pillar_mesh
	pillar.material_override = _glow_material(Color(glow_color, 0.35))
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(pillar)
	var streak := MeshInstance3D.new()
	streak.name = "Streak"
	var streak_mesh := CylinderMesh.new()
	streak_mesh.top_radius = 0.05
	streak_mesh.bottom_radius = 0.3
	streak_mesh.height = 6.0
	streak.mesh = streak_mesh
	streak.position = Vector3(0, 3.4, 0)
	streak.material_override = _glow_material(Color(glow_color, 0.55))
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(streak)
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.75
	ring.outer_radius = 0.95
	glow.mesh = ring
	glow.position = Vector3(0, -sim.pickup_tuning.rest_height + 0.03, 0)
	glow.material_override = _glow_material(Color(glow_color, 0.8))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position = Vector3(0, 0.4, 0)
	light.shadow_enabled = false
	glow.add_child(light)
	return node


func _present_projectiles(blend: float) -> void:
	var alive := {}
	for projectile in sim.projectiles:
		alive[projectile.id] = true
		var node: Node3D = _projectile_nodes.get(projectile.id)
		if node == null:
			node = _make_projectile(projectile)
			_projectile_nodes[projectile.id] = node
			add_child(node)
		var at: Vector3 = (_previous.get("s%d" % projectile.id, projectile.position) as Vector3).lerp(
			projectile.position, blend)
		node.position = at
		var direction := projectile.velocity.normalized()
		if projectile.thrown:
			node.rotation = Vector3(_time * 18.0, atan2(-direction.x, -direction.z), 0)
		elif direction.length_squared() > 0.0:
			var up := Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
			node.basis = Basis.looking_at(direction, up)
	for id: int in _projectile_nodes.keys():
		if not alive.has(id):
			(_projectile_nodes[id] as Node3D).queue_free()
			_projectile_nodes.erase(id)


## Looks down -Z (the flight direction) after looking_at.
func _make_projectile(projectile: Projectile) -> Node3D:
	var node := Node3D.new()
	if projectile.thrown:
		var model := WeaponModels.build(projectile.weapon)
		model.position = -WeaponModels.centre_of(model)
		var spinner := Node3D.new()
		spinner.add_child(model)
		node.add_child(spinner)
		return node
	match projectile.weapon:
		Weapon.Kind.KI_BOW, Weapon.Kind.HEARTSTRING_BOW:
			var heart := projectile.weapon == Weapon.Kind.HEARTSTRING_BOW
			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.03
			shaft_mesh.bottom_radius = 0.03
			shaft_mesh.height = 1.1
			shaft.mesh = shaft_mesh
			shaft.rotation_degrees = Vector3(90, 0, 0)
			shaft.material_override = WeaponModels.material(WeaponModels.PINK if heart else WeaponModels.WOOD)
			node.add_child(shaft)
			var tip := MeshInstance3D.new()
			var tip_mesh := CylinderMesh.new()
			tip_mesh.top_radius = 0.0
			tip_mesh.bottom_radius = 0.09
			tip_mesh.height = 0.22
			tip.mesh = tip_mesh
			tip.rotation_degrees = Vector3(-90, 0, 0)
			tip.position = Vector3(0, 0, -0.6)
			tip.material_override = WeaponModels.material(WeaponModels.GOLD, true)
			node.add_child(tip)
			node.add_child(_tracer(HEART_GLOW if heart else ITEM_GLOW, 1.4, 0.05))
			if heart:
				var heart_node := Node3D.new()
				heart_node.position = Vector3(0, 0, -0.62)
				WeaponModels._heart(heart_node, 0.22, WeaponModels.ROSE, Vector3.ZERO)
				node.add_child(heart_node)
		Weapon.Kind.SCATTER_CANNON:
			node.add_child(_glow_ball(0.12, ITEM_GLOW))
			node.add_child(_tracer(Color(1.0, 0.6, 0.2), 0.9, 0.06))
		_:
			node.add_child(_glow_ball(0.09, Color(1.0, 0.92, 0.6)))
			node.add_child(_tracer(ITEM_GLOW, TRACER_LENGTH if projectile.weapon == Weapon.Kind.ARC_REVOLVER else 1.4, 0.04))
	return node


## A glowing streak trailing behind (+Z) the projectile.
func _tracer(color: Color, length: float, radius: float) -> MeshInstance3D:
	var tracer := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = 0.0
	mesh.height = length
	tracer.mesh = mesh
	tracer.rotation_degrees = Vector3(-90, 0, 0)
	tracer.position = Vector3(0, 0, length * 0.5)
	tracer.material_override = _glow_material(Color(color, 0.8))
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tracer


func _glow_ball(radius: float, color: Color) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	ball.mesh = mesh
	ball.material_override = _glow_material(color)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ball


static var _glow_materials: Dictionary = {}


static func _glow_material(color: Color) -> StandardMaterial3D:
	if _glow_materials.has(color):
		return _glow_materials[color]
	var made := StandardMaterial3D.new()
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.albedo_color = color
	if color.a < 1.0:
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_materials[color] = made
	return made


## Keeps the model on the fighter's hand bone(s) in sync with the weapon in hand.
func _present_held(index: int) -> void:
	var fighter := sim.fighters[index]
	var kind := fighter.held_weapon()
	var held := _held[index]
	if held.kind == kind:
		return
	for node: Node in held.nodes:
		node.queue_free()
	held.nodes = []
	held.kind = kind
	if kind == Weapon.Kind.NONE:
		return
	var skeleton := _skeleton_of(fighter_views[index])
	if skeleton != null:
		held.nodes = attach(skeleton, kind)


## Puts kind's model on the skeleton's hand bone(s) at its grip (WeaponGrip): bows in the left
## hand with a drawable string, gauntlets on both, the rest in the right. Returns the attachments.
static func attach(skeleton: Skeleton3D, kind: Weapon.Kind) -> Array[Node]:
	var nodes: Array[Node] = []
	for hand in WeaponGrip.hands_of(kind):
		var attachment := BoneAttachment3D.new()
		attachment.name = "Held%s" % hand
		attachment.bone_name = hand
		skeleton.add_child(attachment)
		var model := WeaponModels.build(kind)
		model.transform = WeaponGrip.grip_transform(skeleton, kind, hand)
		attachment.add_child(model)
		if WeaponGrip.hold_of(kind) == WeaponGrip.Hold.BOW:
			var heart := kind == Weapon.Kind.HEARTSTRING_BOW
			BowString.new().setup(model, skeleton, RIGHT_HAND,
				Color(1.0, 0.85, 0.95) if heart else WeaponModels.KI_CYAN,
				WeaponModels.PINK if heart else WeaponModels.WOOD)
		nodes.append(attachment)
	return nodes


## Draws a held bow's string to the hand while its holder shoots.
func _draw_bow(index: int) -> void:
	for node: Node in _held[index].nodes:
		var string := node.find_child("BowString", true, false) as BowString
		if string != null:
			string.drawn = sim.fighters[index].state == FighterState.State.ATTACKING


## The bow string of fighter index's held bow, or null.
func bow_string_of(index: int) -> BowString:
	for node: Node in _held[index].nodes:
		var string := node.find_child("BowString", true, false) as BowString
		if string != null:
			return string
	return null


## The held weapon models of fighter index (one per hand).
func held_models(index: int) -> Array[Node3D]:
	var models: Array[Node3D] = []
	for node: Node in _held[index].nodes:
		if is_instance_valid(node) and node.get_child_count() > 0:
			models.append(node.get_child(0) as Node3D)
	return models


static func _skeleton_of(view: Node) -> Skeleton3D:
	var found := view.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
