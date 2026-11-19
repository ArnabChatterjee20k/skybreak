extends GutTest

const MAX := FighterView.MAX_LEAN
const FAST := FighterView.FULL_LEAN_SPEED

var _view: FighterView
var _state: FighterState


func before_each() -> void:
	_state = FighterState.new()
	_view = FighterView.new()
	_view.fighter = _state
	add_child_autofree(_view)


## Where the top of the body points after leaning.
func _body_up() -> Vector3:
	return _view.get_child(0).global_basis.y


func test_standing_still_does_not_lean() -> void:
	assert_eq(FighterView.lean_for(Vector3.ZERO, 0.0, MAX), Vector2.ZERO)


func test_moving_forward_leans_forward_at_full_speed() -> void:
	var lean := FighterView.lean_for(Vector3(0, 0, -FAST), 0.0, MAX)
	assert_almost_eq(lean.x, -MAX, 0.0001)
	assert_almost_eq(lean.y, 0.0, 0.0001)


func test_lean_is_relative_to_facing() -> void:
	# Facing right (yaw -90°) and moving right is moving forward.
	var lean := FighterView.lean_for(Vector3(FAST, 0, 0), deg_to_rad(-90.0), MAX)
	assert_almost_eq(lean.x, -MAX, 0.0001)
	assert_almost_eq(lean.y, 0.0, 0.0001)


func test_lean_never_exceeds_the_maximum() -> void:
	var lean := FighterView.lean_for(Vector3(500, 0, -500), 0.0, MAX)
	assert_almost_eq(absf(lean.x), MAX, 0.0001)
	assert_almost_eq(absf(lean.y), MAX, 0.0001)


func test_body_tips_toward_forward_motion() -> void:
	_state.velocity = Vector3(0, 0, -FAST)
	for _frame in 60:
		_view.present(1.0, 1.0 / 60.0)
	assert_lt(_body_up().z, -0.1, "top of the body tips forward (-Z)")


func test_body_tips_toward_sideways_motion() -> void:
	_state.velocity = Vector3(FAST, 0, 0)
	for _frame in 60:
		_view.present(1.0, 1.0 / 60.0)
	assert_gt(_body_up().x, 0.1, "top of the body tips right (+X)")


func test_view_interpolates_position_between_ticks() -> void:
	_state.position = Vector3.ZERO
	_view.remember_previous_tick()
	_state.position = Vector3(2, 0, 0)
	_view.present(0.25, 1.0 / 60.0)
	assert_almost_eq(_view.position.x, 0.5, 0.0001)


func test_vanished_fighter_is_hidden() -> void:
	_state.enter_state(FighterState.State.VANISHING)
	_view.present(1.0, 1.0 / 60.0)
	assert_false(_view.visible)
	_state.enter_state(FighterState.State.FLYING)
	_view.present(1.0, 1.0 / 60.0)
	assert_true(_view.visible)
