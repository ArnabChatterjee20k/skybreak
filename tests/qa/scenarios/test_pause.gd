extends QaScenario
## Pausing a running match freezes the sim; resuming carries on from the same tick.


## A minimal match level: ticks a sim from _physics_process, like the real arenas.
class TickingLevel:
	extends Node3D

	signal match_finished(winner: int)

	var match_flow := MatchFlow.new()
	var match_sim := CombatSim.new(3)

	func _ready() -> void:
		match_sim.add_fighter(Vector3(0, 0, 6))
		match_sim.add_fighter(Vector3(0, 0, -6))
		match_sim.lock_everyone_onto_nearest()

	func _physics_process(_delta: float) -> void:
		var inputs: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
		match_sim.tick(inputs)
		match_flow.step(match_sim)


func after_each() -> void:
	get_tree().paused = false


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func test_pausing_the_match_freezes_the_sim_and_resuming_continues_it() -> void:
	var level := TickingLevel.new()
	add_child_autofree(level)
	var session := MatchSession.new()
	level.add_child(session)
	await _physics_frames(5)
	assert_gt(level.match_sim.current_tick, 0, "the match is running")
	session.pause()
	assert_true(get_tree().paused)
	assert_true(session.pause_menu.visible)
	var frozen_at := level.match_sim.current_tick
	var hash_at := level.match_sim.state_hash()
	await _physics_frames(10)
	assert_eq(level.match_sim.current_tick, frozen_at, "no ticks while paused")
	assert_eq(level.match_sim.state_hash(), hash_at, "nothing changed")
	session.resume()
	assert_false(get_tree().paused)
	assert_false(session.pause_menu.visible)
	await _physics_frames(10)
	assert_gt(level.match_sim.current_tick, frozen_at, "ticking again after resume")
	assert_lte(level.match_sim.current_tick, frozen_at + 12, "picks up where it stopped")
