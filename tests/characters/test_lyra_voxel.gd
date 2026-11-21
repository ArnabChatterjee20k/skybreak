extends GutTest
## Voxel Lyra (look-dev variant): the hat stays off the floor when she lies
## down, the cape lining's colour, and the cape's lining edge.

const SCENE := "res://game/characters/lyra_voxel/lyra_voxel.tscn"
const D = preload("res://game/characters/lyra_voxel/lyra_voxel_design.gd")
const FRAME := 1.0 / 60.0
## The view's floor: the model sits 1 m below the view (the capsule centre).
const FLOOR_Y := -1.0
const KNOCKDOWN_TICKS := 90

var _view: CharacterView
var _sk: Skeleton3D
var _hat := -1
## Hat vertices in rest skeleton space (skinned only to the Hat bone).
var _hat_verts := PackedVector3Array()
var _lowest := INF
var _head_lowest := INF


func before_all() -> void:
	_view = (load(SCENE) as PackedScene).instantiate() as CharacterView
	add_child(_view)
	_sk = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_hat = _sk.find_bone(D.HAT_BONE)
	var mi: MeshInstance3D = _sk.find_children("*", "MeshInstance3D", false, false)[0]
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var stride := bones.size() / verts.size()
		for i in verts.size():
			if bones[i * stride] == _hat and weights[i * stride] > 0.99:
				_hat_verts.append(verts[i])
	_sk.skeleton_updated.connect(_measure)


func after_all() -> void:
	_view.free()


func _measure() -> void:
	var to_view := _view.global_transform.affine_inverse() * _sk.global_transform
	var m := to_view * _sk.get_bone_global_pose(_hat) * _sk.get_bone_global_rest(_hat).affine_inverse()
	for v in _hat_verts:
		_lowest = minf(_lowest, (m * v).y)
	_head_lowest = minf(_head_lowest, (to_view * _sk.get_bone_global_pose(_sk.find_bone(&"Head"))).origin.y)


func _play_down(state: FighterState.State) -> void:
	var fighter := FighterState.new()
	for _i in 10:
		_view.apply_state(fighter, FRAME)
		await wait_process_frames(1)
	fighter.enter_state(state)
	fighter.stun_ticks = KNOCKDOWN_TICKS
	_lowest = INF
	_head_lowest = INF
	for _t in KNOCKDOWN_TICKS:
		_view.apply_state(fighter, FRAME)
		await wait_process_frames(1)
		fighter.state_ticks += 1
		fighter.stun_ticks = maxi(fighter.stun_ticks - 1, 0)


func test_the_hat_is_skinned_to_its_own_bone_under_the_head() -> void:
	assert_gt(_hat, -1, "the view adds a Hat bone")
	assert_eq(_sk.get_bone_parent(_hat), _sk.find_bone(&"Head"))
	assert_gt(_hat_verts.size(), 10000, "brim, crown and charm ride the Hat bone")


func test_the_hat_sits_untouched_on_her_head_while_she_stands() -> void:
	var fighter := FighterState.new()
	_lowest = INF
	for _i in 20:
		_view.apply_state(fighter, FRAME)
		await wait_process_frames(1)
	assert_gt(_lowest, FLOOR_Y + 1.2, "standing, the brim is far above the floor")
	var local := _sk.get_bone_pose(_hat)
	assert_almost_eq(local.origin.length(), 0.0, 1e-4, "no tilt applied")
	assert_almost_eq(local.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY), 0.0, 1e-3)


func test_the_lowest_hat_point_stays_above_the_floor_through_a_knockdown() -> void:
	await _play_down(FighterState.State.KNOCKDOWN)
	assert_lt(_head_lowest, FLOOR_Y + 0.35, "she really lies down (head near the floor)")
	assert_gt(_lowest, FLOOR_Y, "lowest hat point %.3f vs floor %.3f" % [_lowest, FLOOR_Y])


func test_the_lowest_hat_point_stays_above_the_floor_when_knocked_out() -> void:
	await _play_down(FighterState.State.KO_DOWN)
	assert_lt(_head_lowest, FLOOR_Y + 0.35, "she really lies down (head near the floor)")
	assert_gt(_lowest, FLOOR_Y, "lowest hat point %.3f vs floor %.3f" % [_lowest, FLOOR_Y])


func test_the_approved_brim_is_not_shrunk() -> void:
	assert_eq(D.BRIM_R, 0.36)
	assert_eq(D.BRIM_FRONT_TILT, 13.0)
	assert_eq(D.BRIM_BACK_DROOP, 6.0)


func test_the_cape_lining_is_authored_muted_so_it_lands_near_sat_067_on_screen() -> void:
	var lining: Color = D.COLORS[D.Mat.LINING]
	assert_eq(lining.to_html(false), "44709f")
	# The GPU stage key light lifts saturation by about 0.1.
	assert_almost_eq(lining.s, 0.57, 0.02, "authored saturation")
	assert_almost_eq(lining.h * 360.0, 211.0, 4.0, "cerulean hue")
	assert_lt(lining.s, (D.COLORS[D.Mat.HAT_BAND] as Color).s, "the hat band stays the saturated accent")


func test_the_lining_edge_is_a_shadow_tone_darker_than_the_lining_and_the_stole() -> void:
	var shade: Color = D.COLORS[D.Mat.LINING_SHADE]
	var lining: Color = D.COLORS[D.Mat.LINING]
	var stole: Color = D.COLORS[D.Mat.STOLE]
	assert_lt(shade.get_luminance(), lining.get_luminance() * 0.75)
	assert_lt(shade.get_luminance(), stole.get_luminance() * 0.5)
	assert_almost_eq(shade.h, lining.h, 0.02, "same hue as the lining")


func test_the_cape_edge_carries_no_pale_piping() -> void:
	var g := D.new(_sk).build_body()
	var shade := 0
	var pale := 0
	for z in g.size.z:
		for y in g.size.y:
			for x in g.size.x:
				var i := g.index(x, y, z)
				if g.tags[i] != D.Tag.CAPE:
					continue
				if g.mats[i] == D.Mat.LINING_SHADE:
					shade += 1
				elif g.mats[i] == D.Mat.STARLINE:
					var p := g.center(x, y, z)
					if absf(absf(p.x) - (D.cape_half_w(p.y) - D.facing_w(p.y))) < D.BODY_CELL * 0.5:
						pale += 1
	assert_gt(shade, 100, "the facing edge and hem piping are in the lining's shadow tone")
	assert_eq(pale, 0, "no pale piping line down the cape's sides")
