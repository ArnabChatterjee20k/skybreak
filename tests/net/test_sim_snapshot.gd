extends GutTest

const BotMatch := preload("res://tests/net/bot_match.gd")
const NetScript := preload("res://tests/net/net_script.gd")

var _sim: CombatSim
var _bots: Array
var _humans: Array


func before_each() -> void:
	# Seed 13: with pushboxes (T-D29) seed 11, and with the #150 block gaps seed 12, never has
	# drops and shots out on the same tick.
	_sim = BotMatch.new_sim(13, 2)
	_bots = BotMatch.new_bots(_sim, 13)
	_humans = [NetScript.new(1), NetScript.new(2)]


func _inputs() -> Array[FighterInput]:
	var inputs: Array[FighterInput] = []
	for i in _sim.fighters.size():
		inputs.append(_humans[i].next_input() if i < 2 else _bots[i].next_input(_sim))
	return inputs


func _bot_snapshots() -> Array:
	var saved: Array = []
	for bot: Variant in _bots:
		saved.append(SimSnapshot.capture(bot) if bot else null)
	return saved


func _restore_bots(saved: Array) -> void:
	for i in _bots.size():
		if _bots[i]:
			(saved[i] as SimSnapshot).restore_into(_bots[i])


## Runs until drops and shots are in the world, so the snapshot has to carry them.
func _run_until_pickups_and_projectiles() -> void:
	for i in 12000:
		_sim.tick(_inputs())
		if _sim.round_over:
			_sim.start_round()
		if not _sim.pickups.is_empty() and not _sim.projectiles.is_empty():
			return
	fail_test("no tick had both pickups and projectiles")


func test_restoring_and_re_simulating_the_same_inputs_gives_the_same_state_hash() -> void:
	_run_until_pickups_and_projectiles()
	var saved := _sim.snapshot()
	var saved_bots := _bot_snapshots()
	var hash_at_save := _sim.state_hash()
	var recorded: Array = []
	for i in 600:
		var inputs := _inputs()
		recorded.append(inputs)
		_sim.tick(inputs)
	var expected := _sim.state_hash()
	_sim.restore(saved)
	_restore_bots(saved_bots)
	assert_eq(_sim.state_hash(), hash_at_save, "restore puts back the hashed state")
	for inputs: Array[FighterInput] in recorded:
		_sim.tick(inputs)
	assert_eq(_sim.state_hash(), expected, "re-simulation matches")


func test_restored_bots_produce_the_same_inputs_again() -> void:
	_run_until_pickups_and_projectiles()
	var saved := _sim.snapshot()
	var saved_bots := _bot_snapshots()
	_inputs()
	_sim.tick(_inputs())
	var first := InputCodec.encode(_bots[2].next_input(_sim))
	_sim.restore(saved)
	_restore_bots(saved_bots)
	_inputs()
	_sim.tick(_inputs())
	assert_eq(InputCodec.encode(_bots[2].next_input(_sim)), first)


func test_a_snapshot_covers_pickups_projectiles_and_the_rng() -> void:
	_run_until_pickups_and_projectiles()
	var saved := _sim.snapshot()
	var pickups := _sim.pickups.size()
	var projectile_position := _sim.projectiles[0].position
	var rng_state := _sim.rng.state
	_sim.pickups.clear()
	_sim.projectiles[0].position += Vector3.ONE
	_sim.rng.randi()
	_sim.restore(saved)
	assert_eq(_sim.pickups.size(), pickups)
	assert_eq(_sim.projectiles[0].position, projectile_position)
	assert_eq(_sim.rng.state, rng_state)


func test_a_snapshot_can_be_restored_twice() -> void:
	_run_until_pickups_and_projectiles()
	var saved := _sim.snapshot()
	var hash_at_save := _sim.state_hash()
	for round_trip in 2:
		for i in 30:
			_sim.tick(_inputs())
		assert_ne(_sim.state_hash(), hash_at_save)
		_sim.restore(saved)
		assert_eq(_sim.state_hash(), hash_at_save)


func test_restore_keeps_the_fighter_objects_the_view_holds() -> void:
	var fighter := _sim.fighters[0]
	var saved := _sim.snapshot()
	for i in 20:
		_sim.tick(_inputs())
	_sim.restore(saved)
	assert_same(_sim.fighters[0], fighter)


func test_snapshot_and_restore_take_under_a_millisecond() -> void:
	_run_until_pickups_and_projectiles()
	var start := Time.get_ticks_usec()
	for i in 100:
		_sim.restore(_sim.snapshot())
	var average_ms := (Time.get_ticks_usec() - start) / 100.0 / 1000.0
	gut.p("snapshot + restore, 4 fighters: %.3f ms" % average_ms)
	assert_lt(average_ms, 1.0)
