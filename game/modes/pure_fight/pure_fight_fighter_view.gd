class_name PureFightFighterView
extends Node3D
## One Pure Fight fighter on screen: the legend's voxel model posed by its FightStyle through
## FightRig, placed on the fight line between the last two sim ticks, with a motion trail
## on the striking limb. Reads the sim only.

const TRAIL_LENGTH := 7
const TRAIL_WIDTH := 0.16

var index := 0
var legend: StringName = &"kael"
var character: CharacterView
var rig := FightRig.new()
var animator: FightAnimator
var energy := Color(1.0, 0.75, 0.35)
var _previous := Vector3.ZERO
var _current := Vector3.ZERO
var _time := 0.0
var _trail: MeshInstance3D
var _trail_mesh := ImmediateMesh.new()
var _trail_points: Array[Vector3] = []
var _trail_material := StandardMaterial3D.new()
## World position of each limb end (hands, toes, head) after the last pose.
var limb_points: Dictionary = {}


func setup(sim: PureFightSim, fighter_index: int) -> void:
	index = fighter_index
	legend = sim.pf[index].legend
	var roster := Roster.character(legend)
	var scene: PackedScene = roster.voxel_scene if roster.voxel_scene else roster.scene
	character = scene.instantiate() as CharacterView
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 0.99, 0)
	add_child(body)
	body.add_child(character)
	animator = FightAnimator.new(FightStyle.for_legend(legend))
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(_trail)
	_current = sim.world_feet(index)
	_previous = _current


func _ready() -> void:
	for node in character.find_children("*", "SkeletonModifier3D", true, false):
		if node is MotionLayers:
			(node as SkeletonModifier3D).active = false
	rig.setup(character.model.get_node("%GeneralSkeleton"))
	# Pure Fight is unarmed: hide anything a legend carries.
	for node in character.find_children("*", "BoneAttachment3D", true, false):
		(node as Node3D).visible = false


func remember_previous_tick(_sim: PureFightSim) -> void:
	_previous = _current


func remember_current(sim: PureFightSim) -> void:
	_current = sim.world_feet(index)


func present(sim: PureFightSim, blend: float, delta: float) -> void:
	_time += delta
	var fighter := sim.pf[index]
	position = _previous.lerp(_current, blend)
	var facing := sim.line_dir * float(fighter.facing)
	# The model faces -Z; turn it to look along the line toward its facing.
	basis = Basis.looking_at(facing, Vector3.UP)
	var pose := animator.pose(sim, index, blend, _time, delta)
	if fighter.hitstop > 0:
		var shake := 0.012 * sin(_time * 90.0)
		var hips: Vector3 = pose.get("hip", Vector3.ZERO)
		pose["hip"] = hips + Vector3(shake, 0, 0)
	rig.apply(pose)
	var skeleton_xf := rig.skeleton.global_transform
	for key in rig.points:
		limb_points[key] = skeleton_xf * ((rig.points[key] as Vector3) * rig.scale)
	_update_trail()


func _update_trail() -> void:
	var limb := animator.active_limb
	var key := ""
	if limb != "":
		key = limb.substr(0, 1) + ("hand" if limb.ends_with("h") else "toe")
	if key != "" and limb_points.has(key):
		_trail_points.push_front(limb_points[key])
	elif not _trail_points.is_empty():
		_trail_points.pop_back()
	while _trail_points.size() > TRAIL_LENGTH:
		_trail_points.pop_back()
	_trail_mesh.clear_surfaces()
	if _trail_points.size() < 2:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var to_cam := Vector3.BACK if cam == null else (cam.global_position - _trail_points[0]).normalized()
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_material)
	for i in _trail_points.size():
		var p := _trail_points[i]
		var next := _trail_points[mini(i + 1, _trail_points.size() - 1)]
		var prev := _trail_points[maxi(i - 1, 0)]
		var along := (prev - next).normalized()
		var side := along.cross(to_cam).normalized() * TRAIL_WIDTH * (1.0 - float(i) / _trail_points.size())
		var alpha := 0.55 * (1.0 - float(i) / _trail_points.size())
		var c := Color(energy.r, energy.g, energy.b, alpha)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p + side)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p - side)
	_trail_mesh.surface_end()
