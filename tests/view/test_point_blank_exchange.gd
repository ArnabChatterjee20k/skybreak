extends GutTest
## T-D29: a point-blank exchange in the real sim (bodies touching, strafing,
## trading lights and blocks) seen through the real FighterCamera. Neither
## fighter may fill the screen, and the player may not hide the opponent.

const DT := 1.0 / 60.0
const SETTLE_FRAMES := 60
const SCREEN := Vector2(1920, 1080)
## Most of the screen one fighter's box may cover.
const MAX_SCREEN_COVER := 0.2
## Most of the opponent's box the player's box may hide.
const MAX_OPPONENT_HIDDEN := 0.5
const LIGHT := FighterInput.Action.LIGHT
const BLOCK := FighterInput.Action.BLOCK


## Plays the exchange; returns the worst [cover, hidden, min distance] after
## settling, and in hidden_frames the share of frames with the opponent over
## half hidden. both_strafe: the opponent circles too (else it only presses in).
func _exchange(seed_value: int, both_strafe: bool, hidden_frames: Array = []) -> Vector3:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -3))
	sim.lock_everyone_onto_nearest()
	var camera := FighterCamera.new()
	add_child_autofree(camera)
	var bot := RandomNumberGenerator.new()
	bot.seed = seed_value
	var previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	var plans: Array = [[0, Vector2(0, 1)], [0, Vector2(0, 1)]]
	var worst := Vector3(0.0, 0.0, INF)
	var over_half := 0
	for frame in 600:
		if frame % 20 == 0 and frame >= 60:
			for i in 2:
				# Keep pressing in; strafe, jab or guard at random.
				var held: int = [0, LIGHT, BLOCK, 0][bot.randi_range(0, 3)]
				var strafe := bot.randf_range(-1, 1)
				plans[i] = [held, Vector2(strafe if i == 0 or both_strafe else 0.0, 1.0)]
		var inputs: Array[FighterInput] = []
		for i in 2:
			var input := FighterInput.from_held(plans[i][0], previous[i])
			input.move = plans[i][1]
			input.view_yaw = camera.view_yaw()
			inputs.append(input)
		sim.tick(inputs)
		previous = inputs
		var player := sim.fighters[0].position
		var opponent := sim.fighters[1].position
		camera.follow(player, opponent, true, DT)
		if frame < SETTLE_FRAMES:
			continue
		var view := camera.global_transform
		for point in [player, opponent]:
			worst.x = maxf(worst.x, _screen_cover(view, camera.fov, point))
		var hidden := FlightPlaytest.opponent_hidden_fraction(view, camera.fov, SCREEN, player, opponent)
		if OS.has_environment("PB_DEBUG") and frame % 10 == 0:
			var line := (opponent - player).normalized()
			print("f%d hidden %.2f angle %.0f states %d/%d d %.2f shoulder %.2f" % [frame, hidden,
				rad_to_deg((-view.basis.z).signed_angle_to(Vector3(line.x, 0, line.z), Vector3.UP)),
				sim.fighters[0].state, sim.fighters[1].state, player.distance_to(opponent), camera.shoulder_side()])
		worst.y = maxf(worst.y, hidden)
		worst.z = minf(worst.z, player.distance_to(opponent))
		if hidden > MAX_OPPONENT_HIDDEN:
			over_half += 1
	hidden_frames.append(float(over_half) / (600 - SETTLE_FRAMES))
	return worst


## Fraction of the screen a standing fighter's box covers.
func _screen_cover(view: Transform3D, fov: float, centre: Vector3) -> float:
	var local := view.affine_inverse() * centre
	if local.z >= -0.1:
		return 1.0
	var pixels_per_metre := SCREEN.y * 0.5 / (-local.z * tan(deg_to_rad(fov) / 2.0))
	var half := Vector2(LockOnFraming.FIGHTER_RADIUS, LockOnFraming.FIGHTER_HEIGHT * 0.5) * pixels_per_metre
	var at := Vector2(local.x, -local.y) * pixels_per_metre + SCREEN * 0.5
	var box := Rect2(at - half, half * 2.0).intersection(Rect2(Vector2.ZERO, SCREEN))
	return box.get_area() / (SCREEN.x * SCREEN.y)


func test_a_point_blank_exchange_keeps_both_fighters_clear() -> void:
	for seed_value in [1, 2, 3]:
		var worst := _exchange(seed_value, false)
		gut.p("seed %d: cover %.3f, hidden %.3f, closest %.2f m" % [seed_value, worst.x, worst.y, worst.z])
		# Two default bodies touch at twice the pushbox radius.
		var touching := (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).pushbox_radius * 2.0
		assert_lt(worst.z, touching + 0.06, "seed %d: the bodies met" % seed_value)
		assert_gte(worst.z, touching - 0.01, "seed %d: never closer than touching" % seed_value)
		assert_lte(worst.x, MAX_SCREEN_COVER, "seed %d: a fighter covered %.0f%% of the screen" % [seed_value, worst.x * 100])
		assert_lte(worst.y, MAX_OPPONENT_HIDDEN, "seed %d: the player hid %.0f%% of the opponent" % [seed_value, worst.y * 100])


func test_both_circling_point_blank_rarely_hides_the_opponent() -> void:
	# Circling opposite ways the pair turns up to twice the camera turn cap, so
	# brief occlusion is allowed; it must stay rare.
	for seed_value in [1, 2, 3]:
		var share := []
		var worst := _exchange(seed_value, true, share)
		gut.p("seed %d: cover %.3f, over half hidden in %.1f%% of frames" % [seed_value, worst.x, share[0] * 100])
		assert_lte(worst.x, MAX_SCREEN_COVER)
		assert_lte(share[0], 0.1, "seed %d" % seed_value)


func test_a_fighter_against_the_camera_fades_and_one_at_fight_distance_does_not() -> void:
	var stats := CombatSim.DEFAULT_FIGHTER_STATS as FighterStats
	var body := Vector3(0, 1, 0)
	assert_eq(FighterView.camera_fade_for(Vector3(0, 2, 4.5), body, stats), 0.0, "boom length away")
	assert_almost_eq(FighterView.camera_fade_for(Vector3(0, 1.5, 0.5), body, stats), FighterView.FADED, 0.001,
		"camera inside the body")
	var half := FighterView.camera_fade_for(Vector3(0, 1, 1.15), body, stats)
	assert_between(half, 0.05, FighterView.FADED - 0.05, "fading in between")


func test_fade_for_camera_sets_the_body_transparency() -> void:
	var view := FighterView.new()
	view.fighter = FighterState.new()
	view.fighter.stats = CombatSim.DEFAULT_FIGHTER_STATS as FighterStats
	add_child_autofree(view)
	view.position = Vector3(0, 1, 0)
	view.fade_for_camera(Vector3(0, 1, 0.4))
	# The body (placeholder capsule and visor) fades; the height marker does not.
	var faded := view.find_children("*", "MeshInstance3D", true, false).filter(
		func(mesh: Node) -> bool: return is_equal_approx((mesh as GeometryInstance3D).transparency, view.camera_fade()))
	assert_eq(faded.size(), 2)
	assert_gt(view.camera_fade(), 0.5)
	view.fade_for_camera(Vector3(0, 2, 6))
	assert_eq(view.camera_fade(), 0.0)
