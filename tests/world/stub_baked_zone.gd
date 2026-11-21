extends VoxelZone
## A stand-in voxel zone for bake tests: nodes, typed arrays of nodes and
## transforms, a shared material, a helper object and a node meta.

const Helper := preload("res://tests/world/stub_baked_zone_helper.gd")

var lamps: Array[Node3D] = []
var bases: Array[Transform3D] = []
var glow: ShaderMaterial
var nested := {}
var helper: Helper
var animated := -1.0


func build() -> void:
	glow = ShaderMaterial.new()
	glow.shader = Shader.new()
	glow.shader.code = "shader_type spatial;"
	for i in 3:
		var lamp := MeshInstance3D.new()
		lamp.name = "Lamp%d" % i
		lamp.mesh = BoxMesh.new()
		lamp.material_override = glow
		lamp.position = Vector3(i, 0, 0)
		add_child(lamp)
		lamps.append(lamp)
		bases.append(lamp.transform)
	nested = {"first": [lamps[0], bases[0]], "count": 3}
	helper = Helper.new()
	helper.spins.append(lamps[2])
	set_meta("light", lamps[1])
	set_meta("spot", Vector3(1, 2, 3))
	lantern_materials.append(glow)


func make_restored(script: Script) -> Object:
	if script == Helper:
		return Helper.new()
	return super(script)


func animate(t: float) -> void:
	animated = t
	for i in lamps.size():
		lamps[i].transform = bases[i].translated(Vector3(0, t, 0))
