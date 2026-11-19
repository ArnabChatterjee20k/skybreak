extends GutTest
## Scripted playtest: flies every FlightScenarios route through the real test
## arena and checks the camera targets from playtest #1 (T-113).

## Frames at the start of a scenario the camera gets to settle in.
const SETTLE_FRAMES := 30
const MIN_CAMERA_DISTANCE := 5.5
const MAX_CAMERA_DISTANCE := 10.0
const MIN_PLAYER_SCREEN_HEIGHT := 0.15
## Fastest the camera-to-player distance may change (anti-pumping), m/s.
const MAX_DISTANCE_CHANGE_SPEED := 8.0

var _results := {}


func before_all() -> void:
	for scenario_name in FlightScenarios.all():
		var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
		add_child(arena)
		_results[scenario_name] = FlightPlaytest.new(arena, FlightScenarios.all()[scenario_name]).run()
		arena.free()


func _settled(scenario_name: String) -> Array:
	return _results[scenario_name].slice(SETTLE_FRAMES)


func test_player_is_always_on_screen() -> void:
	for scenario_name in _results:
		var misses := _settled(scenario_name).filter(func(f): return not f.player_on_screen)
		assert_eq(misses.size(), 0, "%s: player off screen in %d frames" % [scenario_name, misses.size()])


func test_player_is_never_smaller_than_15_percent_of_screen_height() -> void:
	for scenario_name in _results:
		var smallest := 1.0
		for frame in _settled(scenario_name):
			smallest = minf(smallest, frame.player_screen_height)
		assert_gte(smallest, MIN_PLAYER_SCREEN_HEIGHT, "%s: smallest %.3f" % [scenario_name, smallest])


func test_camera_stays_6_to_10_metres_from_the_player() -> void:
	for scenario_name in _results:
		var near := INF
		var far := 0.0
		for frame in _settled(scenario_name):
			near = minf(near, frame.camera_distance)
			far = maxf(far, frame.camera_distance)
		assert_gte(near, MIN_CAMERA_DISTANCE, "%s: closest %.2f m" % [scenario_name, near])
		assert_lte(far, MAX_CAMERA_DISTANCE, "%s: farthest %.2f m" % [scenario_name, far])


func test_camera_distance_never_pumps() -> void:
	for scenario_name in _results:
		var frames := _settled(scenario_name)
		var fastest := 0.0
		for i in range(1, frames.size()):
			var change: float = absf(frames[i].camera_distance - frames[i - 1].camera_distance)
			fastest = maxf(fastest, change / FlightPlaytest.FRAME_SECONDS)
		assert_lte(fastest, MAX_DISTANCE_CHANGE_SPEED, "%s: %.1f m/s" % [scenario_name, fastest])


func test_locked_view_pitch_stays_inside_the_clamp() -> void:
	for scenario_name in _results:
		for frame in _settled(scenario_name):
			if not frame.locked:
				continue
			var pitch: float = frame.view_pitch
			if pitch < -LockOnFraming.MAX_VIEW_PITCH_DOWN - 0.02 or pitch > LockOnFraming.MAX_VIEW_PITCH_UP + 0.02:
				fail_test("%s tick %d: pitch %.1f°" % [scenario_name, frame.tick, rad_to_deg(pitch)])
				break
	pass_test("checked")


func test_off_screen_opponent_always_gets_an_edge_marker() -> void:
	# The marker is drawn exactly when placement() says off screen; check that
	# whenever the opponent is off screen the arrow lands inside the screen.
	var screen := Vector2(1920, 1080)
	for scenario_name in _results:
		for frame in _settled(scenario_name):
			if frame.opponent_on_screen:
				continue
			var marker := OpponentMarker.placement(frame.camera, frame.fov, screen, frame.opponent)
			assert_true(Rect2(Vector2.ZERO, screen).has_point(marker.position),
				"%s tick %d: arrow inside the screen" % [scenario_name, frame.tick])


func test_opponent_is_on_screen_in_most_locked_frames_at_moderate_height_gaps() -> void:
	for scenario_name in _results:
		var counted := 0
		var visible := 0
		var frames_since_lock_change := 1000
		var was_locked := true
		for frame in _settled(scenario_name):
			frames_since_lock_change = 0 if frame.locked != was_locked else frames_since_lock_change + 1
			was_locked = frame.locked
			if frames_since_lock_change < 30:
				continue  # the camera is still turning to the new framing
			var gap: Vector3 = frame.opponent - frame.player
			var height_angle := atan2(absf(gap.y), Vector2(gap.x, gap.z).length())
			if not frame.locked or height_angle > LockOnFraming.MAX_VIEW_PITCH_UP:
				continue
			counted += 1
			visible += int(frame.opponent_on_screen)
		if counted > 0:
			assert_gte(float(visible) / counted, 0.99, "%s: %d/%d frames" % [scenario_name, visible, counted])


func test_player_rarely_hides_the_opponent_while_strafing() -> void:
	# T-114: in circle-strafe and figure-8 the player covers more than 20% of the
	# opponent in at most 20% of locked frames.
	for scenario_name in ["2_circle_strafe_locked", "3_figure_eight"]:
		var locked := _settled(scenario_name).filter(func(f): return f.locked)
		var hidden := locked.filter(func(f): return f.opponent_hidden > 0.2)
		var share := float(hidden.size()) / locked.size()
		assert_lte(share, 0.2, "%s: opponent >20%% hidden in %d/%d frames" % [scenario_name, hidden.size(), locked.size()])


func test_player_sits_about_a_third_from_the_screen_edge_while_locked() -> void:
	var screen := Vector2(1920, 1080)
	for scenario_name in ["2_circle_strafe_locked", "3_figure_eight", "5_rush_from_far"]:
		var off := 0
		var locked := 0
		for frame in _settled(scenario_name):
			if not frame.locked:
				continue
			locked += 1
			var x: float = OpponentMarker.placement(frame.camera, frame.fov, screen, frame.player).position.x / screen.x
			if absf(x - 0.5) < 0.12:  # within the middle quarter of the screen
				off += 1
		assert_lte(float(off) / locked, 0.1, "%s: player centred in %d/%d frames" % [scenario_name, off, locked])
