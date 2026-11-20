class_name CombatAudioMapper
extends RefCounted
## Turns CombatSim events and fighter state changes into sound requests.
## Pure: it only reads the sim (never writes it) and never touches audio, so the
## same sim history always gives the same requests. MatchAudio hands them to the
## AudioDirector. A request: {cue: StringName, position: Vector3, params: Dictionary}.
## A loop: {key: StringName, cue: StringName, intensity: float, position, active: bool}.

## Base hitstop (ticks, before the counter bonus) at which a hit sounds medium / heavy.
const MEDIUM_HITSTOP := 6
const HEAVY_HITSTOP := 8
## Move damage (display units) from which the swing whoosh is the heavy one.
const HEAVY_SWING_DAMAGE := 500
## Fall speed (m/s) above which a landing is heavy.
const HEAVY_LANDING_SPEED := 14.0
## Flight speed (m/s) at which the wind loop is at full intensity.
const WIND_FULL_SPEED := 55.0
const WIND_MIN_SPEED := 3.0
## Ticks of charging for the ki charge loop to reach full pitch.
const CHARGE_FULL_TICKS := 120
## A fighter this close above the arena floor (m) counts as on the ground.
const GROUND_MARGIN := 0.05
## Combo counts that tick: every COMBO_STEP hits.
const COMBO_STEP := 5

const EVENT_CUES := {
	CombatSim.EventType.BLOCK: &"block",
	CombatSim.EventType.GUARD_BREAK: &"guard_break",
	CombatSim.EventType.KO: &"ko",
	CombatSim.EventType.PERFECT_BLOCK: &"perfect_block",
	CombatSim.EventType.GRAB: &"grab",
	CombatSim.EventType.THROW: &"throw",
	CombatSim.EventType.GRAB_TECH: &"tech",
	CombatSim.EventType.PUSH_BLOCK: &"push_block",
	CombatSim.EventType.ARMOR: &"armor_hit",
}
const KNOCKBACK_CUES := {
	MoveData.KnockbackType.LAUNCH: &"launcher",
	MoveData.KnockbackType.WALL_SPLAT: &"wall_splat",
}
## Weapon type -> action -> cue (§5.11). Used once the sim emits weapon events.
const WEAPON_CUES := {
	&"ki_gauntlets": {&"swing": &"gauntlets_swing"},
	&"storm_blade": {&"swing": &"blade_swing"},
	&"sky_lance": {&"swing": &"lance_thrust"},
	&"titan_hammer": {&"swing": &"hammer_swing"},
	&"orbit_chakram": {&"swing": &"chakram_throw"},
	&"ember_scythe": {&"swing": &"scythe_swing"},
	&"ki_bow": {&"draw": &"bow_draw", &"fire": &"bow_release"},
	&"arc_revolver": {&"fire": &"revolver_fire", &"reload": &"revolver_reload"},
	&"storm_repeater": {&"fire": &"repeater_fire", &"overheat": &"repeater_overheat"},
	&"scatter_cannon": {&"fire": &"scatter_fire"},
	&"heartstring_bow": {&"draw": &"heartstring_draw", &"fire": &"heartstring_release",
		&"tether": &"heartstring_tether"},
}
## Pickup moments (§5.11) -> cue.
const PICKUP_CUES := {
	&"telegraph": &"sky_drop_whistle", &"spawn": &"pickup_spawn", &"pickup": &"pickup",
	&"switch": &"weapon_switch", &"throw": &"weapon_throw",
}
## Ki attacks (§5.8) -> cue; beams also use the beam loops.
const KI_CUES := {
	&"blast_fire": &"ki_blast_fire", &"blast_impact": &"ki_blast_impact",
	&"beam_fire": &"beam_fire", &"beam_clash": &"beam_clash",
}
const KI_LOOPS := {&"beam_charge": &"beam_charge_loop", &"beam": &"beam_loop"}
## Menu and round flow -> cue.
const UI_CUES := {
	&"move": &"ui_move", &"confirm": &"ui_confirm", &"back": &"ui_back",
	&"count_3": &"round_count_3", &"count_2": &"round_count_2", &"count_1": &"round_count_1",
	&"fight": &"round_fight", &"round_end": &"round_end", &"victory": &"victory",
}
const STATE_CUES: Array[StringName] = [
	&"hit_light", &"hit_medium", &"hit_heavy", &"counter_hit", &"spike_bounce",
	&"combo_tick", &"whoosh_light", &"whoosh_heavy", &"dash", &"air_dash", &"rush_whoosh",
	&"vanish_out", &"vanish_in", &"lock_on", &"lock_switch", &"land_light", &"land_heavy",
	&"flight_start", &"flight_stop", &"power_up_burst", &"round_end",
]
const LOOP_CUES: Array[StringName] = [&"flight_wind_loop", &"ki_charge_loop", &"aura_loop"]

const _HARD_FALL_STATES: Array[FighterState.State] = [
	FighterState.State.HITSTUN, FighterState.State.KNOCKDOWN, FighterState.State.GUARD_BROKEN,
]

## Lock-on sounds are for this fighter (the local player) only.
var listener_index := 0
var _previous: Array[Dictionary] = []
var _round_over := false


## Sound requests for one sim event.
static func cues_for_event(event: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Vector3 = event.get("position", Vector3.ZERO)
	var type: CombatSim.EventType = event.type
	var hitstop: int = event.get("hitstop", 0)
	var params := {"layer_delay": hitstop * CombatSim.TICK_SECONDS}
	if type == CombatSim.EventType.HIT or type == CombatSim.EventType.COUNTER:
		var counter: bool = event.get("counter", false) or type == CombatSim.EventType.COUNTER
		out.append(_request(hit_cue(hitstop, counter, event.get("knockback_type", 0)), at, params))
		if counter:
			out.append(_request(&"counter_hit", at))
	elif EVENT_CUES.has(type):
		out.append(_request(EVENT_CUES[type], at, params))
	if type != CombatSim.EventType.KO and KNOCKBACK_CUES.has(event.get("knockback_type", 0)):
		out.append(_request(KNOCKBACK_CUES[event.knockback_type], at))
	out.append_array(ki_cues_for_event(event))
	return out


## Ki blast and beam sounds (T-KI1): fire, impact, reflect, soak, beam fire, clash and beats.
static func ki_cues_for_event(event: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Vector3 = event.get("position", Vector3.ZERO)
	match event.type:
		CombatSim.EventType.KI_FIRE:
			var charged: bool = event.get("shot", 0) == KiRules.Shot.CHARGED
			out.append(_request(KI_CUES.blast_fire, at, {"pitch_scale": 0.75 if charged else 1.0,
				"volume_db": 3.0 if charged else 0.0}))
		CombatSim.EventType.KI_CHARGE:
			out.append(_request(&"power_up_burst", at, {"pitch_scale": 1.3}))
		CombatSim.EventType.KI_ABSORB:
			out.append(_request(KI_CUES.blast_impact, at, {"pitch_scale": 1.4, "volume_db": -6.0}))
		CombatSim.EventType.PROJECTILE_HIT:
			if event.get("weapon", -1) == Weapon.Kind.NONE:
				if event.get("reflected", false):
					out.append(_request(&"perfect_block", at))
					out.append(_request(KI_CUES.blast_fire, at, {"pitch_scale": 1.25}))
				else:
					out.append(_request(KI_CUES.blast_impact, at))
		CombatSim.EventType.BEAM_FIRE:
			out.append(_request(KI_CUES.beam_fire, at))
		CombatSim.EventType.BEAM_CLASH:
			out.append(_request(KI_CUES.beam_clash, at))
		CombatSim.EventType.CLASH_BEAT:
			if event.get("gain", 0) > 0:
				out.append(_request(&"perfect_block", at, {"pitch_scale": 1.0 + 0.08 * maxi(int(event.get("beat", 0)), 0)}))
			else:
				out.append(_request(&"block", at, {"pitch_scale": 0.7, "volume_db": -4.0}))
		CombatSim.EventType.CLASH_END:
			out.append(_request(KI_CUES.beam_clash, at, {"pitch_scale": 0.8, "volume_db": 3.0}))
	return out


## Light, medium or heavy hit from the event's hitstop and knockback.
static func hit_cue(hitstop: int, counter: bool, knockback: int) -> StringName:
	var base := hitstop - ((CombatSim.DEFAULT_HIT_TUNING as HitTuning).counter_hit_extra_hitstop_ticks if counter else 0)
	if base >= HEAVY_HITSTOP or knockback in [MoveData.KnockbackType.LAUNCH,
			MoveData.KnockbackType.SPIKE, MoveData.KnockbackType.WALL_SPLAT]:
		return &"hit_heavy"
	if base >= MEDIUM_HITSTOP or knockback == MoveData.KnockbackType.BLOWBACK:
		return &"hit_medium"
	return &"hit_light"


static func weapon_cue(weapon: StringName, action: StringName) -> StringName:
	return WEAPON_CUES.get(weapon, {}).get(action, &"")


## Every cue id this mapper can ask for; the banks must have all of them.
static func referenced_cues() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(STATE_CUES)
	out.append_array(LOOP_CUES)
	for table: Dictionary in [EVENT_CUES, KNOCKBACK_CUES, PICKUP_CUES, KI_CUES, KI_LOOPS, UI_CUES]:
		for cue: StringName in table.values():
			out.append(cue)
	for actions: Dictionary in WEAPON_CUES.values():
		for cue: StringName in actions.values():
			out.append(cue)
	for zone_id in ZoneLayout.ZONE_IDS:
		out.append(StringName("amb_%s" % zone_id))
	var unique: Array[StringName] = []
	for cue in out:
		if not unique.has(cue):
			unique.append(cue)
	return unique


## Requests for everything that happened in the sim's last tick: its events plus
## state changes (dash, vanish, flight, landing, attacks, charge, combo, lock-on).
func observe(sim: CombatSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in sim.events:
		out.append_array(cues_for_event(event))
	var now: Array[Dictionary] = []
	for i in sim.fighters.size():
		var snapshot := _snapshot(sim.fighters[i], sim.tuning.ground_height)
		if i < _previous.size():
			out.append_array(_transition_cues(i, _previous[i], snapshot))
		now.append(snapshot)
	_previous = now
	if sim.round_over and not _round_over:
		out.append(_request(&"round_end", Vector3.ZERO))
	_round_over = sim.round_over
	return out


## Continuous sounds per fighter: flight wind by speed, ki charge rising, aura hum.
func loops_for(sim: CombatSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in sim.fighters.size():
		var f := sim.fighters[i]
		var speed := f.velocity.length()
		var flying := f.state in [FighterState.State.FLYING, FighterState.State.DASHING] \
			and f.position.y > sim.tuning.ground_height + GROUND_MARGIN and speed > WIND_MIN_SPEED
		out.append(_loop(&"wind_%d" % i, &"flight_wind_loop", flying, speed / WIND_FULL_SPEED, f.position))
		var charging := f.state == FighterState.State.CHARGING
		out.append(_loop(&"charge_%d" % i, &"ki_charge_loop", charging,
			float(f.state_ticks) / CHARGE_FULL_TICKS, f.position))
		out.append(_loop(&"aura_%d" % i, &"aura_loop", charging, 1.0, f.position))
		out.append_array(_ki_loops(i, f))
	return out


## Charge hum that rises through a charged blast or a beam's startup, then the beam's roar.
static func _ki_loops(index: int, f: FighterState) -> Array[Dictionary]:
	var kit := KiRules.kit_of(f)
	var move := f.move if f.state == FighterState.State.ATTACKING else null
	var charging := move != null and (move == kit.charged or kit.is_beam(move)) and f.move_tick < move.startup_ticks
	var firing := move != null and kit.is_beam(move) and not charging and f.move_tick < move.recovery_start_tick()
	var rise := float(f.move_tick) / move.startup_ticks if charging else 0.0
	return [
		_loop(&"ki_charge_%d" % index, KI_LOOPS.beam_charge, charging, rise, f.position),
		_loop(&"beam_%d" % index, KI_LOOPS.beam, firing, 1.0, f.position),
	]


func _transition_cues(index: int, was: Dictionary, now: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Vector3 = now.position
	var state: FighterState.State = now.state
	var before: FighterState.State = was.state
	if state == FighterState.State.DASHING and (before != FighterState.State.DASHING
			or (now.dash_kind == FighterState.DashKind.RUSH and was.dash_kind != FighterState.DashKind.RUSH)):
		if now.dash_kind == FighterState.DashKind.RUSH:
			out.append(_request(&"rush_whoosh", at))
		else:
			out.append(_request(&"dash" if was.grounded else &"air_dash", at))
	if state == FighterState.State.VANISHING and before != FighterState.State.VANISHING:
		out.append(_request(&"vanish_out", was.position))
	if before == FighterState.State.VANISHING and state != FighterState.State.VANISHING:
		out.append(_request(&"vanish_in", at))
	if state == FighterState.State.FLYING and before != FighterState.State.FLYING \
			and (was.grounded or before == FighterState.State.FALLING):
		out.append(_request(&"flight_start", at))
	if before == FighterState.State.FLYING and state == FighterState.State.FALLING:
		out.append(_request(&"flight_stop", at))
	if state == FighterState.State.KNOCKDOWN and before != FighterState.State.KNOCKDOWN:
		out.append(_request(&"spike_bounce", at))
	elif now.grounded and not was.grounded and state != FighterState.State.VANISHING:
		var hard: bool = -float(was.vertical_speed) > HEAVY_LANDING_SPEED or before in _HARD_FALL_STATES
		out.append(_request(&"land_heavy" if hard else &"land_light", at))
	if state == FighterState.State.ATTACKING and (before != FighterState.State.ATTACKING or now.move != was.move) \
			and now.swing != &"":
		out.append(_request(now.swing, at))
	if state == FighterState.State.CHARGING and before != FighterState.State.CHARGING:
		out.append(_request(&"power_up_burst", at))
	var combo: int = now.combo_hits
	if combo >= COMBO_STEP and combo / COMBO_STEP > int(was.combo_hits) / COMBO_STEP:
		var milestone := combo / COMBO_STEP
		out.append(_request(&"combo_tick", at, {"pitch_scale": 1.0 + 0.06 * (milestone - 1)}))
	if index == listener_index and now.lock != was.lock and now.lock >= 0:
		out.append(_request(&"lock_on" if was.lock < 0 else &"lock_switch", at))
	return out


static func _snapshot(f: FighterState, ground_y: float) -> Dictionary:
	var swing := &""
	if f.move != null and f.move.kind != MoveData.Kind.PUSH_BLOCK:
		swing = &"whoosh_heavy" if f.move.damage >= HEAVY_SWING_DAMAGE else &"whoosh_light"
	return {
		"state": f.state, "dash_kind": f.dash_kind, "grounded": f.position.y <= ground_y + GROUND_MARGIN,
		"vertical_speed": f.velocity.y, "position": f.position, "lock": f.lock_on_target,
		"combo_hits": f.combo_hits, "move": f.move_id(), "swing": swing,
	}


static func _request(cue: StringName, at: Vector3, params: Dictionary = {}) -> Dictionary:
	return {"cue": cue, "position": at, "params": params}


static func _loop(key: StringName, cue: StringName, active: bool, intensity: float, at: Vector3) -> Dictionary:
	return {"key": key, "cue": cue, "active": active, "intensity": clampf(intensity, 0.0, 1.0), "position": at}
