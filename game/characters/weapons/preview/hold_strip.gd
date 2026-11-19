extends SceneTree
## Renders each legend in four held-weapon moments (T-D30e) on one strip, for review by eye:
## mid-swing (Storm Blade), hitstun (Storm Blade), flying (Storm Blade) and a bow draw (Ki Bow).
##
## xvfb-run godot --path . --rendering-driver opengl3 -s res://game/characters/weapons/preview/hold_strip.gd -- <out.png>

const CELL := Vector2i(300, 360)
const SETTLE_FRAMES := 14
const MOMENTS: Array[StringName] = [&"swing", &"hitstun", &"flying", &"bow_draw"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://hold_strip.png")
	var legends := Roster.ids()
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.5, 0.62, 0.78)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 38
	stage.add_child(camera)
	root.size = CELL
	var sheet: Image
	for row in legends.size():
		var roster := Roster.character(legends[row])
		var stats: FighterStats = roster.stats if roster.stats != null else CombatSim.DEFAULT_FIGHTER_STATS
		for column in MOMENTS.size():
			var moment := MOMENTS[column]
			var kind := Weapon.Kind.KI_BOW if moment == &"bow_draw" else Weapon.Kind.STORM_BLADE
			var view: CharacterView = roster.scene.instantiate()
			stage.add_child(view)
			await process_frame
			var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
			var held := WeaponLayer.attach(skeleton, kind)
			var fighter := FighterState.new()
			fighter.stats = stats
			fighter.weapons[0] = kind
			fighter.active_slot = 0
			fighter.position.y = fighter.stand_height
			var top := 1.0
			if view.body != null and view.body.bones.has(&"head"):
				top = skeleton.get_bone_global_rest(view.body.bones[&"head"][0]).origin.y - 1.0
			camera.position = Vector3(-2.3, 0.35 + top * 0.3, -3.9) * (0.9 + top * 0.15)
			camera.look_at(Vector3(0, top * 0.25, 0))
			var move := WeaponMoves.move_set(kind, stats.move_set).light_string[0]
			for f in SETTLE_FRAMES:
				match moment:
					&"swing", &"bow_draw":
						if f == 0:
							fighter.begin_move(move)
						# Swing: the active frames; bow: held at full draw.
						fighter.move_tick = mini(f, move.startup_ticks + (1 if moment == &"swing" else 0))
					&"hitstun":
						fighter.state = FighterState.State.HITSTUN
						fighter.state_ticks = f
					&"flying":
						fighter.state = FighterState.State.FLYING
						fighter.position.y = fighter.stand_height + 3.0
						fighter.velocity = Vector3(0, 0, 14)
				for node in held:
					var string := node.find_child("BowString", true, false) as BowString
					if string != null:
						string.drawn = moment == &"bow_draw"
				view.apply_state(fighter, 1.0 / 60.0)
				await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if sheet == null:
				sheet = Image.create(CELL.x * MOMENTS.size(), CELL.y * legends.size(), false, image.get_format())
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(column, row) * CELL)
			view.queue_free()
			await process_frame
	sheet.save_png(out)
	print("Hold strip written to ", out)
	quit()
