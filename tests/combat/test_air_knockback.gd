extends GutTest
## Air juggles drive the target away from the attacker and never under or over it (polish batch 2).

const LIGHT := FighterInput.Action.LIGHT
const State := FighterState.State
const Knockback := MoveData.KnockbackType

var _sim: CombatSim
var _previous: Array[FighterInput] = []


func _start(target: Vector3, attacker: Vector3, stats: FighterStats = null) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(attacker, stats)
	_sim.add_fighter(target)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]


func _tick(ticks := 1, held := 0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [FighterInput.from_held(held, _previous[0]), FighterInput.new()]
		_sim.tick(inputs)
		_previous = inputs


## A light from fighter 0; ticks until it lands and returns the target's velocity after the hitstop.
func _land_light() -> Vector3:
	_tick(1, LIGHT)
	for _i in 30:
		_tick()
		if not _sim.events.is_empty():
			break
	assert_eq(_sim.fighters[1].state, State.HITSTUN, "the light lands")
	_tick(_sim.events[0].hitstop)
	return _sim.fighters[1].velocity


## A move set whose light throws with knockback (attacker space) and the given type.
func _stats_with_light(knockback: Vector3, type: Knockback) -> FighterStats:
	var stats := (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).duplicate() as FighterStats
	stats.move_set = stats.move_set.duplicate() as MoveSet
	var light := stats.move_set.light_string[0].duplicate() as MoveData
	light.knockback = knockback
	light.knockback_type = type
	# Treated as a heavy for the guard's push (lights push less).
	light.cancel_level = MoveData.CancelLevel.HEAVY
	var string := stats.move_set.light_string.duplicate()
	string[0] = light
	stats.move_set.light_string = string
	return stats


func test_an_air_hit_drives_the_target_away_at_least_the_minimum_speed() -> void:
	_start(Vector3(0, 9.4, -0.8), Vector3(0, 10, 0))
	var velocity := _land_light()
	assert_lte(velocity.z, -_sim.hit_tuning.air_light_knockback_min_out + 0.001, "away along -Z, a light's push")
	assert_gte(velocity.y, 0.0, "never down")


func test_an_air_hit_aimed_straight_down_does_not_sink_the_target_under_the_attacker() -> void:
	_start(Vector3(0, 8.8, -1.0), Vector3(0, 10, 0), _stats_with_light(Vector3(0, -25, 0), Knockback.BLOWBACK))
	var velocity := _land_light()
	assert_gte(velocity.y, 0.0, "no dive under the attacker")
	assert_gte(-velocity.z, _sim.hit_tuning.air_knockback_min_out - 0.001)


func test_an_air_hit_aimed_straight_up_rises_at_most_45_degrees_away() -> void:
	_start(Vector3(0, 11.2, -1.0), Vector3(0, 10, 0), _stats_with_light(Vector3(0, 25, 0), Knockback.BLOWBACK))
	var velocity := _land_light()
	var planar := Vector2(velocity.x, velocity.z).length()
	assert_lte(velocity.y, planar * _sim.hit_tuning.air_knockback_rise + 0.001, "not straight over the attacker")
	assert_gt(planar, 0.0)


func test_a_juggled_target_ends_up_beside_the_attacker_not_stacked() -> void:
	_start(Vector3(0, 9.5, -0.6), Vector3(0, 10, 0), _stats_with_light(Vector3(0, -20, -1), Knockback.BLOWBACK))
	_land_light()
	while _sim.fighters[1].state == State.HITSTUN:
		_tick()
	var offset := _sim.fighters[1].position - _sim.fighters[0].position
	var planar := Vector2(offset.x, offset.z).length()
	assert_gt(planar, absf(offset.y), "beside, not under")
	assert_gt(planar, SpacingMetrics.STACK_RADIUS, "outside the stacking radius")


func test_a_move_can_set_its_own_air_knockback_minimum() -> void:
	var stats := _stats_with_light(Vector3(0, 0, -1), Knockback.BLOWBACK)
	stats.move_set.light_string[0].air_knockback_min_out = 3.0
	_start(Vector3(0, 9.4, -0.8), Vector3(0, 10, 0), stats)
	var velocity := _land_light()
	assert_almost_eq(-velocity.z, 3.0, 0.001)


func test_grounded_exchanges_keep_their_knockback() -> void:
	_start(Vector3(0, 0, -1.5), Vector3.ZERO, _stats_with_light(Vector3(0, 0, -1), Knockback.BLOWBACK))
	var velocity := _land_light()
	assert_almost_eq(velocity.z, -1.0, 0.001, "on the floor only the move's knockback")


func test_an_air_hit_beside_the_attacker_keeps_its_knockback() -> void:
	_start(Vector3(0, 10, -1.0), Vector3(0, 10, 0), _stats_with_light(Vector3(0, 0, -1), Knockback.BLOWBACK))
	_sim.hit_tuning = _sim.hit_tuning.duplicate() as HitTuning
	_sim.hit_tuning.air_knockback_separation = 0.5
	var velocity := _land_light()
	assert_almost_eq(velocity.z, -1.0, 0.001, "already apart: the move's own knockback")
