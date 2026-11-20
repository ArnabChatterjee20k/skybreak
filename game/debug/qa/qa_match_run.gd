class_name QaMatchRun
extends RefCounted
## Plays one QaMatchSpec through the real ZoneMatch level (sim, fighter views, weapon
## layer, camera, round flow) with AIDriver on every slot, one tick per process frame,
## checking the sim after each tick and the view on each presented frame.

const ZONE_MATCH := "res://game/levels/zone_match.tscn"
const FRAME_SECONDS := 1.0 / 60.0

var spec: QaMatchSpec
var level: ZoneMatch
var driver: AIDriver
var view_checks: QaViewChecks
var check_view := true
var tick := 0
var rounds_started := 1
var kos := 0
## check -> {check, fighter, count, first_tick, worst_tick, worst_value, limit, detail}
var violations := {}
var sim_usec := 0
var view_usec := 0
## move id -> {hitstop -> count}
var hitstops := {}
var pending_overlap := false
## Ki attacks the AIs used (T-KI1): kind -> count.
var ki_usage := {"blasts": 0, "charged": 0, "beams": 0, "ultimates": 0, "clashes": 0, "reflects": 0,
	"soaks": 0, "beam_whiffs": 0, "ki_hits": 0}

var _phase := -1


func _init(match_spec: QaMatchSpec) -> void:
	spec = match_spec


## Builds the level under parent; await the next process frame before stepping.
func build(parent: Node) -> void:
	level = (load(ZONE_MATCH) as PackedScene).instantiate()
	level.sim.rng.seed = spec.seed_value
	level.configure({"zone": spec.zone, "fighters": spec.fighters(), "rounds": 3, "mode": &"ffa"})
	parent.add_child(level)
	level.set_physics_process(false)
	level.set_process(false)
	driver = AIDriver.new(spec.fighters(), spec.seed_value)
	level.input_override = func(slot: int, _tick: int) -> FighterInput: return driver.input_for(level.sim, slot)
	view_checks = QaViewChecks.new(level)
	pending_overlap = not QaKnownIssues.has_pushboxes()
	_phase = level.match_flow.phase


func is_over() -> bool:
	return level.match_flow.phase == MatchFlow.Phase.MATCH_OVER


## Checks the frame presented last time (its bones are posed now), then steps one tick
## and presents it. Call once per process frame.
func advance() -> void:
	if tick > 0 and check_view:
		_record_all(view_checks.check_frame())
	var started := Time.get_ticks_usec()
	level.step_tick()
	var stepped := Time.get_ticks_usec()
	level.present_frame(1.0, FRAME_SECONDS)
	view_usec += Time.get_ticks_usec() - stepped
	sim_usec += stepped - started
	tick += 1
	var sim := level.sim
	_record_all(QaSimChecks.check_tick(sim))
	_record_all(QaSimChecks.check_overlap(sim))
	for event: Dictionary in sim.events:
		_count_ki(event)
		if event.type == CombatSim.EventType.KO:
			kos += 1
		if event.type in [CombatSim.EventType.HIT, CombatSim.EventType.COUNTER] and event.has("hitstop"):
			var key := "%s%s" % [event.move_id, "+counter" if event.counter else ""]
			var counts: Dictionary = hitstops.get_or_add(key, {})
			counts[event.hitstop] = int(counts.get(event.hitstop, 0)) + 1
	var phase := level.match_flow.phase
	if phase != _phase and phase == MatchFlow.Phase.INTRO:
		rounds_started += 1
		_record_all(QaSimChecks.check_round_reset(sim, sim.spawn_points))
	if phase == MatchFlow.Phase.KO and _phase == MatchFlow.Phase.FIGHT and not sim.round_over \
			and not level.match_flow.timed_out:
		_record({"check": "round_reset", "fighter": -1, "value": 0, "limit": 0,
			"detail": "KO phase without the sim's round over"})
	_phase = phase


## Match-level checks once it is over (or cut off).
func finish() -> void:
	if check_view:
		_record_all(view_checks.pop_budget())
		_record_all(view_checks.framing_share())


func result() -> Dictionary:
	var list: Array = violations.values()
	return {
		"id": spec.id(), "seed": spec.seed_value, "zone": String(spec.zone), "mode": String(spec.mode),
		"legends": spec.legends.map(func(l: StringName) -> String: return String(l)), "levels": spec.levels,
		"ticks": tick, "rounds_started": rounds_started, "kos": kos,
		"match_over": is_over(), "phase": MatchFlow.Phase.find_key(level.match_flow.phase),
		"sim_ms_per_tick": sim_usec / 1000.0 / maxf(tick, 1),
		"view_ms_per_frame": view_usec / 1000.0 / maxf(tick, 1),
		"view": view_checks.metrics() if check_view else {},
		"hitstops": hitstops,
		"ki": ki_usage,
		"overlap_pending": pending_overlap,
		"violations": list,
	}


func _count_ki(event: Dictionary) -> void:
	var E := CombatSim.EventType
	match event.type:
		E.KI_FIRE:
			ki_usage[&"charged" if event.get("shot", 0) == KiRules.Shot.CHARGED else &"blasts"] += 1
		E.BEAM_START:
			ki_usage[&"ultimates" if event.move_id == &"beam_ultimate" else &"beams"] += 1
		E.BEAM_CLASH:
			ki_usage.clashes += 1
		E.KI_ABSORB:
			ki_usage.soaks += 1
		E.BEAM_END:
			if event.get("whiff", false):
				ki_usage.beam_whiffs += 1
		E.PROJECTILE_HIT:
			if event.get("weapon", -1) == Weapon.Kind.NONE and event.get("reflected", false):
				ki_usage.reflects += 1
		E.HIT, E.COUNTER:
			if String(event.get("move_id", "")) in ["ki_blast", "charged_blast", "beam", "beam_ultimate"]:
				ki_usage.ki_hits += 1


func _record_all(found: Array[Dictionary]) -> void:
	for v in found:
		_record(v)


func _record(v: Dictionary) -> void:
	var key := "%s#%d" % [v.check, v.fighter]
	var fighter: int = v.fighter
	var entry: Dictionary = violations.get(key, {})
	if entry.is_empty():
		entry = {"check": v.check, "fighter": fighter, "count": 0, "first_tick": tick,
			"worst_tick": tick, "worst_value": v.value, "limit": v.limit, "detail": v.detail,
			"legend": String(spec.legends[fighter]) if fighter >= 0 else "",
			"weapon": _weapon_of(fighter)}
		violations[key] = entry
	entry.count += 1
	if _worse(v.value, entry.worst_value, v.limit):
		entry.worst_value = v.value
		entry.worst_tick = tick
		entry.detail = v.detail
		entry.weapon = _weapon_of(fighter)


func _weapon_of(fighter: int) -> String:
	if fighter < 0 or fighter >= level.sim.fighters.size():
		return ""
	var kind := level.sim.fighters[fighter].held_weapon()
	return "" if kind == Weapon.Kind.NONE else String(Weapon.weapon_name(kind))


static func _worse(value: Variant, worst: Variant, limit: Variant) -> bool:
	if not (value is float or value is int) or not (worst is float or worst is int):
		return false
	return absf(float(value) - float(limit)) > absf(float(worst) - float(limit))
