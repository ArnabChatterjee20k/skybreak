extends SceneTree
## Moves reel of voxel Kael on the look-dev stage, driven by the game's own
## clips through CharacterView.apply_state, one sim tick per frame at 60 fps.
##   godot --path . --disable-vsync -s res://game/lookdev/kael_moves_reel.gd -- <out dir> [full|first]
## Writes numbered JPG frames (f_00000.jpg...) for ffmpeg at 60 fps. Needs a GPU.
## The sim is faked here: positions and velocities are scripted per segment so
## the view picks the clips it would in a match (no CombatSim, no opponent).

const VOXEL := "res://game/characters/kael_voxel/kael_voxel.tscn"
const MOVES := "res://game/combat/moves/kael/"
const DT := 1.0 / 60.0
const STAND := 1.0  # FighterState.stand_height: the body's height when standing
const GRAVITY := 22.0
const KI_COLOR := Color(1.0, 0.62, 0.25)

var _out := ""
var _frame := 0
var _viewport: SubViewport
var _stage: LookdevStage
var _body: Node3D
var _view: CharacterView
var _f := FighterState.new()
var _caption: Label
# Camera: smoothed target, orbit yaw (world), framed height and fill.
var _cam_target := Vector3(0, 0.95, 0)
var _cam_yaw := 35.0
var _cam_height := 1.9
var _cam_fill := 0.62
var _cam_pitch := -6.0
var _cam_snap := true
var _close := false
var _fx: Array[Node3D] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var what := args[1] if args.size() > 1 else "full"
	DirAccess.make_dir_recursive_absolute(_out)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	_viewport.add_child(_stage)
	var layer := CanvasLayer.new()
	_viewport.add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(64, 980)
	_caption.add_theme_font_size_override(&"font_size", 40)
	_caption.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.92))
	_caption.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.55))
	_caption.add_theme_constant_override(&"shadow_offset_x", 2)
	_caption.add_theme_constant_override(&"shadow_offset_y", 2)
	layer.add_child(_caption)
	_run.call_deferred(what)


func _run(what: String) -> void:
	_body = Node3D.new()
	_stage.add_child(_body)
	_view = (load(VOXEL) as PackedScene).instantiate() as CharacterView
	_body.add_child(_view)
	_f.position = Vector3(0, STAND, 0)
	_f.facing_yaw = PI  # facing +Z, toward the default camera
	_f.enter_state(FighterState.State.IDLE)
	for i in 30:  # settle the pose and scarf without recording
		await _tick(false)
	if what == "first":
		await _idle("Idle", 2.5)
		await _locomotion("Run", 9.0, 3.0)
		await _flight(3.0)
		await _moves("Jab", ["light_1"], true)
		await _moves("3-hit combo", ["light_1", "light_2", "light_3"], true)
		await _idle("Idle", 1.0)
	else:
		await _idle("Idle", 3.0)
		await _locomotion("Walk", 3.0, 2.5)
		await _locomotion("Run", 9.0, 3.0)
		await _jump()
		await _hover()
		await _flight(3.0)
		await _moves("Jab", ["light_1"], true)
		await _moves("3-hit combo", ["light_1", "light_2", "light_3"], true)
		await _moves("Heavy  /  launcher", ["smash", "launcher"], false)
		await _moves("Sweep kick", ["sweep"], false)
		await _dodge()
		await _guard()
		await _ki_blast()
		await _beam()
		await _hit_and_knockdown()
		await _idle("Idle", 2.5)
	print("frames: %d" % _frame)
	quit()


# ---------------------------------------------------------------- segments

func _reset(at := Vector3.ZERO, yaw := PI) -> void:
	_f.position = Vector3(at.x, STAND, at.z)
	_f.velocity = Vector3.ZERO
	_f.facing_yaw = yaw
	_f.blocking = false
	_f.enter_state(FighterState.State.IDLE)
	_cam_snap = true


func _idle(caption: String, seconds: float) -> void:
	_caption.text = caption
	_close = false
	if _f.state != FighterState.State.IDLE:
		_f.enter_state(FighterState.State.IDLE)
	for i in int(seconds * 60):
		_f.velocity = Vector3.ZERO
		await _tick()


## Walks or runs round a circle (the stage is only so big), easing up to speed.
func _locomotion(caption: String, speed: float, seconds: float) -> void:
	_caption.text = caption
	_close = false
	var centre := Vector3(0, 0, 2.2)
	var radius := 3.2
	# Start from where he stands: on the circle's near side, heading +X.
	var angle := atan2(_f.position.z - centre.z, _f.position.x - centre.x)
	if absf(Vector2(_f.position.x - centre.x, _f.position.z - centre.z).length() - radius) > 0.2:
		_reset(centre + Vector3(0, 0, -radius), PI * 0.5 + PI)
		angle = -PI * 0.5
	if _f.state != FighterState.State.MOVING:
		_f.enter_state(FighterState.State.MOVING)
	var v0 := Vector2(_f.velocity.x, _f.velocity.z).length()
	for i in int(seconds * 60):
		var v := lerpf(v0, speed, minf(i / 30.0, 1.0))
		angle -= v * DT / radius  # clockwise seen from above: he curves to his right
		var pos := centre + Vector3(cos(angle), 0, sin(angle)) * radius
		var tangent := Vector3(sin(angle), 0, -cos(angle))
		_f.velocity = tangent * v
		_f.position = Vector3(pos.x, STAND, pos.z)
		_f.facing_yaw = atan2(-tangent.x, -tangent.z)
		await _tick()


func _jump() -> void:
	_caption.text = "Jump & land"
	_close = false
	_reset(Vector3.ZERO, PI)
	for i in 12:
		await _tick()
	_f.enter_state(FighterState.State.FALLING)
	_f.velocity = Vector3(0, 8.0, 1.2)
	while true:
		_f.velocity.y -= GRAVITY * DT
		_f.position += _f.velocity * DT
		if _f.position.y <= STAND:
			_f.position.y = STAND
			break
		await _tick()
	_f.velocity = Vector3.ZERO
	_f.enter_state(FighterState.State.IDLE)
	for i in 45:
		await _tick()


func _hover() -> void:
	_caption.text = "Hover"
	_f.enter_state(FighterState.State.FLYING)
	var base := _f.position
	for i in 120:
		var t := i * DT
		var rise := minf(t / 0.6, 1.0)
		var y := base.y + 1.3 * (1.0 - pow(1.0 - rise, 3.0)) + sin(t * 3.0) * 0.05
		_f.velocity = Vector3(0, (y - _f.position.y) / DT, 0)
		_f.position.y = y
		await _tick()


## Flies a wide banking loop at speed, the camera close behind and to the side.
func _flight(seconds: float) -> void:
	_caption.text = "Flight"
	_close = true
	if _f.state != FighterState.State.FLYING:
		_reset(Vector3.ZERO, PI)
		_f.enter_state(FighterState.State.FLYING)
		_f.position.y = STAND + 1.3
	# A loop in front of the back wall (the cyclorama bends up at z = -1).
	var centre := Vector3(0, 0, 2.2)
	var radius := 4.2
	var angle := atan2(_f.position.z - centre.z, _f.position.x - centre.x)
	_f.position = Vector3(centre.x + cos(angle) * radius, _f.position.y, centre.z + sin(angle) * radius)
	_cam_snap = true
	var y0 := _f.position.y
	for i in int(seconds * 60):
		var v := lerpf(3.0, 16.0, minf(i / 40.0, 1.0))
		angle -= v * DT / radius
		var pos := centre + Vector3(cos(angle), 0, sin(angle)) * radius
		var tangent := Vector3(sin(angle), 0, -cos(angle))
		var y := y0 + 0.6 * sin(i * DT * 1.7)
		_f.velocity = tangent * v + Vector3(0, (y - _f.position.y) / DT, 0)
		_f.position = Vector3(pos.x, y, pos.z)
		_f.facing_yaw = atan2(-tangent.x, -tangent.z)
		await _tick()
	# Drop back to the floor.
	_f.enter_state(FighterState.State.FALLING)
	_f.velocity = Vector3(_f.velocity.x * 0.2, 0, _f.velocity.z * 0.2)
	_close = false
	while _f.position.y > STAND:
		_f.velocity.y -= GRAVITY * DT
		_f.position += _f.velocity * DT
		await _tick()
	_f.position.y = STAND
	_f.velocity = Vector3.ZERO
	_f.enter_state(FighterState.State.IDLE)
	for i in 30:
		await _tick()


## Plays moves back to back, each cancelled into the next as it starts recovering.
func _moves(caption: String, ids: Array, close: bool) -> void:
	_caption.text = caption
	_close = close
	if _f.state == FighterState.State.FLYING or _f.position.distance_to(Vector3(0, STAND, 0)) > 0.5:
		_reset(Vector3.ZERO, PI)
	for k in ids.size():
		var move: MoveData = load(MOVES + ids[k] + ".tres")
		await _perform(move, k == ids.size() - 1)
	_f.enter_state(FighterState.State.IDLE)
	for i in 20:
		await _tick()


func _perform(move: MoveData, to_the_end: bool) -> void:
	_f.begin_move(move)
	var last := move.total_ticks() if to_the_end else move.recovery_start_tick() + 4
	var step := move.step_distance / maxf(move.startup_ticks + move.active_ticks, 1)
	var forward := Basis(Vector3.UP, _f.facing_yaw) * Vector3.FORWARD
	for t in last:
		_f.move_tick = t
		if t < move.startup_ticks + move.active_ticks:
			_f.position += forward * step
		await _tick()


func _dodge() -> void:
	_caption.text = "Dodge"
	_close = false
	_reset(Vector3.ZERO, PI)
	for i in 10:
		await _tick()
	var side := Basis(Vector3.UP, _f.facing_yaw) * Vector3.RIGHT
	_f.enter_state(FighterState.State.DASHING)
	_f.dash_kind = FighterState.DashKind.DODGE
	_f.dash_direction = side
	for i in 20:
		var v := 9.0 * (1.0 - i / 20.0)
		_f.velocity = side * v
		_f.position += _f.velocity * DT
		if i % 4 == 0:
			_afterimage()
		await _tick()
	_f.velocity = Vector3.ZERO
	_f.dash_kind = FighterState.DashKind.NONE
	_f.enter_state(FighterState.State.IDLE)
	for i in 25:
		await _tick()


func _guard() -> void:
	_caption.text = "Guard"
	_f.enter_state(FighterState.State.BLOCKING)
	_f.blocking = true
	for i in 70:
		await _tick()
	_f.blocking = false
	_f.enter_state(FighterState.State.IDLE)
	for i in 15:
		await _tick()


func _ki_move(id: StringName, startup: int, active: int, recovery: int) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.startup_ticks = startup
	move.active_ticks = active
	move.recovery_ticks = recovery
	return move


func _ki_blast() -> void:
	_caption.text = "Ki blast"
	_close = false
	_reset(_f.position, PI)
	var move := _ki_move(&"ki_blast", 12, 4, 22)
	_f.begin_move(move)
	var orb: MeshInstance3D = null
	var forward := Basis(Vector3.UP, _f.facing_yaw) * Vector3.FORWARD
	for t in move.total_ticks() + 30:
		_f.move_tick = mini(t, move.total_ticks() - 1)
		if t == move.startup_ticks:
			orb = _glow_orb(0.11)
			orb.global_position = _hands_point() + forward * 0.15
		if orb != null:
			orb.global_position += forward * 14.0 * DT
			orb.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 0.9))
		if t == move.total_ticks():
			_f.enter_state(FighterState.State.IDLE)
		await _tick()
	_clear_fx()


func _beam() -> void:
	_caption.text = "Beam charge"
	_close = true
	_f.enter_state(FighterState.State.CHARGING)
	var orb := _glow_orb(0.04)
	for t in 120:
		orb.global_position = _hands_point()
		orb.scale = Vector3.ONE * (1.0 + t / 120.0 * 2.2 + 0.2 * sin(t * 0.7))
		await _tick()
	_caption.text = "Beam"
	var move := _ki_move(&"beam", 8, 70, 20)
	_f.begin_move(move)
	var forward := Basis(Vector3.UP, _f.facing_yaw) * Vector3.FORWARD
	var beam: MeshInstance3D = null
	for t in move.total_ticks():
		_f.move_tick = t
		orb.global_position = _hands_point()
		if t == move.startup_ticks:
			beam = _beam_mesh()
		if beam != null:
			var on := t < move.recovery_start_tick()
			var length := minf((t - move.startup_ticks + 1) * 0.7, 9.0) if on else 0.0
			var start := _hands_point()
			beam.visible = on
			orb.visible = on
			beam.global_position = start + forward * length * 0.5
			beam.look_at(start + forward * length + Vector3(0.0001, 0, 0), Vector3.UP)
			beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			var w := 1.0 + 0.12 * sin(t * 1.3)
			beam.scale = Vector3(w, maxf(length, 0.001), w)
		await _tick()
	_clear_fx()
	_close = false
	_f.enter_state(FighterState.State.IDLE)
	for i in 15:
		await _tick()


func _hit_and_knockdown() -> void:
	_caption.text = "Hit react"
	_close = false
	_f.enter_state(FighterState.State.HITSTUN)
	_f.stun_ticks = 22
	for i in 22:
		await _tick()
	_f.enter_state(FighterState.State.HITSTUN)
	_f.stun_ticks = 26
	_f.knockback_type = MoveData.KnockbackType.values()[1]
	var back := Basis(Vector3.UP, _f.facing_yaw) * Vector3.BACK
	for i in 26:
		_f.position += back * 2.0 * DT
		await _tick()
	_caption.text = "Knockdown"
	_f.enter_state(FighterState.State.KNOCKDOWN)
	_f.stun_ticks = 150
	for i in 150:
		await _tick()
	_f.enter_state(FighterState.State.IDLE)


# ---------------------------------------------------------------- effects

func _glow_material(energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.93, 0.8)
	mat.emission_enabled = true
	mat.emission = KI_COLOR
	mat.emission_energy_multiplier = energy
	return mat


func _glow_orb(radius: float) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	orb.mesh = sphere
	orb.material_override = _glow_material(4.0)
	var halo := MeshInstance3D.new()
	var outer := SphereMesh.new()
	outer.radius = radius * 1.8
	outer.height = radius * 3.6
	halo.mesh = outer
	var mat := _glow_material(2.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(KI_COLOR, 0.35)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.material_override = mat
	orb.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = KI_COLOR
	light.light_energy = 1.6
	light.omni_range = 2.5
	orb.add_child(light)
	_stage.add_child(orb)
	_fx.append(orb)
	return orb


func _beam_mesh() -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.12
	cyl.height = 1.0
	beam.mesh = cyl
	beam.material_override = _glow_material(4.5)
	var shell := MeshInstance3D.new()
	var outer := CylinderMesh.new()
	outer.top_radius = 0.17
	outer.bottom_radius = 0.22
	outer.height = 1.0
	shell.mesh = outer
	var mat := _glow_material(1.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(KI_COLOR, 0.3)
	shell.material_override = mat
	beam.add_child(shell)
	_stage.add_child(beam)
	_fx.append(beam)
	return beam


## A fading translucent copy of the figure's current pose (dodge afterimage).
func _afterimage() -> void:
	var source := _view.model.find_children("*", "MeshInstance3D", true, false)
	var ghost := Node3D.new()
	_stage.add_child(ghost)
	for node in source:
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.skin == null:
			continue
		var baked := mi.bake_mesh_from_current_skeleton_pose()
		if baked == null:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = baked
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(0.45, 0.75, 1.0, 0.22)
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mi.global_transform
	ghost.set_meta(&"life", 18)
	_fx.append(ghost)


func _clear_fx() -> void:
	for node in _fx:
		node.queue_free()
	_fx.clear()


func _hands_point() -> Vector3:
	var skeleton := _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	var l := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(&"LeftHand")).origin
	var r := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(&"RightHand")).origin
	var forward := Basis(Vector3.UP, _f.facing_yaw) * Vector3.FORWARD
	return (l + r) * 0.5 + forward * 0.12


# ---------------------------------------------------------------- stepping

## One sim tick: pose the view, place the body, move the camera, save a frame.
func _tick(record := true) -> void:
	_f.state_ticks += 1
	if _f.stun_ticks > 0 and _f.state in [FighterState.State.HITSTUN, FighterState.State.KNOCKDOWN]:
		pass  # the scripted segments end the stun themselves
	_body.position = _f.position
	_body.rotation.y = _f.facing_yaw
	# The contact shadow follows him and fades out as he leaves the floor.
	var shadow := _stage.contact_shadow
	shadow.position = Vector3(_f.position.x, 0.002, _f.position.z + 0.02)
	shadow.visible = _f.position.y < STAND + 0.35
	_view.apply_state(_f, DT)
	_fade_ghosts()
	_camera()
	if record:
		await _save()
	else:
		await process_frame


func _fade_ghosts() -> void:
	for node in _fx.duplicate():
		if not node.has_meta(&"life"):
			continue
		var life: int = node.get_meta(&"life") - 1
		node.set_meta(&"life", life)
		for child in node.get_children():
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color.a = 0.22 * life / 18.0
		if life <= 0:
			_fx.erase(node)
			node.queue_free()


## A slow 3/4 orbit that follows him; close cuts frame tighter and lower.
func _camera() -> void:
	var target := Vector3(_f.position.x, _f.position.y - STAND + 0.95, _f.position.z)
	var height := 1.25 if _close else 2.1
	var fill := 0.6 if _close else 0.62
	if _f.state == FighterState.State.FLYING and _close:
		height = 1.7
	if _cam_snap:
		_cam_target = target
		_cam_height = height
		_cam_snap = false
	_cam_target = _cam_target.lerp(target, 0.12)
	_cam_height = lerpf(_cam_height, height, 0.06)
	_cam_fill = fill
	_cam_yaw += 6.0 * DT
	# Keep the orbit on his front three-quarter side: blend toward 35 degrees off his facing.
	var front := rad_to_deg(_f.facing_yaw - PI)
	var desired := front + 35.0 + 12.0 * sin(_frame * DT * 0.35)
	_cam_yaw = rad_to_deg(lerp_angle(deg_to_rad(_cam_yaw), deg_to_rad(desired), 0.03))
	# Never swing round behind the cyclorama's back wall: stay on the open +Z side.
	_cam_yaw = clampf(wrapf(_cam_yaw, -180.0, 180.0), -65.0, 65.0)
	_stage.frame(_cam_target, _cam_height, _cam_fill, _cam_pitch, _cam_yaw)


func _save() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_jpg(_out.path_join("f_%05d.jpg" % _frame), 0.93)
	_frame += 1
