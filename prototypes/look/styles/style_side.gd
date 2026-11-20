extends "res://prototypes/look/styles/style_anime.gd"
## Style D: 2.5D side view. B's fighter and world shading, but a fixed side camera that
## auto-zooms to frame every fighter large, fighters pinned to one plane (view only; a
## real conversion would constrain the sim), a painted backdrop and floating platforms.

const BACKDROP_SHADER := preload("res://prototypes/look/shaders/backdrop.gdshader")

## Fight plane: through `fight_centre`, along `plane_axis` (screen right), facing the camera.
var plane_axis := Vector3.RIGHT
var plane_normal := Vector3.FORWARD
var backdrop := MeshInstance3D.new()
var _zoom := 12.0


func _init() -> void:
	super._init()
	fov = 32.0


func setup(zone_match: ZoneMatch) -> void:
	super.setup(zone_match)
	var spawns := zone_match.spawn_positions()
	plane_axis = Vector3(spawns[1].x - spawns[0].x, 0, spawns[1].z - spawns[0].z).normalized()
	plane_normal = plane_axis.cross(Vector3.UP).normalized()
	_build_backdrop()
	_platforms()


func _build_backdrop() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(900, 320)
	backdrop.mesh = q
	var m := ShaderMaterial.new()
	m.shader = BACKDROP_SHADER
	var ember := match_node.zone_id == &"ember_rift"
	m.set_shader_parameter("sky_top", palette.sky_top)
	m.set_shader_parameter("sky_low", palette.sky_horizon)
	m.set_shader_parameter("far_color", Color(palette.fog).darkened(0.05))
	m.set_shader_parameter("near_color", Color(0.24, 0.14, 0.17) if ember else Color(0.42, 0.55, 0.52))
	m.set_shader_parameter("glow_color", Color(1.0, 0.45, 0.12) if ember else Color(1.0, 0.8, 0.9))
	m.set_shader_parameter("islands", 0.0 if ember else 1.0)
	backdrop.material_override = m
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(backdrop)
	# Behind the fight, facing the camera side, its bottom sunk below the floor line.
	var at := fight_centre - plane_normal * 110.0 + Vector3.UP * 95.0
	backdrop.global_transform = Transform3D(Basis(plane_axis, Vector3.UP, plane_normal), at)


## Readable floating platforms over the fight (view only).
func _platforms() -> void:
	var ember := match_node.zone_id == &"ember_rift"
	var slab := painted(Color(0.36, 0.28, 0.3) if ember else Color(0.82, 0.76, 0.78), {"strata": 0.6, "strata_spacing": 1.4})
	var top := painted(Color(0.55, 0.32, 0.22) if ember else Color(0.5, 0.75, 0.38), {}, false)
	var box := BoxMesh.new()
	var slabs: Array[Transform3D] = []
	var tops: Array[Transform3D] = []
	for p in [Vector3(-8, 4.5, -1.5), Vector3(8, 4.5, -1.5)]:
		var at: Vector3 = fight_centre + plane_axis * p.x + Vector3.UP * p.y
		var basis := Basis(plane_axis, Vector3.UP, plane_normal)
		slabs.append(Transform3D(basis.scaled_local(Vector3(8, 1.2, 4)), at))
		tops.append(Transform3D(basis.scaled_local(Vector3(8.2, 0.25, 4.2)), at + Vector3.UP * 0.7))
	# Stage: a slab under the fight whose front face is the clipped edge of the world.
	var floor_y := _ground_y(fight_centre.x, fight_centre.z)
	var basis := Basis(plane_axis, Vector3.UP, plane_normal)
	slabs.append(Transform3D(basis.scaled_local(Vector3(400, 30, 17)), fight_centre + Vector3.UP * (floor_y - fight_centre.y - 15.3)))
	_multi(box, slab, slabs)
	_multi(box, top, tops)


func _process(delta: float) -> void:
	if match_node == null:
		return
	_flatten()
	super._process(delta)


## Pins every fighter view to the fight plane and turns it to face along the plane.
func _flatten() -> void:
	var views := match_node.fighter_views
	for i in views.size():
		var v := views[i]
		var off := v.position - fight_centre
		v.position -= plane_normal * off.dot(plane_normal)
		var target := match_node.sim.fighters[i].lock_on_target
		if target >= 0:
			var dx := (views[target].position - v.position).dot(plane_axis)
			var face := plane_axis * (1.0 if dx >= 0.0 else -1.0)
			v.global_basis = Basis.looking_at(face, Vector3.UP).scaled(v.global_basis.get_scale())


func _frame_camera(delta: float) -> void:
	var views := match_node.fighter_views
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in views:
		var x := (v.position - fight_centre).dot(plane_axis)
		lo = Vector2(minf(lo.x, x), minf(lo.y, v.position.y - 1.0))
		hi = Vector2(maxf(hi.x, x), maxf(hi.y, v.position.y + 1.0))
	var mid := Vector2((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5 + 0.8)
	# Height shown: at least 6.5 m (fighters ~30% tall), else everything plus margin.
	var span := maxf(maxf((hi.x - lo.x) / 1.7778 * 1.4, (hi.y - lo.y) * 1.6), 4.2)
	if wide:
		span = 12.0
	var goal_zoom := span * 0.5 / tan(deg_to_rad(fov * 0.5))
	if not _snapped:
		_zoom = goal_zoom
	_zoom = lerpf(_zoom, goal_zoom, 1.0 - exp(-delta * 2.5))
	var focus := fight_centre + plane_axis * mid.x
	focus.y = mid.y
	var goal := focus + plane_normal * _zoom + Vector3.UP * _zoom * 0.14
	if not _snapped:
		_cam_pos = goal
		_snapped = true
	_cam_pos = _cam_pos.lerp(goal, 1.0 - exp(-delta * 4.0))
	cam.fov = fov
	# Clip everything more than 9 m in front of the fight plane: a stage, not a world.
	cam.near = maxf(0.1, _cam_pos.distance_to(focus) - 9.0)
	cam.far = _cam_pos.distance_to(focus) + 112.0
	cam.global_transform = Transform3D(Basis.looking_at(focus - _cam_pos + Vector3.UP * 0.0001, Vector3.UP), _cam_pos)
