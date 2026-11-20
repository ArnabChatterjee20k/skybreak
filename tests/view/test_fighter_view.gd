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


# --- T-122: the character model replaces the capsule ---

const KAEL := preload("res://game/characters/kael_chunky/kael_chunky.tscn")


func _view_with_kael() -> FighterView:
	var view := FighterView.new()
	view.character_scene = KAEL
	view.fighter = FighterState.new()
	view.fighter.position = Vector3(0, 1, 0)
	add_child_autofree(view)
	return view


func test_a_character_scene_replaces_the_capsule() -> void:
	var view := _view_with_kael()
	assert_eq(view.find_children("*", "CharacterView", true, false).size(), 1, "one character")
	for mesh in view.find_children("*", "MeshInstance3D", true, false):
		assert_false(mesh.mesh is CapsuleMesh, "no placeholder capsule")


func test_without_a_character_scene_the_capsule_stays() -> void:
	var view := FighterView.new()
	view.fighter = FighterState.new()
	add_child_autofree(view)
	var capsules := view.find_children("*", "MeshInstance3D", true, false).filter(
		func(m): return m.mesh is CapsuleMesh)
	assert_eq(capsules.size(), 1)


func test_present_drives_the_character_animation_from_sim_state() -> void:
	var view := _view_with_kael()
	var player: AnimationPlayer = view.find_children("AnimationPlayer", "AnimationPlayer", true, false)[0]
	view.remember_previous_tick()
	view.present(1.0, 1.0 / 60.0)
	var idle_clip := player.current_animation
	view.fighter.state = FighterState.State.FLYING
	view.fighter.velocity = Vector3(0, 0, -30)
	for i in 10:
		view.present(1.0, 1.0 / 60.0)
	assert_ne(player.current_animation, idle_clip, "flying plays a different clip than idle")


func test_the_test_arena_draws_p1_kael_against_p2_vexa() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	add_child_autofree(arena)
	var p1: FighterView = arena.get_node("Fighter1")
	var p2: FighterView = arena.get_node("Fighter2")
	assert_eq(p1.character_scene, KAEL, "P1 is Kael")
	assert_eq(p2.character_scene.resource_path, "res://game/characters/vexa/vexa.tscn", "P2 is Vexa")
	assert_eq(p2.find_children("*", "VexaView", true, false).size(), 1, "P2 draws Vexa's view")
	assert_eq(arena.sim.fighters[0].stats.move_set.resource_path, "res://game/combat/moves/kael/kael_move_set.tres")
	assert_eq(arena.sim.fighters[1].stats.move_set.resource_path, "res://game/combat/moves/vexa/vexa_move_set.tres")

func test_a_ko_snaps_the_body_back_from_the_contact_on_the_ko_frame() -> void:
	# #121: the sim holds the loser in hitstop; the view reacts on the KO frame anyway.
	_state.position = Vector3(0, 1, 0)
	_view.remember_previous_tick()
	_state.health = 0
	_state.hitstop_ticks = 20
	_view.present(1.0, 1.0 / 60.0)
	assert_almost_eq(_view.ko_recoil(), 1.0, 0.001)
	var body: Node3D = _view.get_child(0)
	# No KO event in reach: the contact is taken in front, so the body tips back (+Z).
	assert_gt(_body_up().z, 0.4, "the top of the body tips away from the hit")
	assert_gt(body.position.z, 0.2, "and the body is shoved back")


func test_the_ko_recoil_holds_through_hitstop_then_eases_out() -> void:
	_state.health = 0
	_state.hitstop_ticks = 20
	for i in 10:
		_view.present(1.0, 1.0 / 60.0)
	assert_almost_eq(_view.ko_recoil(), 1.0, 0.001, "held while frozen")
	_state.hitstop_ticks = 0
	for i in int(FighterView.KO_RECOIL_OUT * 60.0) + 2:
		_view.present(1.0, 1.0 / 60.0)
	assert_eq(_view.ko_recoil(), 0.0)
	assert_eq((_view.get_child(0) as Node3D).position, Vector3.ZERO)


func test_the_ko_recoil_points_away_from_the_ko_contact() -> void:
	_state.health = 0
	_view.start_ko_recoil(_state.position + Vector3(2, 0, 0))
	_view.present(1.0, 1.0 / 60.0)
	assert_lt(_body_up().x, -0.4, "hit from +X, tips toward -X")
