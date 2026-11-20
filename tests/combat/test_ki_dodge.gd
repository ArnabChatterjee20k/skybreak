extends GutTest
## Ki against the dodge (T-KI1 x T-DEF2): dash soak only on a held dash, i-frames
## evade blasts and beam ticks, perfect dodges freeze the shooter, no dodging in a
## clash, homing blasts re-acquire unless perfect-dodged.

const A := FighterInput.Action
const E := CombatSim.EventType
const UNIT := FighterState.METER_UNIT
const LYRA_STATS := preload("res://game/combat/moves/lyra/lyra_fighter_stats.tres")
const SIDE := Vector2(1, 0)

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _seen: Array[Dictionary] = []
## Fighter 0's hitstop right after each PERFECT_DODGE tick.
var _freeze_after_perfect: Array[int] = []


## Fighter 0 (the shooter) at the origin, fighter 1 at target (-Z ahead), locked on, full ki.
func _start(target := Vector3(0, 0, -12), first: FighterStats = null) -> void:
	_sim = CombatSim.new(7)
	_sim.add_fighter(Vector3.ZERO, first)
	_sim.add_fighter(target)
	_sim.lock_everyone_onto_nearest()
	for fighter in _sim.fighters:
		fighter.ki = 100 * UNIT
	_previous = [FighterInput.new(), FighterInput.new()]
	_seen = []
	_freeze_after_perfect = []


func _drive(ticks: int, held: int = 0, other_held: int = 0, other_move := Vector2.ZERO) -> void:
	for _i in ticks:
		var first := FighterInput.from_held(held, _previous[0])
		var second := FighterInput.from_held(other_held, _previous[1])
		second.move = other_move
		second.view_yaw = PI
		var inputs: Array[FighterInput] = [first, second]
		_sim.tick(inputs)
		_previous = inputs
		_seen.append_array(_sim.events)
		for event in _sim.events:
			if event.type == E.PERFECT_DODGE:
				_freeze_after_perfect.append(_sim.fighters[0].hitstop_ticks)


func _count(type: E, move_id := &"") -> int:
	var found := 0
	for event in _seen:
		if event.type == type and (move_id == &"" or event.get("move_id", &"") == move_id):
			found += 1
	return found


func _first(type: E) -> Dictionary:
	for event in _seen:
		if event.type == type:
			return event
	return {}


## Fighter 0 fires shot_held for shot_ticks; fighter 1 taps Shift (dodge_move) after delay ticks, then waits.
func _shot_then_dodge(shot_held: int, shot_ticks: int, delay: int, dodge_move: Vector2,
		first: FighterStats = null, gap := 12.0) -> void:
	_start(Vector3(0, 0, -gap), first)
	for tick in 90:
		var held := shot_held if tick < shot_ticks else 0
		_drive(1, held, A.DASH if tick == delay else 0, dodge_move if tick == delay else Vector2.ZERO)


## The first delay in range whose run perfect-dodges, or -1. Leaves that run in _sim.
func _find_perfect(shot_held: int, shot_ticks: int, delays: Array, dodge_move := Vector2.ZERO,
		first: FighterStats = null, gap := 12.0) -> int:
	for delay: int in delays:
		_shot_then_dodge(shot_held, shot_ticks, delay, dodge_move, first, gap)
		if _count(E.PERFECT_DODGE) > 0:
			return delay
	return -1


# Dash soak

func test_a_tap_dodge_never_soaks_a_tap_blast_but_a_held_flight_dash_does() -> void:
	_start()
	_drive(1, A.KI_BLAST)
	_drive(8)
	assert_eq(_sim.projectiles.size(), 1)
	var blast := _sim.projectiles[0]
	var dodger := _sim.fighters[1]
	dodger.enter_state(FighterState.State.DASHING)
	dodger.dash_direction = Vector3(0, 0, 1) # Straight into the blast.
	dodger.dash_kind = FighterState.DashKind.DODGE
	var ki := dodger.ki
	assert_false(KiRules.absorbs(_sim, 1, blast, dodger.position), "a tap dodge does not soak")
	assert_eq(dodger.ki, ki, "and spends nothing")
	dodger.dash_kind = FighterState.DashKind.SUSTAINED
	assert_true(KiRules.absorbs(_sim, 1, blast, dodger.position), "the held flight-dash soaks")
	assert_eq(dodger.ki, ki - _sim.ki_tuning.dash_absorb_ki_cost * UNIT, "for 2 ki")
	dodger.dash_kind = FighterState.DashKind.RUSH
	assert_true(KiRules.absorbs(_sim, 1, blast, dodger.position), "and so does the rush")


func test_a_spot_dodge_out_of_its_i_frames_is_hit_by_a_tap_blast_not_soaked() -> void:
	# Dodging far too early: the blast arrives in the recovery and lands.
	_shot_then_dodge(A.KI_BLAST, 1, 1, Vector2.ZERO)
	assert_eq(_count(E.KI_ABSORB), 0, "no soak in a dodge")
	assert_eq(_count(E.HIT, &"ki_blast"), 1, "the recovery is hittable")


# I-frames evade ki

func test_dodge_i_frames_evade_a_tap_blast() -> void:
	var evaded := false
	for delay in range(1, 30):
		_shot_then_dodge(A.KI_BLAST, 1, delay, Vector2.ZERO)
		if _count(E.DODGE) == 1 and _count(E.HIT) == 0 and _count(E.KI_ABSORB) == 0:
			evaded = true
			break
	assert_true(evaded, "some spot-dodge timing lets the tap blast pass through")


func test_dodge_i_frames_evade_a_charged_blast() -> void:
	var kit := KiRules.kit_of(CombatSim.new().add_fighter(Vector3.ZERO))
	var evaded := false
	for delay in range(kit.charged.startup_ticks - 4, kit.charged.startup_ticks + 30):
		_shot_then_dodge(A.KI_BLAST, kit.charged.startup_ticks + 2, delay, Vector2.ZERO)
		if _count(E.KI_CHARGE) == 1 and _count(E.DODGE) == 1 and _count(E.HIT) == 0:
			evaded = true
			break
	assert_true(evaded, "some spot-dodge timing lets the charged blast pass through")


func test_a_perfect_dodge_of_a_tap_blast_freezes_the_shooter_6_frames_and_pays_ki() -> void:
	var delay := _find_perfect(A.KI_BLAST, 1, range(1, 30))
	assert_gt(delay, -1, "a spot dodge timed onto the blast is perfect")
	var perfect := _first(E.PERFECT_DODGE)
	assert_eq(perfect.get("attacker", -1), 0)
	assert_eq(perfect.get("target", -1), 1)
	assert_true(perfect.get("projectile", false))
	assert_eq(perfect.get("hitstop", 0), _sim.dodge_tuning.perfect_attacker_freeze_ticks)
	assert_eq(_freeze_after_perfect, [_sim.dodge_tuning.perfect_attacker_freeze_ticks], "the shooter froze 6 f")
	assert_eq(perfect.get("ki", 0), _sim.dodge_tuning.perfect_ki)
	assert_eq(_count(E.HIT), 0)


func test_a_perfect_dodge_of_a_charged_blast_freezes_the_shooter() -> void:
	var kit := KiRules.kit_of(CombatSim.new().add_fighter(Vector3.ZERO))
	var delay := _find_perfect(A.KI_BLAST, kit.charged.startup_ticks + 2,
		range(kit.charged.startup_ticks - 4, kit.charged.startup_ticks + 30))
	assert_gt(delay, -1, "a charged blast can be perfect-dodged")
	assert_eq(_first(E.PERFECT_DODGE).get("move_id", &""), &"charged_blast")
	assert_eq(_freeze_after_perfect, [_sim.dodge_tuning.perfect_attacker_freeze_ticks])


func test_a_weapon_projectile_perfect_dodge_still_freezes_nobody() -> void:
	# T-DEF2's rule for weapon shots is unchanged; only ki shots freeze their shooter.
	_start()
	var shot := Projectile.new()
	shot.owner = 0
	shot.ki = KiRules.Shot.NONE
	var dodger := _sim.fighters[1]
	DodgeRules.begin(_sim, 1, FighterDodge.Kind.SPOT, Vector3.ZERO, 1)
	dodger.state_ticks = dodger.dodge.invuln_first
	shot.move = KiRules.kit_of(_sim.fighters[0]).blast
	assert_true(DodgeRules.evade_projectile(_sim, shot, 1, dodger.position))
	assert_eq(_sim.fighters[0].hitstop_ticks, 0)


# Beams

func test_dodge_i_frames_evade_beam_ticks_and_a_perfect_one_freezes_the_beamer_while_the_beam_goes_on() -> void:
	var kit := KiRules.kit_of(CombatSim.new().add_fighter(Vector3.ZERO))
	var start := kit.beam.startup_ticks - 6
	_start(Vector3(0, 0, -12))
	var delay := -1
	for d in range(start, kit.beam.startup_ticks + 12):
		_start(Vector3(0, 0, -12))
		var perfect_tick := -1
		var beams_after := 0
		var invulnerable_hits := 0
		for tick in 90:
			var tap := tick == d
			var was_invulnerable := DodgeRules.is_invulnerable(_sim.fighters[1])
			_drive(1, A.SPECIAL_1 if tick == 0 else 0, A.DASH if tap else 0)
			for event in _sim.events:
				if event.type in [E.HIT, E.COUNTER] and was_invulnerable \
						and DodgeRules.is_invulnerable(_sim.fighters[1]):
					invulnerable_hits += 1
				if event.type == E.PERFECT_DODGE:
					perfect_tick = tick
					beams_after = _sim.beams.size()
		assert_eq(invulnerable_hits, 0, "no beam tick lands through i-frames (delay %d)" % d)
		if perfect_tick >= 0:
			delay = d
			assert_eq(beams_after, 1, "the beam keeps going after the perfect dodge")
			break
	assert_gt(delay, -1, "a spot dodge timed onto the beam's arrival is perfect")
	var perfect := _first(E.PERFECT_DODGE)
	assert_eq(perfect.get("attacker", -1), 0, "the beam owner is the attacker")
	assert_eq(perfect.get("move_id", &""), &"beam")
	assert_eq(_freeze_after_perfect, [_sim.dodge_tuning.perfect_attacker_freeze_ticks], "the beam owner froze 6 f")


func test_a_sidestep_dodge_after_the_beams_aim_lock_makes_it_whiff_with_30_more_recovery() -> void:
	_start(Vector3(0, 0, -20))
	var kit := KiRules.kit_of(_sim.fighters[0])
	_drive(1, A.SPECIAL_1)
	_drive(kit.beam.startup_ticks - 3)
	_drive(1, 0, A.DASH, SIDE)
	assert_eq(_first(E.DODGE).get("kind", -1), FighterDodge.Kind.SIDESTEP, "a sidestep dodge")
	for _i in kit.beam.active_ticks + 20:
		if _count(E.BEAM_END) > 0:
			break
		_drive(1)
	assert_eq(_count(E.HIT) + _count(E.COUNTER), 0, "the sidestep beat the beam")
	assert_true(_first(E.BEAM_END).get("whiff", false), "a whiff")
	var beamer := _sim.fighters[0]
	var left := beamer.move_total_ticks() - beamer.move_tick
	assert_gte(left, kit.beam.recovery_ticks + _sim.ki_tuning.beam_whiff_extra_recovery_ticks - 1,
		"+%d f recovery" % _sim.ki_tuning.beam_whiff_extra_recovery_ticks)


# Clash

func test_nobody_can_dodge_out_of_a_beam_clash() -> void:
	_start(Vector3(0, 0, -24))
	_drive(1, A.SPECIAL_1, A.SPECIAL_1)
	for _i in 60:
		_drive(1)
		if not _sim.beam_clashes.is_empty():
			break
	assert_false(_sim.beam_clashes.is_empty(), "the beams clashed")
	_drive(1, A.DASH, A.DASH, SIDE)
	_drive(2)
	_drive(1, A.DASH, A.DASH)
	assert_eq(_count(E.DODGE), 0, "Shift does nothing in a clash")
	assert_eq(_sim.beam_clashes.size(), 1, "the clash goes on")
	for index in 2:
		assert_eq(_sim.fighters[index].state, FighterState.State.ATTACKING, "fighter %d still locked" % index)
		assert_true(KiRules.in_clash(_sim, index))


# Homing

func test_a_homing_blast_re_acquires_its_target_after_a_plain_dodge() -> void:
	var kept := false
	for delay in range(1, 40):
		_shot_then_dodge(A.KI_BLAST, 1, delay, Vector2.ZERO, LYRA_STATS, 18.0)
		if _count(E.DODGE) != 1 or _count(E.PERFECT_DODGE) > 0:
			continue
		# Replay to the tick after the blast passed through the i-frames.
		_start(Vector3(0, 0, -18), LYRA_STATS)
		for tick in 90:
			_drive(1, A.KI_BLAST if tick == 0 else 0, A.DASH if tick == delay else 0)
			if _sim.projectiles.size() == 1 and _sim.projectiles[0].position.z < -18.5:
				var blast := _sim.projectiles[0]
				assert_eq(blast.homing_target, 1, "still hunting the dodger")
				assert_eq(blast.hit_mask & 2, 0, "and free to hit them again")
				kept = true
				break
		if kept:
			break
	assert_true(kept, "a blast went through a plain dodge and kept homing")


func test_a_perfect_dodge_breaks_a_homing_blast() -> void:
	var delay := _find_perfect(A.KI_BLAST, 1, range(1, 40), Vector2.ZERO, LYRA_STATS, 18.0)
	assert_gt(delay, -1, "a homing blast can be perfect-dodged")
	assert_eq(_count(E.HIT), 0)
	_start(Vector3(0, 0, -18), LYRA_STATS)
	for tick in 90:
		_drive(1, A.KI_BLAST if tick == 0 else 0, A.DASH if tick == delay else 0)
		if _count(E.PERFECT_DODGE) > 0:
			break
	assert_eq(_sim.projectiles.size(), 1, "the blast flies on")
	if _sim.projectiles.size() == 1:
		assert_eq(_sim.projectiles[0].homing_target, -1, "no longer homing")
		assert_eq(_sim.projectiles[0].homing_rate, 0.0)
