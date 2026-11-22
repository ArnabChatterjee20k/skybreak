extends SceneTree
## Contact sheets of Pure Fight poses per legend (stance, locomotion, moves, wins) on the
## look-dev stage, each cell labelled. Needs a renderer (lavapipe is fine):
##   godot --path . --disable-vsync -s res://game/debug/pure_fight/pose_sheet.gd -- <out dir> [legend ...] [--set strip|all] [--cell WxH]

const COLUMNS := 6

var _viewport: SubViewport
var _stage: LookdevStage
var _pivot: Node3D
var _label: Label
var _cell := Vector2i(480, 540)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cell_at := args.find("--cell")
	if cell_at >= 0:
		var parts := args[cell_at + 1].split("x")
		_cell = Vector2i(int(parts[0]), int(parts[1]))
	_viewport = SubViewport.new()
	_viewport.size = _cell
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	_viewport.add_child(_stage)
	var layer := CanvasLayer.new()
	_viewport.add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", maxi(_cell.y / 22, 14))
	_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	layer.add_child(_label)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 and not args[0].begins_with("--") else "user://pose_sheet"
	DirAccess.make_dir_recursive_absolute(out)
	var set_at := args.find("--set")
	var which := args[set_at + 1] if set_at >= 0 else "all"
	var legends: Array[StringName] = []
	for arg in args.slice(1):
		if StringName(arg) in PureMoves.LEGENDS:
			legends.append(StringName(arg))
	if legends.is_empty():
		legends = PureMoves.LEGENDS.duplicate()
	for legend in legends:
		await _sheet(out, legend, which)
	quit()


func _sheet(out: String, legend: StringName, which: String) -> void:
	_pivot = Node3D.new()
	_stage.add_child(_pivot)
	var view := (Roster.character(legend).voxel_scene as PackedScene).instantiate() as CharacterView
	var body := Node3D.new()
	body.position = Vector3(0, 0.99, 0)
	_pivot.add_child(body)
	body.add_child(view)
	await process_frame
	for node in view.find_children("*", "SkeletonModifier3D", true, false):
		if node is MotionLayers:
			(node as SkeletonModifier3D).active = false
	# Unarmed, as in the game (PureFightFighterView hides the same nodes).
	for node in view.find_children("*", "BoneAttachment3D", true, false):
		(node as Node3D).visible = false
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var rig := FightRig.new()
	rig.setup(skeleton)
	var style := FightStyle.for_legend(legend)
	var cells := PureFightPoses.sheet(style, which)
	var columns := cells.size() if which == "strip" else COLUMNS
	var rows := ceili(float(cells.size()) / columns)
	var sheet := Image.create(_cell.x * mini(cells.size(), columns), _cell.y * rows, false, Image.FORMAT_RGB8)
	for i in cells.size():
		var entry: Array = cells[i]
		_label.text = "%s  %s" % [String(legend).to_upper(), entry[0]]
		rig.apply(entry[1])
		_pivot.rotation.y = deg_to_rad(float(entry[2]))
		_stage.frame(Vector3(0, 1.0, 0.3), 2.6, 0.84, -4.0)
		for f in 3:
			rig.apply(entry[1])
			await process_frame
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, _cell), Vector2i((i % columns) * _cell.x, (i / columns) * _cell.y))
	var path := out.path_join("%s_%s.png" % [legend, which])
	sheet.save_png(path)
	print("[pose_sheet] %s (%d cells)" % [path, cells.size()])
	_pivot.queue_free()
