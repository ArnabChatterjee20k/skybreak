class_name PowerModels
extends RefCounted
## Code-built models for power and gadget drops (T-D26), in the same chunky
## toon-and-outline look as WeaponModels. Gold item family with one accent
## colour each; centred on the origin, about 0.7 m across.

const VIOLET := Color(0.55, 0.3, 1.0)
const RED := Color(1.0, 0.25, 0.25)
const LIME := Color(0.45, 1.0, 0.35)
const SILVER := Color(0.85, 0.9, 1.0)


## A new model of kind.
static func build(kind: Power.Kind) -> Node3D:
	var root := Node3D.new()
	root.name = String(Power.power_name(kind)).capitalize().replace(" ", "")
	match kind:
		Power.Kind.OVERDRIVE_ORB:
			WeaponModels._sphere(root, 0.2, WeaponModels.KI_CYAN, Vector3.ZERO, true)
			WeaponModels._torus(root, 0.26, 0.32, WeaponModels.GOLD, Vector3.ZERO, Vector3(90, 0, 0))
			WeaponModels._torus(root, 0.26, 0.32, WeaponModels.GOLD, Vector3.ZERO, Vector3(0, 0, 90))
			WeaponModels._torus(root, 0.26, 0.32, WeaponModels.DARK_GOLD, Vector3.ZERO, Vector3(0, 90, 90))
		Power.Kind.BURST_SHARD:
			WeaponModels._prism(root, Vector3(0.28, 0.36, 0.28), RED, Vector3(0, 0.18, 0), Vector3.ZERO, true)
			WeaponModels._prism(root, Vector3(0.28, 0.24, 0.28), RED, Vector3(0, -0.12, 0), Vector3(180, 0, 0), true)
			WeaponModels._torus(root, 0.2, 0.26, WeaponModels.GOLD, Vector3(0, 0.0, 0), Vector3(0, 0, 0))
		Power.Kind.AEGIS:
			WeaponModels._cylinder(root, 0.34, 0.08, WeaponModels.GOLD, Vector3.ZERO, Vector3(90, 0, 0))
			WeaponModels._cylinder(root, 0.24, 0.1, WeaponModels.DARK_GOLD, Vector3(0, 0, 0.01), Vector3(90, 0, 0))
			WeaponModels._sphere(root, 0.11, Color(1.0, 0.95, 0.6), Vector3(0, 0, 0.06), true)
			WeaponModels._torus(root, 0.32, 0.38, WeaponModels.GOLD, Vector3.ZERO, Vector3(90, 0, 0))
		Power.Kind.HASTE:
			for i in 2:
				WeaponModels._prism(root, Vector3(0.36, 0.2, 0.1), LIME, Vector3(0, 0.14 - i * 0.2, 0),
					Vector3(0, 0, 0), true)
			WeaponModels._torus(root, 0.28, 0.33, WeaponModels.GOLD, Vector3.ZERO, Vector3(90, 0, 0))
			WeaponModels._box(root, Vector3(0.08, 0.5, 0.08), WeaponModels.GOLD, Vector3(0.0, 0.0, -0.08), Vector3(0, 0, 25))
		Power.Kind.SPIKE_BOMB:
			spike_bomb(root)
		Power.Kind.GRAVITY_MINE:
			gravity_mine(root)
		Power.Kind.MIRROR_DECOY:
			WeaponModels._torus(root, 0.2, 0.27, WeaponModels.GOLD, Vector3(0, 0.1, 0), Vector3(90, 0, 0))
			WeaponModels._cylinder(root, 0.21, 0.03, SILVER, Vector3(0, 0.1, 0), Vector3(90, 0, 0), -1.0, true)
			WeaponModels._cylinder(root, 0.045, 0.32, WeaponModels.DARK_GOLD, Vector3(0, -0.3, 0))
			WeaponModels._sphere(root, 0.06, WeaponModels.GOLD, Vector3(0, -0.47, 0))
	return root


## A dark ball with gold spikes and a lit fuse.
static func spike_bomb(root: Node3D) -> void:
	WeaponModels._sphere(root, 0.24, WeaponModels.CHARCOAL, Vector3.ZERO)
	for direction: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT,
			Vector3.FORWARD, Vector3.BACK]:
		var spike := WeaponModels._cylinder(root, 0.07, 0.16, WeaponModels.GOLD, direction * 0.28, Vector3.ZERO, 0.0)
		spike.basis = Basis(Quaternion(Vector3.UP, direction)) if direction != Vector3.DOWN \
			else Basis(Vector3.RIGHT, PI)
	WeaponModels._cylinder(root, 0.03, 0.12, WeaponModels.LEATHER, Vector3(0.12, 0.26, 0), Vector3(0, 0, -30))
	var spark := WeaponModels._sphere(root, 0.05, WeaponModels.EMBER, Vector3(0.16, 0.33, 0), true)
	spark.name = "Spark"


## A dark core in two gold rings with a violet heart.
static func gravity_mine(root: Node3D) -> void:
	WeaponModels._sphere(root, 0.18, WeaponModels.CHARCOAL, Vector3.ZERO)
	WeaponModels._sphere(root, 0.1, VIOLET, Vector3.ZERO, true)
	WeaponModels._torus(root, 0.24, 0.3, WeaponModels.GOLD, Vector3.ZERO, Vector3(90, 0, 0))
	WeaponModels._torus(root, 0.3, 0.35, WeaponModels.DARK_GOLD, Vector3.ZERO, Vector3(20, 0, 70))


## An arrow along -Z with its nock at the origin, for the bow in hand.
static func nocked_arrow(heart: bool) -> Node3D:
	var arrow := Node3D.new()
	arrow.name = "NockedArrow"
	WeaponModels._cylinder(arrow, 0.018, 0.8, WeaponModels.PINK if heart else WeaponModels.WOOD, Vector3(0, 0, -0.4), Vector3(90, 0, 0))
	WeaponModels._cylinder(arrow, 0.05, 0.14, WeaponModels.GOLD, Vector3(0, 0, -0.85), Vector3(-90, 0, 0), 0.0, true)
	WeaponModels._box(arrow, Vector3(0.012, 0.08, 0.12), WeaponModels.ROSE if heart else WeaponModels.TEAL, Vector3(0, 0, -0.06))
	return arrow
