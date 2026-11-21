extends SceneTree
## Stills of voxel Brann holding each weapon in guard and mid-swing (QA-20 review), at
## 1920x1080 on the look-dev stage. Needs a renderer (lavapipe is fine):
##   godot --path . --disable-vsync -s res://tools/diag/brann_grip_stills.gd -- <out dir> [KIND ...]

const SCENE := "res://game/characters/brann_voxel/brann_voxel.tscn"

var _viewport: SubViewport
var _stage: LookdevStage
var _pivot: Node3D
var _view: CharacterView
var _held: Array[Node] = []


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	_viewport.add_child(_stage)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://brann_grip"
	DirAccess.make_dir_recursive_absolute(out)
	var kinds: Array = Weapon.Kind.values().slice(1)
	if args.size() > 1:
		kinds = []
		for k in args.slice(1):
			kinds.append(Weapon.Kind[k])
	_pivot = Node3D.new()
	_stage.add_child(_pivot)
	var facing := Node3D.new()
	facing.rotation.y = PI
	_pivot.add_child(facing)
	_view = (load(SCENE) as PackedScene).instantiate() as CharacterView
	var body := Node3D.new()
	body.position = Vector3(0, 1, 0)
	facing.add_child(body)
	body.add_child(_view)
	var skeleton: Skeleton3D = _view.model.get_node("%GeneralSkeleton")
	var stats: FighterStats = Roster.character(&"brann").stats
	for kind: int in kinds:
		for node in _held:
			node.queue_free()
		_held = WeaponLayer.attach(skeleton, kind)
		var fighter := FighterState.new()
		fighter.stats = stats
		fighter.weapons[0] = kind
		fighter.ammo[0] = Weapon.full_ammo(kind)
		fighter.active_slot = 0
		var name := String(Weapon.Kind.find_key(kind)).to_lower()
		fighter.enter_state(FighterState.State.BLOCKING)
		for f in 40:
			fighter.state_ticks = f
			_view.apply_state(fighter, 1.0 / 60.0)
			await process_frame
		await _shot(out, "%s_guard" % name, 35.0)
		fighter.enter_state(FighterState.State.IDLE)
		for f in 8:
			_view.apply_state(fighter, 1.0 / 60.0)
			await process_frame
		var move: MoveData = WeaponMoves.move_set(kind, stats.move_set).light_string[0]
		fighter.begin_move(move)
		# Mid-swing: the first active tick.
		for t in move.startup_ticks + 1:
			fighter.move_tick = t
			fighter.state_ticks = t
			_view.apply_state(fighter, 1.0 / 60.0)
			await process_frame
		await _shot(out, "%s_swing" % name, 60.0)
		print("%s: %s at tick %d" % [name, move.id, move.startup_ticks])
	quit()


func _shot(out: String, name: String, yaw: float) -> void:
	_pivot.rotation.y = deg_to_rad(yaw)
	_stage.frame(Vector3(0, 1.0, 0), 2.4, 0.82, -6.0)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(out.path_join(name + ".png"))
