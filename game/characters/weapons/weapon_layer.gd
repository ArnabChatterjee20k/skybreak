class_name WeaponLayer
extends Node3D
## Draws everything weapon-related from sim state: pickups (sky-drop pillar
## and streak, then bobbing and glowing on the ground), projectiles (arrows,
## bullets with tracers, pellets, spinning thrown weapons) and the weapon in
## each fighter's hand on its hand bone. Since T-D26 also power and gadget
## drops, thrown gadgets (bomb, mine, decoy), power auras, the Heartstring
## Tether string and the arrow nocked on a held bow. Reads the sim only;
## interpolates between the last two ticks like FighterView.

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

## Grip in the hand bone's frame (degrees, then metres), tuned on the chunky Kael rig.
const GRIP_ROTATION := Vector3(0, 0, -90)
const GRIP_ROTATION_RANGED := Vector3(0, 0, -90)
const GRIP_OFFSET := Vector3(0, 0.08, 0)
## Held weapons are drawn this much bigger than the pickups, Brawlhalla-chunky.
const HELD_SCALE := 1.5

var _pickup_nodes: Dictionary = {}
var _projectile_nodes: Dictionary = {}
var _previous: Dictionary = {}
var _held: Array[Dictionary] = []
var _gadget_nodes: Dictionary = {}
var _auras: Array[Node3D] = []
var _tether_nodes: Dictionary = {}
var _time := 0.0


func setup(combat_sim: CombatSim, views: Array[FighterView]) -> void:
	sim = combat_sim
	fighter_views = views
	_held.clear()
	for node in _auras:
		node.queue_free()
	_auras.clear()
	for view in views:
		_held.append({"kind": -1, "nodes": [], "arrow": null})
		var aura := _make_aura()
		add_child(aura)
		_auras.append(aura)


## Call once per sim tick, before the sim advances.
func remember_previous_tick() -> void:
	_previous.clear()
	for pickup in sim.pickups:
		_previous["p%d" % pickup.id] = pickup.position
	for projectile in sim.projectiles:
		_previous["s%d" % projectile.id] = projectile.position
	for gadget in sim.gadgets:
		_previous["g%d" % gadget.id] = gadget.position


## Call every rendered frame. blend: 0 = previous tick, 1 = latest tick.
func present(blend: float, delta: float) -> void:
	_time += delta
	_present_pickups(blend)
	_present_projectiles(blend)
	_present_gadgets(blend)
	_present_tethers()
	for i in fighter_views.size():
		_present_held(i)
		_present_nocked_arrow(i)
		_present_aura(i)


func _present_pickups(blend: float) -> void:
	var alive := {}
	for pickup in sim.pickups:
		alive[pickup.id] = true
		var node: Node3D = _pickup_nodes.get(pickup.id)
		if node == null:
			node = _make_pickup(pickup.kind, pickup.power)
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


func _make_pickup(kind: Weapon.Kind, power := Power.Kind.NONE) -> Node3D:
	var node := Node3D.new()
	var glow_color := HEART_GLOW if kind == Weapon.Kind.HEARTSTRING_BOW else ITEM_GLOW
	var model := Node3D.new()
	model.name = "Model"
	var weapon := WeaponModels.build(kind) if power == Power.Kind.NONE else PowerModels.build(power)
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
		if projectile.effect == Weapon.Effect.DISC:
			node.rotation = Vector3(0, _time * 22.0, 0)
		elif projectile.thrown:
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
	if projectile.effect == Weapon.Effect.DISC:
		# The chakram flies flat, spinning.
		var disc := WeaponModels.build(Weapon.Kind.ORBIT_CHAKRAM)
		disc.position = -WeaponModels.centre_of(disc)
		var flat := Node3D.new()
		flat.rotation_degrees = Vector3(90, 0, 0)
		flat.add_child(disc)
		node.add_child(flat)
		node.add_child(_glow_ball(0.2, Color(ITEM_GLOW, 0.35)))
		return node
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
	held.arrow = null
	held.kind = kind
	if kind == Weapon.Kind.NONE:
		return
	var skeleton := _skeleton_of(fighter_views[index])
	if skeleton != null:
		held.nodes = attach(skeleton, kind)
		if Weapon.is_bow(kind) and not held.nodes.is_empty():
			var arrow := PowerModels.nocked_arrow(kind == Weapon.Kind.HEARTSTRING_BOW)
			(held.nodes[0] as Node).get_child(0).add_child(arrow)
			held.arrow = arrow


## The arrow on a held bow: shown while it has ammo, pulled back with the draw level.
func _present_nocked_arrow(index: int) -> void:
	var arrow: Node3D = _held[index].arrow
	if arrow == null or not is_instance_valid(arrow):
		return
	var fighter := sim.fighters[index]
	arrow.visible = fighter.held_ammo() > 0
	arrow.position = Vector3(0, 0, nock_offset(fighter.draw_level()))


## Where the nock sits along the bow's Z axis at a draw level (0 = resting on the string).
static func nock_offset(level: int) -> float:
	return 0.26 + 0.1 * level


func _present_gadgets(blend: float) -> void:
	var alive := {}
	for gadget in sim.gadgets:
		alive[gadget.id] = true
		var node: Node3D = _gadget_nodes.get(gadget.id)
		if node == null:
			node = make_gadget(gadget)
			_gadget_nodes[gadget.id] = node
			add_child(node)
		node.position = (_previous.get("g%d" % gadget.id, gadget.position) as Vector3).lerp(gadget.position, blend)
		var model: Node3D = node.get_node("Model")
		match gadget.kind:
			Power.Kind.SPIKE_BOMB:
				model.rotation = Vector3(_time * 6.0, _time * 4.0, 0)
				# The spark blinks faster as the fuse burns down.
				var spark := model.find_child("Spark", true, false) as Node3D
				if spark:
					spark.visible = int(_time * (4.0 + 40.0 / maxf(gadget.ticks_left, 1))) % 2 == 0
			Power.Kind.GRAVITY_MINE:
				model.rotation = Vector3(0, _time * (6.0 if gadget.phase == Gadget.Phase.PULLING else 1.5), 0)
				var field: Node3D = node.get_node("Field")
				field.visible = gadget.phase == Gadget.Phase.PULLING
				field.scale = Vector3.ONE * (1.0 - fmod(_time * 1.5, 1.0))
			Power.Kind.MIRROR_DECOY:
				node.rotation = Vector3(0, gadget.facing_yaw, 0)
				model.visible = gadget.ticks_left > 30 or int(_time * 12.0) % 2 == 0
	for id: int in _gadget_nodes.keys():
		if not alive.has(id):
			(_gadget_nodes[id] as Node3D).queue_free()
			_gadget_nodes.erase(id)


## The view of a gadget in the world: the model, plus the mine's pull field
## and the decoy's see-through body.
static func make_gadget(gadget: Gadget) -> Node3D:
	var node := Node3D.new()
	var model := Node3D.new()
	model.name = "Model"
	node.add_child(model)
	match gadget.kind:
		Power.Kind.SPIKE_BOMB:
			PowerModels.spike_bomb(model)
			model.scale = Vector3.ONE * 1.4
		Power.Kind.GRAVITY_MINE:
			PowerModels.gravity_mine(model)
			model.scale = Vector3.ONE * 1.8
			var field := MeshInstance3D.new()
			field.name = "Field"
			var sphere := SphereMesh.new()
			sphere.radius = Power.MINE_PULL_RADIUS
			sphere.height = Power.MINE_PULL_RADIUS * 2.0
			field.mesh = sphere
			field.material_override = _glow_material(Color(0.55, 0.3, 1.0, 0.12))
			field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(field)
		Power.Kind.MIRROR_DECOY:
			var body := MeshInstance3D.new()
			var capsule := CapsuleMesh.new()
			capsule.radius = Power.DECOY_RADIUS
			capsule.height = Power.DECOY_HEIGHT
			body.mesh = capsule
			body.material_override = _glow_material(Color(0.8, 0.9, 1.0, 0.35))
			body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			model.add_child(body)
			var mirror := PowerModels.build(Power.Kind.MIRROR_DECOY)
			mirror.position = Vector3(0, 0.3, -0.5)
			model.add_child(mirror)
	return node


## Glowing pink strings between tethered fighters.
func _present_tethers() -> void:
	var alive := {}
	for index in sim.fighters.size():
		var partner := sim.fighters[index].tether_partner
		if partner <= index or index >= fighter_views.size() or partner >= fighter_views.size():
			continue
		alive[index] = true
		var string: MeshInstance3D = _tether_nodes.get(index)
		if string == null:
			string = MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.04
			mesh.bottom_radius = 0.04
			mesh.height = 1.0
			string.mesh = mesh
			string.material_override = _glow_material(Color(HEART_GLOW, 0.85))
			string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(string)
			_tether_nodes[index] = string
		var from := fighter_views[index].global_position
		var to := fighter_views[partner].global_position
		var length := maxf(from.distance_to(to), 0.01)
		var up := (to - from) / length
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.99 else Vector3.RIGHT).normalized()
		string.global_transform = Transform3D(Basis(side, up * length, side.cross(up)), (from + to) * 0.5)
	for index: int in _tether_nodes.keys():
		if not alive.has(index):
			(_tether_nodes[index] as Node3D).queue_free()
			_tether_nodes.erase(index)


## Aura around a fighter with active powers: a gold bubble for Aegis, a coloured ring for the timed buffs.
func _make_aura() -> Node3D:
	var aura := Node3D.new()
	var bubble := MeshInstance3D.new()
	bubble.name = "Bubble"
	var sphere := SphereMesh.new()
	sphere.radius = 1.3
	sphere.height = 2.6
	bubble.mesh = sphere
	bubble.material_override = _glow_material(Color(Power.AURA[Power.Kind.AEGIS], 0.22))
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(bubble)
	for kind: Power.Kind in [Power.Kind.OVERDRIVE_ORB, Power.Kind.HASTE]:
		var ring := MeshInstance3D.new()
		ring.name = String(Power.power_name(kind))
		var torus := TorusMesh.new()
		torus.inner_radius = 0.8
		torus.outer_radius = 0.95
		ring.mesh = torus
		ring.material_override = _glow_material(Color(Power.AURA[kind], 0.7))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aura.add_child(ring)
	return aura


func _present_aura(index: int) -> void:
	var aura := _auras[index]
	var powers := sim.fighters[index].powers
	aura.global_position = fighter_views[index].global_position
	var bubble: Node3D = aura.get_node("Bubble")
	bubble.visible = powers.aegis
	bubble.scale = Vector3.ONE * (1.0 + 0.04 * sin(_time * 6.0))
	var overdrive: Node3D = aura.get_node(String(Power.power_name(Power.Kind.OVERDRIVE_ORB)))
	overdrive.visible = powers.overdrive_ticks > 0
	overdrive.position = Vector3(0, -0.6 + 0.5 * sin(_time * 3.0), 0)
	var haste: Node3D = aura.get_node(String(Power.power_name(Power.Kind.HASTE)))
	haste.visible = powers.haste_ticks > 0
	haste.position = Vector3(0, -0.95, 0)
	haste.rotation = Vector3(0, _time * 8.0, 0)


## Puts kind's model on the skeleton's hand bone(s): bows in the left hand,
## gauntlets on both, the rest in the right. Returns the attachments.
static func attach(skeleton: Skeleton3D, kind: Weapon.Kind) -> Array[Node]:
	var nodes: Array[Node] = []
	var bow := kind == Weapon.Kind.KI_BOW or kind == Weapon.Kind.HEARTSTRING_BOW
	var hands: Array[StringName] = []
	if kind == Weapon.Kind.KI_GAUNTLETS:
		hands.append_array([RIGHT_HAND, LEFT_HAND])
	else:
		hands.append(LEFT_HAND if bow else RIGHT_HAND)
	for hand in hands:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = hand
		skeleton.add_child(attachment)
		var model := WeaponModels.build(kind)
		model.transform = grip_transform(kind, hand == LEFT_HAND)
		attachment.add_child(model)
		nodes.append(attachment)
	return nodes


## Where a weapon sits relative to its hand bone, scaled up to read at the
## chunky characters' proportions. Hand bones point +Y along the fingers.
static func grip_transform(kind: Weapon.Kind, left: bool) -> Transform3D:
	var side := -1.0 if left else 1.0
	if kind == Weapon.Kind.KI_GAUNTLETS:
		return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.15), Vector3(0, 0.05, 0))
	var euler := GRIP_ROTATION_RANGED if Weapon.is_ranged(kind) else GRIP_ROTATION
	var basis := Basis.from_euler(Vector3(deg_to_rad(euler.x), deg_to_rad(euler.y * side),
		deg_to_rad(euler.z * side)))
	return Transform3D(basis.scaled(Vector3.ONE * HELD_SCALE), GRIP_OFFSET)


static func _skeleton_of(view: Node) -> Skeleton3D:
	var found := view.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
