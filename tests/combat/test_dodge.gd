extends GutTest
## T-DEF2: dodge (tap Shift), sidestep, anti-mash, air limits, perfect dodge and the grab punish.

const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK
const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const GRAB := FighterInput.Action.GRAB
const State := FighterState.State
const Kind := FighterDodge.Kind
const Event := CombatSim.EventType
const UNIT := FighterState.METER_UNIT
const RIGHT := Vector2(1, 0)
const BACK := Vector2(0, -1)

var _sim: CombatSim
var _dodge: DodgeTuning
var _previous: Array[FighterInput] = []
var _log: Array[Dictionary] = []


## Fighter 0 (the dodger) at the origin, fighter 1 gap metres ahead (-Z), both locked on.
func _start(gap: float = 2.0, height: float = 0.0) -> void:
	_sim = CombatSim.new()
	_dodge = _sim.dodge_tuning
	_sim.add_fighter(Vector3(0, height, 0))
	_sim.add_fighter(Vector3(0, height, -gap))
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	_log = []


## One tick: fighter 0 holds held0 with move0, fighter 1 holds held1 with move1.
func _tick(held0: int = 0, move0: Vector2 = Vector2.ZERO, held1: int = 0, move1: Vector2 = Vector2.ZERO,
		vertical0: int = 0) -> void:
	var a := FighterInput.from_held(held0, _previous[0])
	a.move = move0
	a.vertical = vertical0
	var b := FighterInput.from_held(held1, _previous[1])
	b.move = move1
	var inputs: Array[FighterInput] = [a, b]
	_sim.tick(inputs)
	_previous = inputs
	_log.append_array(_sim.events)


func _idle(ticks: int) -> void:
	for _i in ticks:
		_tick()


func _me() -> FighterState:
	return _sim.fighters[0]


## Frames (1-based) of the dodge just started on which fighter 0 is invulnerable, and its length.
func _frames_of_dodge(held: int = DASH, move: Vector2 = Vector2.ZERO) -> Dictionary:
	var invulnerable: Array[int] = []
	_tick(held, move)
	var frame := 1
	while _me().state == State.DASHING and frame < 200:
		if DodgeRules.is_invulnerable(_me()):
			invulnerable.append(frame)
		_tick()
		frame += 1
	return {"invulnerable": invulnerable, "frames": frame - 1}


func _range(first: int, last: int) -> Array[int]:
	var out: Array[int] = []
	for frame in range(first, last + 1):
		out.append(frame)
	return out


func _count(type: Event) -> int:
	return _log.filter(func(e: Dictionary) -> bool: return e.type == type).size()


# Frames

func test_a_directional_dodge_is_invulnerable_on_frames_3_to_14_of_26() -> void:
	_start(20.0)
	var result := _frames_of_dodge(DASH, BACK)
	assert_eq(_me().dodge.kind, Kind.NONE)
	assert_eq(result.invulnerable, _range(3, 14))
	assert_eq(result.frames, 26)


func test_a_spot_dodge_is_invulnerable_on_frames_2_to_17_of_31_and_stays_put() -> void:
	_start(20.0)
	var result := _frames_of_dodge(DASH)
	assert_eq(result.invulnerable, _range(2, 17))
	assert_eq(result.frames, 31)
	assert_almost_eq(_me().position.x, 0.0, 0.0001)
	assert_almost_eq(_me().position.z, 0.0, 0.0001)


func test_a_sidestep_has_the_directional_frames_and_keeps_the_distance() -> void:
	_start(5.0)
	_tick(DASH, RIGHT)
	assert_eq(_me().dodge.kind, Kind.SIDESTEP)
	assert_eq(_me().dodge.side, 1)
	_start(5.0)
	var result := _frames_of_dodge(DASH, RIGHT)
	assert_eq(result.invulnerable, _range(3, 14))
	assert_eq(result.frames, 26)
	assert_almost_eq(_me().position.distance_to(_sim.fighters[1].position), 5.0, 0.01)
	assert_gt(_me().position.x, 2.0, "went right, round the target")


func test_a_close_sidestep_widens_its_arc_up_to_the_cap() -> void:
	_start(1.5)
	_frames_of_dodge(DASH, RIGHT)
	var offset := _me().position - _sim.fighters[1].position
	var turned := rad_to_deg(Vector2(offset.z, offset.x).angle())
	assert_almost_eq(turned, _dodge.sidestep_max_arc_degrees, 0.5)


func test_shift_toward_the_locked_target_is_still_the_rush_dash_with_no_i_frames() -> void:
	_start(20.0)
	_tick(DASH, Vector2(0, 1))
	assert_eq(_me().dash_kind, FighterState.DashKind.RUSH)
	_tick()
	_tick()
	assert_false(DodgeRules.is_invulnerable(_me()))


# Hold

func test_holding_shift_turns_the_dodge_into_the_flight_dash_and_ends_its_i_frames() -> void:
	_start(30.0, 20.0)
	for _i in _dodge.hold_to_dash_tick + 1:
		_tick(DASH, RIGHT)
	assert_eq(_me().dash_kind, FighterState.DashKind.SUSTAINED)
	assert_false(DodgeRules.is_invulnerable(_me()))


func test_a_flight_dash_from_a_dodge_cannot_be_let_go_before_the_dodge_frames_end() -> void:
	_start(30.0, 20.0)
	for _i in _dodge.hold_to_dash_tick + 1:
		_tick(DASH, BACK)
	_tick()
	assert_eq(_me().state, State.DASHING, "no free cancel of the recovery")
	while _me().state == State.DASHING and _me().state_ticks < 60:
		_tick()
	assert_eq(_me().state, State.FLYING)


# Anti-mash

func test_a_dodge_within_the_chain_window_has_longer_recovery_and_shorter_i_frames() -> void:
	_start(20.0)
	_frames_of_dodge(DASH, BACK)
	_idle(10)
	var result := _frames_of_dodge(DASH, BACK)
	assert_eq(result.invulnerable, _range(3, 14 - _dodge.chain_invuln_loss_ticks))
	assert_eq(result.frames, 26 + _dodge.chain_extra_recovery_ticks)


func test_the_third_chained_dodge_has_no_i_frames_until_the_cooldown_passes() -> void:
	_start(20.0)
	_frames_of_dodge(DASH, BACK)
	_frames_of_dodge(DASH, BACK)
	assert_eq(_frames_of_dodge(DASH, BACK).invulnerable, [] as Array[int], "third in a chain")
	_idle(_dodge.chain_window_ticks + 5)
	assert_eq(_frames_of_dodge(DASH, BACK).invulnerable, [] as Array[int], "still cooling down")
	_idle(_dodge.stale_cooldown_ticks)
	assert_eq(_frames_of_dodge(DASH, BACK).invulnerable, _range(3, 14), "rested")


func test_a_dodge_after_the_chain_window_is_fresh() -> void:
	_start(20.0)
	_frames_of_dodge(DASH, BACK)
	_idle(_dodge.chain_window_ticks)
	assert_eq(_frames_of_dodge(DASH, BACK).invulnerable, _range(3, 14))


func test_mashing_dodge_every_30_ticks_earns_nothing_and_the_third_dodge_has_no_i_frames() -> void:
	_start(2.0)
	var ki_before := _me().ki
	var starts: Array[Dictionary] = []
	for t in 180:
		_tick(DASH if t % 30 == 0 else 0, BACK)
		for event in _sim.events:
			if event.type == Event.DODGE and event.fighter == 0:
				starts.append(event)
	assert_gte(starts.size(), 3)
	assert_false(starts[0].stale)
	assert_true(starts[2].stale, "third dodge of the mash")
	assert_eq(_count(Event.PERFECT_DODGE), 0, "no threat, no reward")
	assert_eq(_me().ki - ki_before, 180 * _sim.meter_tuning.ki_passive_per_second, "passive ki only")


# Air

func test_two_air_dodges_per_airborne_spell_then_no_i_frames_until_landing() -> void:
	_start(30.0, 20.0)
	assert_eq(_frames_of_dodge(DASH, BACK).invulnerable.size(), 12)
	_idle(_dodge.stale_cooldown_ticks)
	assert_eq(_frames_of_dodge(DASH, BACK).invulnerable.size(), 12)
	_idle(_dodge.stale_cooldown_ticks)
	assert_eq(_me().dodge.air_left, 0)
	assert_eq(_frames_of_dodge(DASH, BACK).invulnerable, [] as Array[int], "out of air dodges")


func test_air_dodges_refresh_after_quiet_ticks_and_on_landing() -> void:
	_start(30.0, 20.0)
	_frames_of_dodge(DASH, BACK)
	_frames_of_dodge(DASH, BACK)
	_idle(_dodge.air_refresh_ticks)
	assert_eq(_me().dodge.air_left, _dodge.air_dodges)
	_start(30.0, 20.0)
	_frames_of_dodge(DASH, BACK)
	_me().position.y = 1.0
	_me().enter_state(State.IDLE)
	_idle(1)
	assert_eq(_me().dodge.air_left, _dodge.air_dodges)


func test_no_dodge_out_of_hitstun_or_blockstun() -> void:
	for stun in [State.HITSTUN, State.BLOCKSTUN]:
		_start(20.0)
		_me().enter_state(stun)
		_me().stun_ticks = 30
		_tick(DASH, BACK)
		assert_eq(_me().state, stun, "%s keeps its stun" % State.keys()[stun])
		assert_eq(_me().dodge.kind, Kind.NONE)


# What i-frames beat

func test_a_dodge_passes_through_a_light_and_a_grab() -> void:
	for press in [LIGHT, GRAB]:
		_start(1.5)
		_tick(DASH, BACK, press)
		for _i in 30:
			_tick()
		assert_eq(_me().health, _me().stats.max_health * UNIT, "evaded %d" % press)
		assert_eq(_count(Event.HIT) + _count(Event.GRAB) + _count(Event.COUNTER), 0)


func test_sweep_hits_a_sidestep_through_its_i_frames() -> void:
	_start(1.8)
	var sweep := _sim.fighters[1].stats.move_set.sweep
	_tick(0, Vector2.ZERO, HEAVY, RIGHT)
	for _i in sweep.startup_ticks - 4:
		_tick()
	_tick(DASH, RIGHT)
	for _i in 20:
		_tick()
	assert_gt(_count(Event.HIT) + _count(Event.COUNTER), 0, "tracked")


func test_a_projectile_passes_through_a_dodge() -> void:
	_start(20.0)
	var shot := Projectile.new()
	shot.owner = 1
	shot.position = Vector3(0, 1, -1.2)
	shot.velocity = Vector3(0, 0, 60)
	shot.radius = 0.2
	shot.ticks_left = 60
	shot.move = _sim.fighters[1].stats.move_set.light_string[0]
	_tick(DASH)
	_tick()
	_sim.projectiles.append(shot)
	_tick()
	_tick()
	assert_eq(_me().health, _me().stats.max_health * UNIT)
	assert_eq(_count(Event.PERFECT_DODGE), 1, "met inside the perfect window")


# Perfect dodge

func test_a_live_strike_in_the_perfect_window_freezes_the_attacker_and_pays_ki_once() -> void:
	_start(1.5)
	var light := _sim.fighters[1].stats.move_set.light_string[0]
	_me().ki = 20 * UNIT
	_tick(0, Vector2.ZERO, LIGHT)
	for _i in light.startup_ticks - 4:
		_tick()
	_tick(DASH)
	var perfect := {}
	for _i in 8:
		_tick()
		for event in _sim.events:
			if event.type == Event.PERFECT_DODGE:
				perfect = event
				assert_eq(_sim.fighters[1].hitstop_ticks, _dodge.perfect_attacker_freeze_ticks, "attacker frozen")
				assert_eq(_me().hitstop_ticks, 0, "the dodger keeps moving")
	assert_false(perfect.is_empty(), "perfect dodge")
	assert_eq(perfect.ki, _dodge.perfect_ki)
	assert_eq(perfect.target, 0)
	assert_eq(_me().dodge.chain, 0, "the chain resets")
	assert_eq(_me().dodge.last_frame, 31 - _dodge.perfect_recovery_cut_ticks)


func test_a_second_perfect_dodge_inside_the_cooldown_pays_no_ki() -> void:
	_start(1.5)
	_me().dodge.ki_cooldown = 100
	var light := _sim.fighters[1].stats.move_set.light_string[0]
	_tick(0, Vector2.ZERO, LIGHT)
	for _i in light.startup_ticks - 4:
		_tick()
	_tick(DASH)
	_idle(8)
	assert_eq(_count(Event.PERFECT_DODGE), 1)
	var event: Dictionary = _log.filter(func(e: Dictionary) -> bool: return e.type == Event.PERFECT_DODGE)[0]
	assert_eq(event.ki, 0)


func test_an_early_dodge_meets_the_strike_in_recovery_and_is_hit() -> void:
	_start(1.5)
	_tick(DASH)
	_idle(16)
	_tick(0, Vector2.ZERO, LIGHT)
	_idle(12)
	assert_eq(_count(Event.PERFECT_DODGE), 0)
	assert_gt(_count(Event.HIT) + _count(Event.COUNTER), 0)


# Grab punish (S5)

func test_a_grab_in_dodge_recovery_is_a_counter_hit_that_cannot_be_teched() -> void:
	_start(1.5)
	var grab := _sim.fighters[1].stats.move_set.grab
	_tick(DASH)
	_idle(18 - grab.startup_ticks)
	_tick(0, Vector2.ZERO, GRAB)
	var grabbed := {}
	for _i in grab.startup_ticks + 2:
		_tick()
		for event in _sim.events:
			if event.type == Event.GRAB:
				grabbed = event
	assert_false(grabbed.is_empty(), "grabbed in recovery")
	assert_true(grabbed.counter)
	assert_true(_me().dodge.punished)
	_tick(GRAB)
	_tick()
	assert_eq(_count(Event.GRAB_TECH), 0, "no tech")
	var thrown := {}
	for _i in 60:
		_tick()
		for event in _sim.events:
			if event.type == Event.THROW:
				thrown = event
	assert_true(thrown.counter)
	assert_eq(thrown.hitstop, grab.hitstop_ticks + _dodge.recovery_grab_extra_hitstop_ticks)


# Vanish and rollback

func test_shift_a_tick_before_e_still_vanishes() -> void:
	_start(20.0)
	_tick(DASH, RIGHT)
	_tick(DASH | BLOCK, RIGHT)
	assert_eq(_me().state, State.VANISHING)


func test_the_dodge_state_is_hashed_and_rolls_back() -> void:
	_start(20.0)
	_tick(DASH, BACK)
	var saved := _sim.snapshot()
	var hash_before := _sim.state_hash()
	_me().dodge.chain = 2
	assert_ne(_sim.state_hash(), hash_before)
	_sim.restore(saved)
	assert_eq(_sim.state_hash(), hash_before)
	_idle(5)
	var after := _sim.state_hash()
	_sim.restore(saved)
	_idle(5)
	assert_eq(_sim.state_hash(), after, "replays the same")
