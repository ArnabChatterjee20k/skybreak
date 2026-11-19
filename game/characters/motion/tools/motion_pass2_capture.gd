extends SceneTree
## Motion pass 2 review renders (T-D22c), all four legends. Two copies of a legend stand side by
## side: LEFT (on screen) plays its posed ClipSet clips (motion off), RIGHT plays mocap with its
## MotionProfile and MotionLayers live. Both are driven through apply_state by the same scripted
## FighterState timeline at a fixed 60 fps. Flight rows use a chase camera behind and above, like
## the arena camera. Writes <legend>_sheet.png (one row of COLUMNS moments per scenario) and
## lineup.png (the four legends, new motion, side by side at a few moments).
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 \
##     -s res://game/characters/motion/tools/motion_pass2_capture.gd -- <out dir> [kael|vexa|lyra|brann|lineup]

const CHARACTERS := {
	"kael": ["res://game/characters/kael_chunky/kael_chunky.tscn", "res://game/combat/moves/kael/kael_move_set.tres"],
	"vexa": ["res://game/characters/vexa/vexa.tscn", "res://game/combat/moves/vexa/vexa_move_set.tres"],
	"lyra": ["res://game/characters/lyra/lyra.tscn", "res://game/combat/moves/lyra/lyra_move_set.tres"],
	"brann": ["res://game/characters/brann/brann.tscn", "res://game/combat/moves/brann/brann_move_set.tres"],
}
const SCENARIOS := ["idle", "run", "light_string", "launcher", "heavy_hit", "flight_bank", "dive", "ko_fall"]
## Scenarios framed by the chase camera.
const CHASE := ["flight_bank", "dive"]
## Lineup: [scenario, tick] moments, one row each.
const LINEUP := [["idle", 40], ["run", 70], ["light_string", -1], ["launcher", -1], ["dive", 80], ["ko_fall", 85]]
const CELL := Vector2i(300, 250)
const COLUMNS := 8
const SPACING := 0.85

var _out := ""
var _views: Array[CharacterView] = []
var _moves: MoveSet
var _weapon_nodes: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://motion_integration"
	DirAccess.make_dir_recursive_absolute(_out)
	var names: Array = args.slice(1) if args.size() > 1 else CHARACTERS.keys() + ["lineup"]
	_run.call_deferred(names)


func _run(names: Array) -> void:
	for character: String in names:
		if character == "lineup":
			await _capture_lineup()
		else:
			await _capture_character(character)
	quit(0)


## The four legends (new motion) side by side, one row per LINEUP moment.
func _capture_lineup() -> void:
	var stage := _stage()
	root.add_child(stage)
	var camera := stage.get_node("Camera") as Camera3D
	camera.look_at_from_position(Vector3(0.0, 1.6, -8.4), Vector3(0, 0.95, 0))
	_views.clear()
	var keys := CHARACTERS.keys()
	for i in keys.size():
		var view := (load(CHARACTERS[keys[i]][0]) as PackedScene).instantiate() as CharacterView
		view.position = Vector3(2.4 - i * 1.6, 1.0, 0)
		stage.add_child(view)
		_views.append(view)
	await _frames(3)
	var cell := Vector2i(1200, 420)
	var sheet := Image.create(cell.x, cell.y * LINEUP.size(), false, Image.FORMAT_RGB8)
	for row in LINEUP.size():
		var scenario: String = LINEUP[row][0]
		var timelines: Array = []
		var longest := 0
		for i in keys.size():
			_moves = load(CHARACTERS[keys[i]][1]) as MoveSet
			var timeline := _timeline(scenario)
			timelines.append(timeline)
			longest = maxi(longest, timeline.size())
			if _views[i].layers:
				_views[i].layers.reset()
		var shot: int = LINEUP[row][1]
		if shot < 0:
			# Strikes: each legend at its own first active tick.
			shot = 0
		for tick in longest:
			for i in keys.size():
				var timeline: Array = timelines[i]
				var index := mini(tick, timeline.size() - 1)
				if LINEUP[row][1] < 0:
					var first: FighterState = timeline[0]
					index = mini(tick, first.move.startup_ticks + 1) if first.move else index
				_views[i].apply_state(timeline[index], 1.0 / 60.0)
			await process_frame
			var take := tick == (shot if LINEUP[row][1] >= 0 else 40) or (tick == longest - 1 and shot >= longest)
			if take:
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				image.convert(Image.FORMAT_RGB8)
				var size := image.get_size()
				var crop := image.get_region(Rect2i(0, size.y * 3 / 10, size.x, size.x * 7 / 20))
				crop.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, cell), Vector2i(0, cell.y * row))
				break
		print("lineup %s" % scenario)
	sheet.save_png(_out.path_join("lineup.png"))
	stage.queue_free()
	await _frames(2)


func _capture_character(character: String) -> void:
	var stage := _stage()
	root.add_child(stage)
	_moves = load(CHARACTERS[character][1]) as MoveSet
	_views.clear()
	for side in 2:
		var view := (load(CHARACTERS[character][0]) as PackedScene).instantiate() as CharacterView
		if side == 0:
			view.clips = view.clips.duplicate()
			view.clips.motion = null
		view.position = Vector3(SPACING * (1 - side * 2), 1.0, 0)
		stage.add_child(view)
		_views.append(view)
	await _frames(3)
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * SCENARIOS.size(), false, Image.FORMAT_RGB8)
	for row in SCENARIOS.size():
		var scenario: String = SCENARIOS[row]
		var timeline := _timeline(scenario)
		var strip := Image.create(CELL.x * COLUMNS, CELL.y, false, Image.FORMAT_RGB8)
		var camera := stage.get_node("Camera") as Camera3D
		if scenario in CHASE:
			# Behind and above the fighters (they face -Z), at the arena camera's distance.
			camera.look_at_from_position(Vector3(4.2, 2.6, 3.4), Vector3(0, 0.9, 0))
		else:
			camera.look_at_from_position(Vector3(1.4, 1.5, -5.6), Vector3(0, 0.95, 0))
		var shots := {}
		for c in COLUMNS:
			shots[int(round(float(c) / (COLUMNS - 1) * (timeline.size() - 1)))] = c
		_set_weapon(timeline[0])
		for view in _views:
			if view.layers:
				view.layers.reset()
		for tick in timeline.size():
			var fighter: FighterState = timeline[tick]
			if tick == 0 and scenario == "heavy_hit":
				for view in _views:
					view.react_to_event({"type": CombatSim.EventType.HIT, "position": Vector3(0, 1, -0.8),
						"knockback_type": MoveData.KnockbackType.BLOWBACK}, fighter)
			for view in _views:
				view.apply_state(fighter, 1.0 / 60.0)
			await process_frame
			if shots.has(tick):
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				image.convert(Image.FORMAT_RGB8)
				var size := image.get_size()
				var crop := image.get_region(Rect2i(size.x / 2 - size.y * 6 / 10, 0, size.y * 12 / 10, size.y))
				crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
				strip.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * shots[tick], 0))
		strip.save_png(_out.path_join("%s_%s.png" % [character, scenario]))
		sheet.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), Vector2i(0, CELL.y * row))
		print("%s %s: %d ticks" % [character, scenario, timeline.size()])
	sheet.save_png(_out.path_join("%s_sheet.png" % character))
	_clear_weapons()
	stage.queue_free()
	await _frames(2)


## One FighterState per tick for a scenario.
func _timeline(scenario: String) -> Array[FighterState]:
	var out: Array[FighterState] = []
	var ground := MovementTuning.new().ground_height
	match scenario:
		"idle":
			for t in 90:
				out.append(_state(FighterState.State.IDLE, t, Vector3.ZERO, ground))
		"run":
			for t in 20:
				out.append(_state(FighterState.State.IDLE, t, Vector3.ZERO, ground))
			for t in 60:
				out.append(_state(FighterState.State.MOVING, t, Vector3(0, 0, -minf(t * 0.6, 10.0)), ground))
		"light_string":
			for move: MoveData in _moves.light_string.slice(0, 4):
				out.append_array(_attack(move, ground))
		"launcher":
			out.append_array(_attack(_moves.launcher, ground))
		"sweep":
			out.append_array(_attack(_moves.sweep, ground))
		"heavy_hit":
			for t in 36:
				var f := _state(FighterState.State.HITSTUN, t, Vector3(0, 0, 3.0 * maxf(1.0 - t / 20.0, 0.0)), ground)
				f.stun_ticks = 36 - t
				f.knockback_type = MoveData.KnockbackType.BLOWBACK
				f.hitstop_ticks = 4 - t if t < 4 else 0
				out.append(f)
			for t in 24:
				out.append(_state(FighterState.State.IDLE, t, Vector3.ZERO, ground))
		"flight_bank":
			for t in 100:
				var turn := sin(t / 100.0 * TAU)
				out.append(_state(FighterState.State.FLYING, t, Vector3(turn * 14.0, 0, -18.0), 6.0))
		"dive":
			for t in 20:
				out.append(_state(FighterState.State.FLYING, t, Vector3(0, 0, -t * 0.6), 8.0))
			for t in 10:
				out.append(_state(FighterState.State.DASHING, t, Vector3(0, 0, -30.0), 8.0))
			for t in 30:
				out.append(_state(FighterState.State.FLYING, t, Vector3(0, 0, -22.0), 8.0))
			for t in 60:
				out.append(_state(FighterState.State.FLYING, t, Vector3(0, -minf(t * 0.8, 24.0), -14.0), 8.0))
		"weapon_swing":
			out.append_array(_weapon_attack(Weapon.Kind.TITAN_HAMMER, &"hammer/smash", _moves.smash, ground))
		"bow_draw":
			out.append_array(_weapon_attack(Weapon.Kind.KI_BOW, &"bow/shot", _moves.light_string[0], ground, 30))
		"ko_fall":
			for t in 100:
				var f := _state(FighterState.State.KNOCKDOWN, t, Vector3.ZERO, ground)
				f.stun_ticks = 100 - t
				out.append(f)
			for t in 20:
				out.append(_state(FighterState.State.IDLE, t, Vector3.ZERO, ground))
	return out


func _state(state: FighterState.State, ticks: int, velocity: Vector3, height: float) -> FighterState:
	var f := FighterState.new()
	f.state = state
	f.state_ticks = ticks
	f.velocity = velocity
	f.position = Vector3(0, height, 0)
	return f


func _attack(move: MoveData, ground: float) -> Array[FighterState]:
	var out: Array[FighterState] = []
	for tick in move.total_ticks():
		var f := _state(FighterState.State.ATTACKING, tick, Vector3.ZERO, ground)
		f.move = move
		f.move_tick = tick
		out.append(f)
	return out


func _weapon_attack(kind: Weapon.Kind, id: StringName, base: MoveData, ground: float, hold := 10) -> Array[FighterState]:
	var move := base.duplicate() as MoveData
	move.id = id
	move.recovery_ticks += hold
	var out: Array[FighterState] = []
	for t in 15:
		out.append(_state(FighterState.State.IDLE, t, Vector3.ZERO, ground))
	out.append_array(_attack(move, ground))
	for f in out:
		f.weapons[0] = kind
		f.active_slot = 0
	return out


func _set_weapon(fighter: FighterState) -> void:
	_clear_weapons()
	if fighter.held_weapon() == Weapon.Kind.NONE:
		return
	for view in _views:
		var skeleton := view.model.get_node("%GeneralSkeleton") as Skeleton3D
		_weapon_nodes.append_array(WeaponLayer.attach(skeleton, fighter.held_weapon()))


func _clear_weapons() -> void:
	for node: Node in _weapon_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_weapon_nodes.clear()


func _stage() -> Node3D:
	var stage := Node3D.new()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55, 0.62, 0.7)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 150, 0)
	stage.add_child(light)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor.mesh = plane
	var checker := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for x in 8:
		for y in 8:
			checker.set_pixel(x, y, Color(0.42, 0.45, 0.42) if (x + y) % 2 == 0 else Color(0.5, 0.53, 0.5))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(checker)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(4, 4, 4)
	floor.material_override = material
	stage.add_child(floor)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = 40.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(1.4, 1.5, -5.6), Vector3(0, 0.95, 0))
	camera.current = true
	return stage


func _frames(count: int) -> void:
	for i in count:
		await process_frame
