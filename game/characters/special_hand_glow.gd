class_name SpecialHandGlow
extends RefCounted
## Special tells on the body (T-SP1): a glow orb on each hand bone while a special
## runs, swelling through its startup. Lit, black albedo, emission x GLOW_GAIN, as
## the voxel look-dev glow (MovesReel.glow_material). View only.

## Emission per unit of nominal energy (the voxel look-dev value; keeps the hue through the tonemap).
const GLOW_GAIN := 0.27
const ENERGY := 5.0
## Orb radius in metres at full size, and its share at the first startup tick.
const RADIUS := 0.075
const START_SHARE := 0.45
const HANDS: Array[StringName] = [WeaponGrip.RIGHT_HAND, WeaponGrip.LEFT_HAND]

var orbs: Array[MeshInstance3D] = []
var _skeleton: Skeleton3D
var _color := Color.TRANSPARENT


## Lit, black albedo: the emission alone gives the colour.
static func glow_material(energy: float, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy * GLOW_GAIN
	return mat


func _init(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	for hand in HANDS:
		if skeleton.find_bone(hand) < 0:
			continue
		var socket := BoneAttachment3D.new()
		socket.name = "SpecialGlow%s" % hand
		socket.bone_name = hand
		skeleton.add_child(socket, false, Node.INTERNAL_MODE_BACK)
		var orb := MeshInstance3D.new()
		orb.mesh = sphere
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.visible = false
		socket.add_child(orb)
		orbs.append(orb)


## Shows the orbs on the hands while the fighter performs a special, hides them otherwise.
func update(fighter: FighterState) -> void:
	var special := SpecialRules.current(fighter)
	if special == null:
		for orb in orbs:
			orb.visible = false
		return
	if special.color != _color:
		_color = special.color
		var mat := glow_material(ENERGY, _color)
		for orb in orbs:
			orb.material_override = mat
	var startup := maxi(fighter.move.startup_ticks, 1)
	var share := lerpf(START_SHARE, 1.0, clampf(float(fighter.move_tick) / startup, 0.0, 1.0))
	# The socket carries the rig's scale; the orb's size is in world metres.
	var rig_scale := maxf(_skeleton.global_transform.basis.get_scale().x, 0.001)
	for orb in orbs:
		orb.scale = Vector3.ONE * RADIUS * share / rig_scale
		orb.visible = true
