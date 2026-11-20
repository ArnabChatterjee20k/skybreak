class_name BrannVoxelView
extends BrannView
## Voxel Brann's view: BrannView unchanged, except that its crack pulse
## (BrannView.ember_energy) drives the voxel body's GLOW surface instead of
## the old figure's ember material. Each view owns its copy of the material.

## Emission per unit of ember energy, clamped so bloom stays a thin line glow.
const EMBER_GAIN := 0.7
const EMBER_MIN := 1.0
const EMBER_MAX := 2.6

var _glow: ShaderMaterial


func apply_state(fighter: FighterState, delta: float) -> void:
	super.apply_state(fighter, delta)
	if _glow:
		_glow.set_shader_parameter(&"emission_value", glow_energy(fighter, _time))


## The GLOW surface's emission for a state at a time.
static func glow_energy(fighter: FighterState, time: float) -> float:
	return clampf(ember_energy(fighter, time) * EMBER_GAIN, EMBER_MIN, EMBER_MAX)


## The view's own copy of the ember GLOW material (null before _ready).
func glow_material() -> ShaderMaterial:
	return _glow


func _own_ember(_figure: BrannFigure) -> void:
	var meshes := _skeleton.find_children("*", "MeshInstance3D", false, false)
	if meshes.is_empty():
		return
	var instance := meshes[0] as MeshInstance3D
	for s in instance.mesh.get_surface_count():
		var material := instance.mesh.surface_get_material(s) as ShaderMaterial
		if material == null:
			continue
		var emission: Variant = material.get_shader_parameter(&"emission_value")
		if emission == null or not is_equal_approx(float(emission), BrannVoxelDesign.GLOW_EMISSION):
			continue
		if _glow == null:
			_glow = material.duplicate() as ShaderMaterial
		instance.set_surface_override_material(s, _glow)
