extends SceneTree
## Look-dev stills of the voxel weapons on the neutral stage (LookdevStage):
## each weapon alone (side and 3/4), a turntable, and held by a voxel character.
##   godot --path . --disable-vsync -s res://game/characters/voxel_weapons/preview/voxel_weapon_capture.gd -- \
##       <out dir> [alone|turntable|held|all] [--kinds=blade,revolver,...] [--scene=<character scene>] [--old]
## --old renders the old meshes the same way (for old | new pairs). Needs a GPU
## (lavapipe works for checking code, not for judging looks). 1920x1080 PNGs.

const USAGE := "voxel_weapon_capture.gd -- <out dir> [alone|turntable|held|all] [--kinds=a,b] [--scene=...] [--old]"
const DEFAULT_SCENE := "res://game/characters/kael_voxel/kael_voxel.tscn"
const TURNTABLE_STEPS := 8

var _out := ""
var _viewport: SubViewport
var _stage: LookdevStage
var _old := false


func _initialize() -> void:
	var args := LookdevArgs.parse()
	_out = args.pos(0)
	if _out == "":
		push_error(USAGE)
		quit(1)
		return
	_old = args.get_option("old", "") != ""
	DirAccess.make_dir_recursive_absolute(_out)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	# Weapons float above the floor: the big cyclorama keeps its edge out of close framing.
	_stage.large = true
	_viewport.add_child(_stage)
	var kinds: Array[Weapon.Kind] = []
	var names := args.get_option("kinds", "")
	for kind: Weapon.Kind in VoxelWeapons.DESIGNS:
		if names == "" or String(Weapon.weapon_name(kind)) in names.split(","):
			kinds.append(kind)
	_run.call_deferred(args.pos(1, "all"), kinds, args.get_option("scene", DEFAULT_SCENE))


func _run(what: String, kinds: Array[Weapon.Kind], scene: String) -> void:
	for kind in kinds:
		if what == "heldonly":
			break
		var started := Time.get_ticks_msec()
		var model := WeaponModels.build(kind) if _old else VoxelWeapons.build(kind)
		var built := Time.get_ticks_msec() - started
		var tag := String(Weapon.weapon_name(kind)) + ("_old" if _old else "")
		if not _old:
			print("%s: %d vertices, cell %.4f m (world %.4f m), built in %d ms" % [tag,
				VoxelWeapons.vertex_count(kind), VoxelWeapons.design_of(kind).cell(),
				VoxelWeapons.design_of(kind).cell() * VoxelWeapons.design_of(kind).model_scale(), built])
		if what in ["alone", "all"]:
			await _alone(kind, model, tag + "_side", side_yaw(kind), -2.0)
			await _alone(kind, model, tag + "_34", side_yaw(kind) + 38.0, -16.0)
		if what in ["turntable"]:
			for i in TURNTABLE_STEPS:
				await _alone(kind, model, "%s_turn_%03d" % [tag, i * 45], side_yaw(kind) + i * 45.0, -10.0)
		model.free()
	if what in ["held", "all", "heldonly"]:
		for kind in kinds:
			await _held(scene, kind)
	print("voxel weapon stills written to ", _out)
	quit()


## The camera yaw that shows a kind's flat profile.
static func side_yaw(kind: Weapon.Kind) -> float:
	match kind:
		Weapon.Kind.STORM_BLADE, Weapon.Kind.ORBIT_CHAKRAM:
			return 0.0
		Weapon.Kind.KI_GAUNTLETS:
			return 200.0
	return 90.0


## Long weapons lie flat (tip to the right of the profile view); the rest stand on their grip.
static func lay(kind: Weapon.Kind) -> Basis:
	match kind:
		Weapon.Kind.STORM_BLADE:
			return Basis(Vector3.BACK, -PI * 0.5)
		Weapon.Kind.SKY_LANCE, Weapon.Kind.TITAN_HAMMER, Weapon.Kind.KI_BOW, Weapon.Kind.HEARTSTRING_BOW, \
				Weapon.Kind.EMBER_SCYTHE:
			return Basis(Vector3.RIGHT, -PI * 0.5)
	return Basis.IDENTITY


func _alone(kind: Weapon.Kind, model: Node3D, name: String, yaw: float, pitch: float) -> void:
	var holder := Node3D.new()
	_stage.add_child(holder)
	var scale := float(WeaponGrip.SCALE.get(kind, 1.0))
	# The weapon turns, not the camera, so the cyclorama always fills the frame.
	holder.basis = Basis(Vector3.UP, deg_to_rad(-yaw)) * lay(kind).scaled(Vector3.ONE * scale)
	if model.get_parent():
		model.get_parent().remove_child(model)
	holder.add_child(model)
	var box := _bounds(holder)
	holder.position = Vector3(0, 0.12 + box.size.y * 0.5, 0) - box.get_center()
	var centre := Vector3(0, 0.12 + box.size.y * 0.5, 0)
	var extent := maxf(box.size.y, maxf(box.size.x, box.size.z) * 9.0 / 16.0 * 1.1)
	_stage.camera.fov = 30.0
	_stage.frame(centre, extent, 0.8, pitch, 0.0)
	await _save(name)
	holder.remove_child(model)
	holder.queue_free()


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		var to_node := node.global_transform.affine_inverse() * mi.global_transform
		var b := Transform3D(node.basis, Vector3.ZERO) * to_node * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _held(scene: String, kind: Weapon.Kind) -> void:
	var pivot := Node3D.new()
	_stage.add_child(pivot)
	var facing := Node3D.new()
	facing.rotation.y = PI
	pivot.add_child(facing)
	var view := (load(scene) as PackedScene).instantiate() as CharacterView
	var body := Node3D.new()
	body.position = Vector3(0, 1, 0)
	facing.add_child(body)
	body.add_child(view)
	await process_frame
	var skeleton := view.model.get_node("%GeneralSkeleton") as Skeleton3D
	if _old:
		skeleton.set_meta(WeaponModels.VOXEL_META, false)
	var held := WeaponLayer.attach(skeleton, kind)
	var fighter := FighterState.new()
	fighter.weapons[0] = kind
	fighter.active_slot = 0
	fighter.enter_state(FighterState.State.IDLE)
	for t in 40:
		fighter.state_ticks += 1
		view.apply_state(fighter, 1.0 / 60.0)
		await process_frame
	var tag := String(Weapon.weapon_name(kind)) + ("_old" if _old else "")
	for yaw: float in [35.0, -35.0]:
		pivot.rotation.y = deg_to_rad(yaw)
		_stage.camera.fov = 30.0
		_stage.frame(Vector3(0, 0.95, 0), 2.1, 0.82, -6.0)
		await _save("held_%s_%s" % [tag, "34" if yaw > 0 else "34b"])
	# Close-up on the weapon hand(s).
	var hand := WeaponGrip.hands_of(kind)[0]
	var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(hand)).origin
	pivot.rotation.y = deg_to_rad(35.0)
	await process_frame
	at = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(hand)).origin
	_stage.camera.fov = 24.0
	_stage.frame(at, 0.9, 0.8, -10.0)
	await _save("held_%s_close" % tag)
	for node in held:
		node.queue_free()
	pivot.queue_free()
	await process_frame


func _save(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
