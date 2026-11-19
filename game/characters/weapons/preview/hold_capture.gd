extends SceneTree
## Renders every legend holding every weapon (T-D30): one row per legend at idle, then one
## mid-attack (bows at full draw), on one contact sheet, for review by eye.
##
## xvfb-run godot --path . --rendering-driver opengl3 -s res://game/characters/weapons/preview/hold_capture.gd -- <out.png> [bow]
## With "bow": a close-up of each legend at full draw, from the front and from the string side.

const CELL := Vector2i(300, 360)
const SETTLE_FRAMES := 12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://weapon_holds.png")
	var bow_close_up := args.size() > 1 and args[1] == "bow"
	var kinds: Array = [Weapon.Kind.KI_BOW] if bow_close_up else Weapon.Kind.values().slice(1)
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
		var unarmed: MoveSet = roster.stats.move_set if roster.stats != null else (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
		for column in kinds.size():
			var kind: Weapon.Kind = kinds[column]
			for pose in 2:
				var view: CharacterView = roster.scene.instantiate()
				stage.add_child(view)
				await process_frame
				var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
				var held := WeaponLayer.attach(skeleton, kind)
				var fighter := FighterState.new()
				fighter.stats = roster.stats if roster.stats != null else CombatSim.DEFAULT_FIGHTER_STATS
				fighter.weapons[0] = kind
				fighter.active_slot = 0
				var top := 1.0
				if view.body != null and view.body.bones.has(&"head"):
					top = skeleton.get_bone_global_rest(view.body.bones[&"head"][0]).origin.y - 1.0
				camera.position = Vector3(-2.3, 0.35 + top * 0.3, -3.9) * (0.9 + top * 0.15)
				camera.look_at(Vector3(0, top * 0.25, 0))
				if bow_close_up:
					# Pose 0 from the front, pose 1 from the string side; both at full draw.
					var face := Vector3(0, top + 0.3, 0)
					camera.position = face + (Vector3(-0.35, 0.15, -1.4) if pose == 0 else Vector3(1.4, 0.2, 0.25))
					camera.look_at(face + Vector3(0, -0.05, -0.15))
				var drawn := pose == 1 or bow_close_up
				if drawn:
					var move := WeaponMoves.move_set(kind, unarmed).light_string[0]
					fighter.begin_move(move)
				for f in SETTLE_FRAMES:
					if drawn:
						fighter.move_tick = mini(f, fighter.move.startup_ticks)
					for node in held:
						var string := node.find_child("BowString", true, false) as BowString
						if string != null:
							string.drawn = drawn
					view.apply_state(fighter, 1.0 / 60.0)
					await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				if sheet == null:
					sheet = Image.create(CELL.x * kinds.size(), CELL.y * legends.size() * 2, false, image.get_format())
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(column, row * 2 + pose) * CELL)
				view.queue_free()
				await process_frame
	sheet.save_png(out)
	print("Weapon holds written to ", out)
	quit()
