extends GutTest
## T-117b: locked camera with the fighters 0-2 m apart (overlapping, stacked
## in a juggle, passing through each other). Drives the real FighterCamera
## along scripted paths; media-1.5 showed it cutting a fighter off at the
## screen edge or framing mostly ground here.

const DT := 1.0 / 60.0
const SETTLE_FRAMES := 30
const SCREEN := Vector2(1920, 1080)
## Both fighters' centres must stay inside this fraction of the screen.
const INNER := 0.85
## The midpoint must not sit lower than this NDC height ("mostly ground").
const MAX_MIDPOINT_DROP := 0.6


## path: func(frame) -> [player, target]. Returns per-frame records.
func _fly(path: Callable, frames: int) -> Array[Dictionary]:
	var camera := FighterCamera.new()
	add_child_autofree(camera)
	var records: Array[Dictionary] = []
	var previous := Basis()
	for frame in frames:
		var points: Array = path.call(frame)
		camera.follow(points[0], points[1], true, DT)
		var view := camera.global_transform
		records.append({
			"frame": frame, "view": view, "fov": camera.fov,
			"player": points[0], "target": points[1],
			"turn": rad_to_deg(previous.get_rotation_quaternion().angle_to(view.basis.get_rotation_quaternion())) if frame > 0 else 0.0,
		})
		previous = view.basis
	return records


func _ndc(view: Transform3D, fov: float, point: Vector3) -> Vector2:
	var local := view.affine_inverse() * point
	if local.z >= -0.01:
		return Vector2(INF, INF)
	var tan_v := tan(deg_to_rad(fov) / 2.0)
	return Vector2(local.x / -local.z / (tan_v * SCREEN.x / SCREEN.y), local.y / -local.z / tan_v)


func _check(name: String, records: Array[Dictionary]) -> void:
	var worst_edge := 0.0
	var worst_drop := 0.0
	var worst_turn := 0.0
	var worst_pitch := 0.0
	for r in records.slice(SETTLE_FRAMES):
		for point in [r.player, r.target]:
			var ndc := _ndc(r.view, r.fov, point)
			worst_edge = maxf(worst_edge, maxf(absf(ndc.x), absf(ndc.y)))
		var mid := _ndc(r.view, r.fov, r.player.lerp(r.target, 0.5))
		worst_drop = maxf(worst_drop, -mid.y)
		worst_turn = maxf(worst_turn, r.turn)
		worst_pitch = maxf(worst_pitch, absf(rad_to_deg(asin(clampf(-r.view.basis.z.y, -1, 1)))))
	assert_lte(worst_edge, INNER, "%s: a fighter reached %.2f of the half-screen" % [name, worst_edge])
	assert_lte(worst_drop, MAX_MIDPOINT_DROP, "%s: the pair sank to %.2f (mostly ground)" % [name, worst_drop])
	assert_lte(worst_turn, 3.1, "%s: view turned %.1f° in a frame" % [name, worst_turn])
	assert_lte(worst_pitch, 35.5, "%s: pitch %.1f°" % [name, worst_pitch])


func test_overlapping_fighters_circling_at_half_a_metre() -> void:
	var path := func(frame: int) -> Array:
		var player := Vector3(0, 12, 0)
		var angle := frame * 0.05
		return [player, player + Vector3(sin(angle), 0, -cos(angle)) * 0.6]
	_check("overlap orbit", _fly(path, 240))


func test_juggle_with_the_target_stacked_just_above() -> void:
	var path := func(frame: int) -> Array:
		var player := Vector3(0, 12, 0)
		# Launched: rises from level to 1.8 m above, drifting a little sideways.
		var rise := minf(frame / 40.0, 1.0) * 1.8
		return [player, player + Vector3(0.3 * sin(frame * 0.07), rise, -0.4 + 0.2 * cos(frame * 0.05))]
	_check("stacked juggle", _fly(path, 240))


func test_opponent_passing_straight_through_the_player() -> void:
	var path := func(frame: int) -> Array:
		var player := Vector3(0, 12, 0)
		return [player, player + Vector3(0.2, 0.3, -3.0 + frame * 0.05)]
	_check("pass-through", _fly(path, 150))


func test_opponent_stacked_a_few_metres_below() -> void:
	# The media-1.5 / bot-fight case: diving onto an opponent 2.5-6 m below
	# with almost no horizontal gap; it fell off the bottom of the screen.
	var path := func(frame: int) -> Array:
		var player := Vector3(0, 14, 0)
		var depth := 2.5 + 3.5 * minf(frame / 60.0, 1.0)
		var drift := 0.2 + 0.7 * (1.0 + sin(frame * 0.09))
		return [player, player + Vector3(drift * sin(frame * 0.04), -depth, -drift * cos(frame * 0.04))]
	_check("stacked below", _fly(path, 240))


func test_opponent_stacked_a_few_metres_above() -> void:
	var path := func(frame: int) -> Array:
		var player := Vector3(0, 10, 0)
		var height := 2.5 + 3.0 * minf(frame / 60.0, 1.0)
		return [player, player + Vector3(0.4 * sin(frame * 0.05), height, -0.5)]
	_check("stacked above", _fly(path, 240))
